import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/ble_disc_measurement.dart';

/// BLE Service for Windows Desktop
/// Handles ESP32 connection with Windows-specific quirks:
/// - Service UUID filtering (Windows may report empty device names)
/// - Newline-framed buffering (critical for Windows notification fragmentation)
/// - Single connection handling (Windows allows one BLE connection at a time)
/// - Graceful disconnect recovery
class BleDiscService {
  // ==================== Configuration ====================
  
  /// ESP32 Service UUID - CHANGE THIS to match your ESP32
  static const String serviceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  
  /// ESP32 Characteristic UUID for notifications - CHANGE THIS to match your ESP32
  static const String characteristicUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
  
  /// Device name filter (fallback - may be empty on Windows)
  static const String deviceNameFilter = "SmartDisc";
  
  /// Scan timeout
  static const Duration scanTimeout = Duration(seconds: 15);
  
  // ==================== State ====================
  
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _notificationSubscription;
  
  /// Buffer for incomplete messages (CRITICAL for Windows)
  String _messageBuffer = '';
  
  /// Stream controller for found devices
  final StreamController<List<BluetoothDevice>> _foundDevicesController =
      StreamController<List<BluetoothDevice>>.broadcast();
  
  /// List of found devices
  final List<BluetoothDevice> _foundDevices = [];
  
  /// Stream controller for parsed measurements
  final StreamController<BleDiscMeasurement> _measurementController =
      StreamController<BleDiscMeasurement>.broadcast();
  
  /// Stream controller for connection state
  final StreamController<BleConnectionState> _connectionStateController =
      StreamController<BleConnectionState>.broadcast();
  
  /// Stream controller for errors
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  
  // ==================== Public Streams ====================
  
  Stream<BleDiscMeasurement> get measurements => _measurementController.stream;
  Stream<BleConnectionState> get connectionState => _connectionStateController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<List<BluetoothDevice>> get foundDevices => _foundDevicesController.stream;
  
  bool get isConnected => _connectedDevice != null;
  String get connectedDeviceName => _connectedDevice?.platformName ?? 'Unknown';
  
  // ==================== Public Methods ====================
  
  /// Initialize BLE (check if Bluetooth is available)
  Future<bool> initialize() async {
    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        _errorController.add("Bluetooth not supported on this device");
        return false;
      }
      
      // Check if Bluetooth is enabled
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _errorController.add("Bluetooth is disabled. Enable it in Windows Settings.");
        return false;
      }
      
      return true;
    } catch (e) {
      _errorController.add("BLE initialization failed: $e");
      return false;
    }
  }
  
  /// Scan for ESP32 device
  /// Uses service UUID filtering (critical for Windows)
  Future<BluetoothDevice?> scanForDevice() async {
    try {
      _connectionStateController.add(BleConnectionState.scanning);
      
      _foundDevices.clear();
      BluetoothDevice? foundDevice;
      
      // Start scanning with service UUID filter
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          // Primary filter: Service UUID (Windows-safe)
          final hasTargetService = result.advertisementData.serviceUuids
              .any((uuid) => uuid.toString().toLowerCase() == serviceUuid.toLowerCase());
          
          // Secondary filter: Device name (may be empty on Windows)
          final hasTargetName = result.device.platformName.isNotEmpty &&
              result.device.platformName.contains(deviceNameFilter);
          
          if (hasTargetService || hasTargetName) {
            // ignore: avoid_print
            print("Found device: ${result.device.platformName} (${result.device.remoteId})");
            // ignore: avoid_print
            print("Services: ${result.advertisementData.serviceUuids}");
            
            // Add to found devices if not already there
            if (!_foundDevices.any((d) => d.remoteId == result.device.remoteId)) {
              _foundDevices.add(result.device);
              _foundDevicesController.add(List.from(_foundDevices));
            }
            
            foundDevice = result.device;
          }
        }
      });
      
      // Start scan
      await FlutterBluePlus.startScan(
        timeout: scanTimeout,
        withServices: [Guid(serviceUuid)], // Filter by service UUID
      );
      
      // Wait for scan to complete
      await Future.delayed(scanTimeout);
      await FlutterBluePlus.stopScan();
      await subscription.cancel();
      
      if (foundDevice == null) {
        _errorController.add("ESP32 not found. Ensure it's powered on and advertising.");
        _connectionStateController.add(BleConnectionState.disconnected);
      }
      
      return foundDevice;
    } catch (e) {
      _errorController.add("Scan failed: $e");
      _connectionStateController.add(BleConnectionState.disconnected);
      return null;
    }
  }
  
  /// Connect to device and enable notifications
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _connectionStateController.add(BleConnectionState.connecting);
      
      // Connect (Windows allows only ONE connection at a time)
      await device.connect(timeout: const Duration(seconds: 15));
      _connectedDevice = device;
      
      // ignore: avoid_print
      print("Connected to ${device.platformName}");
      
      // Discover services
      final services = await device.discoverServices();
      
      // Find target service
      BluetoothService? targetService;
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          targetService = service;
          break;
        }
      }
      
      if (targetService == null) {
        throw Exception("Service $serviceUuid not found");
      }
      
      // Find notify characteristic
      BluetoothCharacteristic? notifyChar;
      for (var char in targetService.characteristics) {
        if (char.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
          notifyChar = char;
          break;
        }
      }
      
      if (notifyChar == null) {
        throw Exception("Characteristic $characteristicUuid not found");
      }
      
      // Enable notifications (CRITICAL)
      await notifyChar.setNotifyValue(true);
      
      // Subscribe to notifications with buffering
      _notificationSubscription = notifyChar.lastValueStream.listen(
        _handleNotification,
        onError: (error) {
          _errorController.add("Notification error: $error");
        },
      );
      
      // Listen for disconnects
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });
      
      _connectionStateController.add(BleConnectionState.connected);
      // ignore: avoid_print
      print("Notifications enabled");
      
      return true;
    } catch (e) {
      _errorController.add("Connection failed: $e");
      await disconnect();
      return false;
    }
  }
  
  /// Scan and connect in one step
  Future<bool> scanAndConnect() async {
    final device = await scanForDevice();
    if (device == null) return false;
    return await connectToDevice(device);
  }
  
  /// Disconnect from device
  Future<void> disconnect() async {
    try {
      await _notificationSubscription?.cancel();
      _notificationSubscription = null;
      
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
      }
      
      _messageBuffer = ''; // Clear buffer
      
      _connectionStateController.add(BleConnectionState.disconnected);
    } catch (e) {
      _errorController.add("Disconnect error: $e");
    }
  }
  
  /// Dispose resources
  void dispose() {
    disconnect();
    _measurementController.close();
    _connectionStateController.close();
    _errorController.close();
    _foundDevicesController.close();
  }
  
  // ==================== Private Methods ====================
  
  /// Handle incoming notification with newline-based framing
  /// CRITICAL: Windows can fragment notifications
  void _handleNotification(List<int> value) {
    try {
      // Decode bytes to UTF-8 text
      final textChunk = utf8.decode(value);
      
      // Append to buffer
      _messageBuffer += textChunk;
      
      // Process complete messages (split by newline)
      final lines = _messageBuffer.split('\n');
      
      // Last element might be incomplete, keep it in buffer
      _messageBuffer = lines.last;
      
      // Process complete lines (all except last)
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          _parseMessage(line);
        }
      }
    } catch (e) {
      _errorController.add("Notification decode error: $e");
    }
  }
  
  /// Parse JSON message
  void _parseMessage(String message) {
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      final measurement = BleDiscMeasurement.fromJson(json);
      
      // ignore: avoid_print
      print("Received: $measurement");
      _measurementController.add(measurement);
    } catch (e) {
      _errorController.add("JSON parse error: $e | Raw: $message");
    }
  }
  
  /// Handle disconnect
  void _handleDisconnect() {
    // ignore: avoid_print
    print("Device disconnected");
    _connectedDevice = null;
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _messageBuffer = ''; // Clear buffer
    
    _connectionStateController.add(BleConnectionState.disconnected);
    _errorController.add("Device disconnected. Rescan to reconnect.");
  }
}

/// BLE Connection States
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}

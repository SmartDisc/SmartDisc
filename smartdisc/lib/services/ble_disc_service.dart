import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/ble_disc_measurement.dart';
import 'api_service.dart';

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
  static const String deviceNameFilter = "Bodenstation-ESP32";
  
  /// Scan timeout
  static const Duration scanTimeout = Duration(seconds: 15);
  
  // ==================== State ====================
  
  final ApiService _apiService = ApiService();
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _notificationSubscription;
  
  /// Buffer for incomplete messages (CRITICAL for Windows)
  String _messageBuffer = '';
  
  /// Track saved measurements count
  int _savedCount = 0;
  
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
  
  /// Stream controller for saved count
  final StreamController<int> _savedCountController =
      StreamController<int>.broadcast();
  
  // ==================== Public Streams ====================
  
  Stream<BleDiscMeasurement> get measurements => _measurementController.stream;
  Stream<BleConnectionState> get connectionState => _connectionStateController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<List<BluetoothDevice>> get foundDevices => _foundDevicesController.stream;
  Stream<int> get savedCount => _savedCountController.stream;
  
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
          
          // Secondary filter: Device name (ESP32 or SmartDisc)
          final hasTargetName = result.device.platformName.isNotEmpty &&
              (result.device.platformName.contains("ESP") || 
               result.device.platformName.contains(deviceNameFilter));
          
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
      
      // Start scan (removed service UUID filter to find all devices)
      await FlutterBluePlus.startScan(
        timeout: scanTimeout,
      );
      
      // Wait for scan to complete
      await Future.delayed(scanTimeout);
      await FlutterBluePlus.stopScan();
      await subscription.cancel();
      
      if (foundDevice == null) {
        _errorController.add("ESP32 not found. Ensure it's powered on and advertising.");
        _connectionStateController.add(BleConnectionState.disconnected);
        return null;
      }
      
      // Device found successfully
      _connectionStateController.add(BleConnectionState.disconnected);
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
      
      // Connected successfully
      _errorController.add("Connected to ${device.platformName}");
      
      // CRITICAL: Wait a bit after connection on Windows before discovering services
      // Windows BLE stack needs time to establish the connection fully
      await Future.delayed(const Duration(milliseconds: 500));
      
      // On Windows, discoverServices() may fail with SecurityError
      // Try to discover services, but handle gracefully if blocked
      List<BluetoothService> services = [];
      try {
        services = await device.discoverServices();
      } catch (e) {
        // Service discovery failed, will attempt fallback
        _errorController.add("Service discovery failed: $e");
      }
      
      // Find target service (if we got services)
      BluetoothService? targetService;
      if (services.isNotEmpty) {
        for (var service in services) {
          if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
            targetService = service;
            break;
          }
        }
      }
      
      // Find notify characteristic
      BluetoothCharacteristic? notifyChar;
      
      if (targetService != null) {
        // Found service, look for characteristic
        for (var char in targetService.characteristics) {
          if (char.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
            notifyChar = char;
            break;
          }
        }
      }
      
      // If not found in target service, search all services
      if (notifyChar == null && services.isNotEmpty) {
        for (var service in services) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              notifyChar = char;
              break;
            }
          }
          if (notifyChar != null) break;
        }
      }
      
      // If still not found, try to get services again (Windows sometimes needs retry)
      if (notifyChar == null) {
        try {
          await Future.delayed(const Duration(milliseconds: 500));
          services = await device.discoverServices();
          
          for (var service in services) {
            for (var char in service.characteristics) {
              if (char.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
                notifyChar = char;
                break;
              }
            }
            if (notifyChar != null) break;
          }
        } catch (e) {
          // Retry failed, will report detailed error below
        }
      }
      
      if (notifyChar == null) {
        // Provide detailed error message with discovered services
        final serviceList = services.map((s) => s.uuid.toString()).join(', ');
        throw Exception(
          "Cannot access characteristic $characteristicUuid.\n"
          "Service: $serviceUuid\n"
          "Device: ${device.platformName}\n"
          "Discovered services: ${serviceList.isEmpty ? 'none' : serviceList}\n"
          "Tip: Verify ESP32 is advertising this service and characteristic."
        );
      }
      
      // Verify the characteristic supports notifications
      if (!notifyChar.properties.notify && !notifyChar.properties.indicate) {
        throw Exception(
          "Characteristic $characteristicUuid does not support notifications.\n"
          "Properties: ${notifyChar.properties}"
        );
      }
      
      // Enable notifications (CRITICAL)
      // On Windows, sometimes notifications need to be enabled with a small delay
      try {
        // Enable notifications
        await notifyChar.setNotifyValue(true);
        
        // Wait a bit for Windows to process the notification enable
        await Future.delayed(const Duration(milliseconds: 300));
        
        // ignore: avoid_print
        print("Notifications enabled on characteristic $characteristicUuid");
      } catch (e) {
        throw Exception("Failed to enable notifications: $e");
      }
      
      // Subscribe to notifications with buffering
      // Use lastValueStream which is the standard stream for notifications
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
      _errorController.add("Failed to connect to ESP32: $e");
      _connectionStateController.add(BleConnectionState.disconnected);
      await disconnect();
      return false;
    }
  }
  
  /// Scan and connect in one step
  Future<bool> scanAndConnect() async {
    final device = await scanForDevice();
    if (device == null) {
      // Error already added by scanForDevice
      return false;
    }
    
    // Device found, now try to connect
    final connected = await connectToDevice(device);
    if (!connected) {
      // Error already added by connectToDevice
      return false;
    }
    
    return true;
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
      _savedCount = 0; // Reset counter
      
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
    _savedCountController.close();
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
  
  /// Parse JSON message and save to database
  void _parseMessage(String message) {
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      final measurement = BleDiscMeasurement.fromJson(json);
      
      // ignore: avoid_print
      print("Received: $measurement");
      _measurementController.add(measurement);
      
      // Save to database (async, don't block)
      _saveToDatabase(measurement);
    } catch (e) {
      _errorController.add("JSON parse error: $e | Raw: $message");
    }
  }
  
  /// Save measurement to database
  Future<void> _saveToDatabase(BleDiscMeasurement measurement) async {
    try {
      await _apiService.createThrow(
        scheibeId: measurement.scheibeId,
        rotation: measurement.rotation,
        height: measurement.hoehe,
        accelerationMax: measurement.accelerationMax ?? 0.0,
      );
      
      _savedCount++;
      _savedCountController.add(_savedCount);
      
      // ignore: avoid_print
      print("Saved to database: Throw #$_savedCount");
    } catch (e) {
      _errorController.add("Failed to save throw to database: $e");
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

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
  
  /// ESP32 Service UUID - matches your ESP32 configuration
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  
  /// ESP32 Characteristic UUID for notifications (TX) - matches your ESP32 configuration
  static const String characteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  
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
      
      // Request Bluetooth permissions (Android 12+ requirement)
      try {
        // Try to turn on Bluetooth if off (this also requests permissions)
        if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
          _errorController.add("Please enable Bluetooth in your device settings");
          return false;
        }
      } catch (e) {
        // Permission denied or other error
        _errorController.add("Bluetooth permission denied. Enable in Settings.");
        return false;
      }
      
      return true;
    } catch (e) {
      _errorController.add("BLE initialization failed: $e");
      return false;
    }
  }
  
  /// Scan for ESP32 devices only
  /// Filters by device name since Android doesn't reliably advertise service UUIDs
  Future<bool> scanForDevices() async {
    try {
      _connectionStateController.add(BleConnectionState.scanning);
      
      _foundDevices.clear();
      final List<BluetoothDevice> allDevices = [];
      
      // Start scanning
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (var result in results) {
          // Log all devices for debugging
          // ignore: avoid_print
          print("Scanned device: ${result.device.platformName} (${result.device.remoteId})");
          // ignore: avoid_print
          print("  Services: ${result.advertisementData.serviceUuids}");
          
          // Track all devices
          if (!allDevices.any((d) => d.remoteId == result.device.remoteId)) {
            allDevices.add(result.device);
          }
          
          // Filter: only ESP devices
          final deviceName = result.device.platformName.toLowerCase();
          final isESP = deviceName.contains("esp") || 
                       deviceName.contains("smartdisc") ||
                       deviceName.contains("bodenstation");
          
          if (isESP && !_foundDevices.any((d) => d.remoteId == result.device.remoteId)) {
            // ignore: avoid_print
            print("✓ ESP device found: ${result.device.platformName}");
            _foundDevices.add(result.device);
            _foundDevicesController.add(List.from(_foundDevices));
          }
        }
      });
      
      // Start scan (no filters - find everything, filter in code)
      await FlutterBluePlus.startScan(
        timeout: scanTimeout,
      );
      
      // Wait for scan to complete
      await Future.delayed(scanTimeout);
      await FlutterBluePlus.stopScan();
      await subscription.cancel();
      
      _connectionStateController.add(BleConnectionState.disconnected);
      
      if (_foundDevices.isEmpty) {
        _errorController.add(
          "No ESP32 device found.\n"
          "Scanned ${allDevices.length} device(s).\n"
          "Ensure ESP32 name contains 'ESP', 'SmartDisc', or 'Bodenstation'."
        );
        return false;
      }
      
      // ignore: avoid_print
      print("Found ${_foundDevices.length} ESP device(s)");
      return true;
    } catch (e) {
      _errorController.add("Scan failed: $e");
      _connectionStateController.add(BleConnectionState.disconnected);
      return false;
    }
  }
  
  /// Get list of found devices for manual selection
  List<BluetoothDevice> getFoundDevices() {
    return List.from(_foundDevices);
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
      try {
        // Enable notifications
        await notifyChar.setNotifyValue(true);
        
        // Wait a bit to ensure notifications are enabled
        await Future.delayed(const Duration(milliseconds: 300));
        
        // ignore: avoid_print
        print("Notifications enabled on characteristic $characteristicUuid");
      } catch (e) {
        throw Exception("Failed to enable notifications: $e");
      }
      
      // Subscribe to notifications - use onValueReceived for flutter_blue_plus
      // ignore: avoid_print
      print("Setting up notification listener...");
      _notificationSubscription = notifyChar.onValueReceived.listen(
        (value) {
          // ignore: avoid_print
          print("Raw notification received: ${value.length} bytes");
          _handleNotification(value);
        },
        onError: (error) {
          _errorController.add("Notification error: $error");
          // ignore: avoid_print
          print("Notification stream error: $error");
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
  
  /// Scan for ESP devices and auto-connect if only one found
  Future<bool> scanAndConnect() async {
    final success = await scanForDevices();
    if (!success) return false;
    
    // Auto-connect if only one ESP device found
    if (_foundDevices.length == 1) {
      // ignore: avoid_print
      print("Auto-connecting to ${_foundDevices[0].platformName}");
      return await connectToDevice(_foundDevices[0]);
    }
    
    // Multiple devices found - user needs to select
    // Return true to indicate scan succeeded, but connection needs manual selection
    return true;
  }
  
  /// Connect to a specific device by index
  Future<bool> connectToDeviceByIndex(int index) async {
    if (index < 0 || index >= _foundDevices.length) {
      _errorController.add("Invalid device index");
      return false;
    }
    
    final device = _foundDevices[index];
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
  /// CRITICAL: Windows/Android can fragment notifications
  void _handleNotification(List<int> value) {
    try {
      // Decode bytes to UTF-8 text
      final textChunk = utf8.decode(value);
      
      // ignore: avoid_print
      print("Decoded text: '$textChunk'");
      
      // Append to buffer
      _messageBuffer += textChunk;
      
      // Process complete messages (split by newline)
      final lines = _messageBuffer.split('\n');
      
      // ignore: avoid_print
      print("Buffer has ${lines.length} lines, buffer='$_messageBuffer'");
      
      // Last element might be incomplete, keep it in buffer
      _messageBuffer = lines.last;
      
      // Process complete lines (all except last)
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          // ignore: avoid_print
          print("Processing line: '$line'");
          _parseMessage(line);
        }
      }
    } catch (e) {
      _errorController.add("Notification decode error: $e");
      // ignore: avoid_print
      print("Decode error: $e");
    }
  }
  
  /// Parse JSON message and save to database
  void _parseMessage(String message) {
    try {
      // ignore: avoid_print
      print("Attempting to parse JSON: $message");
      
      final json = jsonDecode(message) as Map<String, dynamic>;
      final measurement = BleDiscMeasurement.fromJson(json);
      
      // ignore: avoid_print
      print("✓ Parsed successfully: $measurement");
      _measurementController.add(measurement);
      
      // Save to database (async, don't block)
      _saveToDatabase(measurement);
    } catch (e) {
      final errorMsg = "JSON parse error: $e | Raw: $message";
      _errorController.add(errorMsg);
      // ignore: avoid_print
      print(errorMsg);
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

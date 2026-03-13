import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/ble_disc_measurement.dart';
import 'api_service.dart';

class RawDataLog {
  final DateTime timestamp;
  final String type;
  final String? title;
  final String? message;

  RawDataLog({required this.timestamp, required this.type, this.title, this.message});

  factory RawDataLog.now({required String type, String? title, String? message}) =>
      RawDataLog(timestamp: DateTime.now(), type: type, title: title, message: message);
}

/// BLE Service for Windows Desktop
/// Handles ESP32 connection with Windows-specific quirks:
/// - Service UUID filtering (Windows may report empty device names)
/// - Newline-framed buffering (critical for Windows notification fragmentation)
/// - Single connection handling (Windows allows one BLE connection at a time)
/// - Graceful disconnect recovery
class BleDiscService {
  // ==================== Configuration ====================
  
  /// ESP32 Service UUID - matches your ESP32 configuration
  /// NOTE: This must exactly match the ESP32 firmware.
  /// Common SmartDisc/ESP32 examples use this value.
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

  /// Currently selected/active disc ID in the app.
  /// When set, only BLE measurements whose `scheibeId` matches this ID
  /// will be forwarded to the UI and backend.
  String? _activeDiscId;
  
  /// Track saved measurements count (kept for backwards compatibility; updated externally).
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
  
  /// Stream controller for raw data logs (debug)
  final StreamController<RawDataLog> _rawLogController =
      StreamController<RawDataLog>.broadcast();
  
  // ==================== Public Streams ====================
  
  Stream<BleDiscMeasurement> get measurements => _measurementController.stream;
  Stream<BleConnectionState> get connectionState => _connectionStateController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<List<BluetoothDevice>> get foundDevices => _foundDevicesController.stream;
  Stream<int> get savedCount => _savedCountController.stream;
  Stream<RawDataLog> get rawLogs => _rawLogController.stream;
  
  bool get isConnected => _connectedDevice != null;
  String get connectedDeviceName => _connectedDevice?.platformName ?? 'Unknown';

  /// Set or clear the currently active disc ID.
  /// IMPORTANT: If `null`, NO measurements will be forwarded.
  void setActiveDiscId(String? discId) {
    _activeDiscId = discId;
    _logRaw(
      'connection',
      title: 'Active disc changed',
      message: discId == null
          ? 'No active disc selected – all incoming BLE packets will be discarded.'
          : 'Now accepting only measurements for disc ID "$discId".',
    );
  }
  
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
  /// Uses a two-pass strategy:
  /// 1) Service-filtered scan (fast, strict)
  /// 2) Keyword fallback scan (more tolerant when service UUID isn't advertised)
  Future<bool> scanForDevices() async {
    try {
      _connectionStateController.add(BleConnectionState.scanning);

      _foundDevices.clear();
      _foundDevicesController.add(List.from(_foundDevices));

      final List<BluetoothDevice> allDevices = [];

      bool isEspDevice(BluetoothDevice device, List<Guid> advertisedServices) {
        final deviceName = device.platformName.toLowerCase();
        final lowerServices =
            advertisedServices.map((s) => s.toString().toLowerCase()).toList();
        final bool matchesService =
            lowerServices.contains(serviceUuid.toLowerCase());
        return deviceName.contains("esp") ||
            deviceName.contains("smartdisc") ||
            deviceName.contains("bodenstation") ||
            matchesService;
      }

      void addIfEspDevice(BluetoothDevice device, List<Guid> advertisedServices) {
        if (!allDevices.any((d) => d.remoteId == device.remoteId)) {
          allDevices.add(device);
        }

        if (isEspDevice(device, advertisedServices) &&
            !_foundDevices.any((d) => d.remoteId == device.remoteId)) {
          _logRaw(
            'connection',
            title: '✓ ESP device found',
            message: device.platformName.isEmpty
                ? device.remoteId.toString()
                : device.platformName,
          );
          _foundDevices.add(device);
          _foundDevicesController.add(List.from(_foundDevices));
        }
      }

      // On native platforms, pre-populate with already-connected system devices.
      if (!kIsWeb) {
        try {
          final knownDevices =
              await FlutterBluePlus.systemDevices([Guid(serviceUuid)]);
          for (final device in knownDevices) {
            addIfEspDevice(device, const []);
          }
        } catch (_) {
          // Non-fatal.
        }
      }

      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          _logRaw(
            'connection',
            title: 'Device scanned',
            message:
                '${result.device.platformName} (${result.device.remoteId})\n  Services: ${result.advertisementData.serviceUuids}',
          );

          addIfEspDevice(result.device, result.advertisementData.serviceUuids);
        }
      });

      // Ensure no stale scan is running.
      await FlutterBluePlus.stopScan();

      // Primary scan.
      // On web, Chrome ORs service-UUID filter with name filters, so including
      // device names gives the picker a second way to match the ESP32 even when
      // the service UUID is absent from the advertisement packet.
      await FlutterBluePlus.startScan(
        timeout: scanTimeout,
        withServices: [Guid(serviceUuid)],
        withNames: ['Bodenstation-ESP32', 'SmartDisc', 'ESP32'],
        webOptionalServices: [Guid(serviceUuid)],
      );
      await Future.delayed(scanTimeout);
      await FlutterBluePlus.stopScan();

      // Keyword fallback (native only – Web Bluetooth does not support keyword filtering).
      if (_foundDevices.isEmpty && !kIsWeb) {
        _logRaw(
          'connection',
          title: 'Scan fallback',
          message:
              'No ESP found with service filter. Retrying with keyword scan.',
        );

        await FlutterBluePlus.startScan(
          timeout: scanTimeout,
          withKeywords: const ['esp', 'smartdisc', 'bodenstation'],
        );
        await Future.delayed(scanTimeout);
        await FlutterBluePlus.stopScan();
      }

      await subscription.cancel();

      _connectionStateController.add(BleConnectionState.disconnected);

      if (_foundDevices.isEmpty) {
        _errorController.add(
          "No ESP32 device found.\n"
          "Scanned ${allDevices.length} device(s).\n"
          "Try moving closer, waiting 5-10s, then scanning again."
        );
        return false;
      }

      _logRaw(
        'connection',
        title: 'Scan complete',
        message: 'Found ${_foundDevices.length} ESP device(s)',
      );
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
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 15),
      );
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
      // Some ESP32 + browser/adapter combinations need longer CCCD write time
      // or a second try after fresh service discovery.
      try {
        await notifyChar.setNotifyValue(true, timeout: 30);
      } catch (firstError) {
        _logRaw(
          'error',
          title: 'Notify enable attempt 1 failed',
          message: firstError.toString(),
        );

        await Future.delayed(const Duration(milliseconds: 700));

        // Retry after rediscovery to refresh stale characteristic handles.
        try {
          final retryServices = await device.discoverServices();
          BluetoothCharacteristic? retryNotifyChar;
          for (final service in retryServices) {
            for (final char in service.characteristics) {
              if (char.uuid.toString().toLowerCase() ==
                  characteristicUuid.toLowerCase()) {
                retryNotifyChar = char;
                break;
              }
            }
            if (retryNotifyChar != null) break;
          }
          if (retryNotifyChar != null) {
            notifyChar = retryNotifyChar;
          }

          await notifyChar.setNotifyValue(true, timeout: 30);
        } catch (secondError) {
          throw Exception(
            "Failed to enable notifications after retry: $secondError (first attempt: $firstError)",
          );
        }
      }

      // Wait a bit to ensure notifications are enabled
      await Future.delayed(const Duration(milliseconds: 300));

      _logRaw('connection', 
        title: 'Notifications enabled',
        message: 'Characteristic: $characteristicUuid'
      );
      
      // Subscribe to notifications - use onValueReceived for flutter_blue_plus
      _logRaw('connection', title: 'Setting up notification listener');
      _notificationSubscription = notifyChar.onValueReceived.listen(
        (value) {
          _logRaw('raw', 
            title: 'Raw BLE packet',
            message: 'Received ${value.length} bytes: ${utf8.decode(value)}'
          );
          _handleNotification(value);
        },
        onError: (error) {
          if (!_errorController.isClosed) {
            _errorController.add("Notification error: $error");
          }
          _logRaw('error', 
            title: 'Notification stream error',
            message: error.toString()
          );
        },
      );
      
      // Listen for disconnects
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });
      
      _connectionStateController.add(BleConnectionState.connected);
      _logRaw('connection', 
        title: '✓ Connected successfully',
        message: 'Device: ${device.platformName}'
      );
      
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
      _logRaw('connection', 
        title: 'Auto-connecting',
        message: _foundDevices[0].platformName
      );
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
      
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(BleConnectionState.disconnected);
      }
    } catch (e) {
      if (!_errorController.isClosed) {
        _errorController.add("Disconnect error: $e");
      }
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
    _rawLogController.close();
  }
  
  // ==================== Private Methods ====================
  
  /// Log raw data for debugging
  void _logRaw(String type, {String? title, String? message}) {
    if (!_rawLogController.isClosed) {
      _rawLogController.add(RawDataLog.now(
        type: type,
        title: title,
        message: message,
      ));
    }
  }
  
  /// Handle incoming notification with newline-based framing
  /// CRITICAL: Windows/Android can fragment notifications
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
      _logRaw('error', 
        title: 'Decode error',
        message: e.toString()
      );
    }
  }
  
  /// Parse JSON message and add to batch
  void _parseMessage(String message) {
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      final measurement = BleDiscMeasurement.fromJson(json);

      // Normalize IDs for robust comparison
      final incomingId = (measurement.scheibeId).trim();
      final activeId = (_activeDiscId ?? '').trim();

      // If no active disc is selected, discard everything (safety).
      if (activeId.isEmpty) {
        final msg =
            'Received disc ID "$incomingId" while no active disc is selected.';
        _logRaw(
          'error',
          title: 'Discarded measurement (no active disc)',
          message: msg,
        );
        if (!_errorController.isClosed) {
          _errorController.add(msg);
        }
        return;
      }

      // Enforce disc ID match before doing anything else.
      if (incomingId != activeId) {
        final msg =
            'Discarded measurement: active disc "$activeId", received "$incomingId".';
        _logRaw(
          'error',
          title: 'Discarded measurement (disc ID mismatch)',
          message: msg,
        );
        if (!_errorController.isClosed) {
          _errorController.add(msg);
        }
        return;
      }
      
      // At this point, the packet is accepted and will be forwarded.
      _logRaw(
        'success',
        title: 'Accepted measurement',
        message:
            'Disc ${measurement.scheibeId} | height=${measurement.hoehe.toStringAsFixed(3)} m, '
            'rotation=${measurement.rotation.toStringAsFixed(2)}, '
            'accelMax=${measurement.accelerationMax?.toStringAsFixed(2) ?? '-'}',
      );

      if (!_measurementController.isClosed) {
        _measurementController.add(measurement);
      }
      
      // Log successful parse
      _logRaw(
        'success',
        title: '✓ Measurement parsed',
        message: 'Disc #${measurement.scheibeId}: Rot=${measurement.rotation.toStringAsFixed(2)} rps, H=${measurement.hoehe.toStringAsFixed(2)} m',
      );
    } catch (e) {
      final errorMsg = "JSON parse error: $e | Raw: $message";
      if (!_errorController.isClosed) {
        _errorController.add(errorMsg);
      }
      _logRaw('error', 
        title: 'JSON parse failed',
        message: 'Error: $e\nRaw: $message'
      );
    }
  }
  
  /// Legacy no-op hooks kept for backwards compatibility.
  void _startBatchTimer() {}
  void _stopBatchTimer() {}
  Future<void> _sendBatch() async {}
  
  /// Handle disconnect
  void _handleDisconnect() {
    _logRaw('connection', 
      title: 'Device disconnected',
      message: 'Connection lost'
    );
    _connectedDevice = null;
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _messageBuffer = ''; // Clear buffer
    
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(BleConnectionState.disconnected);
    }
    if (!_errorController.isClosed) {
      _errorController.add("Device disconnected. Rescan to reconnect.");
    }
  }
}

/// BLE Connection States
enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
}

import 'package:flutter/material.dart';
import '../services/ble_disc_service.dart';
import '../models/ble_disc_measurement.dart';

/// Example screen showing how to use BLE service on Windows
///
/// Usage:
/// 1. Press "Scan & Connect" to find ESP32
/// 2. Measurements will appear in real-time
/// 3. Press "Disconnect" to stop
class BleTestScreen extends StatefulWidget {
  const BleTestScreen({super.key});

  @override
  State<BleTestScreen> createState() => _BleTestScreenState();
}

class _BleTestScreenState extends State<BleTestScreen> {
  final BleDiscService _bleService = BleDiscService();

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  final List<BleDiscMeasurement> _measurements = [];
  final List<String> _errors = [];
  List<String> _foundDeviceNames = [];
  bool _isInitialized = false;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    _initBle();
  }

  Future<void> _initBle() async {
    final success = await _bleService.initialize();
    setState(() {
      _isInitialized = success;
    });

    if (!success) {
      _showError(
        "BLE initialization failed. Check Windows Bluetooth settings.",
      );
      return;
    }

    // Listen to connection state
    _bleService.connectionState.listen((state) {
      setState(() {
        _connectionState = state;
      });
    });

    // Listen to measurements
    _bleService.measurements.listen((measurement) {
      setState(() {
        _measurements.insert(0, measurement);
        if (_measurements.length > 50) {
          _measurements.removeLast();
        }
      });
    });

    // Listen to errors
    _bleService.errors.listen((error) {
      setState(() {
        _errors.insert(0, error);
        if (_errors.length > 20) {
          _errors.removeLast();
        }
      });
      _showError(error);
    });

    // Listen to found devices
    _bleService.foundDevices.listen((devices) {
      setState(() {
        _foundDeviceNames = devices
            .map(
              (d) => d.platformName.isNotEmpty
                  ? d.platformName
                  : d.remoteId.toString(),
            )
            .toList();
      });
    });
    
    // Listen to saved count
    _bleService.savedCount.listen((count) {
      setState(() {
        _savedCount = count;
      });
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _scanAndConnect() async {
    setState(() {
      _measurements.clear();
      _errors.clear();
    });

    // Scan for ESP devices
    final success = await _bleService.scanAndConnect();

    if (success && mounted) {
      final devices = _bleService.getFoundDevices();
      
      // If already connected, we're done (auto-connected to single device)
      if (_bleService.isConnected) {
        _showSuccess("Connected to ${_bleService.connectedDeviceName}");
        return;
      }
      
      // Multiple ESP devices found - show selection dialog
      if (devices.length > 1) {
        _showDeviceSelectionDialog();
      }
    }
  }
  
  Future<void> _showDeviceSelectionDialog() async {
    final devices = _bleService.getFoundDevices();
    
    if (devices.isEmpty) {
      _showError("No ESP devices found");
      return;
    }
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select ESP32 Device (${devices.length} found)'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              final name = device.platformName.isNotEmpty 
                  ? device.platformName 
                  : 'Unknown Device';
              final id = device.remoteId.toString();
              
              return ListTile(
                leading: const Icon(Icons.bluetooth, color: Colors.blue),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(id, style: const TextStyle(fontSize: 11)),
                onTap: () async {
                  Navigator.of(context).pop();
                  // Connect to selected device
                  final connected = await _bleService.connectToDeviceByIndex(index);
                  if (connected) {
                    _showSuccess("Connected to $name");
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await _bleService.disconnect();
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return !_isInitialized
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Bluetooth not available',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Enable Bluetooth in Windows Settings',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          )
        : Column(
            children: [
                // Large connection status card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _connectionState == BleConnectionState.connected
                            ? [Colors.green[400]!, Colors.green[600]!]
                            : _connectionState == BleConnectionState.scanning
                                ? [Colors.blue[400]!, Colors.blue[600]!]
                                : [Colors.grey[300]!, Colors.grey[500]!],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (_connectionState ==
                                  BleConnectionState.connected
                              ? Colors.green
                              : Colors.blue)
                              .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _connectionState == BleConnectionState.connected
                                  ? Icons.check_circle
                                  : _connectionState ==
                                          BleConnectionState.scanning
                                      ? Icons.bluetooth_searching
                                      : Icons.bluetooth_disabled,
                              size: 32,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _connectionState ==
                                            BleConnectionState.connected
                                        ? _bleService.connectedDeviceName
                                        : _connectionState ==
                                                BleConnectionState.scanning
                                            ? 'Scanning for devices...'
                                            : 'Not connected',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _connectionState ==
                                            BleConnectionState.connected
                                        ? 'Receiving data in real-time'
                                        : _connectionState ==
                                                BleConnectionState.scanning
                                            ? 'Looking for ESP32 devices...'
                                            : 'Ready to scan and connect',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_foundDeviceNames.isNotEmpty &&
                            _connectionState != BleConnectionState.connected)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available: ${_foundDeviceNames.length} device${_foundDeviceNames.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: _foundDeviceNames
                                      .map(
                                        (name) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withOpacity(0.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.bluetooth,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Saved throws counter (when connected)
                if (_connectionState == BleConnectionState.connected && _savedCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_done, color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$_savedCount throw${_savedCount != 1 ? 's' : ''} saved to History',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_connectionState == BleConnectionState.connected && _savedCount > 0)
                  const SizedBox(height: 16),

                // Control buttons
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _connectionState ==
                                      BleConnectionState.connected ||
                                  _connectionState ==
                                      BleConnectionState.connecting ||
                                  _connectionState ==
                                      BleConnectionState.scanning
                              ? null
                              : _scanAndConnect,
                          icon: const Icon(Icons.bluetooth_searching),
                          label: const Text('Scan & Connect'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _connectionState == BleConnectionState.connected
                              ? _disconnect
                              : null,
                          icon: const Icon(Icons.bluetooth_disabled),
                          label: const Text('Disconnect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Measurements list
                Expanded(
                  child: _measurements.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _connectionState == BleConnectionState.connected
                                    ? Icons.hourglass_empty
                                    : Icons.bluetooth,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _connectionState == BleConnectionState.connected
                                    ? 'Waiting for measurements...\n(${_measurements.length} received)'
                                    : 'Connect to ESP32 to receive data',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _measurements.length,
                          itemBuilder: (context, index) {
                            final m = _measurements[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              elevation: 2,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: Colors.blue[400]!,
                                      width: 4,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue[100],
                                    child: Text(
                                      m.scheibeId,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    'Disc #${m.scheibeId}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Height: ${m.hoehe.toStringAsFixed(3)} m',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              'Rotation: ${m.rotation.toStringAsFixed(2)} rps',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (m.accelerationMax != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Acceleration: ${m.accelerationMax!.toStringAsFixed(2)} m/s²',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.orangeAccent,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Text(
                                    '#${_measurements.length - index}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Data stats bar
                if (_connectionState == BleConnectionState.connected &&
                    _measurements.isNotEmpty)
                  Container(
                    color: Colors.blue[50],
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Measurements',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _measurements.length.toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Latest Height',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${_measurements.first.hoehe.toStringAsFixed(3)} m',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Latest Rotation',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${_measurements.first.rotation.toStringAsFixed(2)} rps',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Error log (collapsible)
                if (_errors.isNotEmpty)
                  Container(
                    color: Colors.red[50],
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Errors:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _errors.length,
                            itemBuilder: (context, index) {
                              return Text(
                                '• ${_errors[index]}',
                                style: const TextStyle(fontSize: 12),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );  // Closes Column - this ends the ternary operator
  }  // Closes build method

  Widget _buildStatusIndicator() {
    final Color color;
    final String text;
    final IconData icon;

    switch (_connectionState) {
      case BleConnectionState.disconnected:
        color = Colors.grey;
        text = 'Disconnected';
        icon = Icons.bluetooth_disabled;
        break;
      case BleConnectionState.scanning:
        color = Colors.orange;
        text = 'Scanning...';
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionState.connecting:
        color = Colors.blue;
        text = 'Connecting...';
        icon = Icons.bluetooth_connected;
        break;
      case BleConnectionState.connected:
        color = Colors.green;
        text = 'Connected';
        icon = Icons.bluetooth_connected;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

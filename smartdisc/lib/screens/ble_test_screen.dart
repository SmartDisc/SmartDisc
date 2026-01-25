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

    final success = await _bleService.scanAndConnect();

    if (success) {
      _showSuccess("Connected to ESP32");
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Test (Windows)'),
        elevation: 2,
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: _buildStatusIndicator()),
          ),
        ],
      ),
      body: !_isInitialized
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
                // Connection info card
                Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: _connectionState == BleConnectionState.connected
                        ? Colors.green[50]
                        : Colors.blue[50],
                    border: Border.all(
                      color: _connectionState == BleConnectionState.connected
                          ? Colors.green
                          : Colors.blue,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color:
                                _connectionState == BleConnectionState.connected
                                ? Colors.green
                                : Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _connectionState ==
                                          BleConnectionState.connected
                                      ? 'Connected to: ${_bleService.connectedDeviceName}'
                                      : 'Connection Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        _connectionState ==
                                            BleConnectionState.connected
                                        ? Colors.green[700]
                                        : Colors.blue[700],
                                  ),
                                ),
                                if (_connectionState ==
                                    BleConnectionState.connected)
                                  Text(
                                    'Receiving data in real-time',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  )
                                else if (_foundDeviceNames.isNotEmpty)
                                  Text(
                                    'Found ${_foundDeviceNames.length} device(s)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
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
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available devices:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: _foundDeviceNames
                                    .map(
                                      (name) => Chip(
                                        label: Text(
                                          name,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        avatar: const Icon(
                                          Icons.bluetooth,
                                          size: 16,
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
            ),
    );
  }

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

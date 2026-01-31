import 'package:bluetooth_connectivity/core/bluetooth/bluetooth_service.dart';
import 'package:bluetooth_connectivity/features/chat/chat_screen.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';
import 'package:bluetooth_connectivity/core/bluetooth/flutter_bluetooth_classic_fixed.dart';

class DiscoveryScreen extends StatefulWidget {
  final bool isServer;
  const DiscoveryScreen({super.key, required this.isServer});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final BluetoothService _bluetoothService = BluetoothService();

  List<BluetoothDevice> _bondedDevices = [];

  @override
  void initState() {
    super.initState();
    // Only Scan if Client (User Chose "Find Devices")
    if (!widget.isServer) {
      _requestPermissionsAndStart();
    } else {
      // Server Logic: User Chose "Make Discoverable"
      _startServer();
    }
  }

  Future<void> _requestPermissionsAndStart() async {
    bool granted = await _bluetoothService.requestPermissions();
    if (granted) {
      _loadBondedDevices();
      _bluetoothService.startDiscovery();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bluetooth permissions denied")),
        );
      }
    }
  }

  Future<void> _loadBondedDevices() async {
    final devices = await _bluetoothService.getBondedDevices();
    if (mounted) {
      setState(() {
        _bondedDevices = devices;
      });
    }
  }

  void _startServer() async {
    // 1. Listen for Host connection success FIRST
    _bluetoothService.serverConnectionStream.listen((isConnected) {
      if (isConnected && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Client Connected!")));

        // Hack: Create a dummy device.
        final dummyDevice = BluetoothDevice(
          address: "Client",
          name: "Client Device",
          paired: false,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(device: dummyDevice),
          ),
        );
      }
    });

    // 2. Start the Native Server
    await _bluetoothService.startServer();
  }

  @override
  void dispose() {
    if (!widget.isServer) {
      _bluetoothService.stopDiscovery();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isServer ? "Waiting for Connection..." : "Scanning...",
        ),
      ),
      body: widget.isServer
          ? Center(
              child: FutureBuilder<String>(
                future: Future.wait(
                  [
                    _bluetoothService.currentName,
                    _bluetoothService.currentAddress,
                  ],
                ).then((values) => "Name: ${values[0]}\nAddress: ${values[1]}"),
                builder: (context, snapshot) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 32),
                      const Text(
                        "Waiting for Connection...",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        snapshot.data ?? "Fetching device info...",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "Ask the other device to scan and connect to the Name/Address above.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: const Text("Make Visible Again (300s)"),
                        onPressed: () =>
                            _bluetoothService.requestDiscoverable(300),
                      ),
                    ],
                  );
                },
              ),
            )
          : StreamBuilder<List<BluetoothDevice>>(
              stream: _bluetoothService.discoveryResultsStream,
              initialData: const [],
              builder: (context, snapshot) {
                final discoveredResults = snapshot.data ?? [];

                // Combine Lists or Show Sections? Sections is better.
                return ListView(
                  children: [
                    // Bonded Devices Section
                    if (_bondedDevices.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "Paired Devices",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ..._bondedDevices.map(
                        (device) => ListTile(
                          leading: const Icon(Icons.link, color: Colors.blue),
                          title: Text(device.name ?? "Unknown"),
                          subtitle: Text(device.address),
                          onTap: () => _connect(device),
                        ),
                      ),
                    ],

                    // Discovered Devices Section
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Available Devices",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (discoveredResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text("Scanning...")),
                      ),

                    ...discoveredResults.map(
                      (device) => ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(device.name ?? "Unknown Device"),
                        subtitle: Text(device.address),
                        // trailing: Text("${result.rssi} dBm"), // RSSI not available in BluetoothDevice
                        onTap: () => _connect(device),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  void _connect(BluetoothDevice device) async {
    _bluetoothService.stopDiscovery(); // Stop scanning before connecting
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Connecting...")));

    bool connected = await _bluetoothService.connectToDevice(device);
    if (connected && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Connected!")));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(device: device)),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Connection Failed")));
    }
  }
}

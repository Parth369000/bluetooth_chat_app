import 'package:bluetooth_connectivity/core/bluetooth/bluetooth_service.dart';
import 'package:bluetooth_connectivity/features/discovery/discovery_screen.dart'; // We will create this next
import 'package:flutter/material.dart';
// import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';
import 'package:bluetooth_connectivity/core/bluetooth/flutter_bluetooth_classic_fixed.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BluetoothService _bluetoothService = BluetoothService();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    await _bluetoothService.requestPermissions();
    await _bluetoothService.init();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bluetooth Chat")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bluetooth_audio,
              size: 80,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 20),
            StreamBuilder<BluetoothState>(
              stream: _bluetoothService.stateStream,
              initialData: _bluetoothService.state,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final isEnabled = state?.isEnabled ?? false;
                final status = state?.status ?? "Unknown";
                return Text(
                  "Bluetooth: ${isEnabled ? "ON ($status)" : "OFF ($status)"}",
                  style: Theme.of(context).textTheme.bodyLarge,
                );
              },
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text("Find Devices (Client)"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const DiscoveryScreen(isServer: false),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.wifi_tethering),
              label: const Text("Make Discoverable (Host)"),
              onPressed: () async {
                // Make discoverable
                await _bluetoothService.requestDiscoverable(300); // 5 mins
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const DiscoveryScreen(isServer: true),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

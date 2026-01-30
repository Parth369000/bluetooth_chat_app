import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:bluetooth_connectivity/core/bluetooth/bluetooth_protocol.dart';
import 'package:bluetooth_connectivity/core/models/message_model.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  // Singleton
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  // State
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  BluetoothConnection? _connection;
  bool _isNativeConnected = false; // Track Native Server state
  StreamSubscription<BluetoothDiscoveryResult>? _discoveryStreamSubscription;
  bool _isDiscovering = false;

  // Public Getters
  BluetoothState get state => _bluetoothState;
  bool get isConnected =>
      (_connection?.isConnected ?? false) || _isNativeConnected;
  bool get isDiscovering => _isDiscovering;

  // Streams
  final StreamController<BluetoothState> _stateController =
      StreamController<BluetoothState>.broadcast();
  Stream<BluetoothState> get stateStream => _stateController.stream;

  final StreamController<List<BluetoothDiscoveryResult>>
  _discoveryResultsController =
      StreamController<List<BluetoothDiscoveryResult>>.broadcast();
  Stream<List<BluetoothDiscoveryResult>> get discoveryResultsStream =>
      _discoveryResultsController.stream;

  // List to hold discovered devices during a scan
  final List<BluetoothDiscoveryResult> _discoveredDevices = [];

  /// Initialize and Listen to State
  Future<void> init() async {
    _bluetoothState = await _bluetooth.state;
    _bluetooth.onStateChanged().listen((BluetoothState state) {
      _bluetoothState = state;
      _stateController.add(state);
    });
  }

  /// Request Permissions (Critical for Android 12+)
  /// Request Permissions (Critical for Android 12+)
  Future<bool> requestPermissions() async {
    debugPrint("Requesting permissions...");
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    statuses.forEach((key, value) {
      debugPrint("Permission $key: $value");
    });

    // Check if critical permissions are granted
    bool scan = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    bool connect = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    bool location = statuses[Permission.location]?.isGranted ?? false;
    // Location service itself must be enabled usually!

    return (scan && connect) || location;
  }

  // ...

  /// Enable Bluetooth
  Future<bool> enableBluetooth() async {
    if (_bluetoothState == BluetoothState.STATE_ON) return true;
    return (await _bluetooth.requestEnable()) ?? false;
  }

  /// Get Bonded (Paired) Devices
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await _bluetooth.getBondedDevices();
    } catch (e) {
      debugPrint("Error getting bonded devices: $e");
      return [];
    }
  }

  /// Make Device Discoverable (Server Mode Preparation)
  Future<int?> requestDiscoverable(int seconds) async {
    return await _bluetooth.requestDiscoverable(seconds);
  }

  /// Get Device Name
  Future<String> get currentName async => (await _bluetooth.name) ?? "Unknown";

  /// Get Device Address
  Future<String> get currentAddress async =>
      (await _bluetooth.address) ?? "Unknown";

  /// Start Discovery (Scanning)
  void startDiscovery() {
    if (_isDiscovering) {
      debugPrint("Already discovering...");
      return;
    }

    debugPrint("Starting Discovery...");
    _discoveredDevices.clear();
    _discoveryResultsController.add([]); // Clear UI
    _isDiscovering = true;

    int lastUpdate = 0;
    try {
      _discoveryStreamSubscription = _bluetooth.startDiscovery().listen(
        (r) {
          // Avoid duplicates or update existing
          final existingIndex = _discoveredDevices.indexWhere(
            (element) => element.device.address == r.device.address,
          );
          if (existingIndex >= 0) {
            _discoveredDevices[existingIndex] = r;
          } else {
            _discoveredDevices.add(r);
          }

          // Throttle UI updates to prevent "Skipped frames" and Jank
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastUpdate > 500) {
            // Update every 500ms max
            _discoveryResultsController.add(List.from(_discoveredDevices));
            lastUpdate = now;
            debugPrint("UI Updated with ${_discoveredDevices.length} devices");
          }
        },
        onError: (e) {
          debugPrint("Discovery Stream Error: $e");
          _isDiscovering = false;
        },
        onDone: () {
          debugPrint("Discovery Stream Done");
          _isDiscovering = false;
          _discoveryResultsController.add(
            List.from(_discoveredDevices),
          ); // Final update
        },
      );
    } catch (e) {
      debugPrint("Start Discovery Failed: $e");
      _isDiscovering = false;
    }
  }

  /// Stop Discovery
  Future<void> stopDiscovery() async {
    await _discoveryStreamSubscription?.cancel();
    _isDiscovering = false;
  }

  /// Connect to a Device (Client Mode)
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Connect
      _connection = await BluetoothConnection.toAddress(device.address);
      return _connection?.isConnected ?? false;
    } catch (e) {
      debugPrint("Connection failed: $e");
      return false;
    }
  }

  /// Start Server (Host Mode)
  /// Note: Connection usually needs to be handled in a separate isolate or async task
  /// so it doesn't block UI while waiting.
  // Method Channel for Native Server
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.example.bluetooth_connectivity/server',
  );
  static const EventChannel _nativeEventChannel = EventChannel(
    'com.example.bluetooth_connectivity/server_events',
  );

  // Stream to notify UI of Server Connection Status
  final StreamController<bool> _serverConnectionController =
      StreamController<bool>.broadcast();
  Stream<bool> get serverConnectionStream => _serverConnectionController.stream;

  /// Start Server (Host Mode) - Using Native Implementation
  Future<void> startServer() async {
    try {
      // 1. Setup Listener FIRST to catch "CONNECTED" even if it happens instantly.
      _nativeEventChannel.receiveBroadcastStream().listen((data) {
        if (data is String) {
          debugPrint("Native Event: $data");
          if (data == "CONNECTED") {
            _connection = null; // Ensure lib connection is null
            _isNativeConnected = true; // Set Native State
            _serverConnectionController.add(true); // Notify UI!
          } else if (data == "DISCONNECTED") {
            _isNativeConnected = false;
            _serverConnectionController.add(false);
          }
        } else if (data is Uint8List || data is List<int>) {
          _nativeMessageController.add(
            data is Uint8List ? data : Uint8List.fromList(data.cast<int>()),
          );
        }
      });

      // 2. NOW Start the Server
      await _nativeChannel.invokeMethod('startServer');
    } catch (e) {
      debugPrint("Native Server Error: $e");
    }
  }

  // Custom controller for bridging Native messages to Dart Model stream
  final StreamController<Uint8List> _nativeMessageController =
      StreamController<Uint8List>.broadcast();

  // Override messageStream to use native controller if Native Server is active
  // This is a hybrid approach: Default to lib connection, fallback to native controller.

  Stream<MessageModel>? get messageStream {
    if (_connection != null && _connection!.isConnected) {
      // Client Mode (Lib)
      return _connection!.input!.transform(_protocol.transformer);
    } else {
      // Server Mode (Native) or Disconnected
      return _nativeMessageController.stream.transform(_protocol.transformer);
    }
  }

  final BluetoothProtocol _protocol = BluetoothProtocol();

  /// Send Message
  Future<void> sendMessage(MessageModel message) async {
    final encoded = _protocol.encode(message);

    if (_connection != null && _connection!.isConnected) {
      // Client Mode (Lib)
      _connection!.output.add(encoded);
      await _connection!.output.allSent;
    } else {
      // Server Mode (Native)
      String packet = utf8.decode(encoded);
      try {
        await _nativeChannel.invokeMethod('sendMessage', {"message": packet});
      } catch (e) {
        debugPrint("Native Send Error: $e");
      }
    }
  }

  /// Disconnect
  void disconnect() {
    _connection?.close();
    _connection = null;
  }

  // Dispose
  void dispose() {
    _stateController.close();
    _discoveryResultsController.close();
    _discoveryStreamSubscription?.cancel();
    disconnect();
  }
}

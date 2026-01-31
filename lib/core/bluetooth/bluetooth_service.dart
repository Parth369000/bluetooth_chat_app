import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';
import 'package:bluetooth_connectivity/core/bluetooth/flutter_bluetooth_classic_fixed.dart';
import 'package:bluetooth_connectivity/core/bluetooth/bluetooth_protocol.dart';
import 'package:bluetooth_connectivity/core/models/message_model.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  // Singleton
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final FlutterBluetoothClassic _bluetooth = FlutterBluetoothClassic();

  // State
  BluetoothState? _bluetoothState;
  bool _isConnected = false;
  bool _isNativeConnected = false; 
  StreamSubscription? _discoveryStreamSubscription;
  bool _isDiscovering = false;

  // Public Getters
  BluetoothState? get state => _bluetoothState;
  bool get isConnected => _isConnected || _isNativeConnected;
  bool get isDiscovering => _isDiscovering;

  // Streams
  final StreamController<BluetoothState> _stateController =
      StreamController<BluetoothState>.broadcast();
  Stream<BluetoothState> get stateStream => _stateController.stream;

  final StreamController<List<BluetoothDevice>>
  _discoveryResultsController =
      StreamController<List<BluetoothDevice>>.broadcast();
  Stream<List<BluetoothDevice>> get discoveryResultsStream =>
      _discoveryResultsController.stream;

  final List<BluetoothDevice> _discoveredDevices = [];

  Future<void> init() async {
    _bluetooth.onStateChanged.listen((BluetoothState state) {
      _bluetoothState = state;
      _stateController.add(state);
    });
    
    _bluetooth.onConnectionChanged.listen((BluetoothConnectionState state) {
        if (state.isConnected) {
            _isConnected = true;
        } else {
            _isConnected = false;
        }
    });
    
    _bluetooth.onDataReceived.listen((BluetoothData data) {
         if (_isConnected) {
             // We'll expose this via messageStream logic
             debugPrint("Data received: ${data.asString()}");
         }
    });

    // Check initial state
    bool enabled = await _bluetooth.isBluetoothEnabled();
    _bluetoothState = BluetoothState(isEnabled: enabled, status: enabled ? "on" : "off");
    _stateController.add(_bluetoothState!);
  }

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    bool scan = statuses[Permission.bluetoothScan]?.isGranted ?? false;
    bool connect = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    bool location = statuses[Permission.location]?.isGranted ?? false;

    return (scan && connect) || location;
  }

  Future<bool> enableBluetooth() async {
      return await _bluetooth.enableBluetooth();
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await _bluetooth.getPairedDevices();
    } catch (e) {
      debugPrint("Error getting paired devices: $e");
      return [];
    }
  }

  Future<int?> requestDiscoverable(int seconds) async {
     return null; 
  }

  Future<String> get currentName async => "Unknown"; 
  Future<String> get currentAddress async => "Unknown"; 

  void startDiscovery() {
    if (_isDiscovering) return;

    _discoveredDevices.clear();
    _discoveryResultsController.add([]); 
    _isDiscovering = true;

    try {
       _bluetooth.startDiscovery();
       
       _discoveryStreamSubscription = _bluetooth.onDeviceDiscovered.listen(
        (device) {
          final existingIndex = _discoveredDevices.indexWhere(
            (element) => element.address == device.address,
          );
          if (existingIndex == -1) {
            _discoveredDevices.add(device);
            _discoveryResultsController.add(List.from(_discoveredDevices));
          }
        },
        onError: (e) {
          debugPrint("Discovery Error: $e");
          _isDiscovering = false;
        },
        onDone: () {
          _isDiscovering = false;
        },
      );
    } catch (e) {
      debugPrint("Failed to start discovery: $e");
      _isDiscovering = false;
    }
  }

  Future<void> stopDiscovery() async {
    await _bluetooth.stopDiscovery();
    await _discoveryStreamSubscription?.cancel();
    _isDiscovering = false;
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await _bluetooth.connect(device.address);
      _isConnected = true; 
      return true;
    } catch (e) {
      debugPrint("Connect error: $e");
      return false;
    }
  }

  // Server Implementation (unchanged)
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.example.bluetooth_connectivity/server',
  );
  static const EventChannel _nativeEventChannel = EventChannel(
    'com.example.bluetooth_connectivity/server_events',
  );

  final StreamController<bool> _serverConnectionController =
      StreamController<bool>.broadcast();
  Stream<bool> get serverConnectionStream => _serverConnectionController.stream;

  Future<void> startServer() async {
    try {
      _nativeEventChannel.receiveBroadcastStream().listen((data) {
        if (data is String) {
          if (data == "CONNECTED") {
            _isNativeConnected = true; 
            _serverConnectionController.add(true); 
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

      await _nativeChannel.invokeMethod('startServer');
    } catch (e) {
      debugPrint("Native Server Error: $e");
    }
  }

  final StreamController<Uint8List> _nativeMessageController =
      StreamController<Uint8List>.broadcast();

  Stream<MessageModel>? get messageStream {
    if (_isNativeConnected) {
         return _nativeMessageController.stream.transform(_protocol.transformer);
    }
    // Transform BluetoothData to Uint8List for protocol
    return _bluetooth.onDataReceived.map((d) => Uint8List.fromList(d.data)).transform(_protocol.transformer); 
  }

  final BluetoothProtocol _protocol = BluetoothProtocol();

  Future<void> sendMessage(MessageModel message) async {
    final encoded = _protocol.encode(message);

    if (_isNativeConnected) {
      String packet = utf8.decode(encoded);
      try {
        await _nativeChannel.invokeMethod('sendMessage', {"message": packet});
      } catch (e) {
        debugPrint("Native Send Error: $e");
      }
    } else {
       await _bluetooth.sendData(encoded); 
    }
  }

  Future<void> disconnect() async {
    await _bluetooth.disconnect();
    _isConnected = false;
  }

  void dispose() {
    _stateController.close();
    _discoveryResultsController.close();
    _discoveryStreamSubscription?.cancel();
    disconnect();
  }
}

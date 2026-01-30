package com.example.bluetooth_connectivity

import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel 
import android.os.Bundle
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.bluetooth_connectivity/server"
    private val EVENT_CHANNEL = "com.example.bluetooth_connectivity/server_events"
    
    // Bluetooth Globals
    private var eventSink: EventChannel.EventSink? = null
    private var acceptThread: AcceptThread? = null
    private var connectedThread: ConnectedThread? = null
    private val uuid: java.util.UUID = java.util.UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") // Standard SPP UUID

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method Channel for Commands
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startServer") {
                startServer()
                result.success("Server Started")
            } else if (call.method == "sendMessage") {
                val message = call.argument<String>("message")
                if (message != null) {
                    write(message.toByteArray())
                    result.success(true)
                } else {
                    result.error("INVALID", "Message is null", null)
                }
            } else if (call.method == "stopServer") {
                stopServer()
                result.success("Server Stopped")
            } else {
                result.notImplemented()
            }
        }

        // Event Channel for Incoming Data
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun startServer() {
        if (acceptThread == null) {
            acceptThread = AcceptThread()
            acceptThread?.start()
        }
    }
    
    private fun stopServer() {
        acceptThread?.cancel()
        acceptThread = null
        connectedThread?.cancel()
        connectedThread = null
    }

    private fun write(bytes: ByteArray) {
        connectedThread?.write(bytes)
    }

    private fun notifyFlutter(data: Any) {
        runOnUiThread {
            eventSink?.success(data)
        }
    }

    // Thread to Listen for Connections
    private inner class AcceptThread : Thread() {
        private val mmServerSocket: android.bluetooth.BluetoothServerSocket? by lazy(LazyThreadSafetyMode.NONE) {
            val bluetoothAdapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            try {
                // Must explicitly check permission in real app, but for now assuming enabled
                 // In newer Android, this requires BLUETOOTH_CONNECT permission check
                bluetoothAdapter?.listenUsingRfcommWithServiceRecord("BluetoothChat", uuid)
            } catch (e: SecurityException) {
                notifyFlutter("ERROR: Permission missing")
                null
            } catch (e: java.io.IOException) {
                notifyFlutter("ERROR: Listen failed ${e.message}")
                null
            }
        }

        override fun run() {
            var shouldLoop = true
            while (shouldLoop) {
                val socket: android.bluetooth.BluetoothSocket? = try {
                    mmServerSocket?.accept()
                } catch (e: java.io.IOException) {
                    shouldLoop = false
                    null
                }
                socket?.also {
                    notifyFlutter("CONNECTED")
                    manageMyConnectedSocket(it)
                    mmServerSocket?.close()
                    shouldLoop = false
                }
            }
        }

        fun cancel() {
            try {
                mmServerSocket?.close()
            } catch (e: java.io.IOException) { }
        }
    }

    private fun manageMyConnectedSocket(socket: android.bluetooth.BluetoothSocket) {
        connectedThread = ConnectedThread(socket)
        connectedThread?.start()
    }

    // Thread to Handle Active Connection
    private inner class ConnectedThread(private val mmSocket: android.bluetooth.BluetoothSocket) : Thread() {
        private val mmInStream: java.io.InputStream = mmSocket.inputStream
        private val mmOutStream: java.io.OutputStream = mmSocket.outputStream
        private val buffer: ByteArray = ByteArray(1024)

        override fun run() {
            var numBytes: Int
            while (true) {
                numBytes = try {
                    mmInStream.read(buffer)
                } catch (e: java.io.IOException) {
                    notifyFlutter("DISCONNECTED")
                    break
                }
                
                // convert to string or pass raw bytes
                // We send raw bytes to flutter to handle buffering/decoding
                val readMsg = ByteArray(numBytes)
                System.arraycopy(buffer, 0, readMsg, 0, numBytes)
                notifyFlutter(readMsg)
            }
        }

        fun write(bytes: ByteArray) {
            try {
                mmOutStream.write(bytes)
            } catch (e: java.io.IOException) {
                 notifyFlutter("ERROR: Write failed")
            }
        }

        fun cancel() {
            try {
                mmSocket.close()
            } catch (e: java.io.IOException) { }
        }
    }
}

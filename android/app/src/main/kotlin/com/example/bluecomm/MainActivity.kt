package com.example.bluecomm

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    // Platform channel names for method calls and data streaming.
    private val METHOD_CHANNEL = "com.example.bluecomm/rfcomm"
    private val DATA_EVENT_CHANNEL = "com.example.bluecomm/rfcomm_data"
    private val SERVER_EVENT_CHANNEL = "com.example.bluecomm/rfcomm_server"

    // Standard Serial Port Profile UUID for Bluetooth Classic RFCOMM.
    private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    // Active Bluetooth socket and I/O streams.
    private var activeSocket: BluetoothSocket? = null
    private var inputStream: InputStream? = null
    private var outputStream: OutputStream? = null

    // Server socket for accepting incoming connections.
    private var serverSocket: BluetoothServerSocket? = null
    private var serverThread: Thread? = null
    private var isServerRunning = false

    // Read thread for incoming data.
    private var readThread: Thread? = null
    private var isReading = false

    // Event sink for streaming received data to Dart.
    private var dataSink: EventChannel.EventSink? = null

    // Event sink for notifying Dart about incoming connections.
    private var serverSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method channel for connect, disconnect, send, and server control.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> {
                        val address = call.argument<String>("address")!!
                        connectToDevice(address, result)
                    }
                    "disconnect" -> {
                        disconnectSocket()
                        result.success(true)
                    }
                    "send" -> {
                        val data = call.argument<ByteArray>("data")!!
                        sendData(data, result)
                    }
                    "startServer" -> {
                        startServerSocket(result)
                    }
                    "stopServer" -> {
                        stopServerSocket()
                        result.success(true)
                    }
                    "isConnected" -> {
                        result.success(activeSocket?.isConnected == true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Event channel for streaming received bytes to Dart.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DATA_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    dataSink = events
                }
                override fun onCancel(arguments: Any?) {
                    dataSink = null
                }
            })

        // Event channel for notifying Dart about incoming connections.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SERVER_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    serverSink = events
                }
                override fun onCancel(arguments: Any?) {
                    serverSink = null
                }
            })
    }

    /**
     * Connects to a Bluetooth device using RFCOMM.
     * Tries the standard createRfcommSocketToServiceRecord first.
     * On failure, falls back to the reflection-based createRfcommSocket(1)
     * which bypasses SDP lookup — the well-known Android RFCOMM fix.
     */
    private fun connectToDevice(address: String, result: MethodChannel.Result) {
        Thread {
            try {
                // Close any existing connection first.
                disconnectSocket()

                val adapter = BluetoothAdapter.getDefaultAdapter()
                if (adapter == null) {
                    runOnUiThread { result.error("NO_ADAPTER", "Bluetooth not available", null) }
                    return@Thread
                }

                // Cancel discovery — it interferes with RFCOMM connections.
                adapter.cancelDiscovery()
                Thread.sleep(300)

                val device: BluetoothDevice = adapter.getRemoteDevice(address)
                var socket: BluetoothSocket? = null
                var connected = false

                // Attempt 1: Standard SPP UUID connection.
                try {
                    socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                    socket.connect()
                    connected = true
                } catch (e: IOException) {
                    // Standard method failed — close the failed socket.
                    try { socket?.close() } catch (_: Exception) {}
                    socket = null
                }

                // Attempt 2: Reflection-based fallback on RFCOMM channel 1.
                // This bypasses SDP service discovery which fails on many Android devices.
                if (!connected) {
                    try {
                        val method = device.javaClass.getMethod(
                            "createRfcommSocket",
                            Int::class.javaPrimitiveType
                        )
                        socket = method.invoke(device, 1) as BluetoothSocket
                        socket.connect()
                        connected = true
                    } catch (e: Exception) {
                        try { socket?.close() } catch (_: Exception) {}
                        socket = null
                    }
                }

                // Attempt 3: Insecure RFCOMM connection (no pairing required).
                if (!connected) {
                    try {
                        socket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
                        socket.connect()
                        connected = true
                    } catch (e: Exception) {
                        try { socket?.close() } catch (_: Exception) {}
                        socket = null
                    }
                }

                if (connected && socket != null) {
                    // Store the socket and start reading data.
                    activeSocket = socket
                    inputStream = socket.inputStream
                    outputStream = socket.outputStream
                    startReadThread()

                    runOnUiThread {
                        result.success(mapOf(
                            "connected" to true,
                            "address" to address,
                            "name" to (device.name ?: "Unknown")
                        ))
                    }
                } else {
                    runOnUiThread {
                        result.error(
                            "CONNECTION_FAILED",
                            "All connection methods failed for $address",
                            null
                        )
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("CONNECTION_ERROR", e.message, e.toString())
                }
            }
        }.start()
    }

    /**
     * Starts a BluetoothServerSocket listening on the SPP UUID.
     * When a remote device connects, the server accepts the connection
     * and notifies Dart via the server event channel.
     */
    private fun startServerSocket(result: MethodChannel.Result) {
        if (isServerRunning) {
            result.success(true)
            return
        }

        try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            if (adapter == null) {
                result.error("NO_ADAPTER", "Bluetooth not available", null)
                return
            }

            serverSocket = adapter.listenUsingRfcommWithServiceRecord("BlueComm", SPP_UUID)
            isServerRunning = true

            serverThread = Thread {
                while (isServerRunning) {
                    try {
                        // accept() blocks until a connection is made or cancelled.
                        val socket = serverSocket?.accept() ?: break
                        val device = socket.remoteDevice

                        // Only accept if we don't already have an active connection.
                        if (activeSocket?.isConnected == true) {
                            socket.close()
                            continue
                        }

                        // Accept the incoming connection.
                        activeSocket = socket
                        inputStream = socket.inputStream
                        outputStream = socket.outputStream
                        startReadThread()

                        // Notify Dart about the incoming connection.
                        runOnUiThread {
                            serverSink?.success(mapOf(
                                "address" to device.address,
                                "name" to (device.name ?: "Unknown")
                            ))
                        }
                    } catch (e: IOException) {
                        // Server socket was closed or error occurred.
                        if (isServerRunning) {
                            // Unexpected error — retry after delay.
                            try { Thread.sleep(1000) } catch (_: Exception) {}
                        }
                    }
                }
            }
            serverThread?.isDaemon = true
            serverThread?.start()

            result.success(true)
        } catch (e: Exception) {
            result.error("SERVER_ERROR", e.message, null)
        }
    }

    /**
     * Stops the server socket and its listening thread.
     */
    private fun stopServerSocket() {
        isServerRunning = false
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
        serverThread?.interrupt()
        serverThread = null
    }

    /**
     * Starts a background thread that reads bytes from the RFCOMM socket's
     * InputStream and sends them to Dart via the data event channel.
     */
    private fun startReadThread() {
        stopReadThread()
        isReading = true

        readThread = Thread {
            val buffer = ByteArray(1024)
            while (isReading) {
                try {
                    val bytesRead = inputStream?.read(buffer) ?: -1
                    if (bytesRead > 0) {
                        val data = buffer.copyOf(bytesRead)
                        runOnUiThread {
                            dataSink?.success(data)
                        }
                    } else if (bytesRead == -1) {
                        // End of stream — peer disconnected.
                        runOnUiThread {
                            dataSink?.endOfStream()
                        }
                        break
                    }
                } catch (e: IOException) {
                    // Read error — socket likely closed.
                    runOnUiThread {
                        dataSink?.endOfStream()
                    }
                    break
                }
            }
        }
        readThread?.isDaemon = true
        readThread?.start()
    }

    /**
     * Stops the read thread.
     */
    private fun stopReadThread() {
        isReading = false
        readThread?.interrupt()
        readThread = null
    }

    /**
     * Sends raw bytes over the active RFCOMM socket.
     */
    private fun sendData(data: ByteArray, result: MethodChannel.Result) {
        Thread {
            try {
                outputStream?.write(data)
                outputStream?.flush()
                runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                runOnUiThread { result.error("SEND_ERROR", e.message, null) }
            }
        }.start()
    }

    /**
     * Closes the active RFCOMM socket and releases all associated resources.
     */
    private fun disconnectSocket() {
        isReading = false
        try { readThread?.interrupt() } catch (_: Exception) {}
        readThread = null
        try { inputStream?.close() } catch (_: Exception) {}
        try { outputStream?.close() } catch (_: Exception) {}
        try { activeSocket?.close() } catch (_: Exception) {}
        inputStream = null
        outputStream = null
        activeSocket = null
    }

    override fun onDestroy() {
        disconnectSocket()
        stopServerSocket()
        super.onDestroy()
    }
}

package com.robotarm.robot_arm_app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.robotarm.controller/bluetooth"
    private val EVENT_CHANNEL = "com.robotarm.controller/bluetooth_stream"
    private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val PERMISSION_REQUEST_CODE = 1001

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null
    private var inputStream: InputStream? = null
    private var readThread: Thread? = null
    private var isConnected = false

    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()

        // Event Channel for incoming data stream
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

        // Method Channel for Bluetooth commands
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBluetoothAvailable" -> {
                    result.success(bluetoothAdapter != null)
                }
                "isBluetoothEnabled" -> {
                    result.success(bluetoothAdapter?.isEnabled == true)
                }
                "hasBluetoothPermissions" -> {
                    result.success(hasPermissions())
                }
                "requestBluetoothPermissions" -> {
                    requestBluetoothPermissions(result)
                }
                "getPairedDevices" -> {
                    if (!hasPermissions()) {
                        pendingPermissionResult = result
                        requestRequiredPermissions()
                    } else {
                        getPairedDevices(result)
                    }
                }
                "connect" -> {
                    val address = call.argument<String>("address")
                    if (address != null) {
                        connectToDevice(address, result)
                    } else {
                        result.error("INVALID_ARGS", "Device address cannot be null", null)
                    }
                }
                "send" -> {
                    val data = call.argument<String>("data")
                    if (data != null) {
                        sendData(data, result)
                    } else {
                        result.error("INVALID_ARGS", "Data cannot be null", null)
                    }
                }
                "disconnect" -> {
                    disconnect(result)
                }
                "isConnected" -> {
                    result.success(isConnected)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestRequiredPermissions() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN
            )
        } else {
            arrayOf(
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
        }
        ActivityCompat.requestPermissions(this, permissions, PERMISSION_REQUEST_CODE)
    }

    private fun requestBluetoothPermissions(result: MethodChannel.Result) {
        if (hasPermissions()) {
            result.success(true)
            return
        }
        pendingPermissionResult = result
        requestRequiredPermissions()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            val pending = pendingPermissionResult
            pendingPermissionResult = null

            if (pending != null) {
                if (allGranted) {
                    // If the caller was expecting getPairedDevices, deliver it, else true
                    getPairedDevices(pending)
                } else {
                    pending.error("PERMISSION_DENIED", "Required Bluetooth permissions were not granted by the user", null)
                }
            }
        }
    }

    private fun getPairedDevices(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            result.success(emptyList<Map<String, String>>())
            return
        }

        try {
            val bondedDevices: Set<BluetoothDevice> = adapter.bondedDevices ?: emptySet()
            val deviceList = mutableListOf<Map<String, String>>()
            for (device in bondedDevices) {
                val name = try { device.name } catch (_: SecurityException) { "Unknown Device" } ?: "Unknown Device"
                val map = mapOf(
                    "name" to name,
                    "address" to device.address
                )
                deviceList.add(map)
            }
            result.success(deviceList)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Bluetooth permission not granted: ${e.message}", null)
        } catch (e: Exception) {
            result.error("ERROR", "Failed to retrieve paired devices: ${e.message}", null)
        }
    }

    private fun connectToDevice(address: String, result: MethodChannel.Result) {
        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            result.error("BLUETOOTH_DISABLED", "Bluetooth is disabled or unavailable", null)
            return
        }

        Thread {
            try {
                // Close existing connection if open
                closeConnection()

                val device = adapter.getRemoteDevice(address)
                // Cancel discovery as it slows down connection
                try { adapter.cancelDiscovery() } catch (_: Exception) {}

                val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()

                bluetoothSocket = socket
                outputStream = socket.outputStream
                inputStream = socket.inputStream
                isConnected = true

                startReadThread()

                mainHandler.post {
                    result.success(true)
                }
            } catch (e: Exception) {
                closeConnection()
                mainHandler.post {
                    result.error("CONNECT_FAILED", "Failed to connect to $address: ${e.message}", null)
                }
            }
        }.start()
    }

    private fun startReadThread() {
        val stream = inputStream ?: return
        readThread = Thread {
            val buffer = ByteArray(1024)
            while (isConnected) {
                try {
                    val bytes = stream.read(buffer)
                    if (bytes > 0) {
                        val message = String(buffer, 0, bytes, Charsets.US_ASCII)
                        mainHandler.post {
                            eventSink?.success(message)
                        }
                    }
                } catch (e: IOException) {
                    // Socket closed or disconnect occurred
                    if (isConnected) {
                        closeConnection()
                        mainHandler.post {
                            eventSink?.error("DISCONNECTED", "Connection lost", null)
                        }
                    }
                    break
                }
            }
        }
        readThread?.start()
    }

    private fun sendData(data: String, result: MethodChannel.Result) {
        val stream = outputStream
        if (!isConnected || stream == null) {
            result.error("NOT_CONNECTED", "Bluetooth socket is not connected", null)
            return
        }

        Thread {
            try {
                stream.write(data.toByteArray(Charsets.US_ASCII))
                stream.flush()
                mainHandler.post {
                    result.success(true)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SEND_FAILED", "Failed to write data: ${e.message}", null)
                }
            }
        }.start()
    }

    private fun disconnect(result: MethodChannel.Result) {
        Thread {
            closeConnection()
            mainHandler.post {
                result.success(true)
            }
        }.start()
    }

    private fun closeConnection() {
        isConnected = false
        try { readThread?.interrupt() } catch (_: Exception) {}
        try { inputStream?.close() } catch (_: Exception) {}
        try { outputStream?.close() } catch (_: Exception) {}
        try { bluetoothSocket?.close() } catch (_: Exception) {}
        readThread = null
        inputStream = null
        outputStream = null
        bluetoothSocket = null
    }

    override fun onDestroy() {
        closeConnection()
        super.onDestroy()
    }
}

package com.awj.owj_assistant

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.awj.owj_assistant/device_control"
    private var cameraManager: CameraManager? = null
    private var torchCallback: CameraManager.TorchCallback? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setVolume" -> handleSetVolume(call, result)
                    "setBrightness" -> handleSetBrightness(call, result)
                    "takeScreenshot" -> handleTakeScreenshot(result)
                    "toggleWifi" -> handleToggleWifi(call, result)
                    "toggleBluetooth" -> handleToggleBluetooth(call, result)
                    "toggleFlashlight" -> handleToggleFlashlight(call, result)
                    "getBatteryInfo" -> handleGetBatteryInfo(result)
                    "getDeviceInfo" -> handleGetDeviceInfo(result)
                    else -> result.notImplemented()
                }
            }
    }

    // ─── setVolume ─────────────────────────────────────────────────────

    private fun handleSetVolume(
        call: io.flutter.plugin.common.MethodCall,
        result: io.flutter.plugin.common.MethodChannel.Result
    ) {
        try {
            val level = call.argument<Int>("level") ?: 0
            val streamTypeStr = call.argument<String>("streamType") ?: "music"

            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

            val streamType = when (streamTypeStr.lowercase()) {
                "music", "media" -> AudioManager.STREAM_MUSIC
                "ring" -> AudioManager.STREAM_RING
                "alarm" -> AudioManager.STREAM_ALARM
                "notification" -> AudioManager.STREAM_NOTIFICATION
                "system" -> AudioManager.STREAM_SYSTEM
                "voice_call" -> AudioManager.STREAM_VOICE_CALL
                else -> AudioManager.STREAM_MUSIC
            }

            val maxVolume = audioManager.getStreamMaxVolume(streamType)
            val clampedLevel = level.coerceIn(0, maxVolume)
            audioManager.setStreamVolume(streamType, clampedLevel, 0)

            result.success(true)
        } catch (e: Exception) {
            Log.e("DeviceControl", "setVolume failed", e)
            result.error("VOLUME_ERROR", "Failed to set volume: ${e.message}", null)
        }
    }

    // ─── setBrightness ─────────────────────────────────────────────────

    private fun handleSetBrightness(
        call: io.flutter.plugin.common.MethodCall,
        result: io.flutter.plugin.common.MethodChannel.Result
    ) {
        try {
            val level = call.argument<Int>("level") ?: 128

            // Check if we have WRITE_SETTINGS permission
            if (!Settings.System.canWrite(this)) {
                // Open the WRITE_SETTINGS permission screen as fallback
                val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                    data = android.net.Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.error(
                    "BRIGHTNESS_PERMISSION",
                    "WRITE_SETTINGS permission required. Opening settings...",
                    null
                )
                return
            }

            // Disable auto-brightness so manual brightness takes effect
            Settings.System.putInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS_MODE,
                Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
            )

            val clampedLevel = level.coerceIn(0, 255)
            Settings.System.putInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS,
                clampedLevel
            )

            result.success(true)
        } catch (e: Exception) {
            Log.e("DeviceControl", "setBrightness failed", e)
            result.error("BRIGHTNESS_ERROR", "Failed to set brightness: ${e.message}", null)
        }
    }

    // ─── takeScreenshot ────────────────────────────────────────────────

    private fun handleTakeScreenshot(result: io.flutter.plugin.common.MethodChannel.Result) {
        try {
            // On modern Android, apps cannot take screenshots silently.
            // The best we can do is trigger the system screenshot intent
            // or open the assist screenshot action.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // Android 9+: Use the assist screenshot action
                val intent = Intent("android.intent.action.ASSIST").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    putExtra("assist_screenshot", true)
                }
                try {
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    // Fallback: tell user to use hardware keys
                    result.error(
                        "SCREENSHOT_ERROR",
                        "Automatic screenshot not supported. Use Power + Volume Down.",
                        null
                    )
                }
            } else {
                // Older Android: try the system screenshot service
                try {
                    @Suppress("DEPRECATION")
                    val screenshotIntent = Intent("com.android.systemui.screenshot.TakeScreenshot")
                    screenshotIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(screenshotIntent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error(
                        "SCREENSHOT_ERROR",
                        "Screenshot not supported on this device. Use Power + Volume Down.",
                        null
                    )
                }
            }
        } catch (e: Exception) {
            Log.e("DeviceControl", "takeScreenshot failed", e)
            result.error("SCREENSHOT_ERROR", "Failed to take screenshot: ${e.message}", null)
        }
    }

    // ─── toggleWifi ────────────────────────────────────────────────────

    @SuppressLint("MissingPermission")
    private fun handleToggleWifi(
        call: io.flutter.plugin.common.MethodCall,
        result: io.flutter.plugin.common.MethodChannel.Result
    ) {
        try {
            val enable = call.argument<Boolean>("enable") ?: true

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+: Cannot programmatically toggle WiFi.
                // Open WiFi settings panel as fallback.
                val panelIntent = Intent(Settings.Panel.ACTION_WIFI)
                panelIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(panelIntent)
                result.error(
                    "WIFI_SETTINGS_OPENED",
                    "WiFi toggle not allowed on Android 10+. Opening WiFi settings panel.",
                    null
                )
                return
            }

            // Pre-Android 10: Use WifiManager
            @Suppress("DEPRECATION")
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
            @Suppress("DEPRECATION")
            val success = wifiManager.setWifiEnabled(enable)

            if (success) {
                result.success(true)
            } else {
                // Fallback: open WiFi settings
                val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.error("WIFI_SETTINGS_OPENED", "WiFi toggle failed. Opening WiFi settings.", null)
            }
        } catch (e: Exception) {
            Log.e("DeviceControl", "toggleWifi failed", e)
            // Fallback: open WiFi settings
            try {
                val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (_: Exception) {}
            result.error("WIFI_ERROR", "Failed to toggle WiFi: ${e.message}", null)
        }
    }

    // ─── toggleBluetooth ───────────────────────────────────────────────

    @SuppressLint("MissingPermission")
    private fun handleToggleBluetooth(
        call: io.flutter.plugin.common.MethodCall,
        result: io.flutter.plugin.common.MethodChannel.Result
    ) {
        try {
            val enable = call.argument<Boolean>("enable") ?: true

            val bluetoothAdapter = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager?
                bluetoothManager?.adapter
            } else {
                @Suppress("DEPRECATION")
                android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            }

            if (bluetoothAdapter == null) {
                result.error("BLUETOOTH_ERROR", "Device does not support Bluetooth", null)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Android 13+: Check for BLUETOOTH_CONNECT permission
                if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT)
                    != PackageManager.PERMISSION_GRANTED
                ) {
                    ActivityCompat.requestPermissions(
                        this as Activity,
                        arrayOf(Manifest.permission.BLUETOOTH_CONNECT),
                        1001
                    )
                    result.error(
                        "BLUETOOTH_PERMISSION",
                        "BLUETOOTH_CONNECT permission required. Opening Bluetooth settings.",
                        null
                    )
                    return
                }
            }

            val success = if (enable) {
                bluetoothAdapter.enable()
            } else {
                bluetoothAdapter.disable()
            }

            if (success) {
                result.success(true)
            } else {
                // Fallback: open Bluetooth settings
                val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.error(
                    "BLUETOOTH_SETTINGS_OPENED",
                    "Bluetooth toggle failed. Opening Bluetooth settings.",
                    null
                )
            }
        } catch (e: SecurityException) {
            Log.e("DeviceControl", "toggleBluetooth: SecurityException", e)
            // Fallback: open Bluetooth settings
            try {
                val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (_: Exception) {}
            result.error(
                "BLUETOOTH_PERMISSION",
                "Bluetooth permission denied. Opening Bluetooth settings.",
                null
            )
        } catch (e: Exception) {
            Log.e("DeviceControl", "toggleBluetooth failed", e)
            try {
                val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
            } catch (_: Exception) {}
            result.error("BLUETOOTH_ERROR", "Failed to toggle Bluetooth: ${e.message}", null)
        }
    }

    // ─── toggleFlashlight ──────────────────────────────────────────────

    @SuppressLint("MissingPermission")
    private fun handleToggleFlashlight(
        call: io.flutter.plugin.common.MethodCall,
        result: io.flutter.plugin.common.MethodChannel.Result
    ) {
        try {
            val enable = call.argument<Boolean>("enable") ?: true

            val camManager = cameraManager ?: run {
                result.error("FLASHLIGHT_ERROR", "Camera service not available", null)
                return
            }

            // Find a camera with a flash unit
            val cameraId = camManager.cameraIdList.firstOrNull { id ->
                camManager.getCameraCharacteristics(id)
                    .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }

            if (cameraId == null) {
                result.error("FLASHLIGHT_ERROR", "No camera with flash available", null)
                return
            }

            camManager.setTorchMode(cameraId, enable)
            result.success(true)
        } catch (e: Exception) {
            Log.e("DeviceControl", "toggleFlashlight failed", e)
            result.error("FLASHLIGHT_ERROR", "Failed to toggle flashlight: ${e.message}", null)
        }
    }

    // ─── getBatteryInfo ────────────────────────────────────────────────

    private fun handleGetBatteryInfo(result: io.flutter.plugin.common.MethodChannel.Result) {
        try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager

            val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val isCharging = batteryManager.isCharging

            val info = hashMapOf<String, Any>(
                "level" to level,
                "isCharging" to isCharging
            )

            result.success(info)
        } catch (e: Exception) {
            Log.e("DeviceControl", "getBatteryInfo failed", e)
            result.error("BATTERY_ERROR", "Failed to get battery info: ${e.message}", null)
        }
    }

    // ─── getDeviceInfo ─────────────────────────────────────────────────

    @SuppressLint("HardwareIds")
    private fun handleGetDeviceInfo(result: io.flutter.plugin.common.MethodChannel.Result) {
        try {
            val info = hashMapOf<String, Any>(
                "model" to (Build.MODEL ?: "Unknown"),
                "manufacturer" to (Build.MANUFACTURER ?: "Unknown"),
                "osVersion" to (Build.VERSION.RELEASE ?: "Unknown"),
                "sdkVersion" to Build.VERSION.SDK_INT
            )

            // Serial number is only available with appropriate permissions
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
                        == PackageManager.PERMISSION_GRANTED
                    ) {
                        info["serial"] = Build.getSerial()
                    } else {
                        info["serial"] = "Permission required"
                    }
                } else {
                    @Suppress("DEPRECATION")
                    info["serial"] = Build.SERIAL ?: "Unknown"
                }
            } catch (e: SecurityException) {
                info["serial"] = "Permission denied"
            }

            result.success(info)
        } catch (e: Exception) {
            Log.e("DeviceControl", "getDeviceInfo failed", e)
            result.error("DEVICE_INFO_ERROR", "Failed to get device info: ${e.message}", null)
        }
    }
}

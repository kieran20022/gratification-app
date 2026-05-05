package com.example.gratify

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    private val channelName = "com.gratify/app_monitor"
    private var methodChannel: MethodChannel? = null
    private var pendingDelay: Map<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAccessibilityPermission" -> result.success(isAccessibilityServiceEnabled())
                "checkOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                "requestAccessibilityPermission" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "requestOverlayPermission" -> {
                    startActivity(
                        Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName"))
                    )
                    result.success(null)
                }
                "getInstalledApps" -> Thread {
                    val apps = getInstalledApps()
                    runOnUiThread { result.success(apps) }
                }.start()
                "getAppIcon" -> {
                    val pkg = call.argument<String>("packageName")!!
                    result.success(getAppIconBytes(pkg))
                }
                "startMonitoring" -> {
                    setMonitoringEnabled(true)
                    result.success(null)
                }
                "stopMonitoring" -> {
                    setMonitoringEnabled(false)
                    result.success(null)
                }
                "isMonitoringActive" -> {
                    // Monitoring is active if accessibility service is enabled AND the flag is set
                    val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                    result.success(isAccessibilityServiceEnabled() && prefs.getBoolean("flutter.monitoring_enabled", true))
                }
                "recordAccessGranted" -> {
                    val pkg = call.argument<String>("packageName")!!
                    getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        .edit()
                        .putLong("flutter.access_granted_$pkg", System.currentTimeMillis())
                        .apply()
                    result.success(null)
                }
                "previewReminder" -> {
                    val appName = call.argument<String>("appName") ?: ""
                    val intervalSeconds = call.argument<Int>("intervalSeconds") ?: 0
                    sendBroadcast(Intent(AppMonitorAccessibilityService.ACTION_PREVIEW_REMINDER).apply {
                        `package` = packageName
                        putExtra("appName", appName)
                        putExtra("intervalSeconds", intervalSeconds)
                    })
                    result.success(null)
                }
                "openApp" -> {
                    moveTaskToBack(true)
                    result.success(null)
                    finishAndRemoveTask()
                }
                "goHome" -> {
                    val home = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(home)
                    result.success(null)
                    finishAndRemoveTask()
                }
                else -> result.notImplemented()
            }
        }

        // Deliver any delay that arrived before the engine was ready
        pendingDelay?.let {
            methodChannel!!.invokeMethod("onAppOpened", it)
            pendingDelay = null
        }

        // Handle the intent that launched this activity
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("SHOW_DELAY", false) != true) return
        val data = mapOf(
            "packageName" to (intent.getStringExtra("PKG") ?: ""),
            "appName"     to (intent.getStringExtra("APP_NAME") ?: ""),
            "delaySeconds" to intent.getIntExtra("DELAY_SECS", 30)
        )
        if (methodChannel != null) {
            methodChannel!!.invokeMethod("onAppOpened", data)
        } else {
            pendingDelay = data
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val am = getSystemService(ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        return enabledServices.any { it.resolveInfo.serviceInfo.packageName == packageName &&
                it.resolveInfo.serviceInfo.name == AppMonitorAccessibilityService::class.java.name }
    }

    private fun setMonitoringEnabled(enabled: Boolean) {
        getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .edit()
            .putBoolean("flutter.monitoring_enabled", enabled)
            .apply()
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        return pm.getInstalledApplications(0)
            .filter { pm.getLaunchIntentForPackage(it.packageName) != null && it.packageName != packageName }
            .map { mapOf("name" to pm.getApplicationLabel(it).toString(), "packageName" to it.packageName) }
            .sortedBy { it["name"] }
    }

    private fun getAppIconBytes(pkg: String): ByteArray? {
        return try {
            val drawable = packageManager.getApplicationIcon(pkg)
            val size = 108
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            val out = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            bitmap.recycle()
            out.toByteArray()
        } catch (_: Exception) { null }
    }
}

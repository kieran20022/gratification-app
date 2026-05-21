package com.example.gratify

import android.accessibilityservice.AccessibilityServiceInfo
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Process
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
            "packageName"      to (intent.getStringExtra("PKG") ?: ""),
            "appName"          to (intent.getStringExtra("APP_NAME") ?: ""),
            "delaySeconds"     to intent.getIntExtra("DELAY_SECS", 30),
            "fromSessionLimit" to intent.getBooleanExtra("FROM_SESSION_LIMIT", false)
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

    private fun getInstalledApps(): List<Map<String, Any>> {
        val screenTimes = getScreenTimeMap()
        val pm = packageManager
        return pm.getInstalledApplications(0)
            .filter { pm.getLaunchIntentForPackage(it.packageName) != null && it.packageName != packageName }
            .map {
                mapOf(
                    "name"       to pm.getApplicationLabel(it).toString(),
                    "packageName" to it.packageName,
                    "screenTime" to (screenTimes[it.packageName] ?: 0L),
                )
            }
            .sortedWith(
                compareByDescending<Map<String, Any>> { it["screenTime"] as Long }
                    .thenBy { it["name"] as String }
            )
    }

    private fun getScreenTimeMap(): Map<String, Long> {
        return try {
            val appOps = getSystemService(APP_OPS_SERVICE) as AppOpsManager
            val mode   = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
            if (mode != AppOpsManager.MODE_ALLOWED) return emptyMap()

            val usm = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
            val cal = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, 0)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
            }
            val stats = usm.queryAndAggregateUsageStats(cal.timeInMillis, System.currentTimeMillis())
            stats.mapValues { it.value.totalTimeInForeground / 1_000L }
        } catch (_: Exception) { emptyMap() }
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

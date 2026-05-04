package com.example.gratify

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray

class AppMonitorAccessibilityService : AccessibilityService() {

    private var lastForegroundPkg: String? = null
    // Cache of packages that have a launcher intent (user-launchable apps)
    private val launchableCache = mutableSetOf<String>()
    private var cacheFilled = false

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        if (pkg == packageName) return          // Gratify itself
        if (!isLaunchableApp(pkg)) return       // system dialogs, keyboard, status bar, etc.
        if (pkg == lastForegroundPkg) return    // navigating within the same app

        lastForegroundPkg = pkg

        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!flutterPrefs.getBoolean("flutter.monitoring_enabled", true)) return

        val app = findRestrictedApp(pkg, flutterPrefs) ?: return

        startActivity(Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("SHOW_DELAY", true)
            putExtra("PKG", pkg)
            putExtra("APP_NAME", app.first)
            putExtra("DELAY_SECS", app.second)
        })
    }

    override fun onInterrupt() {}

    private fun isLaunchableApp(pkg: String): Boolean {
        if (!cacheFilled) fillCache()
        return launchableCache.contains(pkg)
    }

    private fun fillCache() {
        packageManager.getInstalledApplications(PackageManager.GET_META_DATA)
            .filter { packageManager.getLaunchIntentForPackage(it.packageName) != null }
            .forEach { launchableCache.add(it.packageName) }
        cacheFilled = true
    }

    private fun findRestrictedApp(pkg: String, prefs: android.content.SharedPreferences): Pair<String, Int>? {
        val json = prefs.getString("flutter.restricted_apps", null) ?: return null
        return try {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optString("packageName") == pkg) {
                    return Pair(obj.getString("name"), obj.getInt("delaySeconds"))
                }
            }
            null
        } catch (_: Exception) { null }
    }
}

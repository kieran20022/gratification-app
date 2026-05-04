package com.example.gratify

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray

class AppMonitorAccessibilityService : AccessibilityService() {

    // Cache of packages that have a launcher intent (user-launchable apps)
    private val launchableCache = mutableSetOf<String>()
    private var cacheFilled = false

    // Last user-launchable package that came to the foreground.
    // Null means "unknown / came from home or recents" → next open is a fresh launch.
    private var lastLaunchablePkg: String? = null

    // Packages that represent the home screen or recents overlay.
    // When these fire we reset lastLaunchablePkg so the next app open is treated
    // as a fresh launch (fixes the recents re-open suppression bug).
    // All other non-launchable system events (keyboard, dialogs, story transitions, etc.)
    // are ignored without touching lastLaunchablePkg so in-app navigation stays suppressed.
    private val homeAndRecentsPackages: Set<String> by lazy {
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        packageManager.queryIntentActivities(homeIntent, 0)
            .map { it.activityInfo.packageName }
            .toSet() + setOf("com.android.systemui")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return

        if (homeAndRecentsPackages.contains(pkg)) {
            lastLaunchablePkg = null   // user went home/recents — next open is fresh
            return
        }

        if (!isLaunchableApp(pkg)) return   // other system events — ignore entirely

        val sameApp = pkg == lastLaunchablePkg
        lastLaunchablePkg = pkg
        if (sameApp) return                 // in-app navigation (comments, stories, sub-screens)

        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!flutterPrefs.getBoolean("flutter.monitoring_enabled", true)) return

        val app = findRestrictedApp(pkg, flutterPrefs) ?: return

        // Always enforce a minimum 5 s immunity after access is granted so moveTaskToBack
        // (which surfaces the restricted app right after the countdown) never immediately
        // re-triggers the delay. graceMinutes > 0 extends this to the user-configured window.
        val graceMs = if (app.third > 0) app.third * 60_000L else 5_000L
        val grantedAt = flutterPrefs.getLong("flutter.access_granted_$pkg", 0L)
        if (grantedAt > 0L && System.currentTimeMillis() - grantedAt < graceMs) return

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

    private fun findRestrictedApp(pkg: String, prefs: android.content.SharedPreferences): Triple<String, Int, Int>? {
        val json = prefs.getString("flutter.restricted_apps", null) ?: return null
        return try {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optString("packageName") == pkg) {
                    return Triple(
                        obj.getString("name"),
                        obj.getInt("delaySeconds"),
                        obj.optInt("graceMinutes", 2),
                    )
                }
            }
            null
        } catch (_: Exception) { null }
    }
}

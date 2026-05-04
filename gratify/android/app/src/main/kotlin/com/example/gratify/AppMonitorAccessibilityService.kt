package com.example.gratify

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray
import java.util.Calendar

class AppMonitorAccessibilityService : AccessibilityService() {

    // Cache of packages that have a launcher intent (user-launchable apps)
    private val launchableCache = mutableSetOf<String>()
    private var cacheFilled = false

    // Last user-launchable package that came to the foreground.
    // Null means "unknown / came from home or recents" -> next open is a fresh launch.
    private var lastLaunchablePkg: String? = null

    // Package whose overlay is currently visible (null = no overlay).
    private var currentOverlayPackage: String? = null
    private var overlayView: View? = null

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
            lastLaunchablePkg = null   // user went home/recents -- next open is fresh
            hideOverlayIfActive()      // remove overlay when leaving the restricted app
            return
        }

        if (!isLaunchableApp(pkg)) return   // other system events -- ignore entirely

        val sameApp = pkg == lastLaunchablePkg
        lastLaunchablePkg = pkg

        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!flutterPrefs.getBoolean("flutter.monitoring_enabled", true)) return

        val app = findRestrictedApp(pkg, flutterPrefs)

        // Overlay state is updated on every foreground change, independent of the
        // delay/grace logic, so it activates even when the user returns within the grace window.
        updateOverlay(pkg, app)

        if (app == null) return
        if (sameApp) return                 // in-app navigation (comments, stories, sub-screens)

        // Always enforce a minimum 5 s immunity after access is granted so moveTaskToBack
        // (which surfaces the restricted app right after the countdown) never immediately
        // re-triggers the delay. graceMinutes > 0 extends this to the user-configured window.
        val graceMs = if (app.graceMinutes > 0) app.graceMinutes * 60_000L else 5_000L
        val grantedAt = flutterPrefs.getLong("flutter.access_granted_$pkg", 0L)
        if (grantedAt > 0L && System.currentTimeMillis() - grantedAt < graceMs) return

        startActivity(Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("SHOW_DELAY", true)
            putExtra("PKG", pkg)
            putExtra("APP_NAME", app.name)
            putExtra("DELAY_SECS", app.delaySeconds)
        })
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        hideOverlay()
    }

    // -------------------------------------------------------------------------
    // Grayscale overlay
    // -------------------------------------------------------------------------

    private fun updateOverlay(pkg: String, app: RestrictedAppInfo?) {
        val shouldShow = app != null
                && app.grayscale
                && isInGrayscaleWindow(app.grayscaleStartMinute, app.grayscaleEndMinute)

        when {
            shouldShow && currentOverlayPackage != pkg -> {
                showOverlay()
                currentOverlayPackage = pkg
            }
            !shouldShow && currentOverlayPackage != null -> {
                hideOverlay()
                currentOverlayPackage = null
            }
        }
    }

    private fun hideOverlayIfActive() {
        if (currentOverlayPackage != null) {
            hideOverlay()
            currentOverlayPackage = null
        }
    }

    // Shows a full-screen translucent gray view using TYPE_ACCESSIBILITY_OVERLAY.
    // The overlay is touch-transparent so the app beneath remains fully usable.
    // The gray tint at ~55% opacity compresses the color range of the content
    // beneath it, producing a perceptible desaturation without blocking interaction.
    private fun showOverlay() {
        if (overlayView != null) return
        val wm = getSystemService(WindowManager::class.java) ?: return
        val view = View(this).apply {
            setBackgroundColor(Color.argb(140, 120, 120, 120))
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        try {
            wm.addView(view, params)
            overlayView = view
        } catch (_: Exception) { }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        try {
            val wm = getSystemService(WindowManager::class.java)
            wm?.removeView(view)
        } catch (_: Exception) { }
        overlayView = null
    }

    // Returns true if the current time falls within [startMinute, endMinute).
    // When either bound is null the window is treated as all-day.
    // Supports overnight windows where start > end (e.g. 22:00 to 08:00).
    private fun isInGrayscaleWindow(startMinute: Int?, endMinute: Int?): Boolean {
        if (startMinute == null || endMinute == null) return true
        val now = getNowMinutes()
        return if (startMinute <= endMinute) {
            now in startMinute until endMinute
        } else {
            now >= startMinute || now < endMinute
        }
    }

    private fun getNowMinutes(): Int {
        val cal = Calendar.getInstance()
        return cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
    }

    // -------------------------------------------------------------------------
    // App lookup helpers
    // -------------------------------------------------------------------------

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

    private fun findRestrictedApp(pkg: String, prefs: android.content.SharedPreferences): RestrictedAppInfo? {
        val json = prefs.getString("flutter.restricted_apps", null) ?: return null
        return try {
            val arr = JSONArray(json)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optString("packageName") == pkg) {
                    return RestrictedAppInfo(
                        name                 = obj.getString("name"),
                        delaySeconds         = obj.getInt("delaySeconds"),
                        graceMinutes         = obj.optInt("graceMinutes", 2),
                        grayscale            = obj.optBoolean("grayscale", false),
                        grayscaleStartMinute = if (obj.isNull("grayscaleStartMinute")) null
                                               else obj.getInt("grayscaleStartMinute"),
                        grayscaleEndMinute   = if (obj.isNull("grayscaleEndMinute")) null
                                               else obj.getInt("grayscaleEndMinute"),
                    )
                }
            }
            null
        } catch (_: Exception) { null }
    }

    private data class RestrictedAppInfo(
        val name: String,
        val delaySeconds: Int,
        val graceMinutes: Int,
        val grayscale: Boolean,
        val grayscaleStartMinute: Int?,
        val grayscaleEndMinute: Int?,
    )
}

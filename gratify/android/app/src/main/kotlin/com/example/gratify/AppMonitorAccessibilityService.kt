package com.example.gratify

import android.accessibilityservice.AccessibilityService
import android.animation.AnimatorSet
import android.animation.Keyframe
import android.animation.ObjectAnimator
import android.animation.PropertyValuesHolder
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.animation.AccelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.TextView
import org.json.JSONArray
import java.util.Calendar

class AppMonitorAccessibilityService : AccessibilityService() {

    companion object {
        const val ACTION_PREVIEW_REMINDER = "com.example.gratify.PREVIEW_REMINDER"
    }

    private val launchableCache = mutableSetOf<String>()
    private var cacheFilled = false

    private val activeRestrictedSessions = mutableSetOf<String>()

    private val sessionStartTimes = mutableMapOf<String, Long>()
    private val handler = Handler(Looper.getMainLooper())
    private val pendingReminderRunnables = mutableMapOf<String, Runnable>()
    private val pendingLimitRunnables = mutableMapOf<String, Runnable>()

    private var currentOverlayPackage: String? = null
    private var overlayView: View? = null

    private val homePackages: Set<String> by lazy {
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        packageManager.queryIntentActivities(homeIntent, 0)
            .map { it.activityInfo.packageName }
            .toSet()
    }

    private val previewReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val appName = intent.getStringExtra("appName") ?: return
            val intervalSeconds = intent.getIntExtra("intervalSeconds", 0)
            showReminderBanner(appName, intervalSeconds)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        val filter = IntentFilter(ACTION_PREVIEW_REMINDER)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(previewReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(previewReceiver, filter)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return

        if (homePackages.contains(pkg)) {
            cancelAllSessionTimers()
            activeRestrictedSessions.clear()
            hideOverlayIfActive()
            return
        }

        if (!isLaunchableApp(pkg)) return

        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!flutterPrefs.getBoolean("flutter.monitoring_enabled", true)) return

        val app = findRestrictedApp(pkg, flutterPrefs)
        updateOverlay(pkg, app)

        if (app == null) return

        if (activeRestrictedSessions.contains(pkg)) return

        val graceMs = if (app.graceMinutes > 0) app.graceMinutes * 60_000L else 5_000L
        val grantedAt = flutterPrefs.getLong("flutter.access_granted_$pkg", 0L)
        if (grantedAt > 0L && System.currentTimeMillis() - grantedAt < graceMs) {
            activeRestrictedSessions.add(pkg)
            startSessionTimer(pkg, app)
            return
        }

        triggerDelay(pkg, app)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(previewReceiver) } catch (_: Exception) {}
        cancelAllSessionTimers()
        hideOverlay()
    }

    // -------------------------------------------------------------------------
    // Session timers
    // -------------------------------------------------------------------------

    private fun startSessionTimer(pkg: String, app: RestrictedAppInfo) {
        if (sessionStartTimes.containsKey(pkg)) return
        sessionStartTimes[pkg] = System.currentTimeMillis()
        if (app.reminderIntervalSeconds > 0) scheduleReminder(pkg, app, 1)
        if (app.usageLimitSeconds > 0) scheduleUsageLimit(pkg, app)
    }

    private fun scheduleReminder(pkg: String, app: RestrictedAppInfo, count: Int) {
        val startTime = sessionStartTimes[pkg] ?: return
        val fireAt = startTime + count.toLong() * app.reminderIntervalSeconds * 1_000L
        val delay = fireAt - System.currentTimeMillis()
        if (delay < 0) return

        val runnable = Runnable {
            if (!activeRestrictedSessions.contains(pkg)) return@Runnable
            showReminderBanner(app.name, count * app.reminderIntervalSeconds)
            scheduleReminder(pkg, app, count + 1)
        }
        pendingReminderRunnables[pkg] = runnable
        handler.postDelayed(runnable, delay)
    }

    private fun scheduleUsageLimit(pkg: String, app: RestrictedAppInfo) {
        val startTime = sessionStartTimes[pkg] ?: return
        val fireAt = startTime + app.usageLimitSeconds * 1_000L
        val delay = fireAt - System.currentTimeMillis()

        val runnable = Runnable {
            if (!activeRestrictedSessions.contains(pkg)) return@Runnable
            activeRestrictedSessions.remove(pkg)
            sessionStartTimes.remove(pkg)
            pendingReminderRunnables.remove(pkg)?.let { handler.removeCallbacks(it) }
            pendingLimitRunnables.remove(pkg)
            triggerDelay(pkg, app)
        }
        pendingLimitRunnables[pkg] = runnable
        handler.postDelayed(runnable, delay.coerceAtLeast(0))
    }

    private fun cancelAllSessionTimers() {
        pendingReminderRunnables.values.forEach { handler.removeCallbacks(it) }
        pendingLimitRunnables.values.forEach { handler.removeCallbacks(it) }
        pendingReminderRunnables.clear()
        pendingLimitRunnables.clear()
        sessionStartTimes.clear()
    }

    private fun triggerDelay(pkg: String, app: RestrictedAppInfo) {
        startActivity(Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("SHOW_DELAY", true)
            putExtra("PKG", pkg)
            putExtra("APP_NAME", app.name)
            putExtra("DELAY_SECS", app.delaySeconds)
        })
    }

    private fun showReminderBanner(appName: String, elapsedSeconds: Int) {
        val wm = getSystemService(WindowManager::class.java) ?: return

        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val animIdx     = flutterPrefs.getInt("flutter.reminder_animation", 0)
        val posIdx      = flutterPrefs.getInt("flutter.reminder_position",  1)
        val msgTemplate = flutterPrefs.getString("flutter.reminder_message", null)
                          ?: "You've been in {app} for {time}"

        val timeStr = if (elapsedSeconds < 60) {
            val s = elapsedSeconds
            "$s ${if (s == 1) "second" else "seconds"}"
        } else {
            val m = elapsedSeconds / 60
            "$m ${if (m == 1) "minute" else "minutes"}"
        }
        val message = msgTemplate.replace("{app}", appName).replace("{time}", timeStr)

        // Extra padding around the pill so scale animations never clip rounded corners.
        val paddingPx = (50 * resources.displayMetrics.density).toInt()

        val bg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 200f
            setColor(Color.argb(235, 28, 26, 46))
        }
        val tv = TextView(this).apply {
            text = message
            setTextColor(Color.WHITE)
            textSize = 14f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(64, 32, 64, 32)
            background = bg
        }
        val container = FrameLayout(this).apply {
            setPadding(paddingPx, paddingPx, paddingPx, paddingPx)
            addView(tv, FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            ))
        }

        val yOffsetPx = (80 * resources.displayMetrics.density).toInt()
        val gravity   = when (posIdx) {
            0    -> Gravity.TOP    or Gravity.CENTER_HORIZONTAL
            2    -> Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            else -> Gravity.CENTER
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            this.gravity = gravity
            if (posIdx != 1) y = yOffsetPx
        }

        try {
            wm.addView(container, params)

            when (animIdx) {
                4 -> { /* none — container appears instantly at full size */ }

                3 -> { // fade in
                    container.alpha = 0f
                    ObjectAnimator.ofFloat(container, "alpha", 0f, 1f).apply {
                        duration     = 400
                        interpolator = DecelerateInterpolator()
                    }.start()
                }

                else -> {
                    // Entrance: fade + scale + float up (0–300 ms)
                    container.alpha        = 0f
                    container.scaleX       = 0.82f
                    container.scaleY       = 0.82f
                    container.translationY = 40f
                    AnimatorSet().apply {
                        playTogether(
                            ObjectAnimator.ofFloat(container, "alpha",        0f,    1f),
                            ObjectAnimator.ofFloat(container, "scaleX",       0.82f, 1f),
                            ObjectAnimator.ofFloat(container, "scaleY",       0.82f, 1f),
                            ObjectAnimator.ofFloat(container, "translationY", 40f,   0f),
                        )
                        duration     = 300
                        interpolator = DecelerateInterpolator(2f)
                    }.start()

                    // Attention animation on the inner tv — padding headroom prevents clipping
                    when (animIdx) {
                        0 -> { // bounce: spring-like scale keyframes
                            val bounce = ObjectAnimator.ofPropertyValuesHolder(tv,
                                PropertyValuesHolder.ofKeyframe("scaleX",
                                    Keyframe.ofFloat(0f,    1f),
                                    Keyframe.ofFloat(0.25f, 1.10f),
                                    Keyframe.ofFloat(0.55f, 0.95f),
                                    Keyframe.ofFloat(0.78f, 1.04f),
                                    Keyframe.ofFloat(1f,    1f)),
                                PropertyValuesHolder.ofKeyframe("scaleY",
                                    Keyframe.ofFloat(0f,    1f),
                                    Keyframe.ofFloat(0.25f, 1.10f),
                                    Keyframe.ofFloat(0.55f, 0.95f),
                                    Keyframe.ofFloat(0.78f, 1.04f),
                                    Keyframe.ofFloat(1f,    1f)),
                            ).apply { duration = 560 }
                            handler.postDelayed({ bounce.start() }, 380)
                        }
                        1 -> { // pulse: gentle scale in/out
                            val pulse = ObjectAnimator.ofPropertyValuesHolder(tv,
                                PropertyValuesHolder.ofFloat("scaleX", 1f, 1.08f, 1f),
                                PropertyValuesHolder.ofFloat("scaleY", 1f, 1.08f, 1f),
                            ).apply { duration = 600 }
                            handler.postDelayed({ pulse.start() }, 380)
                        }
                        2 -> { // shake: horizontal translation
                            val shake = ObjectAnimator.ofFloat(tv, "translationX",
                                0f, 14f, -14f, 10f, -10f, 6f, -6f, 0f).apply { duration = 500 }
                            handler.postDelayed({ shake.start() }, 350)
                        }
                    }
                }
            }

            // Exit: fade out + scale down (at 3 200 ms)
            val exit = AnimatorSet().apply {
                playTogether(
                    ObjectAnimator.ofFloat(container, "alpha",  1f, 0f),
                    ObjectAnimator.ofFloat(container, "scaleX", 1f, 0.88f),
                    ObjectAnimator.ofFloat(container, "scaleY", 1f, 0.88f),
                )
                duration     = 260
                interpolator = AccelerateInterpolator()
            }
            handler.postDelayed({ exit.start() }, 3_200)
            handler.postDelayed({
                try { wm.removeView(container) } catch (_: Exception) {}
            }, 3_460)

        } catch (_: Exception) {}
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
                        name                   = obj.getString("name"),
                        delaySeconds           = obj.getInt("delaySeconds"),
                        graceMinutes           = obj.optInt("graceMinutes", 2),
                        grayscale              = obj.optBoolean("grayscale", false),
                        grayscaleStartMinute   = if (obj.isNull("grayscaleStartMinute")) null
                                                 else obj.getInt("grayscaleStartMinute"),
                        grayscaleEndMinute     = if (obj.isNull("grayscaleEndMinute")) null
                                                 else obj.getInt("grayscaleEndMinute"),
                        reminderIntervalSeconds = obj.optInt("reminderIntervalSeconds", 0),
                        usageLimitSeconds      = obj.optInt("usageLimitSeconds", 0),
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
        val reminderIntervalSeconds: Int,
        val usageLimitSeconds: Int,
    )
}

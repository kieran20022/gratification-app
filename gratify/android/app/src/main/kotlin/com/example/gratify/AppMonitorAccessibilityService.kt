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
    private val pendingDelayPackages = mutableSetOf<String>()

    private val sessionStartTimes = mutableMapOf<String, Long>()
    private val handler = Handler(Looper.getMainLooper())
    private val pendingReminderRunnables = mutableMapOf<String, Runnable>()
    private val pendingLimitRunnables = mutableMapOf<String, Runnable>()

    private var currentOverlayPackage: String? = null
    private var overlayView: View? = null
    private var activeBannerContainer: View? = null
    // Timestamp of the last wm.addView call for a reminder banner.
    // Used to suppress spurious home-package accessibility events that some devices
    // fire when a TYPE_ACCESSIBILITY_OVERLAY window is added, which would otherwise
    // clear activeRestrictedSessions and cause triggerDelay to fire.
    private var lastBannerAddedAt: Long = 0L

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
            // Some devices fire a spurious home-package event immediately after a
            // TYPE_ACCESSIBILITY_OVERLAY window is added. Ignore it if we just showed
            // a reminder banner (real home navigation takes longer than 600 ms).
            if (System.currentTimeMillis() - lastBannerAddedAt > 600L) {
                cancelAllSessionTimers()
                activeRestrictedSessions.clear()
                hideOverlayIfActive()
            }
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
            // User completed the delay — clear any pending flag and start the session.
            pendingDelayPackages.remove(pkg)
            activeRestrictedSessions.add(pkg)
            startSessionTimer(pkg, app)
            return
        }

        // Delay screen is already showing for this package — don't re-trigger.
        if (pendingDelayPackages.contains(pkg)) return

        pendingDelayPackages.add(pkg)
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
        // Capture now once so both timers compute delays from the same reference.
        // Without this, scheduleUsageLimit would call currentTimeMillis() a few ms
        // later than scheduleReminder, giving the limit a slightly shorter delay and
        // causing it to fire before the reminder when both intervals are equal.
        val now = System.currentTimeMillis()
        sessionStartTimes[pkg] = now
        if (app.reminderIntervalSeconds > 0) scheduleReminder(pkg, app, 1, scheduledAt = now)
        if (app.usageLimitSeconds > 0) scheduleUsageLimit(pkg, app, scheduledAt = now)
    }

    private fun scheduleReminder(
        pkg: String,
        app: RestrictedAppInfo,
        count: Int,
        scheduledAt: Long = System.currentTimeMillis(),
    ) {
        // Skip reminders that would fire at or after the usage limit — the delay screen
        // already communicates the session end; showing a banner simultaneously is confusing.
        if (app.usageLimitSeconds > 0 &&
                count.toLong() * app.reminderIntervalSeconds >= app.usageLimitSeconds) return

        val startTime = sessionStartTimes[pkg] ?: return
        val fireAt = startTime + count.toLong() * app.reminderIntervalSeconds * 1_000L
        val delay = fireAt - scheduledAt
        if (delay < 0) return

        val runnable = Runnable {
            if (!activeRestrictedSessions.contains(pkg)) return@Runnable
            showReminderBanner(app.name, count * app.reminderIntervalSeconds)
            scheduleReminder(pkg, app, count + 1)
        }
        pendingReminderRunnables[pkg] = runnable
        handler.postDelayed(runnable, delay)
    }

    private fun scheduleUsageLimit(
        pkg: String,
        app: RestrictedAppInfo,
        scheduledAt: Long = System.currentTimeMillis(),
    ) {
        val startTime = sessionStartTimes[pkg] ?: return
        val fireAt = startTime + app.usageLimitSeconds * 1_000L
        val delay = fireAt - scheduledAt

        val runnable = Runnable {
            if (!activeRestrictedSessions.contains(pkg)) return@Runnable
            activeRestrictedSessions.remove(pkg)
            sessionStartTimes.remove(pkg)
            pendingReminderRunnables.remove(pkg)?.let { handler.removeCallbacks(it) }
            pendingLimitRunnables.remove(pkg)
            dismissActiveBanner()
            pendingDelayPackages.add(pkg)
            triggerDelay(pkg, app, fromSessionLimit = true)
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
        pendingDelayPackages.clear()
    }

    private fun dismissActiveBanner() {
        val container = activeBannerContainer ?: return
        activeBannerContainer = null
        try {
            getSystemService(WindowManager::class.java)?.removeView(container)
        } catch (_: Exception) {}
    }

    private fun triggerDelay(pkg: String, app: RestrictedAppInfo, fromSessionLimit: Boolean = false) {
        startActivity(Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("SHOW_DELAY", true)
            putExtra("PKG", pkg)
            putExtra("APP_NAME", app.name)
            putExtra("DELAY_SECS", app.delaySeconds)
            putExtra("FROM_SESSION_LIMIT", fromSessionLimit)
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

        val paddingPx = (50 * resources.displayMetrics.density).toInt()

        val colorModeIdx = flutterPrefs.getInt("flutter.reminder_color_mode", 0)
        val customRgb    = flutterPrefs.getInt("flutter.reminder_custom_color", 0x7B6FD4)
        val bannerBgColor: Int
        val bannerTextColor: Int
        when (colorModeIdx) {
            1 -> {
                bannerBgColor   = Color.argb(235, 248, 247, 255)
                bannerTextColor = Color.rgb(28, 26, 46)
            }
            2 -> {
                val r = (customRgb shr 16) and 0xFF
                val g = (customRgb shr 8)  and 0xFF
                val b = customRgb          and 0xFF
                val luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                bannerBgColor   = Color.argb(235, r, g, b)
                bannerTextColor = if (luminance > 0.45) Color.rgb(28, 26, 46) else Color.WHITE
            }
            else -> {
                bannerBgColor   = Color.argb(235, 28, 26, 46)
                bannerTextColor = Color.WHITE
            }
        }

        val bg = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 200f
            setColor(bannerBgColor)
        }
        val screenWidth = resources.displayMetrics.widthPixels
        val tv = TextView(this).apply {
            text = message
            setTextColor(bannerTextColor)
            textSize = 14f
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            setPadding(64, 32, 64, 32)
            background = bg
            maxWidth = screenWidth - 2 * paddingPx - 128
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
            lastBannerAddedAt = System.currentTimeMillis()
            wm.addView(container, params)
            activeBannerContainer = container

            when (animIdx) {
                4 -> { /* none */ }

                3 -> {
                    container.alpha = 0f
                    ObjectAnimator.ofFloat(container, "alpha", 0f, 1f).apply {
                        duration     = 400
                        interpolator = DecelerateInterpolator()
                    }.start()
                }

                else -> {
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

                    when (animIdx) {
                        0 -> {
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
                            handler.postDelayed({ try { bounce.start() } catch (_: Exception) {} }, 380)
                        }
                        1 -> {
                            val pulse = ObjectAnimator.ofPropertyValuesHolder(tv,
                                PropertyValuesHolder.ofFloat("scaleX", 1f, 1.08f, 1f),
                                PropertyValuesHolder.ofFloat("scaleY", 1f, 1.08f, 1f),
                            ).apply { duration = 600 }
                            handler.postDelayed({ try { pulse.start() } catch (_: Exception) {} }, 380)
                        }
                        2 -> {
                            val shake = ObjectAnimator.ofFloat(tv, "translationX",
                                0f, 14f, -14f, 10f, -10f, 6f, -6f, 0f).apply { duration = 500 }
                            handler.postDelayed({ try { shake.start() } catch (_: Exception) {} }, 350)
                        }
                    }
                }
            }

            // Exit: fade out + scale down (3 s visibility)
            val exit = AnimatorSet().apply {
                playTogether(
                    ObjectAnimator.ofFloat(container, "alpha",  1f, 0f),
                    ObjectAnimator.ofFloat(container, "scaleX", 1f, 0.88f),
                    ObjectAnimator.ofFloat(container, "scaleY", 1f, 0.88f),
                )
                duration     = 260
                interpolator = AccelerateInterpolator()
            }
            handler.postDelayed({ try { exit.start() } catch (_: Exception) {} }, 3_000)
            handler.postDelayed({
                try { wm.removeView(container) } catch (_: Exception) {}
                if (activeBannerContainer === container) activeBannerContainer = null
            }, 3_260)

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

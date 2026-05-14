package com.example.gratify

import android.accessibilityservice.AccessibilityService
import android.animation.ValueAnimator
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
import android.widget.FrameLayout
import android.widget.TextView
import org.json.JSONArray
import java.util.Calendar

class AppMonitorAccessibilityService : AccessibilityService() {

    companion object {
        const val ACTION_PREVIEW_REMINDER = "com.example.gratify.PREVIEW_REMINDER"
        // ~3.15 s at full opacity (350 ms fade-in, 3500 ms hold, 260 ms fade-out, removed at 4260 ms)
        private const val BANNER_DURATION_MS = 4_000L
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

    // Stored runnables for the active banner's fade-out and removal so they can be
    // cancelled by dismissActiveBanner instead of running on a removed view.
    private var bannerFadeRunnable: Runnable? = null
    private var bannerRemoveRunnable: Runnable? = null

    // lastBannerAddedAt / bannerExpiresAt are set only after a successful wm.addView so
    // that a failed add never silently blocks the next attempt. bannerExpiresAt is also
    // used as a minimum interval guard: no new banner fires before it has passed.
    private var lastBannerAddedAt: Long = 0L
    private var bannerExpiresAt: Long = 0L

    // Debounce handle for session clears triggered by home-package events. The clear is
    // deferred by 2 s and cancelled if a non-home window event arrives first, which
    // absorbs spurious home-package events that some apps (e.g. TikTok) fire transiently
    // during in-feed navigation without ever actually going to the launcher.
    private var pendingSessionClear: Runnable? = null

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
            // Debounce the session clear by 2 s. If TikTok (or similar) fires a spurious
            // home-package event during in-app navigation, a real window event from the
            // restricted app will arrive within milliseconds and cancel this clear before
            // it executes. Only a genuine, sustained trip to the home screen (no foreground
            // app event for 2 s) actually clears the session.
            if (pendingSessionClear == null) {
                val clear = Runnable {
                    cancelAllSessionTimers()
                    activeRestrictedSessions.clear()
                    hideOverlayIfActive()
                    pendingSessionClear = null
                }
                pendingSessionClear = clear
                handler.postDelayed(clear, 2_000L)
            }
            return
        }

        // Any non-home foreground event means an app is active — cancel any pending
        // session clear so a spurious home event can't reset a live session.
        pendingSessionClear?.let { handler.removeCallbacks(it); pendingSessionClear = null }

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
        pendingSessionClear?.let { handler.removeCallbacks(it) }
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
            showReminderBanner(app.name, count * app.reminderIntervalSeconds, app.reminderIntervalSeconds)
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
            pendingDelayPackages.add(pkg)
            // If a reminder banner fired recently, let it finish its 3-second minimum
            // display before force-dismissing it and showing the delay screen.
            val bannerAge = System.currentTimeMillis() - lastBannerAddedAt
            val wait = if (activeBannerContainer != null && bannerAge < 3_000L) 3_000L - bannerAge else 0L
            handler.postDelayed({
                dismissActiveBanner(force = true)
                triggerDelay(pkg, app, fromSessionLimit = true)
            }, wait)
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

    // Removes the active banner. Non-forced calls are ignored if the banner has been
    // visible for less than 3 seconds, ensuring a minimum readable display time.
    private fun dismissActiveBanner(force: Boolean = false) {
        val container = activeBannerContainer ?: return
        if (!force && System.currentTimeMillis() - lastBannerAddedAt < 3_000L) return
        activeBannerContainer = null
        // Cancel the scheduled fade/remove runnables so they don't run on a removed view.
        bannerFadeRunnable?.let { handler.removeCallbacks(it); bannerFadeRunnable = null }
        bannerRemoveRunnable?.let { handler.removeCallbacks(it); bannerRemoveRunnable = null }
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

    private fun showReminderBanner(appName: String, elapsedSeconds: Int, intervalSeconds: Int = 0) {
        val now = System.currentTimeMillis()
        // Block until the current banner has expired AND enough time has elapsed since
        // the last banner started (based on the reminder interval). This prevents a
        // session-restart from scheduling a new count=1 timer that fires just after the
        // previous banner expires, producing a double-flash.
        val minNextAt = if (intervalSeconds > 0) lastBannerAddedAt + intervalSeconds * 1_000L
                        else bannerExpiresAt
        if (now < maxOf(bannerExpiresAt, minNextAt)) return
        dismissActiveBanner()
        val wm = getSystemService(WindowManager::class.java) ?: return

        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        // Flutter's shared_preferences stores Dart ints as Long on Android.
        // getInt() on a Long-typed key throws ClassCastException; use getLong().toInt().
        val posIdx      = flutterPrefs.getLong("flutter.reminder_position", 1L).toInt()
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

        val colorModeIdx = flutterPrefs.getLong("flutter.reminder_color_mode", 0L).toInt()
        val customRgb    = flutterPrefs.getLong("flutter.reminder_custom_color", 0x7B6FD4L).toInt()
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

        // ValueAnimator drives animation via Choreographer and never calls
        // isAttachedToWindow(), so it works immediately after wm.addView() without
        // needing post{} or attachment guards that ObjectAnimator/AnimatorSet require.
        container.alpha = 0f

        try {
            wm.addView(container, params)
            // Set timestamps only after a successful addView. If addView throws, we
            // leave bannerExpiresAt unchanged so the next call is not silently blocked.
            lastBannerAddedAt = System.currentTimeMillis()
            bannerExpiresAt = lastBannerAddedAt + BANNER_DURATION_MS
            activeBannerContainer = container

            ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 350
                addUpdateListener { container.alpha = animatedValue as Float }
            }.start()

            val fadeOut = ValueAnimator.ofFloat(1f, 0f).apply {
                duration = 260
                addUpdateListener { container.alpha = animatedValue as Float }
            }

            val fadeRunnable = Runnable { fadeOut.start() }
            val removeRunnable = Runnable {
                fadeOut.cancel()
                try { wm.removeView(container) } catch (_: Exception) {}
                if (activeBannerContainer === container) activeBannerContainer = null
                bannerFadeRunnable = null
                bannerRemoveRunnable = null
            }
            bannerFadeRunnable = fadeRunnable
            bannerRemoveRunnable = removeRunnable
            handler.postDelayed(fadeRunnable, BANNER_DURATION_MS - 500L)
            handler.postDelayed(removeRunnable, BANNER_DURATION_MS + 260L)

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

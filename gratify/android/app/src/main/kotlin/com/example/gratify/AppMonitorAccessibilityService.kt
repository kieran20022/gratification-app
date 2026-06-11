package com.example.gratify

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
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
import android.view.accessibility.AccessibilityWindowInfo
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import android.widget.TextView
import org.json.JSONArray
import java.util.Calendar

class AppMonitorAccessibilityService : AccessibilityService() {

    companion object {
        const val ACTION_PREVIEW_REMINDER = "com.example.gratify.PREVIEW_REMINDER"
        private const val HOME_DEBOUNCE_MS = 8_000L
        // How long to ignore window-state events after WE add an overlay window,
        // so we don't react to the event the system fires for our own overlay.
        private const val SELF_EVENT_GUARD_MS = 1_500L
        // If the delay screen was requested less than this long ago, a foreground
        // event for the target app is part of the launch race, not the user
        // having dismissed the delay screen.
        private const val DELAY_LAUNCH_RACE_MS = 3_000L
    }

    // Lazily-populated per-package cache of "has a launcher activity". A map
    // (instead of a fill-once set) means apps installed AFTER the service
    // started are still detected, and negative results are cached too.
    private val launchableCache = mutableMapOf<String, Boolean>()

    private val activeRestrictedSessions = mutableSetOf<String>()
    private val pendingDelayPackages = mutableSetOf<String>()
    // When each package entered the pending-delay state. Used to tell "the delay
    // screen is still launching" apart from "the user dismissed the delay screen
    // without granting and went straight back into the app", which must
    // re-trigger the delay screen instead of being silently ignored.
    private val pendingDelaySince = mutableMapOf<String, Long>()

    private val sessionStartTimes = mutableMapOf<String, Long>()
    private val handler = Handler(Looper.getMainLooper())
    private val pendingReminderRunnables = mutableMapOf<String, Runnable>()
    private val pendingLimitRunnables = mutableMapOf<String, Runnable>()
    private val pendingTriggerRunnables = mutableMapOf<String, Runnable>()
    // Per-package "clear this session after the user has been away for a
    // while". A package's timer starts when the user leaves it (home, lock
    // screen, or another app taking the foreground) and is cancelled only when
    // THAT package returns to the foreground.
    private val pendingSessionClears = mutableMapOf<String, Runnable>()

    private var currentOverlayPackage: String? = null
    private var overlayView: View? = null
    private var activeBannerContainer: View? = null
    private var bannerRemoveRunnable: Runnable? = null
    private var lastBannerAddedAt: Long = 0L
    private var bannerExpiresAt: Long = 0L

    // The package the service currently believes is in the foreground. Launch
    // handling only runs when this CHANGES, so repeated window-state events from
    // in-app navigation (dialogs, fragments, sub-activities) are ignored.
    private var lastForegroundPackage: String? = null

    // Timestamp until which window-state events are ignored. Set whenever we add
    // one of our own overlay windows, because addView() makes the system fire a
    // TYPE_WINDOW_STATE_CHANGED that we must not react to. Home/launcher events
    // are exempt from this guard — swallowing a real trip to the home screen
    // would leave stale foreground/session state behind.
    private var ignoreEventsUntil: Long = 0L

    // True from the moment we fire the delay-screen intent until we receive the
    // corresponding com.example.gratify foreground event. Used to distinguish a
    // genuine delay-screen launch (which should reset lastForegroundPackage) from
    // overlay self-events.
    private var delayScreenPending = false

    // Which package the most recent delay screen was launched for, and whether
    // that screen has actually been observed in the foreground. Once the screen
    // has been SEEN, a foreground event for the target app without a grant can
    // only mean the user dismissed the delay screen (back press / swipe away),
    // so it must be re-triggered immediately — a time window alone is racy,
    // because a back press can easily happen within any "still launching" grace.
    private var delayScreenLaunchedFor: String? = null
    private var delayScreenSeen = false

    // Parse cache for the restricted-apps JSON so it isn't re-parsed on every
    // single window event.
    private var restrictedJsonCache: String? = null
    private var restrictedAppsByPkg: Map<String, RestrictedAppInfo> = emptyMap()

    private val homePackages: Set<String> by lazy {
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        packageManager.queryIntentActivities(homeIntent, 0)
            .map { it.activityInfo.packageName }
            .toSet()
    }

    // Keyboards (IMEs) put a window ON TOP of the current app; they are not an
    // app switch. Without filtering them out, opening a comment field fires a
    // window event for the IME package (Gboard etc. count as "launchable"),
    // which clobbers lastForegroundPackage — and closing the keyboard then makes
    // the real app look like a fresh launch.
    private val imePackages: Set<String> by lazy {
        try {
            (getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager)
                .inputMethodList.map { it.packageName }.toSet()
        } catch (_: Exception) {
            emptySet()
        }
    }

    private val previewReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val appName = intent.getStringExtra("appName") ?: return
            val intervalSeconds = intent.getIntExtra("intervalSeconds", 0)
            showReminderBanner(appName, intervalSeconds)
        }
    }

    // Locking the phone never produces a "home" window event, so without this
    // receiver, sessions survived the screen being off indefinitely and the
    // delay screen never re-triggered after the user came back. ACTION_USER_PRESENT
    // matters too: unlocking back into an app is NOT guaranteed to fire a window
    // event, so we actively check what's in the foreground at that moment —
    // otherwise an expired session would only be noticed at the next in-app
    // window change (e.g. opening comments), which looks like the delay screen
    // appearing out of nowhere.
    private var screenOn = true
    private val screenStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    screenOn = false
                    lastForegroundPackage = null
                    scheduleSessionClears(except = null)
                }
                Intent.ACTION_SCREEN_ON -> screenOn = true
                Intent.ACTION_USER_PRESENT -> {
                    screenOn = true
                    handler.postDelayed({
                        val fg = currentForegroundPackage() ?: return@postDelayed
                        if (fg == packageName) return@postDelayed
                        if (homePackages.contains(fg)) return@postDelayed
                        if (imePackages.contains(fg)) return@postDelayed
                        handleAppForeground(fg)
                    }, 600L)
                }
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        val previewFilter = IntentFilter(ACTION_PREVIEW_REMINDER)
        val screenFilter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(previewReceiver, previewFilter, RECEIVER_NOT_EXPORTED)
            // Screen actions are protected system broadcasts; the system is
            // still allowed to deliver them to a NOT_EXPORTED receiver.
            registerReceiver(screenStateReceiver, screenFilter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(previewReceiver, previewFilter)
            registerReceiver(screenStateReceiver, screenFilter)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val pkg = event.packageName?.toString() ?: return
        if (pkg.isEmpty()) return

        // Our own windows (delay screen, banners, grayscale overlay) all report
        // our package name. Only a deliberate delay-screen launch may reset the
        // foreground tracking; overlay self-events are harmless no-ops.
        if (pkg == packageName) {
            if (delayScreenPending) {
                lastForegroundPackage = null
                delayScreenPending = false
                // The delay screen has genuinely reached the foreground.
                delayScreenSeen = true
            }
            return
        }

        // Keyboard windows are not an app switch; ignore them entirely. This
        // also keeps the grayscale overlay from being hidden while typing.
        if (imePackages.contains(pkg)) return

        // Ignore the window-state event the system fires when we add our own
        // banner/grayscale overlay — but NEVER swallow a genuine trip to the
        // home screen, otherwise going home right after a banner appears leaves
        // stale state and the session never clears.
        val isHome = homePackages.contains(pkg)
        if (!isHome && System.currentTimeMillis() < ignoreEventsUntil) return

        if (isHome) {
            // Going home is a real foreground change; re-evaluate on return.
            lastForegroundPackage = null
            scheduleSessionClears(except = null)
            return
        }

        handleAppForeground(pkg)
    }

    /**
     * Core handling for "a launchable third-party app is in the foreground".
     * Called from window-state events and from the post-unlock foreground check.
     */
    private fun handleAppForeground(pkg: String) {
        if (!isLaunchableApp(pkg)) return

        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!flutterPrefs.getBoolean("flutter.monitoring_enabled", true)) return

        // The user is in THIS app again, so its away-timer (if any) is void;
        // every other package with live state starts (or keeps) its away-timer.
        pendingSessionClears.remove(pkg)?.let { handler.removeCallbacks(it) }
        scheduleSessionClears(except = pkg)

        val app = findRestrictedApp(pkg, flutterPrefs)
        updateOverlay(pkg, app)

        // Only the FIRST event for a freshly-foregrounded app counts as a launch.
        // Subsequent events for the same package are in-app navigation (opening
        // comments, profiles, tabs, dialogs) and must not re-trigger anything.
        if (pkg == lastForegroundPackage) return
        lastForegroundPackage = pkg

        if (app == null) return

        if (activeRestrictedSessions.contains(pkg)) return

        val graceMs = if (app.graceMinutes > 0) app.graceMinutes * 60_000L else 5_000L
        val grantedAt = flutterPrefs.getLong("flutter.access_granted_$pkg", 0L)
        if (grantedAt > 0L && System.currentTimeMillis() - grantedAt < graceMs) {
            pendingTriggerRunnables.remove(pkg)?.let { handler.removeCallbacks(it) }
            pendingDelayPackages.remove(pkg)
            pendingDelaySince.remove(pkg)
            if (delayScreenLaunchedFor == pkg) {
                delayScreenLaunchedFor = null
                delayScreenSeen = false
            }
            activeRestrictedSessions.add(pkg)
            startSessionTimer(pkg, app)
            return
        }

        if (pendingDelayPackages.contains(pkg)) {
            if (delayScreenSeen && delayScreenLaunchedFor == pkg) {
                // The delay screen reached the foreground, and now the app is
                // back WITHOUT a grant — the user dismissed it (back press /
                // swipe). Re-trigger immediately, regardless of how quickly it
                // happened; otherwise a fast back press bypasses monitoring.
                delayScreenSeen = false
                triggerDelay(pkg, app)
                return
            }
            // The delay screen hasn't been observed in the foreground yet, so
            // this event is part of the launch race — unless enough time has
            // passed that the launch must have silently failed, in which case
            // try again.
            val since = pendingDelaySince[pkg] ?: 0L
            if (System.currentTimeMillis() - since < DELAY_LAUNCH_RACE_MS) return
            triggerDelay(pkg, app)
            return
        }

        pendingDelayPackages.add(pkg)
        pendingDelaySince[pkg] = System.currentTimeMillis()
        triggerDelay(pkg, app)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(previewReceiver) } catch (_: Exception) {}
        try { unregisterReceiver(screenStateReceiver) } catch (_: Exception) {}
        // Drop EVERY pending callback so nothing (banner removal, delay
        // triggers, session clears...) runs against a dead service.
        handler.removeCallbacksAndMessages(null)
        pendingSessionClears.clear()
        pendingReminderRunnables.clear()
        pendingLimitRunnables.clear()
        pendingTriggerRunnables.clear()
        sessionStartTimes.clear()
        activeRestrictedSessions.clear()
        pendingDelayPackages.clear()
        pendingDelaySince.clear()
        dismissActiveBanner(force = true)
        hideOverlay()
        currentOverlayPackage = null
    }

    /**
     * Start an away-timer for every package that has live state (an active
     * session or a pending delay), except the one currently in the foreground.
     * Already-running timers are left untouched so the debounce window isn't
     * extended by unrelated events.
     */
    private fun scheduleSessionClears(except: String?) {
        (activeRestrictedSessions + pendingDelayPackages)
            .filter { it != except }
            .forEach { scheduleClearFor(it) }
    }

    private fun scheduleClearFor(p: String) {
        if (pendingSessionClears.containsKey(p)) return
        val r = Runnable {
            pendingSessionClears.remove(p)
            // Verify the user has actually LEFT the app before wiping its
            // session. Normal in-app use (scrolling, watching) generates NO
            // window events, so a single stray foreground event — a chat-head /
            // bubble window from another app, a floating overlay, a missed
            // resume after unlock — could start an away-timer that nothing ever
            // cancels. The session would then evaporate while the user is still
            // inside the app, and the next in-app window change (opening
            // comments, a profile, a dialog) would masquerade as a fresh launch
            // and re-trigger the delay screen mid-use.
            val fg = if (screenOn) currentForegroundPackage() else null
            if (fg != null && (fg == p || imePackages.contains(fg))) {
                // Still in use (or typing, with the IME window active on top of
                // it) — repair the foreground tracking, keep the session, and
                // re-arm so this self-corrects once the user genuinely leaves.
                if (fg == p) lastForegroundPackage = p
                scheduleClearFor(p)
                return@Runnable
            }
            clearSessionFor(p)
        }
        pendingSessionClears[p] = r
        handler.postDelayed(r, HOME_DEBOUNCE_MS)
    }

    /**
     * What is actually in the foreground right now, according to the system —
     * independent of the (inferable, but spoofable-by-stray-events) event
     * stream. Requires flagRetrieveInteractiveWindows and/or
     * canRetrieveWindowContent in the accessibility service config; returns
     * null if neither is available, in which case callers fall back to the
     * event-derived state.
     */
    private fun currentForegroundPackage(): String? {
        try {
            val active = windows.firstOrNull { it.isActive }
                ?: windows.firstOrNull {
                    it.type == AccessibilityWindowInfo.TYPE_APPLICATION && it.isFocused
                }
            val pkg = active?.root?.packageName?.toString()
            if (!pkg.isNullOrEmpty()) return pkg
        } catch (_: Exception) {}
        return try {
            rootInActiveWindow?.packageName?.toString()
        } catch (_: Exception) {
            null
        }
    }

    private fun clearSessionFor(pkg: String) {
        activeRestrictedSessions.remove(pkg)
        sessionStartTimes.remove(pkg)
        pendingDelayPackages.remove(pkg)
        pendingDelaySince.remove(pkg)
        pendingReminderRunnables.remove(pkg)?.let { handler.removeCallbacks(it) }
        pendingLimitRunnables.remove(pkg)?.let { handler.removeCallbacks(it) }
        pendingTriggerRunnables.remove(pkg)?.let { handler.removeCallbacks(it) }
        if (delayScreenLaunchedFor == pkg) {
            delayScreenLaunchedFor = null
            delayScreenSeen = false
        }
        if (currentOverlayPackage == pkg) {
            hideOverlay()
            currentOverlayPackage = null
        }
    }

    private fun startSessionTimer(pkg: String, app: RestrictedAppInfo) {
        if (sessionStartTimes.containsKey(pkg)) return
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
        if (app.usageLimitSeconds > 0 &&
                count.toLong() * app.reminderIntervalSeconds >= app.usageLimitSeconds) return

        val startTime = sessionStartTimes[pkg] ?: return
        val fireAt = startTime + count.toLong() * app.reminderIntervalSeconds * 1_000L
        val delay = fireAt - scheduledAt
        if (delay < 0) return

        val runnable = Runnable {
            if (!activeRestrictedSessions.contains(pkg)) return@Runnable
            // Only show the banner if the user is actually IN the app right now;
            // otherwise it would pop up on top of whatever else they're doing.
            // The reminder chain keeps running either way.
            if (lastForegroundPackage == pkg) {
                showReminderBanner(app.name, count * app.reminderIntervalSeconds, app.reminderIntervalSeconds)
            }
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

            // The previous grant must not let the user straight back in after the
            // limit has been reached — wipe it so the next entry hits the delay.
            getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .edit().putLong("flutter.access_granted_$pkg", 0L).apply()

            pendingDelayPackages.add(pkg)

            if (lastForegroundPackage != pkg) {
                // The limit elapsed while the user wasn't in the app (e.g. they
                // stepped out to the home screen). Don't pop the delay screen out
                // of nowhere — the pending-delay state makes it show on the next
                // entry instead. A zero timestamp means "trigger immediately on
                // re-entry" (no launch race to protect against).
                pendingDelaySince[pkg] = 0L
                return@Runnable
            }

            pendingDelaySince[pkg] = System.currentTimeMillis()
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

    private fun dismissActiveBanner(force: Boolean = false) {
        val container = activeBannerContainer ?: return
        if (!force && System.currentTimeMillis() - lastBannerAddedAt < 3_000L) return
        activeBannerContainer = null
        // Cancel the scheduled remove runnable so it doesn't run on a removed view.
        bannerRemoveRunnable?.let { handler.removeCallbacks(it); bannerRemoveRunnable = null }
        try {
            getSystemService(WindowManager::class.java)?.removeView(container)
        } catch (_: Exception) {}
    }

    private fun triggerDelay(pkg: String, app: RestrictedAppInfo, fromSessionLimit: Boolean = false) {
        pendingTriggerRunnables.remove(pkg)?.let { handler.removeCallbacks(it) }

        val now = System.currentTimeMillis()
        val wait = if (activeBannerContainer != null && now < bannerExpiresAt) {
            bannerExpiresAt - now + 100L
        } else 0L

        val runnable = Runnable {
            pendingTriggerRunnables.remove(pkg)
            if (!pendingDelayPackages.contains(pkg)) return@Runnable
            // If the trigger was deferred (e.g. waiting for a banner) the user
            // may have left the app in the meantime — don't pop the delay
            // screen over whatever they're doing now. The pending-delay state
            // stays, so it fires immediately on their next entry instead.
            val fg = currentForegroundPackage()
            if (fg != null && fg != pkg && fg != packageName && !imePackages.contains(fg)) {
                pendingDelaySince[pkg] = 0L
                return@Runnable
            }
            if (activeBannerContainer != null) dismissActiveBanner(force = true)
            // Stamp from the moment the screen is actually launched, so the
            // launch-failure fallback in onAccessibilityEvent measures correctly.
            pendingDelaySince[pkg] = System.currentTimeMillis()
            delayScreenPending = true
            delayScreenLaunchedFor = pkg
            delayScreenSeen = false
            startActivity(Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("SHOW_DELAY", true)
                putExtra("PKG", pkg)
                putExtra("APP_NAME", app.name)
                putExtra("DELAY_SECS", app.delaySeconds)
                putExtra("FROM_SESSION_LIMIT", fromSessionLimit)
            })
        }
        pendingTriggerRunnables[pkg] = runnable
        handler.postDelayed(runnable, wait)
    }

    private fun showReminderBanner(appName: String, elapsedSeconds: Int, intervalSeconds: Int = 0) {
        val now = System.currentTimeMillis()
        val minNextAt = if (intervalSeconds > 0) lastBannerAddedAt + intervalSeconds * 1_000L
                        else bannerExpiresAt
        if (now < maxOf(bannerExpiresAt, minNextAt)) return
        dismissActiveBanner()
        val wm = getSystemService(WindowManager::class.java) ?: return

        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
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

        val animIdx      = flutterPrefs.getLong("flutter.reminder_animation",  0L).toInt()
        val durationMs   = flutterPrefs.getLong("flutter.reminder_duration",   4L).coerceIn(1L, 5L) * 1_000L
        val colorModeIdx = flutterPrefs.getLong("flutter.reminder_color_mode", 0L).toInt()
        val customRgb    = flutterPrefs.getLong("flutter.reminder_custom_color", 0x7B6FD4L).toInt()
        val opacityPct   = flutterPrefs.getLong("flutter.reminder_opacity", 92L).toInt()
        val alpha        = (opacityPct * 255 / 100).coerceIn(0, 255)
        val bannerBgColor: Int
        val bannerTextColor: Int
        when (colorModeIdx) {
            1 -> {
                bannerBgColor   = Color.argb(alpha, 248, 247, 255)
                bannerTextColor = Color.rgb(28, 26, 46)
            }
            2 -> {
                val r = (customRgb shr 16) and 0xFF
                val g = (customRgb shr 8)  and 0xFF
                val b = customRgb          and 0xFF
                val luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                bannerBgColor   = Color.argb(alpha, r, g, b)
                bannerTextColor = if (luminance > 0.45) Color.rgb(28, 26, 46) else Color.WHITE
            }
            else -> {
                bannerBgColor   = Color.argb(alpha, 28, 26, 46)
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
            gravity = Gravity.CENTER
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
            // Let the window manager animate the window's enter/exit at the
            // surface level. This avoids per-frame view-alpha changes inside the
            // overlay, which is what caused the flicker.
            windowAnimations = when (animIdx) {
                1    -> R.style.BannerAnimationFade
                2    -> R.style.BannerAnimationSlide
                3    -> 0
                else -> R.style.BannerAnimation
            }
        }

        container.alpha = 1f
        // Ignore the window-state event addView() will generate for this overlay.
        // Use maxOf so a concurrent showOverlay() call can't shorten the guard.
        ignoreEventsUntil = maxOf(ignoreEventsUntil, System.currentTimeMillis() + SELF_EVENT_GUARD_MS)
        try {
            // The enter animation plays automatically when the window is added,
            // and the exit animation plays automatically when it is removed.
            wm.addView(container, params)
            lastBannerAddedAt = System.currentTimeMillis()
            bannerExpiresAt = lastBannerAddedAt + durationMs
            activeBannerContainer = container

            val removeRunnable = Runnable {
                try { wm.removeView(container) } catch (_: Exception) {}
                if (activeBannerContainer === container) activeBannerContainer = null
                bannerRemoveRunnable = null
            }
            bannerRemoveRunnable = removeRunnable
            handler.postDelayed(removeRunnable, durationMs)

        } catch (_: Exception) {
            ignoreEventsUntil = 0L
        }
    }

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
        // Ignore the window-state event addView() will generate for this overlay.
        // Use maxOf so a concurrent showReminderBanner() call can't shorten the guard.
        ignoreEventsUntil = maxOf(ignoreEventsUntil, System.currentTimeMillis() + SELF_EVENT_GUARD_MS)
        try {
            wm.addView(view, params)
            overlayView = view
        } catch (_: Exception) {
            ignoreEventsUntil = 0L
        }
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

    private fun isLaunchableApp(pkg: String): Boolean = launchableCache.getOrPut(pkg) {
        try {
            packageManager.getLaunchIntentForPackage(pkg) != null
        } catch (_: Exception) {
            false
        }
    }

    private fun findRestrictedApp(pkg: String, prefs: SharedPreferences): RestrictedAppInfo? {
        val json = prefs.getString("flutter.restricted_apps", null) ?: return null
        if (json != restrictedJsonCache) {
            restrictedJsonCache = json
            restrictedAppsByPkg = parseRestrictedApps(json)
        }
        return restrictedAppsByPkg[pkg]
    }

    private fun parseRestrictedApps(json: String): Map<String, RestrictedAppInfo> {
        return try {
            val arr = JSONArray(json)
            val map = mutableMapOf<String, RestrictedAppInfo>()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val p = obj.optString("packageName")
                if (p.isEmpty()) continue
                map[p] = RestrictedAppInfo(
                    name                    = obj.getString("name"),
                    delaySeconds            = obj.getInt("delaySeconds"),
                    graceMinutes            = obj.optInt("graceMinutes", 2),
                    grayscale               = obj.optBoolean("grayscale", false),
                    grayscaleStartMinute    = if (obj.isNull("grayscaleStartMinute")) null
                                              else obj.getInt("grayscaleStartMinute"),
                    grayscaleEndMinute      = if (obj.isNull("grayscaleEndMinute")) null
                                              else obj.getInt("grayscaleEndMinute"),
                    reminderIntervalSeconds = obj.optInt("reminderIntervalSeconds", 0),
                    usageLimitSeconds       = obj.optInt("usageLimitSeconds", 0),
                )
            }
            map
        } catch (_: Exception) {
            emptyMap()
        }
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
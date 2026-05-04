import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_settings.dart';
import '../models/restricted_app.dart';
import '../services/app_service.dart';
import '../services/settings_service.dart';
import '../widgets/app_icon_widget.dart';
import '../widgets/countdown_ring.dart';

class DelayScreen extends StatefulWidget {
  final RestrictedApp app;

  /// When true the restricted app is running behind Gratify.
  /// "Open App" will call moveTaskToBack so it resurfaces instead
  /// of just popping the Flutter route.
  final bool fromService;

  const DelayScreen({
    super.key,
    required this.app,
    this.fromService = false,
  });

  @override
  State<DelayScreen> createState() => _DelayScreenState();
}

class _DelayScreenState extends State<DelayScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _canOpen = false;
  AppSettings _settings = const AppSettings();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.app.delaySeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _canOpen = true);
        }
      });
    _controller.forward();
    SettingsService().load().then((s) {
      if (mounted) setState(() => _settings = s);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onOpenApp() async {
    if (widget.fromService) {
      await AppService.recordAccessGranted(widget.app.packageName);
      await AppService.openApp(); // moveTaskToBack — restricted app resurfaces
      SystemNavigator.pop(); // fully close Gratify
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _onNeverMind() async {
    if (widget.fromService) {
      // Go to Android home screen so the restricted app doesn't resurface.
      await AppService.goHome();
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  String get _attemptsText {
    final count = widget.app.dailyAttempts;
    if (count <= 1) return 'First time opening today';
    return "You've tried to open this app $count times today";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                if (_settings.showAppLogo)
                  AppIconWidget(
                    packageName: widget.app.packageName,
                    appName: widget.app.name,
                    size: 72,
                    borderRadius: 20,
                  ),
                if (_settings.showAppLogo && _settings.showAppName)
                  const SizedBox(height: 16),
                if (_settings.showAppName)
                  Text(
                    widget.app.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                if (_settings.showAttemptCount) ...[
                  const SizedBox(height: 8),
                  Text(
                    _attemptsText,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF9896B0)),
                  ),
                ],
                const Spacer(flex: 1),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final progress = 1.0 - _controller.value;
                    final remaining =
                        (widget.app.delaySeconds * (1 - _controller.value))
                            .ceil();
                    return CountdownRing(
                      progress: progress,
                      secondsRemaining: remaining,
                      style: _settings.countdownStyle,
                      showNumbers: _settings.showCountdownNumbers,
                    );
                  },
                ),
                const Spacer(flex: 1),
                Text(
                  _settings.heading,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _settings.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9896B0),
                    height: 1.6,
                  ),
                ),
                const Spacer(flex: 2),
                ElevatedButton(
                  onPressed: _canOpen ? _onOpenApp : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B6FD4),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBC8E8),
                    disabledForegroundColor: const Color(0xFF9896B0),
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    _canOpen ? 'Open App' : 'Please wait...',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _onNeverMind,
                  child: const Text(
                    'Never mind, go back',
                    style: TextStyle(color: Color(0xFF9896B0), fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

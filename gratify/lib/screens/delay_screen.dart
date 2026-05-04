import 'package:flutter/material.dart';
import '../models/restricted_app.dart';
import '../services/app_service.dart';
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7F5FF), Color(0xFFEDE8FF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF9896B0)),
                  ),
                ),
                const Spacer(flex: 2),
                AppIconWidget(
                  packageName: widget.app.packageName,
                  appName: widget.app.name,
                  size: 72,
                  borderRadius: 20,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.app.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D2D3A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _attemptsText,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF9896B0)),
                ),
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
                    );
                  },
                ),
                const Spacer(flex: 1),
                const Text(
                  'Are you sure you want to\nopen this app?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D2D3A),
                    height: 1.5,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Take a breath. This is your moment\nto pause and reflect.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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

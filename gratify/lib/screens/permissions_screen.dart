import 'package:flutter/material.dart';
import '../services/app_service.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const PermissionsScreen({super.key, required this.onComplete});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  bool _hasAccessibility = false;
  bool _hasOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final accessibility = await AppService.checkAccessibilityPermission();
    final overlay = await AppService.checkOverlayPermission();
    if (mounted) setState(() { _hasAccessibility = accessibility; _hasOverlay = overlay; });
    if (accessibility && overlay) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B6FD4).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_open_rounded,
                    color: Color(0xFF7B6FD4), size: 28),
              ),
              const SizedBox(height: 24),
              const Text(
                'Two quick steps',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D2D3A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gratify needs two Android permissions\nto intercept app launches.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF9896B0),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              _PermStep(
                step: 1,
                title: 'Accessibility Service',
                description:
                    'Lets Gratify detect when a restricted app is opened and show the delay screen instantly.',
                granted: _hasAccessibility,
                onTap: AppService.requestAccessibilityPermission,
              ),
              const SizedBox(height: 16),
              _PermStep(
                step: 2,
                title: 'Display Over Other Apps',
                description:
                    'Lets Gratify appear on top of the app you\'re trying to open.',
                granted: _hasOverlay,
                onTap: AppService.requestOverlayPermission,
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: (_hasAccessibility && _hasOverlay) ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 300),
                child: ElevatedButton(
                  onPressed:
                      (_hasAccessibility && _hasOverlay) ? widget.onComplete : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B6FD4),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('All set — start monitoring',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermStep extends StatelessWidget {
  final int step;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onTap;

  const _PermStep({
    required this.step,
    required this.title,
    required this.description,
    required this.granted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: granted
              ? const Color(0xFF6BBFB5).withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: granted
                ? Container(
                    key: const ValueKey('check'),
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6BBFB5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 20),
                  )
                : Container(
                    key: const ValueKey('num'),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B6FD4).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('$step',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7B6FD4),
                          )),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF2D2D3A))),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9896B0),
                        height: 1.4)),
                if (!granted) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onTap,
                    child: const Text('Open Settings →',
                        style: TextStyle(
                            color: Color(0xFF7B6FD4),
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

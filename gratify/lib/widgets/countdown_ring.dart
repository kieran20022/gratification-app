import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class CountdownRing extends StatelessWidget {
  final double progress; // 1.0 = full (just started), 0.0 = empty (done)
  final int secondsRemaining;
  final CountdownStyle style;
  final bool showNumbers;
  final double size;

  const CountdownRing({
    super.key,
    required this.progress,
    required this.secondsRemaining,
    this.style = CountdownStyle.ring,
    this.showNumbers = true,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (style == CountdownStyle.none) {
      if (!showNumbers) return const SizedBox.shrink();
      return _NumberOnly(secondsRemaining: secondsRemaining);
    }

    if (style == CountdownStyle.bar) {
      return _BarCountdown(
        progress: progress,
        secondsRemaining: secondsRemaining,
        showNumbers: showNumbers,
        width: size,
      );
    }

    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CustomPaint(
              painter: style == CountdownStyle.fill
                  ? _FillPainter(
                      progress: progress,
                      trackColor: cs.onSurface.withValues(alpha: 0.1),
                      progressColor: cs.primary,
                    )
                  : _RingPainter(
                      progress: progress,
                      trackColor: cs.onSurface.withValues(alpha: 0.1),
                      progressColor: cs.primary,
                    ),
            ),
          ),
          if (showNumbers)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '$secondsRemaining',
                    key: ValueKey(secondsRemaining),
                    style: TextStyle(
                      fontSize: size * 0.327,
                      fontWeight: FontWeight.w200,
                      color: cs.onSurface,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'seconds',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9896B0),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NumberOnly extends StatelessWidget {
  final int secondsRemaining;
  const _NumberOnly({required this.secondsRemaining});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: Text(
            '$secondsRemaining',
            key: ValueKey(secondsRemaining),
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.w200,
              color: cs.onSurface,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'seconds',
          style: TextStyle(fontSize: 14, color: Color(0xFF9896B0), letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class _BarCountdown extends StatelessWidget {
  final double progress;
  final int secondsRemaining;
  final bool showNumbers;
  final double width;

  const _BarCountdown({
    required this.progress,
    required this.secondsRemaining,
    required this.showNumbers,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showNumbers) ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Text(
                '$secondsRemaining',
                key: ValueKey(secondsRemaining),
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w200,
                  color: cs.onSurface,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'seconds',
              style: TextStyle(fontSize: 14, color: Color(0xFF9896B0), letterSpacing: 0.5),
            ),
            const SizedBox(height: 20),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: cs.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0.005) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}

class _FillPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _FillPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0.005) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        true,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_FillPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}

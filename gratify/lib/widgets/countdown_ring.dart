import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class CountdownRing extends StatelessWidget {
  final double progress; // 1.0 = full (just started), 0.0 = empty (done)
  final int secondsRemaining;
  final CountdownStyle style;
  final bool showNumbers;
  final double size;
  final double numberFontSize;
  final double labelFontSize;
  final bool showBreathText;

  const CountdownRing({
    super.key,
    required this.progress,
    required this.secondsRemaining,
    this.style           = CountdownStyle.ring,
    this.showNumbers     = true,
    this.size            = 220,
    this.numberFontSize  = AppSettings.defaultFontSizeTimerNumber,
    this.labelFontSize   = AppSettings.defaultFontSizeTimerLabel,
    this.showBreathText  = true,
  });

  @override
  Widget build(BuildContext context) {
    if (style == CountdownStyle.none) {
      if (!showNumbers) return const SizedBox.shrink();
      return _NumberOnly(
        secondsRemaining: secondsRemaining,
        numberFontSize: numberFontSize,
        labelFontSize: labelFontSize,
      );
    }

    if (style == CountdownStyle.bar) {
      return _BarCountdown(
        progress: progress,
        secondsRemaining: secondsRemaining,
        showNumbers: showNumbers,
        width: size,
        numberFontSize: numberFontSize,
        labelFontSize: labelFontSize,
      );
    }

    if (style == CountdownStyle.breath) {
      return _BreathRing(
        secondsRemaining: secondsRemaining,
        showNumbers: showNumbers,
        size: size,
        numberFontSize: numberFontSize,
        labelFontSize: labelFontSize,
        showBreathText: showBreathText,
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
                      fontSize: numberFontSize,
                      fontWeight: FontWeight.w200,
                      color: cs.onSurface,
                      height: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'seconds',
                  style: TextStyle(
                    fontSize: labelFontSize,
                    color: const Color(0xFF9896B0),
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

// ── Breath ring ───────────────────────────────────────────────────────────────

class _BreathRing extends StatefulWidget {
  final int secondsRemaining;
  final bool showNumbers;
  final double size;
  final double numberFontSize;
  final double labelFontSize;
  final bool showBreathText;

  const _BreathRing({
    required this.secondsRemaining,
    required this.showNumbers,
    required this.size,
    required this.numberFontSize,
    required this.labelFontSize,
    required this.showBreathText,
  });

  @override
  State<_BreathRing> createState() => _BreathRingState();
}

class _BreathRingState extends State<_BreathRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  static const _inDuration  = 4.0;
  static const _outDuration = 4.0;
  static const _totalDuration = _inDuration + _outDuration;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_totalDuration * 1000).round()),
    )..repeat();

    _scaleAnim = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.72, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _inDuration,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.72)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _outDuration,
      ),
    ]).animate(_ctrl);

    _opacityAnim = TweenSequence([
      TweenSequenceItem(
        tween: Tween(begin: 0.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _inDuration,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.35)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _outDuration,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = widget.size;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final breathIn = _ctrl.value < (_inDuration / _totalDuration);
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Transform.scale(
                scale: _scaleAnim.value,
                child: Opacity(
                  opacity: _opacityAnim.value * 0.18,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: CustomPaint(
                      painter: _SolidCirclePainter(color: cs.primary),
                    ),
                  ),
                ),
              ),
              // Animated ring
              Transform.scale(
                scale: _scaleAnim.value,
                child: Opacity(
                  opacity: _opacityAnim.value,
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: CustomPaint(
                      painter: _RingPainter(
                        progress: 1.0,
                        trackColor: Colors.transparent,
                        progressColor: cs.primary,
                      ),
                    ),
                  ),
                ),
              ),
              // Center text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showNumbers) ...[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.3),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        '${widget.secondsRemaining}',
                        key: ValueKey(widget.secondsRemaining),
                        style: TextStyle(
                          fontSize: widget.numberFontSize,
                          fontWeight: FontWeight.w200,
                          color: cs.onSurface,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (widget.showBreathText)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: child,
                      ),
                      child: Text(
                        breathIn ? 'breathe in' : 'breathe out',
                        key: ValueKey(breathIn),
                        style: TextStyle(
                          fontSize: widget.labelFontSize,
                          color: const Color(0xFF9896B0),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Number only ───────────────────────────────────────────────────────────────

class _NumberOnly extends StatelessWidget {
  final int secondsRemaining;
  final double numberFontSize;
  final double labelFontSize;

  const _NumberOnly({
    required this.secondsRemaining,
    this.numberFontSize = AppSettings.defaultFontSizeTimerNumber,
    this.labelFontSize  = AppSettings.defaultFontSizeTimerLabel,
  });

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
              fontSize: numberFontSize,
              fontWeight: FontWeight.w200,
              color: cs.onSurface,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'seconds',
          style: TextStyle(
            fontSize: labelFontSize,
            color: const Color(0xFF9896B0),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Bar countdown ─────────────────────────────────────────────────────────────

class _BarCountdown extends StatelessWidget {
  final double progress;
  final int secondsRemaining;
  final bool showNumbers;
  final double width;
  final double numberFontSize;
  final double labelFontSize;

  const _BarCountdown({
    required this.progress,
    required this.secondsRemaining,
    required this.showNumbers,
    required this.width,
    this.numberFontSize = AppSettings.defaultFontSizeTimerNumber,
    this.labelFontSize  = AppSettings.defaultFontSizeTimerLabel,
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
                  fontSize: numberFontSize,
                  fontWeight: FontWeight.w200,
                  color: cs.onSurface,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'seconds',
              style: TextStyle(
                fontSize: labelFontSize,
                color: const Color(0xFF9896B0),
                letterSpacing: 0.5,
              ),
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

// ── Painters ──────────────────────────────────────────────────────────────────

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

class _SolidCirclePainter extends CustomPainter {
  final Color color;
  const _SolidCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    canvas.drawCircle(
        center, radius, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_SolidCirclePainter old) => old.color != color;
}

import 'package:flutter/material.dart';
import '../models/reminder_settings.dart';
import '../services/reminder_settings_service.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final _service = ReminderSettingsService();
  final _msgCtrl = TextEditingController();

  ReminderAnimation _animation = ReminderAnimation.bounce;
  ReminderPosition _position = ReminderPosition.center;
  bool _loaded = false;
  int _replayKey = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _service.load();
    if (!mounted) return;
    setState(() {
      _msgCtrl.text = s.message;
      _animation = s.animation;
      _position = s.position;
      _loaded = true;
    });
  }

  ReminderSettings get _current => ReminderSettings(
    message: _msgCtrl.text.trim().isEmpty
        ? ReminderSettings.defaultMessage
        : _msgCtrl.text,
    animation: _animation,
    position: _position,
  );

  void _save() => _service.save(_current);

  @override
  void dispose() {
    _save();
    _msgCtrl.dispose();
    super.dispose();
  }

  void _resetToDefaults() {
    setState(() {
      _msgCtrl.text = ReminderSettings.defaultMessage;
      _animation = ReminderAnimation.bounce;
      _position = ReminderPosition.center;
    });
    _save();
  }

  String get _previewMessage {
    return _current.message
        .replaceAll('{app}', 'TikTok')
        .replaceAll('{time}', '5 minutes');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Usage Reminder')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── Live preview ─────────────────────────────────────────────
                const _SectionLabel('Preview'),
                const SizedBox(height: 14),
                _BannerPreviewCard(
                  key: ValueKey(_replayKey),
                  message: _previewMessage,
                  position: _position,
                  animation: _animation,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _replayKey++),
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: const Text('Replay'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE8927C),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                const SizedBox(height: 24),

                // ── Animation ────────────────────────────────────────────────
                const _SectionLabel('Animation'),
                const SizedBox(height: 14),
                _AnimationSelector(
                  value: _animation,
                  onChanged: (v) {
                    setState(() => _animation = v);
                    _save();
                  },
                ),

                const SizedBox(height: 32),
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                const SizedBox(height: 24),

                // ── Position ─────────────────────────────────────────────────
                const _SectionLabel('Position'),
                const SizedBox(height: 14),
                _PositionSelector(
                  value: _position,
                  onChanged: (v) {
                    setState(() => _position = v);
                    _save();
                  },
                ),

                const SizedBox(height: 32),
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                const SizedBox(height: 24),

                // ── Message ──────────────────────────────────────────────────
                const _SectionLabel('Message'),
                const SizedBox(height: 14),
                _MessageField(
                  controller: _msgCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Placeholders',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9896B0),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _PlaceholderChip(tag: '{app}', desc: 'the app name'),
                      const SizedBox(height: 4),
                      _PlaceholderChip(
                        tag: '{time}',
                        desc: 'time elapsed (e.g. 5 minutes)',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                Center(
                  child: TextButton(
                    onPressed: _resetToDefaults,
                    child: const Text(
                      'Reset to defaults',
                      style: TextStyle(color: Color(0xFF9896B0), fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

// ── Banner preview card ───────────────────────────────────────────────────────

class _BannerPreviewCard extends StatefulWidget {
  final String message;
  final ReminderPosition position;
  final ReminderAnimation animation;

  const _BannerPreviewCard({
    super.key,
    required this.message,
    required this.position,
    required this.animation,
  });

  @override
  State<_BannerPreviewCard> createState() => _BannerPreviewCardState();
}

class _BannerPreviewCardState extends State<_BannerPreviewCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _playOnce();
  }

  @override
  void didUpdateWidget(_BannerPreviewCard old) {
    super.didUpdateWidget(old);
    if (old.animation != widget.animation || old.position != widget.position) {
      _ctrl.stop();
      _ctrl.reset();
      _playOnce();
    }
  }

  void _playOnce() {
    final duration = _animDuration(widget.animation);
    _ctrl.duration = duration;
    _ctrl.forward();
  }

  Duration _animDuration(ReminderAnimation a) => switch (a) {
    ReminderAnimation.bounce => const Duration(milliseconds: 700),
    ReminderAnimation.pulse => const Duration(milliseconds: 600),
    ReminderAnimation.shake => const Duration(milliseconds: 500),
    ReminderAnimation.fade => const Duration(milliseconds: 400),
    ReminderAnimation.none => const Duration(milliseconds: 1),
  };

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final alignment = switch (widget.position) {
      ReminderPosition.top => Alignment.topCenter,
      ReminderPosition.center => Alignment.center,
      ReminderPosition.bottom => Alignment.bottomCenter,
    };

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.07)),
      ),
      child: Stack(
        alignment: alignment,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) => Transform(
                alignment: Alignment.center,
                transform: _buildTransform(widget.animation, _ctrl.value),
                child: Opacity(
                  opacity: _buildOpacity(widget.animation, _ctrl.value),
                  child: child,
                ),
              ),
              child: _BannerPill(message: widget.message),
            ),
          ),
        ],
      ),
    );
  }

  Matrix4 _buildTransform(ReminderAnimation anim, double t) {
    return switch (anim) {
      ReminderAnimation.bounce => () {
        // spring: 0→1.12→0.94→1.04→1.0
        double scale;
        if (t < 0.30) {
          scale = 1.0 + (t / 0.30) * 0.12;
        } else if (t < 0.55) {
          scale = 1.12 - ((t - 0.30) / 0.25) * 0.18;
        } else if (t < 0.78) {
          scale = 0.94 + ((t - 0.55) / 0.23) * 0.10;
        } else {
          scale = 1.04 - ((t - 0.78) / 0.22) * 0.04;
        }
        return Matrix4.identity()..scale(scale, scale);
      }(),
      ReminderAnimation.pulse => () {
        final s = 1.0 + (0.08 * (t < 0.5 ? t / 0.5 : (1 - t) / 0.5));
        return Matrix4.identity()..scale(s, s);
      }(),
      ReminderAnimation.shake => () {
        const amp = 8.0;
        final x =
            amp *
            (t < 0.2
                ? t / 0.2
                : t < 0.4
                ? 1 - (t - 0.2) / 0.2 * 2
                : t < 0.6
                ? -1 + (t - 0.4) / 0.2 * 2
                : t < 0.8
                ? (1 - (t - 0.6) / 0.2) * 1
                : 0.0);
        return Matrix4.identity()..translate(x, 0.0);
      }(),
      _ => Matrix4.identity(),
    };
  }

  double _buildOpacity(ReminderAnimation anim, double t) => switch (anim) {
    ReminderAnimation.fade => t < 0.5 ? t / 0.5 : 1.0,
    ReminderAnimation.none => 1.0,
    _ => t == 0 ? 0.0 : 1.0,
  };
}

class _BannerPill extends StatelessWidget {
  final String message;
  const _BannerPill({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1A2E).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Selectors ─────────────────────────────────────────────────────────────────

class _AnimationSelector extends StatelessWidget {
  final ReminderAnimation value;
  final ValueChanged<ReminderAnimation> onChanged;
  const _AnimationSelector({required this.value, required this.onChanged});

  static const _options = [
    (ReminderAnimation.bounce, Icons.sports_basketball_outlined, 'Bounce'),
    (ReminderAnimation.pulse, Icons.radio_button_checked, 'Pulse'),
    (ReminderAnimation.shake, Icons.swap_horiz_rounded, 'Shake'),
    (ReminderAnimation.fade, Icons.opacity, 'Fade'),
    (ReminderAnimation.none, Icons.remove_circle_outline, 'None'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: _options.map((opt) {
        final (style, icon, label) = opt;
        final selected = value == style;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(style),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE8927C).withValues(alpha: 0.15)
                    : cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFE8927C)
                      : cs.onSurface.withValues(alpha: 0.1),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? const Color(0xFFE8927C)
                        : const Color(0xFF9896B0),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFFE8927C)
                          : const Color(0xFF9896B0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PositionSelector extends StatelessWidget {
  final ReminderPosition value;
  final ValueChanged<ReminderPosition> onChanged;
  const _PositionSelector({required this.value, required this.onChanged});

  static const _options = [
    (ReminderPosition.top, Icons.vertical_align_top, 'Top'),
    (ReminderPosition.center, Icons.vertical_align_center, 'Center'),
    (ReminderPosition.bottom, Icons.vertical_align_bottom, 'Bottom'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: _options.map((opt) {
        final (pos, icon, label) = opt;
        final selected = value == pos;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(pos),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE8927C).withValues(alpha: 0.15)
                    : cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFE8927C)
                      : cs.onSurface.withValues(alpha: 0.1),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected
                        ? const Color(0xFFE8927C)
                        : const Color(0xFF9896B0),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFFE8927C)
                          : const Color(0xFF9896B0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Message field ─────────────────────────────────────────────────────────────

class _MessageField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _MessageField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLines: 3,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5),
      decoration: InputDecoration(
        hintText: ReminderSettings.defaultMessage,
        hintStyle: const TextStyle(color: Color(0xFF9896B0), fontSize: 14),
        filled: true,
        fillColor: cs.surface,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFFE8927C).withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderChip extends StatelessWidget {
  final String tag;
  final String desc;
  const _PlaceholderChip({required this.tag, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE8927C).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tag,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE8927C),
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '→  $desc',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9896B0)),
        ),
      ],
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF9896B0),
      letterSpacing: 1.1,
    ),
  );
}

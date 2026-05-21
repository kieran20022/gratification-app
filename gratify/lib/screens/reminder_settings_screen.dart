import 'package:flutter/material.dart';
import '../models/reminder_settings.dart';
import '../services/reminder_settings_service.dart';
import '../services/app_service.dart';

class ReminderSettingsScreen extends StatefulWidget {
  final String? previewAppName;
  final int?    previewIntervalSeconds;

  const ReminderSettingsScreen({
    super.key,
    this.previewAppName,
    this.previewIntervalSeconds,
  });

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final _service = ReminderSettingsService();
  final _msgCtrl = TextEditingController();

  ReminderPosition _position    = ReminderPosition.center;
  BannerColorMode  _colorMode   = BannerColorMode.dark;
  int              _customColor = ReminderSettings.defaultCustomColor;
  BannerAnimation  _animation   = BannerAnimation.pop;
  int              _opacity     = ReminderSettings.defaultOpacity;
  int              _duration    = ReminderSettings.defaultDuration;
  bool             _loaded      = false;

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
      _position     = s.position;
      _colorMode    = s.colorMode;
      _customColor  = s.customColor;
      _animation    = s.animation;
      _opacity      = s.opacity;
      _duration     = s.duration;
      _loaded       = true;
    });
  }

  ReminderSettings get _current => ReminderSettings(
    message:     _msgCtrl.text.trim().isEmpty ? ReminderSettings.defaultMessage : _msgCtrl.text,
    position:    _position,
    colorMode:   _colorMode,
    customColor: _customColor,
    animation:   _animation,
    opacity:     _opacity,
    duration:    _duration,
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
      _position     = ReminderPosition.center;
      _colorMode    = BannerColorMode.dark;
      _customColor  = ReminderSettings.defaultCustomColor;
      _animation    = BannerAnimation.pop;
      _opacity      = ReminderSettings.defaultOpacity;
      _duration     = ReminderSettings.defaultDuration;
    });
    _save();
  }

  String get _previewMessage => _current.message
      .replaceAll('{app}',  widget.previewAppName ?? 'TikTok')
      .replaceAll('{time}', widget.previewIntervalSeconds != null
          ? _formatSeconds(widget.previewIntervalSeconds!)
          : '5 minutes');

  String _formatSeconds(int s) {
    if (s < 60) return '$s ${s == 1 ? "second" : "seconds"}';
    final m = s ~/ 60;
    return '$m ${m == 1 ? "minute" : "minutes"}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Usage Reminder')),
      floatingActionButton: FloatingActionButton(
        onPressed: () { _save(); Navigator.pop(context); },
        backgroundColor: const Color(0xFF7B6FD4),
        foregroundColor: Colors.white,
        elevation: 3,
        tooltip: 'Save',
        child: const Icon(Icons.check_rounded),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              children: [
                // ── Preview ─────────────────────────────────────────────────
                const _SectionLabel('Preview'),
                const SizedBox(height: 14),
                _BannerPreviewCard(
                  message:    _previewMessage,
                  position:   _position,
                  colorMode:  _colorMode,
                  customColor: _customColor,
                  opacity:    _opacity,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      final appName = widget.previewAppName ?? 'TikTok';
                      final secs    = widget.previewIntervalSeconds ?? 300;
                      AppService.previewReminder(appName, secs);
                    },
                    icon: const Icon(Icons.phone_android_rounded, size: 16),
                    label: const Text('Preview on device'),
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
                  value:     _animation,
                  onChanged: (v) { setState(() => _animation = v); _save(); },
                ),

                const SizedBox(height: 32),
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                const SizedBox(height: 24),

                // ── Position ─────────────────────────────────────────────────
                const _SectionLabel('Position'),
                const SizedBox(height: 14),
                _PositionSelector(
                  value:     _position,
                  onChanged: (v) { setState(() => _position = v); _save(); },
                ),

                const SizedBox(height: 32),
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                const SizedBox(height: 24),

                // ── Color ────────────────────────────────────────────────────
                const _SectionLabel('Popup Color'),
                const SizedBox(height: 14),
                _ColorModeSelector(
                  value:     _colorMode,
                  onChanged: (v) { setState(() => _colorMode = v); _save(); },
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: _colorMode == BannerColorMode.custom
                      ? Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _ColorGrid(
                            selected:  _customColor,
                            onChanged: (v) { setState(() => _customColor = v); _save(); },
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: 24),

                // ── Opacity ──────────────────────────────────────────────────
                Row(
                  children: [
                    const _SectionLabel('Opacity'),
                    const Spacer(),
                    Text(
                      '$_opacity%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9896B0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor:   const Color(0xFFE8927C),
                    inactiveTrackColor: const Color(0xFFE8927C).withValues(alpha: 0.18),
                    thumbColor:         const Color(0xFFE8927C),
                    overlayColor:       const Color(0xFFE8927C).withValues(alpha: 0.12),
                    trackHeight:        3,
                    thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:       const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value:    _opacity.toDouble(),
                    min:      10,
                    max:      100,
                    divisions: 18,
                    onChanged: (v) {
                      setState(() => _opacity = v.round());
                    },
                    onChangeEnd: (_) => _save(),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Duration ─────────────────────────────────────────────────
                Row(
                  children: [
                    const _SectionLabel('Display Time'),
                    const Spacer(),
                    Text(
                      '$_duration s',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9896B0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor:   const Color(0xFFE8927C),
                    inactiveTrackColor: const Color(0xFFE8927C).withValues(alpha: 0.18),
                    thumbColor:         const Color(0xFFE8927C),
                    overlayColor:       const Color(0xFFE8927C).withValues(alpha: 0.12),
                    trackHeight:        3,
                    thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:       const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value:     _duration.toDouble(),
                    min:       1,
                    max:       5,
                    divisions: 4,
                    onChanged: (v) {
                      setState(() => _duration = v.round());
                    },
                    onChangeEnd: (_) => _save(),
                  ),
                ),

                const SizedBox(height: 8),
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                const SizedBox(height: 24),

                // ── Message ──────────────────────────────────────────────────
                const _SectionLabel('Message'),
                const SizedBox(height: 14),
                _MessageField(
                  controller: _msgCtrl,
                  onChanged:  (_) { setState(() {}); _save(); },
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
                      _PlaceholderChip(tag: '{app}',  desc: 'the app name'),
                      const SizedBox(height: 4),
                      _PlaceholderChip(tag: '{time}', desc: 'time elapsed (e.g. 5 minutes)'),
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

// ── Color helpers ─────────────────────────────────────────────────────────────

Color _bannerBgColor(BannerColorMode mode, int rgb) => switch (mode) {
  BannerColorMode.dark   => const Color(0xFF1C1A2E),
  BannerColorMode.bright => const Color(0xFFF8F7FF),
  BannerColorMode.custom => Color(0xFF000000 | rgb),
};

Color _bannerTextColor(BannerColorMode mode, int rgb) => switch (mode) {
  BannerColorMode.dark   => Colors.white,
  BannerColorMode.bright => const Color(0xFF1C1A2E),
  BannerColorMode.custom => Color(0xFF000000 | rgb).computeLuminance() > 0.45
      ? const Color(0xFF1C1A2E)
      : Colors.white,
};

// ── Banner preview card ───────────────────────────────────────────────────────

class _BannerPreviewCard extends StatelessWidget {
  final String           message;
  final ReminderPosition position;
  final BannerColorMode  colorMode;
  final int              customColor;
  final int              opacity;

  const _BannerPreviewCard({
    required this.message,
    required this.position,
    required this.colorMode,
    required this.customColor,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = switch (position) {
      ReminderPosition.top    => Alignment.topCenter,
      ReminderPosition.center => Alignment.center,
      ReminderPosition.bottom => Alignment.bottomCenter,
    };

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        alignment: alignment,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: _BannerPill(
              message:   message,
              bgColor:   _bannerBgColor(colorMode, customColor),
              textColor: _bannerTextColor(colorMode, customColor),
              opacity:   opacity / 100.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerPill extends StatelessWidget {
  final String message;
  final Color  bgColor;
  final Color  textColor;
  final double opacity;

  const _BannerPill({
    required this.message,
    required this.bgColor,
    required this.textColor,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Selectors ─────────────────────────────────────────────────────────────────

class _AnimationSelector extends StatelessWidget {
  final BannerAnimation value;
  final ValueChanged<BannerAnimation> onChanged;
  const _AnimationSelector({required this.value, required this.onChanged});

  static const _options = [
    (BannerAnimation.pop,   Icons.open_in_full_rounded,   'Pop'),
    (BannerAnimation.fade,  Icons.blur_on_rounded,         'Fade'),
    (BannerAnimation.slide, Icons.swap_vert_rounded,       'Slide'),
    (BannerAnimation.none,  Icons.flash_on_rounded,        'None'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: _options.map((opt) {
        final (anim, icon, label) = opt;
        final selected = value == anim;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(anim),
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
                  color: selected ? const Color(0xFFE8927C) : cs.onSurface.withValues(alpha: 0.1),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22,
                      color: selected ? const Color(0xFFE8927C) : const Color(0xFF9896B0)),
                  const SizedBox(height: 5),
                  Text(label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? const Color(0xFFE8927C) : const Color(0xFF9896B0),
                      )),
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
    (ReminderPosition.top,    Icons.vertical_align_top,    'Top'),
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
                  color: selected ? const Color(0xFFE8927C) : cs.onSurface.withValues(alpha: 0.1),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22,
                      color: selected ? const Color(0xFFE8927C) : const Color(0xFF9896B0)),
                  const SizedBox(height: 5),
                  Text(label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? const Color(0xFFE8927C) : const Color(0xFF9896B0),
                      )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ColorModeSelector extends StatelessWidget {
  final BannerColorMode value;
  final ValueChanged<BannerColorMode> onChanged;
  const _ColorModeSelector({required this.value, required this.onChanged});

  static const _options = [
    (BannerColorMode.dark,   Icons.dark_mode_outlined,  'Dark'),
    (BannerColorMode.bright, Icons.light_mode_outlined, 'Bright'),
    (BannerColorMode.custom, Icons.palette_outlined,    'Custom'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: _options.map((opt) {
        final (mode, icon, label) = opt;
        final selected = value == mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(mode),
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
                  color: selected ? const Color(0xFFE8927C) : cs.onSurface.withValues(alpha: 0.1),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22,
                      color: selected ? const Color(0xFFE8927C) : const Color(0xFF9896B0)),
                  const SizedBox(height: 5),
                  Text(label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected ? const Color(0xFFE8927C) : const Color(0xFF9896B0),
                      )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ColorGrid extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _ColorGrid({required this.selected, required this.onChanged});

  static const _presets = [
    0x7B6FD4, // purple (default)
    0x6BBFB5, // teal
    0xE8927C, // orange
    0x4A90E2, // blue
    0xD474AA, // pink
    0xE25C5C, // red
    0x1C1A2E, // dark navy
    0x2E7D32, // forest green
    0xF59E0B, // amber
    0x6B7280, // slate gray
    0x0891B2, // cyan
    0x92400E, // brown
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _presets.map((rgb) {
        final isSelected  = selected == rgb;
        final color       = Color(0xFF000000 | rgb);
        final checkColor  = color.computeLuminance() > 0.45
            ? Colors.black87
            : Colors.white;
        return GestureDetector(
          onTap: () => onChanged(rgb),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFFE8927C) : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isSelected ? 0.5 : 0.2),
                  blurRadius: isSelected ? 10 : 4,
                ),
              ],
            ),
            child: isSelected
                ? Icon(Icons.check_rounded, size: 18, color: checkColor)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

// ── Message field ─────────────────────────────────────────────────────────────

class _MessageField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>  onChanged;
  const _MessageField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLines:   3,
      onChanged:  onChanged,
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
        Text('→  $desc',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9896B0))),
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

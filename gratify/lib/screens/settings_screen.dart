import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../widgets/app_icon_widget.dart';
import '../widgets/countdown_ring.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = SettingsService();
  final _headingCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  bool _showAttemptCount = true;
  bool _showAppLogo = true;
  bool _showAppName = true;
  CountdownStyle _countdownStyle = CountdownStyle.ring;
  bool _showCountdownNumbers = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _service.load();
    if (!mounted) return;
    setState(() {
      _headingCtrl.text = s.heading;
      _subtitleCtrl.text = s.subtitle;
      _showAttemptCount = s.showAttemptCount;
      _showAppLogo = s.showAppLogo;
      _showAppName = s.showAppName;
      _countdownStyle = s.countdownStyle;
      _showCountdownNumbers = s.showCountdownNumbers;
      _loaded = true;
    });
  }

  AppSettings get _current => AppSettings(
        heading: _headingCtrl.text.trim().isEmpty
            ? AppSettings.defaultHeading
            : _headingCtrl.text,
        subtitle: _subtitleCtrl.text.trim().isEmpty
            ? AppSettings.defaultSubtitle
            : _subtitleCtrl.text,
        showAttemptCount: _showAttemptCount,
        showAppLogo: _showAppLogo,
        showAppName: _showAppName,
        countdownStyle: _countdownStyle,
        showCountdownNumbers: _showCountdownNumbers,
      );

  void _save() => _service.save(_current);

  @override
  void dispose() {
    _save();
    _headingCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  void _resetToDefaults() {
    setState(() {
      _headingCtrl.text = AppSettings.defaultHeading;
      _subtitleCtrl.text = AppSettings.defaultSubtitle;
      _showAttemptCount = true;
      _showAppLogo = true;
      _showAppName = true;
      _countdownStyle = CountdownStyle.ring;
      _showCountdownNumbers = true;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── Preview ──────────────────────────────────────────────────
                const _SectionLabel('Preview'),
                const SizedBox(height: 14),
                _PreviewCard(settings: _current),

                const SizedBox(height: 32),
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                const SizedBox(height: 24),

                // ── Delay Screen text ─────────────────────────────────────────
                const _SectionLabel('Delay Screen'),
                const SizedBox(height: 14),

                const _FieldLabel('Question'),
                const SizedBox(height: 8),
                _TextField(
                  controller: _headingCtrl,
                  hint: 'e.g. Are you sure you want to open this app?',
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                const _FieldHint('Shown as the heading on the pause screen.'),

                const SizedBox(height: 20),

                const _FieldLabel('Message'),
                const SizedBox(height: 8),
                _TextField(
                  controller: _subtitleCtrl,
                  hint: 'e.g. Take a breath and reflect.',
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                const _FieldHint('Shown below the timer.'),

                const SizedBox(height: 32),
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                const SizedBox(height: 24),

                // ── Display ───────────────────────────────────────────────────
                const _SectionLabel('Display'),
                const SizedBox(height: 14),

                _ToggleRow(
                  icon: Icons.image_outlined,
                  title: 'Show app logo',
                  subtitle: 'Display the app icon on the pause screen.',
                  value: _showAppLogo,
                  onChanged: (v) {
                    setState(() => _showAppLogo = v);
                    _save();
                  },
                ),
                const SizedBox(height: 10),
                _ToggleRow(
                  icon: Icons.title_rounded,
                  title: 'Show app name',
                  subtitle: 'Display the app name on the pause screen.',
                  value: _showAppName,
                  onChanged: (v) {
                    setState(() => _showAppName = v);
                    _save();
                  },
                ),
                const SizedBox(height: 10),
                _ToggleRow(
                  icon: Icons.tag_rounded,
                  title: 'Show attempt count',
                  subtitle: 'How many times you opened the app today.',
                  value: _showAttemptCount,
                  onChanged: (v) {
                    setState(() => _showAttemptCount = v);
                    _save();
                  },
                ),

                const SizedBox(height: 24),
                const _FieldLabel('Countdown style'),
                const SizedBox(height: 10),
                _CountdownStyleSelector(
                  value: _countdownStyle,
                  onChanged: (v) {
                    setState(() => _countdownStyle = v);
                    _save();
                  },
                ),

                const SizedBox(height: 16),
                _ToggleRow(
                  icon: Icons.numbers_rounded,
                  title: 'Show countdown numbers',
                  subtitle: 'Display the seconds remaining inside the timer.',
                  value: _showCountdownNumbers,
                  onChanged: (v) {
                    setState(() => _showCountdownNumbers = v);
                    _save();
                  },
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

// ── Preview card ──────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final AppSettings settings;
  const _PreviewCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (settings.showAppLogo)
            AppIconWidget(
              packageName: 'com.example.gratify',
              appName: 'Gratify',
              size: 56,
              borderRadius: 16,
            ),
          if (settings.showAppLogo && settings.showAppName)
            const SizedBox(height: 10),
          if (settings.showAppName)
            Text(
              'Gratify',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                letterSpacing: -0.4,
              ),
            ),
          const SizedBox(height: 16),
          CountdownRing(
            progress: 0.6,
            secondsRemaining: 6,
            style: settings.countdownStyle,
            showNumbers: settings.showCountdownNumbers,
            size: 140,
          ),
          const SizedBox(height: 20),
          Text(
            settings.heading,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            settings.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9896B0),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Countdown style selector ──────────────────────────────────────────────────

class _CountdownStyleSelector extends StatelessWidget {
  final CountdownStyle value;
  final ValueChanged<CountdownStyle> onChanged;

  const _CountdownStyleSelector({required this.value, required this.onChanged});

  static const _options = [
    (CountdownStyle.ring, Icons.radio_button_unchecked, 'Ring'),
    (CountdownStyle.fill, Icons.circle, 'Fill'),
    (CountdownStyle.bar, Icons.horizontal_rule_rounded, 'Bar'),
    (CountdownStyle.none, Icons.not_interested_outlined, 'None'),
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
                    ? const Color(0xFF7B6FD4).withValues(alpha: 0.15)
                    : cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF7B6FD4)
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
                        ? const Color(0xFF7B6FD4)
                        : const Color(0xFF9896B0),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? const Color(0xFF7B6FD4)
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

// ── Sub-widgets ──────────────────────────────────────────────────────────────

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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
}

class _FieldHint extends StatelessWidget {
  final String text;
  const _FieldHint(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF9896B0),
          height: 1.4,
        ),
      );
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _TextField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5),
      decoration: InputDecoration(
        hintText: hint,
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
            color: const Color(0xFF7B6FD4).withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF7B6FD4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF7B6FD4)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9896B0),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF7B6FD4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

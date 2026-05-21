import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../widgets/app_icon_widget.dart';
import '../widgets/countdown_ring.dart';

// Scale used when rendering text inside the small preview card.
const _previewScale = 140.0 / 220.0;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service      = SettingsService();
  final _headingCtrl  = TextEditingController();
  final _subtitleCtrl = TextEditingController();

  bool _showAttemptCount    = true;
  bool _showAppLogo         = true;
  bool _showAppName         = true;
  bool _showHeading         = true;
  bool _showSubtitle        = true;
  CountdownStyle _countdownStyle = CountdownStyle.ring;
  bool _showCountdownNumbers = true;
  bool _showBreathText      = true;

  double _fsAppName       = AppSettings.defaultFontSizeAppName;
  double _fsAttemptCount  = AppSettings.defaultFontSizeAttemptCount;
  double _fsHeading       = AppSettings.defaultFontSizeHeading;
  double _fsSubtitle      = AppSettings.defaultFontSizeSubtitle;
  double _fsTimerNumber   = AppSettings.defaultFontSizeTimerNumber;
  double _fsTimerLabel    = AppSettings.defaultFontSizeTimerLabel;

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
      _headingCtrl.text     = s.heading;
      _subtitleCtrl.text    = s.subtitle;
      _showAttemptCount     = s.showAttemptCount;
      _showAppLogo          = s.showAppLogo;
      _showAppName          = s.showAppName;
      _showHeading          = s.showHeading;
      _showSubtitle         = s.showSubtitle;
      _countdownStyle       = s.countdownStyle;
      _showCountdownNumbers = s.showCountdownNumbers;
      _showBreathText       = s.showBreathText;
      _fsAppName            = s.fontSizeAppName;
      _fsAttemptCount       = s.fontSizeAttemptCount;
      _fsHeading            = s.fontSizeHeading;
      _fsSubtitle           = s.fontSizeSubtitle;
      _fsTimerNumber        = s.fontSizeTimerNumber;
      _fsTimerLabel         = s.fontSizeTimerLabel;
      _loaded               = true;
    });
  }

  AppSettings get _current => AppSettings(
        heading:  _headingCtrl.text.trim().isEmpty  ? AppSettings.defaultHeading  : _headingCtrl.text,
        subtitle: _subtitleCtrl.text.trim().isEmpty ? AppSettings.defaultSubtitle : _subtitleCtrl.text,
        showAttemptCount:     _showAttemptCount,
        showAppLogo:          _showAppLogo,
        showAppName:          _showAppName,
        showHeading:          _showHeading,
        showSubtitle:         _showSubtitle,
        countdownStyle:       _countdownStyle,
        showCountdownNumbers: _showCountdownNumbers,
        showBreathText:       _showBreathText,
        fontSizeAppName:      _fsAppName,
        fontSizeAttemptCount: _fsAttemptCount,
        fontSizeHeading:      _fsHeading,
        fontSizeSubtitle:     _fsSubtitle,
        fontSizeTimerNumber:  _fsTimerNumber,
        fontSizeTimerLabel:   _fsTimerLabel,
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
      _headingCtrl.text     = AppSettings.defaultHeading;
      _subtitleCtrl.text    = AppSettings.defaultSubtitle;
      _showAttemptCount     = true;
      _showAppLogo          = true;
      _showAppName          = true;
      _showHeading          = true;
      _showSubtitle         = true;
      _countdownStyle       = CountdownStyle.ring;
      _showCountdownNumbers = true;
      _showBreathText       = true;
      _fsAppName            = AppSettings.defaultFontSizeAppName;
      _fsAttemptCount       = AppSettings.defaultFontSizeAttemptCount;
      _fsHeading            = AppSettings.defaultFontSizeHeading;
      _fsSubtitle           = AppSettings.defaultFontSizeSubtitle;
      _fsTimerNumber        = AppSettings.defaultFontSizeTimerNumber;
      _fsTimerLabel         = AppSettings.defaultFontSizeTimerLabel;
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
                _TappablePreviewCard(
                  settings: _current,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => _PreviewPage(settings: _current),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                const SizedBox(height: 24),

                // ── Countdown ─────────────────────────────────────────────────
                const _SectionLabel('Countdown'),
                const SizedBox(height: 14),

                const _FieldLabel('Style'),
                const SizedBox(height: 10),
                _CountdownStyleSelector(
                  value: _countdownStyle,
                  onChanged: (v) { setState(() => _countdownStyle = v); _save(); },
                ),

                const SizedBox(height: 16),
                _ToggleRow(
                  icon: Icons.numbers_rounded,
                  title: 'Show countdown numbers',
                  subtitle: 'Display the seconds remaining inside the timer.',
                  value: _showCountdownNumbers,
                  onChanged: (v) { setState(() => _showCountdownNumbers = v); _save(); },
                ),
                if (_countdownStyle == CountdownStyle.breath) ...[
                  const SizedBox(height: 10),
                  _ToggleRow(
                    icon: Icons.air_rounded,
                    title: 'Show breath cue',
                    subtitle: 'Show "breathe in / breathe out" text in the ring.',
                    value: _showBreathText,
                    onChanged: (v) { setState(() => _showBreathText = v); _save(); },
                  ),
                ],

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
                  onChanged: (v) { setState(() => _showAppLogo = v); _save(); },
                ),
                const SizedBox(height: 10),
                _ToggleRow(
                  icon: Icons.title_rounded,
                  title: 'Show app name',
                  subtitle: 'Display the app name on the pause screen.',
                  value: _showAppName,
                  onChanged: (v) { setState(() => _showAppName = v); _save(); },
                ),
                const SizedBox(height: 10),
                _ToggleRow(
                  icon: Icons.tag_rounded,
                  title: 'Show attempt count',
                  subtitle: 'How many times you opened the app today.',
                  value: _showAttemptCount,
                  onChanged: (v) { setState(() => _showAttemptCount = v); _save(); },
                ),

                const SizedBox(height: 32),
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                const SizedBox(height: 24),

                // ── Delay Screen text ─────────────────────────────────────────
                const _SectionLabel('Delay Screen'),
                const SizedBox(height: 14),

                _ToggleFieldSection(
                  label:   'Header',
                  hint:    'Shown as the heading on the pause screen.',
                  enabled: _showHeading,
                  onToggle: (v) { setState(() => _showHeading = v); _save(); },
                  child: _TextField(
                    controller: _headingCtrl,
                    hint: 'e.g. Are you sure you want to open this app?',
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(height: 20),

                _ToggleFieldSection(
                  label:   'Subtitle',
                  hint:    'Shown below the timer.',
                  enabled: _showSubtitle,
                  onToggle: (v) { setState(() => _showSubtitle = v); _save(); },
                  child: _TextField(
                    controller: _subtitleCtrl,
                    hint: 'e.g. Take a breath and reflect.',
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(height: 32),
                Divider(color: cs.onSurface.withValues(alpha: 0.08)),
                const SizedBox(height: 24),

                // ── Text sizes ────────────────────────────────────────────────
                const _SectionLabel('Text Sizes'),
                const SizedBox(height: 16),
                _SizeSliderGroup(
                  items: [
                    _SizeSliderItem(
                      label: 'App name',
                      value: _fsAppName,
                      min: 12, max: 40,
                      onChanged: (v) => setState(() => _fsAppName = v),
                      onChangeEnd: (_) => _save(),
                    ),
                    _SizeSliderItem(
                      label: 'Attempt count',
                      value: _fsAttemptCount,
                      min: 8, max: 24,
                      onChanged: (v) => setState(() => _fsAttemptCount = v),
                      onChangeEnd: (_) => _save(),
                    ),
                    _SizeSliderItem(
                      label: 'Header',
                      value: _fsHeading,
                      min: 10, max: 32,
                      onChanged: (v) => setState(() => _fsHeading = v),
                      onChangeEnd: (_) => _save(),
                    ),
                    _SizeSliderItem(
                      label: 'Subtitle',
                      value: _fsSubtitle,
                      min: 8, max: 24,
                      onChanged: (v) => setState(() => _fsSubtitle = v),
                      onChangeEnd: (_) => _save(),
                    ),
                    _SizeSliderItem(
                      label: 'Timer number',
                      value: _fsTimerNumber,
                      min: 20, max: 100,
                      onChanged: (v) => setState(() => _fsTimerNumber = v),
                      onChangeEnd: (_) => _save(),
                    ),
                    _SizeSliderItem(
                      label: 'Timer label',
                      value: _fsTimerLabel,
                      min: 8, max: 24,
                      onChanged: (v) => setState(() => _fsTimerLabel = v),
                      onChangeEnd: (_) => _save(),
                    ),
                  ],
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

// ── Tappable preview card ─────────────────────────────────────────────────────

class _TappablePreviewCard extends StatelessWidget {
  final AppSettings settings;
  final VoidCallback onTap;
  const _TappablePreviewCard({required this.settings, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s  = settings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
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
                if (s.showAppLogo)
                  AppIconWidget(
                    packageName: 'com.example.gratify',
                    appName: 'Gratify',
                    size: 56,
                    borderRadius: 16,
                  ),
                if (s.showAppLogo && s.showAppName) const SizedBox(height: 10),
                if (s.showAppName)
                  Text(
                    'Gratify',
                    style: TextStyle(
                      fontSize: s.fontSizeAppName * _previewScale,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      letterSpacing: -0.4,
                    ),
                  ),
                const SizedBox(height: 16),
                CountdownRing(
                  progress: 0.6,
                  secondsRemaining: 6,
                  style: s.countdownStyle,
                  showNumbers: s.showCountdownNumbers,
                  size: 140,
                  numberFontSize: s.fontSizeTimerNumber * _previewScale,
                  labelFontSize:  s.fontSizeTimerLabel  * _previewScale,
                  showBreathText: s.showBreathText,
                ),
                const SizedBox(height: 20),
                if (s.showHeading)
                  Text(
                    s.heading,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: s.fontSizeHeading * _previewScale,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      height: 1.5,
                    ),
                  ),
                if (s.showHeading && s.showSubtitle) const SizedBox(height: 6),
                if (s.showSubtitle)
                  Text(
                    s.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: s.fontSizeSubtitle * _previewScale,
                      color: const Color(0xFF9896B0),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.open_in_full_rounded,
                size: 12, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(width: 5),
            Text(
              'Tap to preview full screen',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Full-screen preview page ──────────────────────────────────────────────────

class _PreviewPage extends StatefulWidget {
  final AppSettings settings;
  const _PreviewPage({required this.settings});

  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _canOpen = false;

  static const _previewSeconds = 10;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _previewSeconds),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() => _canOpen = true);
      });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s  = widget.settings;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: cs.onSurface.withValues(alpha: 0.4)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Preview',
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurface.withValues(alpha: 0.35),
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
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
                if (s.showAppLogo)
                  AppIconWidget(
                    packageName: 'com.example.gratify',
                    appName: 'Gratify',
                    size: 72,
                    borderRadius: 20,
                  ),
                if (s.showAppLogo && s.showAppName) const SizedBox(height: 16),
                if (s.showAppName)
                  Text(
                    'Gratify',
                    style: TextStyle(
                      fontSize: s.fontSizeAppName,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                if (s.showAttemptCount) ...[
                  const SizedBox(height: 8),
                  Text(
                    "You've tried to open this app 3 times today",
                    style: TextStyle(
                      fontSize: s.fontSizeAttemptCount,
                      color: const Color(0xFF9896B0),
                    ),
                  ),
                ],
                const Spacer(flex: 1),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final progress  = 1.0 - _ctrl.value;
                    final remaining = (_previewSeconds * (1 - _ctrl.value)).ceil();
                    return CountdownRing(
                      progress: progress,
                      secondsRemaining: remaining,
                      style: s.countdownStyle,
                      showNumbers: s.showCountdownNumbers,
                      numberFontSize: s.fontSizeTimerNumber,
                      labelFontSize:  s.fontSizeTimerLabel,
                      showBreathText: s.showBreathText,
                    );
                  },
                ),
                const Spacer(flex: 1),
                if (s.showHeading)
                  Text(
                    s.heading,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: s.fontSizeHeading,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                      height: 1.5,
                      letterSpacing: -0.2,
                    ),
                  ),
                if (s.showHeading && s.showSubtitle) const SizedBox(height: 10),
                if (s.showSubtitle)
                  Text(
                    s.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: s.fontSizeSubtitle,
                      color: const Color(0xFF9896B0),
                      height: 1.6,
                    ),
                  ),
                const Spacer(flex: 2),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B6FD4),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Never mind, go back',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedOpacity(
                  opacity: _canOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: IgnorePointer(
                    ignoring: !_canOpen,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Open App',
                        style: TextStyle(color: Color(0xFF9896B0), fontSize: 14),
                      ),
                    ),
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

// ── Size slider group ─────────────────────────────────────────────────────────

class _SizeSliderItem {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _SizeSliderItem({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
  });
}

class _SizeSliderGroup extends StatelessWidget {
  final List<_SizeSliderItem> items;
  const _SizeSliderGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 108,
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      activeTrackColor: const Color(0xFF7B6FD4),
                      inactiveTrackColor: cs.onSurface.withValues(alpha: 0.1),
                      thumbColor: const Color(0xFF7B6FD4),
                      overlayColor:
                          const Color(0xFF7B6FD4).withValues(alpha: 0.12),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: item.value,
                      min: item.min,
                      max: item.max,
                      divisions: (item.max - item.min).round(),
                      onChanged: item.onChanged,
                      onChangeEnd: item.onChangeEnd,
                    ),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${item.value.round()}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7B6FD4),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
    (CountdownStyle.ring,   Icons.radio_button_unchecked,  'Ring'),
    (CountdownStyle.fill,   Icons.circle,                  'Fill'),
    (CountdownStyle.bar,    Icons.horizontal_rule_rounded, 'Bar'),
    (CountdownStyle.breath, Icons.air_rounded,             'Breath'),
    (CountdownStyle.none,   Icons.not_interested_outlined, 'None'),
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
                      fontSize: 10,
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

class _ToggleFieldSection extends StatelessWidget {
  final String label;
  final String hint;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final Widget child;

  const _ToggleFieldSection({
    required this.label,
    required this.hint,
    required this.enabled,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: enabled
                          ? cs.onSurface
                          : cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled
                          ? const Color(0xFF9896B0)
                          : const Color(0xFF9896B0).withValues(alpha: 0.4),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onToggle,
              activeThumbColor: const Color(0xFF7B6FD4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedOpacity(
          opacity: enabled ? 1.0 : 0.35,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(ignoring: !enabled, child: child),
        ),
      ],
    );
  }
}

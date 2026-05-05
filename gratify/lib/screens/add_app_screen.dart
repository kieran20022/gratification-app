import 'package:flutter/material.dart';
import '../models/restricted_app.dart';
import '../widgets/app_icon_widget.dart';
import 'app_picker_screen.dart';

/// Screen for adding a new restricted app or editing an existing one.
/// When [existing] is null, a new [RestrictedApp] is created on save;
/// otherwise the existing entry is updated in-place.
class AddAppScreen extends StatefulWidget {
  /// The app being edited, or null when creating a new restriction.
  final RestrictedApp? existing;

  /// Called with the resulting [RestrictedApp] after the user taps save.
  final ValueChanged<RestrictedApp> onSave;

  const AddAppScreen({super.key, this.existing, required this.onSave});

  @override
  State<AddAppScreen> createState() => _AddAppScreenState();
}

class _AddAppScreenState extends State<AddAppScreen> {
  String? _appName;
  String? _packageName;
  late double _delaySeconds;
  late int _graceMinutes;
  late bool _grayscale;
  late int _reminderIntervalSeconds;
  late int _usageLimitSeconds;

  /// null means the grayscale window covers all day.
  TimeOfDay? _grayscaleStart;
  TimeOfDay? _grayscaleEnd;

  /// Quick-select delay presets shown as chips (in seconds).
  static const _presets = [10, 15, 20, 30, 60];

  /// Quick-select grace period presets shown as chips (in minutes).
  /// 0 means "always delay" — no grace window at all.
  static const _gracePresets = [0, 1, 2, 5, 10, 30];

  /// Quick-select reminder interval presets (in seconds). 0 = disabled.
  static const _reminderPresets = [0, 30, 300, 600, 900, 1800];

  /// Quick-select session limit presets (in seconds). 0 = disabled.
  static const _limitPresets = [0, 30, 300, 600, 900, 1800, 3600];

  @override
  void initState() {
    super.initState();
    // Pre-populate fields when editing an existing restriction.
    _appName = widget.existing?.name;
    _packageName = widget.existing?.packageName;
    _delaySeconds = (widget.existing?.delaySeconds ?? 10).toDouble();
    _graceMinutes = widget.existing?.graceMinutes ?? 2;
    _grayscale = widget.existing?.grayscale ?? false;
    _reminderIntervalSeconds = widget.existing?.reminderIntervalSeconds ?? 0;
    _usageLimitSeconds = widget.existing?.usageLimitSeconds ?? 0;
    final startMin = widget.existing?.grayscaleStartMinute;
    final endMin = widget.existing?.grayscaleEndMinute;
    _grayscaleStart = startMin != null
        ? TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60)
        : null;
    _grayscaleEnd = endMin != null
        ? TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60)
        : null;
  }

  /// Converts a raw seconds value into a human-readable label,
  /// e.g. 90 → "1 min 30 sec", 60 → "1 minute", 10 → "10 seconds".
  String _formatDelay(double seconds) {
    final s = seconds.round();
    if (s < 60) return '$s seconds';
    final m = s ~/ 60;
    final rem = s % 60;
    if (rem == 0) return '$m minute${m > 1 ? 's' : ''}';
    return '$m min $rem sec';
  }

  /// Formats a seconds value as "30s", "5m", "1h", etc.
  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) {
      final m = seconds ~/ 60;
      return '${m}m';
    }
    final h = seconds ~/ 3600;
    return '${h}h';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  /// Opens the app picker and updates state with the user's selection.
  /// The mounted guard prevents calling setState after the widget is disposed,
  /// which can happen if the user navigates away before the picker returns.
  Future<void> _pickApp() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(builder: (_) => const AppPickerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _appName = result['name'];
        _packageName = result['packageName'];
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_grayscaleStart ?? const TimeOfDay(hour: 22, minute: 0))
        : (_grayscaleEnd ?? const TimeOfDay(hour: 8, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _grayscaleStart = picked;
        } else {
          _grayscaleEnd = picked;
        }
      });
    }
  }

  /// Validates the form, constructs a [RestrictedApp], and notifies the parent.
  /// New apps receive a millisecond-epoch ID to guarantee uniqueness without
  /// requiring a database sequence.
  void _save() {
    if (_appName == null || _packageName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an app first')),
      );
      return;
    }
    // Convert TimeOfDay back to minutes-since-midnight for storage.
    final startMin = _grayscale && _grayscaleStart != null
        ? _grayscaleStart!.hour * 60 + _grayscaleStart!.minute
        : null;
    final endMin = _grayscale && _grayscaleEnd != null
        ? _grayscaleEnd!.hour * 60 + _grayscaleEnd!.minute
        : null;
    final app = RestrictedApp(
      id:
          widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _appName!,
      packageName: _packageName!,
      delaySeconds: _delaySeconds.round(),
      graceMinutes: _graceMinutes,
      dailyAttempts: widget.existing?.dailyAttempts ?? 0,
      lastAttemptDate: widget.existing?.lastAttemptDate ?? '',
      grayscale: _grayscale,
      grayscaleStartMinute: startMin,
      grayscaleEndMinute: endMin,
      reminderIntervalSeconds: _reminderIntervalSeconds,
      usageLimitSeconds: _usageLimitSeconds,
    );
    widget.onSave(app);
    Navigator.pop(context);
  }

  /// Returns a deterministic accent color derived from the app name's hash,
  /// so each app consistently renders the same color across sessions.
  Color get _iconColor {
    if (_appName == null) return const Color(0xFF9896B0);
    const colors = [
      Color(0xFF7B6FD4),
      Color(0xFF6BBFB5),
      Color(0xFFE8927C),
      Color(0xFF74B9D4),
      Color(0xFFD474AA),
    ];
    return colors[_appName!.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add App' : 'Edit App'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Tappable card that opens the app picker.
          // The border animates in with the app's accent color once selected.
          GestureDetector(
            onTap: _pickApp,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _appName != null
                      ? _iconColor.withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // Show the real app icon once an app is chosen,
                  // otherwise show a placeholder add-icon.
                  if (_appName != null && _packageName != null)
                    AppIconWidget(
                      packageName: _packageName!,
                      appName: _appName!,
                      size: 44,
                      borderRadius: 12,
                    )
                  else
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E4F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF9896B0),
                      ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _appName ?? 'Choose an app',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _appName != null
                                ? Theme.of(context).colorScheme.onSurface
                                : const Color(0xFF9896B0),
                          ),
                        ),
                        if (_packageName != null)
                          Text(
                            _packageName!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9896B0),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF9896B0)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // --- Delay Duration section ---
          // How long the countdown screen is shown before the app opens.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delay Duration',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              // Live badge showing the currently selected delay.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B6FD4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatDelay(_delaySeconds),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B6FD4),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Preset chips let the user jump to a common value instantly.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((s) {
              final selected = _delaySeconds.round() == s;
              final label = s < 60 ? '${s}s' : '${s ~/ 60}m';
              return _Chip(
                label: label,
                selected: selected,
                onTap: () => setState(() => _delaySeconds = s.toDouble()),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Slider snaps to 5-second increments (divisions: 11 covers 5–60 in steps of 5).
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF7B6FD4),
              inactiveTrackColor: const Color(0xFFE8E4F8),
              thumbColor: const Color(0xFF7B6FD4),
              overlayColor: const Color(0xFF7B6FD4).withValues(alpha: 0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: _delaySeconds,
              min: 5,
              max: 60,
              divisions: 11,
              onChanged: (v) =>
                  setState(() => _delaySeconds = (v / 5).round() * 5.0),
            ),
          ),

          // Range labels beneath the slider for visual context.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  '5 sec',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9896B0)),
                ),
                Text(
                  '1 min',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9896B0)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // --- Re-open Window (grace period) section ---
          // If the user re-opens the app within this window after a successful
          // delay, the countdown is skipped. Keeps the experience from feeling
          // punishing for quick task-switches.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Re-open Window',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              // Badge showing the active grace period.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6BBFB5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _graceMinutes == 0
                      ? 'Always delay'
                      : _graceMinutes == 1
                      ? '1 minute'
                      : '$_graceMinutes minutes',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6BBFB5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'After opening, re-opens within this window skip the delay.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9896B0),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _gracePresets.map((m) {
              final selected = _graceMinutes == m;
              final label = m == 0
                  ? 'Off'
                  : m == 1
                  ? '1m'
                  : '${m}m';
              return _Chip(
                label: label,
                selected: selected,
                selectedColor: const Color(0xFF6BBFB5),
                onTap: () => setState(() => _graceMinutes = m),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // --- Grayscale section ---
          // Shows a translucent gray overlay over the app to mute its colors
          // and reduce visual engagement. No extra permissions required.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grayscale',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Mutes the app\'s colors to reduce its visual appeal.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9896B0),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _grayscale,
                onChanged: (v) => setState(() {
                  _grayscale = v;
                  // Clear time restrictions when turning grayscale off.
                  if (!v) {
                    _grayscaleStart = null;
                    _grayscaleEnd = null;
                  }
                }),
                activeThumbColor: const Color(0xFF7B6FD4),
              ),
            ],
          ),

          // Time restriction rows animate in when grayscale is enabled.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _grayscale
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Time restriction',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9896B0),
                              ),
                            ),
                            const Spacer(),
                            // "All day" toggle clears any set time window.
                            _Chip(
                              label: 'All day',
                              selected:
                                  _grayscaleStart == null &&
                                  _grayscaleEnd == null,
                              selectedColor: const Color(0xFF7B6FD4),
                              onTap: () => setState(() {
                                _grayscaleStart = null;
                                _grayscaleEnd = null;
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _TimeButton(
                                label: 'From',
                                time: _grayscaleStart,
                                placeholder: 'Set time',
                                onTap: () => _pickTime(isStart: true),
                                onClear: _grayscaleStart != null
                                    ? () =>
                                          setState(() => _grayscaleStart = null)
                                    : null,
                                formatTime: _formatTime,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TimeButton(
                                label: 'To',
                                time: _grayscaleEnd,
                                placeholder: 'Set time',
                                onTap: () => _pickTime(isStart: false),
                                onClear: _grayscaleEnd != null
                                    ? () => setState(() => _grayscaleEnd = null)
                                    : null,
                                formatTime: _formatTime,
                              ),
                            ),
                          ],
                        ),
                        if (_grayscaleStart != null || _grayscaleEnd != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Grayscale active ${_grayscaleStart != null ? "from ${_formatTime(_grayscaleStart!)}" : ""}${_grayscaleStart != null && _grayscaleEnd != null ? " " : ""}${_grayscaleEnd != null ? "until ${_formatTime(_grayscaleEnd!)}" : ""}.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9896B0),
                                height: 1.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 32),

          // --- Usage Reminder section ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Usage Reminder',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8927C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _reminderIntervalSeconds == 0
                          ? 'Off'
                          : 'Every ${_formatDuration(_reminderIntervalSeconds)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE8927C),
                      ),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Shows a brief nudge while you\'re in the app.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9896B0), height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reminderPresets.map((s) {
              final selected = _reminderIntervalSeconds == s;
              return _Chip(
                label: s == 0 ? 'Off' : _formatDuration(s),
                selected: selected,
                selectedColor: const Color(0xFFE8927C),
                onTap: () => setState(() => _reminderIntervalSeconds = s),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          // --- Session Limit section ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Session Limit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD474AA).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _usageLimitSeconds == 0
                      ? 'Off'
                      : '${_formatDuration(_usageLimitSeconds)} limit',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD474AA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Re-triggers the delay screen after this much use.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9896B0), height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _limitPresets.map((s) {
              final selected = _usageLimitSeconds == s;
              return _Chip(
                label: s == 0 ? 'Off' : _formatDuration(s),
                selected: selected,
                selectedColor: const Color(0xFFD474AA),
                onTap: () => setState(() => _usageLimitSeconds = s),
              );
            }).toList(),
          ),

          const SizedBox(height: 48),

          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B6FD4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              widget.existing == null ? 'Add App' : 'Save Changes',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable time-picker button showing the selected time or a placeholder.
class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String Function(TimeOfDay) formatTime;

  const _TimeButton({
    required this.label,
    required this.time,
    required this.placeholder,
    required this.onTap,
    required this.onClear,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final isSet = time != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSet
                ? const Color(0xFF7B6FD4).withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9896B0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSet ? formatTime(time!) : placeholder,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSet
                          ? Theme.of(context).colorScheme.onSurface
                          : const Color(0xFF9896B0),
                    ),
                  ),
                ],
              ),
            ),
            if (isSet && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Color(0xFF9896B0),
                ),
              )
            else
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: Color(0xFF9896B0),
              ),
          ],
        ),
      ),
    );
  }
}

/// A pill-shaped toggle chip used for preset value selection.
/// Animates between selected and unselected states.
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// The fill color when the chip is selected; defaults to the primary purple.
  final Color selectedColor;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor = const Color(0xFF7B6FD4),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

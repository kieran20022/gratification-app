import 'package:flutter/material.dart';
import '../models/restricted_app.dart';
import '../widgets/app_icon_widget.dart';
import 'app_picker_screen.dart';

class AddAppScreen extends StatefulWidget {
  final RestrictedApp? existing;
  final ValueChanged<RestrictedApp> onSave;

  const AddAppScreen({
    super.key,
    this.existing,
    required this.onSave,
  });

  @override
  State<AddAppScreen> createState() => _AddAppScreenState();
}

class _AddAppScreenState extends State<AddAppScreen> {
  String? _appName;
  String? _packageName;
  late double _delaySeconds;
  late int _graceMinutes;

  static const _presets = [10, 15, 20, 30, 60];
  static const _gracePresets = [0, 1, 2, 5, 10, 30];

  @override
  void initState() {
    super.initState();
    _appName = widget.existing?.name;
    _packageName = widget.existing?.packageName;
    _delaySeconds = (widget.existing?.delaySeconds ?? 10).toDouble();
    _graceMinutes = widget.existing?.graceMinutes ?? 2;
  }

  String _formatDelay(double seconds) {
    final s = seconds.round();
    if (s < 60) return '$s seconds';
    final m = s ~/ 60;
    final rem = s % 60;
    if (rem == 0) return '$m minute${m > 1 ? 's' : ''}';
    return '$m min $rem sec';
  }

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

  void _save() {
    if (_appName == null || _packageName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an app first')),
      );
      return;
    }
    final app = RestrictedApp(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _appName!,
      packageName: _packageName!,
      delaySeconds: _delaySeconds.round(),
      graceMinutes: _graceMinutes,
      dailyAttempts: widget.existing?.dailyAttempts ?? 0,
      lastAttemptDate: widget.existing?.lastAttemptDate ?? '',
    );
    widget.onSave(app);
    Navigator.pop(context);
  }

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
          // App selector
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
                      child: const Icon(Icons.add_rounded,
                          color: Color(0xFF9896B0)),
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
                                fontSize: 11, color: Color(0xFF9896B0)),
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

          // Delay duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Delay Duration',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B6FD4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatDelay(_delaySeconds),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7B6FD4)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('5 sec',
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF9896B0))),
                Text('1 min',
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF9896B0))),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Grace period
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Re-open Window',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      color: Color(0xFF6BBFB5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'After opening, re-opens within this window skip the delay.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9896B0), height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _gracePresets.map((m) {
              final selected = _graceMinutes == m;
              final label = m == 0 ? 'Off' : m == 1 ? '1m' : '${m}m';
              return _Chip(
                label: label,
                selected: selected,
                selectedColor: const Color(0xFF6BBFB5),
                onTap: () => setState(() => _graceMinutes = m),
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
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              widget.existing == null ? 'Add App' : 'Save Changes',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
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
          color: selected ? selectedColor : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

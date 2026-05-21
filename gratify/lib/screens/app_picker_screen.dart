import 'package:flutter/material.dart';
import '../services/app_service.dart';
import '../widgets/app_icon_widget.dart';

class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key});

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _search    = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final apps = await AppService.getInstalledApps();
    if (!mounted) return;
    setState(() {
      _all      = apps;
      _filtered = apps;
      _loading  = false;
    });
    // Only open the keyboard once the list is ready.
    _focusNode.requestFocus();
  }

  void _filter(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _all
          : _all
              .where((a) =>
                  (a['name'] as String).toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  String _formatScreenTime(int seconds) {
    if (seconds <= 0) return '';
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark ? cs.surfaceContainerHighest : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select App'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller:  _search,
              focusNode:   _focusNode,
              enabled:     !_loading,
              onChanged:   _filter,
              style: TextStyle(color: cs.onSurface),
              decoration: InputDecoration(
                hintText:  'Search apps...',
                hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                prefixIcon: Icon(Icons.search,
                    color: cs.onSurface.withValues(alpha: 0.45)),
                filled:     true,
                fillColor:  barColor,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:   BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const _SkeletonList()
          : _filtered.isEmpty
              ? const Center(
                  child: Text('No apps found',
                      style: TextStyle(color: Color(0xFF9896B0))),
                )
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final app        = _filtered[i];
                    final name       = app['name'] as String;
                    final pkg        = app['packageName'] as String;
                    final screenTime = (app['screenTime'] as num?)?.toInt() ?? 0;
                    final timeLabel  = _formatScreenTime(screenTime);

                    return ListTile(
                      leading: AppIconWidget(
                        packageName: pkg,
                        appName:     name,
                        size:        42,
                        borderRadius: 10,
                      ),
                      title: Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(pkg,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9896B0))),
                      trailing: timeLabel.isEmpty
                          ? null
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7B6FD4)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                timeLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF7B6FD4),
                                ),
                              ),
                            ),
                      onTap: () => Navigator.pop(context, {
                        'name':        name,
                        'packageName': pkg,
                      }),
                    );
                  },
                ),
    );
  }
}

// ── Skeleton loader ───────────────────────────────────────────────────────────

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => ListView.builder(
        itemCount: 14,
        itemBuilder: (context, i) => _SkeletonTile(opacity: _anim.value, index: i),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  final double opacity;
  final int    index;
  const _SkeletonTile({required this.opacity, required this.index});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withValues(alpha: opacity);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // App icon placeholder
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 16),
          // Text lines
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: base,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 140,
                  decoration: BoxDecoration(
                    color: base.withValues(alpha: opacity * 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Screen-time badge placeholder — stagger across rows for realism
          if (index % 3 != 2)
            Container(
              width: 36, height: 22,
              decoration: BoxDecoration(
                color: base.withValues(alpha: opacity * 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
        ],
      ),
    );
  }
}

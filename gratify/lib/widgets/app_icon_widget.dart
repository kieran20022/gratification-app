import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/app_service.dart';

class AppIconWidget extends StatefulWidget {
  final String packageName;
  final String appName;
  final double size;
  final double borderRadius;

  const AppIconWidget({
    super.key,
    required this.packageName,
    required this.appName,
    this.size = 48,
    this.borderRadius = 12,
  });

  @override
  State<AppIconWidget> createState() => _AppIconWidgetState();
}

class _AppIconWidgetState extends State<AppIconWidget> {
  // Process-wide cache so icons aren't re-fetched across screens
  static final _cache = <String, Uint8List?>{};

  Uint8List? _bytes;
  bool _loaded = false;

  Color get _fallbackColor {
    const colors = [
      Color(0xFF7B6FD4),
      Color(0xFF6BBFB5),
      Color(0xFFE8927C),
      Color(0xFF74B9D4),
      Color(0xFFD474AA),
    ];
    return colors[widget.appName.hashCode.abs() % colors.length];
  }

  @override
  void initState() {
    super.initState();
    _load(widget.packageName);
  }

  @override
  void didUpdateWidget(AppIconWidget old) {
    super.didUpdateWidget(old);
    if (old.packageName != widget.packageName) {
      setState(() { _bytes = null; _loaded = false; });
      _load(widget.packageName);
    }
  }

  Future<void> _load(String pkg) async {
    if (_cache.containsKey(pkg)) {
      if (mounted) setState(() { _bytes = _cache[pkg]; _loaded = true; });
      return;
    }
    final bytes = await AppService.getAppIcon(pkg);
    _cache[pkg] = bytes;
    if (mounted) setState(() { _bytes = bytes; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded && _bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.memory(
          _bytes!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    // Placeholder shown while loading (or if icon unavailable)
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: _fallbackColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      child: Center(
        child: Text(
          widget.appName.isNotEmpty ? widget.appName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.w700,
            color: _fallbackColor,
          ),
        ),
      ),
    );
  }
}

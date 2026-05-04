import 'package:flutter/material.dart';
import '../services/app_service.dart';
import '../widgets/app_icon_widget.dart';

class AppPickerScreen extends StatefulWidget {
  const AppPickerScreen({super.key});

  @override
  State<AppPickerScreen> createState() => _AppPickerScreenState();
}

class _AppPickerScreenState extends State<AppPickerScreen> {
  List<Map<String, String>> _all = [];
  List<Map<String, String>> _filtered = [];
  bool _loading = true;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final apps = await AppService.getInstalledApps();
    if (mounted) {
      setState(() {
        _all = apps;
        _filtered = apps;
        _loading = false;
      });
    }
  }

  void _filter(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _all
          : _all
              .where((a) =>
                  a['name']!.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select App'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _filter,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                hintStyle: const TextStyle(color: Color(0xFF9896B0)),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF9896B0)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF7B6FD4)),
            )
          : _filtered.isEmpty
              ? const Center(
                  child: Text('No apps found',
                      style: TextStyle(color: Color(0xFF9896B0))),
                )
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final app = _filtered[i];
                    final name = app['name']!;
                    final pkg = app['packageName']!;
                    return ListTile(
                      leading: AppIconWidget(
                        packageName: pkg,
                        appName: name,
                        size: 42,
                        borderRadius: 10,
                      ),
                      title: Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        pkg,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9896B0)),
                      ),
                      onTap: () => Navigator.pop(context, app),
                    );
                  },
                ),
    );
  }
}

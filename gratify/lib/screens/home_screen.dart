import 'package:flutter/material.dart';
import '../models/restricted_app.dart';
import '../services/app_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_icon_widget.dart';
import 'add_app_screen.dart';
import 'permissions_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _storage = StorageService();
  List<RestrictedApp> _apps = [];
  bool _loading = true;
  bool _hasAccessibility = false;
  bool _hasOverlay = false;
  bool _monitoring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _init() async {
    await _loadApps();
    await _refreshPermissions();
  }

  Future<void> _loadApps() async {
    final apps = await _storage.loadApps();
    if (mounted) setState(() { _apps = apps; _loading = false; });
  }

  Future<void> _refreshPermissions() async {
    final accessibility = await AppService.checkAccessibilityPermission();
    final overlay = await AppService.checkOverlayPermission();
    final active = await AppService.isMonitoringActive();
    if (mounted) {
      setState(() {
        _hasAccessibility = accessibility;
        _hasOverlay = overlay;
        _monitoring = active;
      });
    }
  }

  bool get _permissionsGranted => _hasAccessibility && _hasOverlay;

  Future<void> _toggleMonitoring(bool value) async {
    if (value) {
      if (!_permissionsGranted) {
        _showPermissionsScreen();
        return;
      }
      await AppService.startMonitoring();
    } else {
      await AppService.stopMonitoring();
    }
    setState(() => _monitoring = value);
  }

  void _showPermissionsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PermissionsScreen(
          onComplete: () {
            Navigator.pop(context);
            _toggleMonitoring(true);
          },
        ),
      ),
    );
  }

  Future<void> _addApp() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddAppScreen(
          onSave: (app) async {
            setState(() => _apps.add(app));
            await _storage.saveApps(_apps);
          },
        ),
      ),
    );
  }

  Future<void> _editApp(RestrictedApp app) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddAppScreen(
          existing: app,
          onSave: (updated) async {
            final i = _apps.indexWhere((a) => a.id == app.id);
            setState(() => _apps[i] = updated);
            await _storage.saveApps(_apps);
          },
        ),
      ),
    );
  }

  void _deleteApp(RestrictedApp app) {
    setState(() => _apps.removeWhere((a) => a.id == app.id));
    _storage.saveApps(_apps);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gratify'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          if (_apps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Icon(
                    _monitoring ? Icons.shield : Icons.shield_outlined,
                    size: 18,
                    color: _monitoring
                        ? const Color(0xFF6BBFB5)
                        : const Color(0xFF9896B0),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: _monitoring,
                    onChanged: _toggleMonitoring,
                    activeThumbColor: const Color(0xFF6BBFB5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_permissionsGranted && _apps.isNotEmpty)
                  _PermissionBanner(onSetup: _showPermissionsScreen),
                Expanded(
                  child: _apps.isEmpty
                      ? _EmptyState(onAddApp: _addApp)
                      : _AppList(
                          apps: _apps,
                          monitoring: _monitoring,
                          onEdit: _editApp,
                          onDelete: _deleteApp,
                        ),
                ),
              ],
            ),
      floatingActionButton: _apps.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _addApp,
              backgroundColor: const Color(0xFF7B6FD4),
              foregroundColor: Colors.white,
              elevation: 2,
              child: const Icon(Icons.add),
            ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onSetup;
  const _PermissionBanner({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSetup,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8927C).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFE8927C).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: const [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE8927C), size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Permissions needed to intercept app launches.  Set up →',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB36A50),
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddApp;
  const _EmptyState({required this.onAddApp});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF7B6FD4).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  size: 48, color: Color(0xFF7B6FD4)),
            ),
            const SizedBox(height: 28),
            Text(
              'No apps restricted yet',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.3),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add the apps you want to be more\nmindful about opening.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, color: Color(0xFF9896B0), height: 1.6),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: onAddApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B6FD4),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Add your first app',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppList extends StatelessWidget {
  final List<RestrictedApp> apps;
  final bool monitoring;
  final ValueChanged<RestrictedApp> onEdit;
  final ValueChanged<RestrictedApp> onDelete;

  const _AppList({
    required this.apps,
    required this.monitoring,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Row(
            children: [
              Text(
                '${apps.length} app${apps.length == 1 ? '' : 's'} restricted',
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9896B0),
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (monitoring)
                const Row(children: [
                  Icon(Icons.circle, size: 8, color: Color(0xFF6BBFB5)),
                  SizedBox(width: 5),
                  Text('Monitoring active',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6BBFB5),
                          fontWeight: FontWeight.w600)),
                ])
              else
                const Text('Monitoring off',
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF9896B0))),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: apps.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final app = apps[index];
              return _AppCard(
                app: app,
                onTap: () => onEdit(app),
                onEdit: () => onEdit(app),
                onDelete: () => onDelete(app),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AppCard extends StatelessWidget {
  final RestrictedApp app;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AppCard({
    required this.app,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });


  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AppIconWidget(
                packageName: app.packageName,
                appName: app.name,
                size: 48,
                borderRadius: 12,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 13, color: Color(0xFF9896B0)),
                        const SizedBox(width: 4),
                        Text(app.delayLabel,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF9896B0))),
                        if (app.dailyAttempts > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8927C)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${app.dailyAttempts}× today',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFE8927C),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ])),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ])),
                ],
                icon: const Icon(Icons.more_vert, color: Color(0xFF9896B0)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

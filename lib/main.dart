import 'package:flutter/material.dart';

import 'screens/role_gate_screen.dart';
import 'screens/shell.dart';
import 'models/enums.dart';
import 'services/billing_repository.dart';
import 'state/billing_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await BillingRepository.create();
  final controller = BillingController(repository);
  runApp(UnitedKitesApp(controller: controller));
  await controller.load();
}

class UnitedKitesApp extends StatelessWidget {
  const UnitedKitesApp({super.key, required this.controller});

  final BillingController controller;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: _MaterialHost(controller: controller),
    );
  }
}

/// Rebuilds [MaterialApp] only for session / locale / theme — not for every
/// invoice, expense, or stock [notifyListeners], which would dispose overlays
/// and trip InheritedNotifier `_dependents.isEmpty`.
class _MaterialHost extends StatefulWidget {
  const _MaterialHost({required this.controller});

  final BillingController controller;

  @override
  State<_MaterialHost> createState() => _MaterialHostState();
}

class _MaterialHostState extends State<_MaterialHost> {
  UserSession? _session;
  bool _ar = false;
  bool _dark = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _capture();
    widget.controller.addListener(_onBilling);
  }

  @override
  void didUpdateWidget(covariant _MaterialHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onBilling);
      widget.controller.addListener(_onBilling);
      _capture();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onBilling);
    super.dispose();
  }

  void _capture() {
    _session = widget.controller.session;
    _ar = widget.controller.s.isAr;
    _dark = widget.controller.settings.options.darkTheme;
    _loading = widget.controller.loading;
  }

  void _onBilling() {
    final session = widget.controller.session;
    final ar = widget.controller.s.isAr;
    final dark = widget.controller.settings.options.darkTheme;
    final loading = widget.controller.loading;
    if (session == _session && ar == _ar && dark == _dark && loading == _loading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(_capture);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return MaterialApp(
      title: 'United Kites',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      home: _loading
          ? const _BootScreen()
          : _session == null
              ? const RoleGateScreen()
              : const BillingShell(),
      builder: (context, child) {
        return Directionality(
          textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF7F4F2),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 16),
            Text(
              'United Kites',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

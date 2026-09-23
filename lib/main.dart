import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'models/enums.dart';
import 'services/billing_repository.dart';
import 'state/billing_controller.dart';
import 'theme/app_theme.dart';

/// Unauthenticated users stay on [AuthRoutes.login]. A session opens [AuthRoutes.pos].
class AuthRoutes {
  const AuthRoutes._();

  static const boot = '/boot';
  static const login = '/login';
  static const pos = '/pos';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      ).timeout(const Duration(seconds: 6));
    } catch (_) {
      // Local cache still boots. BillingRepository retries the connection.
    }
  }
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
  final _navigatorKey = GlobalKey<NavigatorState>();
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
    final wasLoading = _loading;
    final wasSignedIn = _session != null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(_capture);
      _syncAuthRoute(wasLoading: wasLoading, wasSignedIn: wasSignedIn);
    });
  }

  String get _authRoute {
    if (_loading) return AuthRoutes.boot;
    if (_session == null) return AuthRoutes.login;
    return AuthRoutes.pos;
  }

  void _syncAuthRoute({required bool wasLoading, required bool wasSignedIn}) {
    if (wasLoading == _loading && wasSignedIn == (_session != null)) return;
    final nav = _navigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncAuthRoute(wasLoading: wasLoading, wasSignedIn: wasSignedIn);
      });
      return;
    }
    nav.pushNamedAndRemoveUntil(_authRoute, (_) => false);
  }

  Route<void> _onGenerateRoute(RouteSettings settings) {
    final name = _authRoute;
    final page = switch (name) {
      AuthRoutes.boot => const _BootScreen(),
      AuthRoutes.login => const LoginScreen(),
      _ => const BillingShell(),
    };
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name, arguments: settings.arguments),
      builder: (_) => page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'United Kites',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: _authRoute,
      onGenerateRoute: _onGenerateRoute,
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

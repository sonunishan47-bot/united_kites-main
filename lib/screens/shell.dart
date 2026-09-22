import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'catalog_screen.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'route_screen.dart';

class AppScope extends InheritedNotifier<BillingController> {
  const AppScope({
    super.key,
    required BillingController controller,
    required super.child,
  }) : super(notifier: controller);

  static BillingController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }

  /// Lookup without registering a dependency (safe during overlays / login).
  static BillingController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}

class BillingShell extends StatefulWidget {
  const BillingShell({super.key});

  @override
  State<BillingShell> createState() => BillingShellState();
}

class _Dest {
  const _Dest(this.title, this.icon, this.page);
  final String title;
  final IconData icon;
  final Widget page;
}

class BillingShellState extends State<BillingShell> {
  int index = 0;

  void goToDashboard() {
    if (!mounted) return;
    setState(() => index = 0);
  }

  List<_Dest> _dests(S s) {
    return [
      _Dest(s.home, Icons.home_outlined, const HomeScreen()),
      _Dest(s.dashboard, Icons.space_dashboard_outlined, const DashboardScreen()),
      _Dest(s.items, Icons.inventory_2_outlined, const CatalogScreen()),
      _Dest(s.routes, Icons.map_outlined, const RouteScreen()),
      _Dest(s.more, Icons.grid_view_rounded, const MoreScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final dests = _dests(s);
    if (index >= dests.length) {
      index = 0;
    }
    final wide = MediaQuery.sizeOf(context).width >= 980;

    if (billing.sessionLocked) {
      return _AppLockScreen(billing: billing);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(dests[index].title),
        actions: [
          LocaleToggleButton(billing),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(billing.usingSupabase ? 'Supabase' : s.t('Local', 'محلي')),
              ),
            ),
          ),
          TextButton(
            onPressed: () => billing.setSession(null),
            child: Text(s.signOut),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: index,
                  backgroundColor: Colors.white,
                  indicatorColor: const Color(0xFFE3F2FD),
                  selectedIconTheme: const IconThemeData(color: AppTheme.accent),
                  unselectedIconTheme: const IconThemeData(color: Color(0xFF64748B)),
                  selectedLabelTextStyle: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  onDestinationSelected: (value) => setState(() => index = value),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in dests)
                      NavigationRailDestination(icon: Icon(d.icon), label: Text(d.title)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: dests[index].page),
              ],
            )
          : dests[index].page,
      bottomNavigationBar: wide
          ? null
          : NavigationBarTheme(
              data: NavigationBarThemeData(
                height: 68,
                labelTextStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.1),
                ),
              ),
              child: NavigationBar(
                selectedIndex: index,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  for (final d in dests)
                    NavigationDestination(icon: Icon(d.icon), label: d.title),
                ],
                onDestinationSelected: (value) => setState(() => index = value),
              ),
            ),
    );
  }
}

class _AppLockScreen extends StatefulWidget {
  const _AppLockScreen({required this.billing});

  final BillingController billing;

  @override
  State<_AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<_AppLockScreen> {
  final pin = TextEditingController();
  String? error;

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  void _unlock() {
    if (widget.billing.unlockApp(pin.text)) return;
    setState(() => error = widget.billing.s.t('Incorrect PIN.', 'رمز غير صحيح.'));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.billing.s;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                Text(
                  s.t('App locked', 'التطبيق مقفل'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pin,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: s.t('PIN', 'الرمز'),
                    errorText: error,
                  ),
                  onSubmitted: (_) => _unlock(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _unlock,
                  child: Text(s.t('Unlock', 'فتح')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

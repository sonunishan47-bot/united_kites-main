import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../screens/shell.dart';
import '../state/billing_controller.dart';
import '../widgets/company_header.dart';

/// Role login for the POS. Admin, Partner, Van 1, and Van 2 each unlock
/// with their own PIN. A successful sign-in writes [UserSession], and the
/// app router replaces this route with the sales shell.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.read(context);
    return ListenableBuilder(
      listenable: billing,
      builder: (context, _) => _buildGate(context, billing),
    );
  }

  Widget _buildGate(BuildContext context, BillingController billing) {
    final s = billing.s;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          _HeroHeader(
            onToggleLocale: () => billing.setLocale(s.isAr ? 'en' : 'ar'),
            localeLabel: s.isAr ? 'English' : 'العربية',
            tagline: s.t(
              'Wholesale billing & CRM',
              'الفوترة بالجملة وإدارة العملاء',
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
              children: [
                Text(
                  s.t('Sign in to continue', 'تسجيل الدخول للمتابعة'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.t('Choose your workspace', 'اختر مساحة العمل'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 22),
                _RoleCard(
                  title: s.t('Admin', 'المدير'),
                  subtitle: s.t(
                    'Full billing, stock, CRM & settings',
                    'الفوترة والمخزون والعملاء والإعدادات',
                  ),
                  icon: Icons.admin_panel_settings_rounded,
                  accent: const Color(0xFF1E3A5F),
                  tint: const Color(0xFFEFF4FB),
                  onTap: _busy ? null : () => _enterAdmin(billing),
                ),
                const SizedBox(height: 14),
                _RoleCard(
                  title: s.t('Partner', 'الشريك'),
                  subtitle: s.t(
                    'Live read-only sales & profit desk',
                    'لوحة مباشرة للمبيعات والأرباح',
                  ),
                  icon: Icons.handshake_rounded,
                  accent: const Color(0xFF0F766E),
                  tint: const Color(0xFFECFDF8),
                  onTap: _busy ? null : () => _enterPartner(billing),
                ),
                const SizedBox(height: 14),
                _RoleCard(
                  title: s.t('Van 1 (V1)', 'الفان 1'),
                  subtitle: s.t(
                    'Van 1 stock, billing & collections only',
                    'مخزون وفواتير وتحصيل الفان 1 فقط',
                  ),
                  icon: Icons.local_shipping_rounded,
                  accent: const Color(0xFFC2410C),
                  tint: const Color(0xFFFFF4ED),
                  onTap: _busy ? null : () => _enterVan(billing, StockLocation.van1),
                ),
                const SizedBox(height: 14),
                _RoleCard(
                  title: s.t('Van 2 (V2)', 'الفان 2'),
                  subtitle: s.t(
                    'Van 2 stock, billing & collections only',
                    'مخزون وفواتير وتحصيل الفان 2 فقط',
                  ),
                  icon: Icons.airport_shuttle_rounded,
                  accent: const Color(0xFF9A3412),
                  tint: const Color(0xFFFFF7ED),
                  onTap: _busy ? null : () => _enterVan(billing, StockLocation.van2),
                ),
                if (error != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  s.t(
                    'ZATCA-ready billing  ·  CRM  ·  Van sales',
                    'فوترة زاتكا  ·  العملاء  ·  مبيعات الفان',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enterAdmin(BillingController billing) async {
    final pin = await _askPin(
      title: billing.s.t('Admin access', 'دخول المدير'),
      hint: billing.s.t('Enter admin PIN', 'أدخل رمز المدير'),
      continueLabel: billing.s.t('Continue', 'متابعة'),
    );
    if (!mounted) return;
    if (pin == null) return;
    if (!billing.unlockAdmin(pin)) {
      setState(() => error = billing.s.t('Incorrect PIN.', 'الرمز غير صحيح.'));
      return;
    }
    _completeLogin(billing, UserSession.admin);
  }

  Future<void> _enterPartner(BillingController billing) async {
    final pin = await _askPin(
      title: billing.s.t('Partner access', 'دخول الشريك'),
      hint: billing.s.t('Enter partner PIN', 'أدخل رمز الشريك'),
      continueLabel: billing.s.t('Continue', 'متابعة'),
    );
    if (!mounted) return;
    if (pin == null) return;
    if (!billing.unlockPartner(pin)) {
      setState(() => error = billing.s.t('Incorrect PIN.', 'الرمز غير صحيح.'));
      return;
    }
    _completeLogin(billing, UserSession.partner);
  }

  Future<void> _enterVan(BillingController billing, StockLocation van) async {
    final pin = await _askPin(
      title: van == StockLocation.van2
          ? billing.s.t('Van 2 access', 'دخول الفان 2')
          : billing.s.t('Van 1 access', 'دخول الفان 1'),
      hint: billing.s.t('Enter van PIN', 'أدخل رمز الفان'),
      continueLabel: billing.s.t('Continue', 'متابعة'),
    );
    if (!mounted) return;
    if (pin == null) return;
    final unlocked = billing.unlockVan(pin);
    if (unlocked != van) {
      setState(() => error = billing.s.t('Incorrect PIN.', 'الرمز غير صحيح.'));
      return;
    }
    _completeLogin(
      billing,
      van == StockLocation.van2 ? UserSession.salesmanVan2 : UserSession.salesmanVan1,
    );
  }

  /// Close overlays first, then apply session on the next frame so
  /// InheritedNotifier dependents are not deactivated mid-build.
  void _completeLogin(BillingController billing, UserSession session) {
    setState(() {
      _busy = true;
      error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      billing.setSession(session);
    });
  }

  Future<String?> _askPin({
    required String title,
    required String hint,
    required String continueLabel,
  }) async {
    final pin = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pin,
                obscureText: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onSubmitted: (_) => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(continueLabel),
              ),
            ],
          ),
        );
      },
    );
    final value = pin.text.trim();
    // Sheet still owns the TextField during the close animation.
    Future<void>.delayed(const Duration(milliseconds: 400), pin.dispose);
    if (ok != true || value.isEmpty) return null;
    return value;
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.onToggleLocale,
    required this.localeLabel,
    required this.tagline,
  });

  final VoidCallback onToggleLocale;
  final String localeLabel;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 8,
        bottom: 32,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2540), Color(0xFF164E7A), Color(0xFF0F3A5F)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x330A2540),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton(
                onPressed: onToggleLocale,
                child: Text(
                  localeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 112,
            height: 112,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const AppBrandLogo(size: 92, borderRadius: 18),
          ),
          const SizedBox(height: 18),
          const Text(
            'UNITED KITES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 3.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tagline,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EEF5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: accent.withValues(alpha: 0.55)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



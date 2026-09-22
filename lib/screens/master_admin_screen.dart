import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/route_safety.dart';
import '../widgets/vyapar.dart';
import 'shell.dart';

class MasterAdminScreen extends StatefulWidget {
  const MasterAdminScreen({super.key});

  @override
  State<MasterAdminScreen> createState() => _MasterAdminScreenState();
}

class _MasterAdminScreenState extends State<MasterAdminScreen> {
  bool unlocked = false;
  bool reveal = false;
  String? error;
  final masterCtl = TextEditingController();

  @override
  void dispose() {
    masterCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    if (!billing.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(s.t('Master Admin', 'المدير الرئيسي'))),
        body: Center(child: Text(s.t('Admin only.', 'للمدير فقط.'))),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(s.t('Master Admin', 'المدير الرئيسي'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (!unlocked) ...[
            UkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('Enter Master Admin PIN', 'أدخل رمز المدير الرئيسي'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.t(
                      'This vault controls Partner, Van 1, and Van 2 access. Changing a PIN logs that role out immediately.',
                      'هذه الخزنة تتحكم في دخول الشريك والفان 1 والفان 2. تغيير الرمز يلغي الجلسة فوراً.',
                    ),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: masterCtl,
                    obscureText: true,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: s.t('Master PIN', 'الرمز الرئيسي'),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                    onSubmitted: (_) => _unlock(billing),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _unlock(billing),
                      child: Text(s.t('Unlock', 'فتح')),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            UkCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.t('Show PINs', 'إظهار الرموز'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Switch.adaptive(value: reveal, onChanged: (v) => setState(() => reveal = v)),
                ],
              ),
            ),
            _PinVaultCard(
              title: s.t('Partner Access', 'دخول الشريك'),
              subtitle: s.t('Read-only sales desk', 'لوحة مبيعات للقراءة فقط'),
              pin: billing.settings.partnerPin,
              reveal: reveal,
              onGenerate: () => _setPin(billing, partner: billing.nextUniqueAccessPin()),
              onReset: () => _editPin(billing, title: s.t('Partner PIN', 'رمز الشريك'), current: billing.settings.partnerPin, onSave: (v) => _setPin(billing, partner: v)),
            ),
            _PinVaultCard(
              title: s.t('Van 1 (V1) Access', 'دخول الفان 1'),
              subtitle: s.t('Van 1 stock and billing only', 'مخزون وفواتير الفان 1 فقط'),
              pin: billing.settings.van1Pin,
              reveal: reveal,
              onGenerate: () => _setPin(billing, van1: billing.nextUniqueAccessPin()),
              onReset: () => _editPin(billing, title: s.t('Van 1 PIN', 'رمز الفان 1'), current: billing.settings.van1Pin, onSave: (v) => _setPin(billing, van1: v)),
            ),
            _PinVaultCard(
              title: s.t('Van 2 (V2) Access', 'دخول الفان 2'),
              subtitle: s.t('Van 2 stock and billing only', 'مخزون وفواتير الفان 2 فقط'),
              pin: billing.settings.van2Pin,
              reveal: reveal,
              onGenerate: () => _setPin(billing, van2: billing.nextUniqueAccessPin()),
              onReset: () => _editPin(billing, title: s.t('Van 2 PIN', 'رمز الفان 2'), current: billing.settings.van2Pin, onSave: (v) => _setPin(billing, van2: v)),
            ),
            _PinVaultCard(
              title: s.t('Master Admin PIN', 'رمز المدير الرئيسي'),
              subtitle: s.t('Protects this settings vault', 'يحمي هذه الخزنة'),
              pin: billing.settings.masterAdminPin,
              reveal: reveal,
              onGenerate: () => _setPin(billing, master: billing.nextUniqueAccessPin()),
              onReset: () => _editPin(
                billing,
                title: s.t('Master Admin PIN', 'رمز المدير الرئيسي'),
                current: billing.settings.masterAdminPin,
                onSave: (v) => _setPin(billing, master: v),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _unlock(BillingController billing) {
    if (!billing.unlockMasterAdmin(masterCtl.text)) {
      setState(() => error = billing.s.t('Incorrect Master Admin PIN.', 'رمز المدير الرئيسي غير صحيح.'));
      return;
    }
    setState(() {
      unlocked = true;
      error = null;
    });
  }

  Future<void> _setPin(
    BillingController billing, {
    String? partner,
    String? van1,
    String? van2,
    String? master,
  }) async {
    final pins = [
      partner ?? billing.settings.partnerPin,
      van1 ?? billing.settings.van1Pin,
      van2 ?? billing.settings.van2Pin,
    ];
    if (pins.toSet().length != pins.length) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(billing.s.t('Each role needs a unique PIN.', 'كل دور يحتاج رمزاً مختلفاً.'))),
      );
      return;
    }
    await billing.updateAccessPins(
      partnerPin: partner,
      van1Pin: van1,
      van2Pin: van2,
      masterAdminPin: master,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          billing.s.t(
            'PIN updated. Old sessions for that role are locked out.',
            'تم تحديث الرمز. الجلسات القديمة لهذا الدور أُلغيت.',
          ),
        ),
      ),
    );
  }

  Future<void> _editPin(
    BillingController billing, {
    required String title,
    required String current,
    required Future<void> Function(String value) onSave,
  }) async {
    final ctl = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: billing.s.t('6-digit PIN', 'رمز من 6 أرقام')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(billing.s.t('Cancel', 'إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(billing.s.t('Save', 'حفظ'))),
        ],
      ),
    );
    final value = ctl.text.trim();
    await waitForOverlaySettle();
    ctl.dispose();
    if (ok != true || value.length < 4) return;
    if (!mounted) return;
    await onSave(value);
  }
}

class _PinVaultCard extends StatelessWidget {
  const _PinVaultCard({
    required this.title,
    required this.subtitle,
    required this.pin,
    required this.reveal,
    required this.onGenerate,
    required this.onReset,
  });

  final String title;
  final String subtitle;
  final String pin;
  final bool reveal;
  final VoidCallback onGenerate;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return UkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  reveal ? pin : '••••••',
                  style: const TextStyle(fontSize: 22, letterSpacing: 4, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: pin));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN copied')));
                  }
                },
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: const Text('Generate'),
              ),
              FilledButton.tonalIcon(
                onPressed: onReset,
                icon: const Icon(Icons.lock_reset, size: 18),
                label: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

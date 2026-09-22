import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/app_options.dart';
import '../models/shop_settings.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/route_safety.dart';
import '../widgets/cloud_sync_card.dart';
import '../widgets/vyapar.dart';
import 'master_admin_screen.dart';
import 'print_setup_screen.dart';
import 'shell.dart';

class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final admin = billing.canEditAppSettings;

    Widget tile(IconData icon, String title, String subtitle, Widget page, {bool sensitive = false}) {
      if (sensitive && !admin) return const SizedBox.shrink();
      return UkCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFEEF2FF),
              child: Icon(icon, color: AppTheme.navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const CloudSyncCard(),
          if (!admin)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                s.t(
                  'Language and theme only. Financial settings are Admin-only.',
                  'اللغة والمظهر فقط. الإعدادات المالية للمدير.',
                  'ഭാഷയും തീമും മാത്രം. സാമ്പത്തിക ക്രമീകരണങ്ങൾ അഡ്മിന് മാത്രം.',
                ),
              ),
            ),
          tile(Icons.settings_outlined, s.t('General', 'عام', 'ജനറൽ'), s.t('Language, lock, backup, theme', 'لغة، قفل، نسخ، مظهر'), const GeneralSettingsScreen()),
          if (admin) ...[
            tile(Icons.receipt_long_outlined, s.t('Transaction', 'المعاملات', 'ട്രാൻസാക്ഷൻ'), s.t('Numbering, discounts, POS', 'ترقيم، خصم، بيع سريع'), const TransactionSettingsScreen(), sensitive: true),
            tile(Icons.print_outlined, s.t('Invoice Print', 'طباعة الفاتورة', 'പ്രിന്റ്'), s.t('Paper, logo, signature', 'ورق، شعار، توقيع'), const InvoicePrintSettingsScreen(), sensitive: true),
            tile(Icons.percent_outlined, s.t('Taxes & VAT', 'الضرائب', 'നികുതി'), s.t('ZATCA 15% VAT', 'ضريبة زاتكا 15٪'), const TaxSettingsScreen(), sensitive: true),
            tile(Icons.chat_outlined, s.t('Transaction Message', 'رسالة الفاتورة', 'സന്ദേശം'), s.t('WhatsApp template', 'قالب واتساب'), const MessageSettingsScreen(), sensitive: true),
            tile(Icons.notifications_outlined, s.t('Reminders', 'تذكيرات', 'ഓർമ്മപ്പെടുത്തൽ'), s.t('Overdue collection alerts', 'تنبيه الديون'), const ReminderSettingsScreen(), sensitive: true),
            tile(Icons.people_outlined, s.t('Party', 'العملاء', 'കസ്റ്റമർ'), s.t('Credit limit & outstanding', 'حد ائتمان والمديونية'), const PartySettingsScreen(), sensitive: true),
            tile(Icons.inventory_2_outlined, s.t('Item / Stock', 'الأصناف', 'സ്റ്റോക്ക്'), s.t('Categories, barcode, pricing', 'فئات، باركود، أسعار'), const ItemSettingsScreen(), sensitive: true),
            tile(Icons.currency_exchange, s.t('Multi-Currency', 'عملات', 'കറൻസി'), s.t('Base SAR and rates', 'الريال وأسعار الصرف'), const CurrencySettingsScreen(), sensitive: true),
            tile(Icons.tune, s.t('Printer hardware', 'الطابعة', 'പ്രിന്റർ'), s.t('Bluetooth pairing', 'بلوتوث'), const PrintSetupScreen(), sensitive: true),
            tile(
              Icons.shield_outlined,
              s.t('Master Admin', 'المدير الرئيسي', 'മാസ്റ്റർ അഡ്മിൻ'),
              s.t('Access PINs for Partner, Van 1 & Van 2', 'رموز الشريك والفان 1 و 2', 'പാർട്ണർ, വാൻ 1, വാൻ 2 പിന്നുകൾ'),
              const MasterAdminScreen(),
              sensitive: true,
            ),
            const SizedBox(height: 8),
            const _DangerZoneCard(),
          ],
        ],
      ),
    );
  }
}

class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard();

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    return UkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('Danger Zone / Reset Options', 'منطقة الخطر / خيارات إعادة التعيين'),
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB91C1C)),
          ),
          const SizedBox(height: 8),
          Text(
            s.t(
              'Permanently clear all transactions, invoices, customer ledgers, sales returns, and reset van stocks.',
              'يمسح نهائياً كل المعاملات والفواتير وكشوف العملاء والمرتجعات ويعيد مخزون الفان.',
            ),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
              ),
              onPressed: () => _confirmFactoryReset(context),
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(
                s.t('Reset All Data', 'مسح كل البيانات'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmFactoryReset(BuildContext context) async {
  final billing = AppScope.of(context);
  final s = billing.s;
  final pin = TextEditingController();
  var error = '';
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setLocal) {
          return AlertDialog(
            title: Text(s.t('Confirm factory reset', 'تأكيد إعادة التعيين')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    'This cannot be undone. Enter the Admin PIN to continue.',
                    'لا يمكن التراجع. أدخل رمز المدير للمتابعة.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pin,
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: s.t('Admin PIN / Password', 'رمز / كلمة مرور المدير'),
                    errorText: error.isEmpty ? null : error,
                  ),
                  onSubmitted: (_) {},
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => popAfterFrame(dialogContext, false),
                child: Text(s.t('Cancel', 'إلغاء')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
                onPressed: () {
                  final p = pin.text.trim();
                  if (!billing.unlockAdmin(p) && !billing.unlockMasterAdmin(p)) {
                    setLocal(() => error = s.t('Incorrect Admin PIN.', 'رمز المدير غير صحيح.'));
                    return;
                  }
                  popAfterFrame(dialogContext, true);
                },
                child: Text(s.t('Reset All Data', 'مسح كل البيانات')),
              ),
            ],
          );
        },
      );
    },
  );
  final entered = pin.text;
  pin.dispose();
  await waitForOverlaySettle();
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  final shell = context.findAncestorStateOfType<BillingShellState>();
  try {
    await billing.factoryResetTransactions(pin: entered);
  } on RbacException catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  if (!context.mounted) return;
  nav.popUntil((route) => route.isFirst);
  shell?.goToDashboard();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        s.t(
          'System reset successful! All transactions cleared.',
          'تمت إعادة التعيين بنجاح! تم مسح كل المعاملات.',
        ),
      ),
    ),
  );
}


class _SettingsBody extends StatelessWidget {
  const _SettingsBody({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: children,
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }
}

Future<void> _patch(BuildContext context, AppOptions Function(AppOptions o) fn) {
  return AppScope.of(context).patchOptions(fn);
}

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final o = billing.settings.options;
    final admin = billing.canEditAppSettings;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('General Settings', 'إعدادات عامة', 'ജനറൽ'))),
      body: _SettingsBody(
        children: [
          const CloudSyncCard(),
          UkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('App language', 'لغة التطبيق', 'ഭാഷ'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final code in ['en', 'ar', 'ml'])
                      ChoiceChip(
                        label: Text(code == 'en' ? 'English' : code == 'ar' ? 'العربية' : 'മലയാളം'),
                        selected: billing.localeCode == code,
                        onSelected: (_) => billing.setLocale(code),
                      ),
                  ],
                ),
              ],
            ),
          ),
          UkCard(
            child: _Toggle(
              title: s.t('Dark theme', 'المظهر الداكن', 'ഡാർക്ക് തീം'),
              value: o.darkTheme,
              onChanged: (v) => _patch(context, (c) => c.copyWith(darkTheme: v)),
            ),
          ),
          UkCard(
            child: Column(
              children: [
                _Toggle(
                  title: s.t('Security lock (passcode)', 'قفل برمز', 'പാസ്കോഡ് ലോക്ക്'),
                  value: o.lockEnabled,
                  onChanged: admin ? (v) => _patch(context, (c) => c.copyWith(lockEnabled: v)) : null,
                ),
                _Toggle(
                  title: s.t('Biometric / fingerprint', 'بصمة', 'ഫിംഗർപ്രിന്റ്'),
                  subtitle: s.t('Uses device biometrics when available.', 'يستخدم بصمة الجهاز إن توفرت.', 'ലഭ്യമെങ്കിൽ ഡിവൈസ് ബയോമെട്രിക്സ്.'),
                  value: o.biometricEnabled,
                  onChanged: admin
                      ? (v) {
                          _patch(context, (c) => c.copyWith(biometricEnabled: v));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                s.t(
                                  'Biometrics apply on supported phones. Desktop uses passcode.',
                                  'البصمة على الجوال. سطح المكتب يستخدم الرمز.',
                                  'ഫോണിൽ ബയോമെട്രിക്സ്. ഡെസ്ക്ടോപ്പ് പാസ്കോഡ്.',
                                ),
                              ),
                            ),
                          );
                        }
                      : null,
                ),
                TextField(
                  enabled: admin,
                  obscureText: true,
                  decoration: InputDecoration(labelText: s.t('Lock PIN (blank = admin PIN)', 'رمز القفل')),
                  controller: TextEditingController(text: o.lockPin),
                  onSubmitted: admin ? (v) => _patch(context, (c) => c.copyWith(lockPin: v.trim())) : null,
                ),
              ],
            ),
          ),
          UkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('Auto backup & cloud sync', 'نسخ احتياطي سحابي'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: o.backupTarget,
                  decoration: InputDecoration(labelText: s.t('Backup target', 'وجهة النسخ')),
                  items: [
                    DropdownMenuItem(value: 'local', child: Text(s.t('Local device', 'الجهاز'))),
                    DropdownMenuItem(value: 'cloud', child: Text(s.t('Cloud / Google Drive', 'السحابة / درايف'))),
                  ],
                  onChanged: admin ? (v) => _patch(context, (c) => c.copyWith(backupTarget: v ?? 'local')) : null,
                ),
                if (o.lastBackupAt.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(s.t('Last backup: ${o.lastBackupAt}', 'آخر نسخة: ${o.lastBackupAt}')),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: admin
                      ? () async {
                          await billing.backupNow();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(s.t('Backup saved to local store / cloud cache.', 'تم حفظ النسخة محلياً / على السحابة.'))),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.backup_outlined),
                  label: Text(s.t('Backup Now', 'نسخ الآن', 'ബാക്കപ്പ്')),
                ),
              ],
            ),
          ),
          UkCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.t('Financial year start', 'بداية السنة المالية')),
              subtitle: Text(o.financialYearStart.isEmpty ? billing.settings.booksBeginning : o.financialYearStart),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: !admin
                  ? null
                  : () async {
                      final initial = DateTime.tryParse(o.financialYearStart) ?? DateTime(2026, 1, 1);
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(2015),
                        lastDate: DateTime(2040),
                      );
                      if (picked == null || !context.mounted) return;
                      final iso = DateFormat('yyyy-MM-dd').format(picked);
                      await billing.saveSettings(
                        billing.settings.copyWith(
                          booksBeginning: iso,
                          options: o.copyWith(financialYearStart: iso),
                        ),
                      );
                    },
            ),
          ),
          if (admin) const _DangerZoneCard(),
        ],
      ),
    );
  }
}

class TransactionSettingsScreen extends StatelessWidget {
  const TransactionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final o = billing.settings.options;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Transaction Settings', 'إعدادات المعاملات'))),
      body: _SettingsBody(
        children: [
          UkCard(
            child: Column(
              children: [
                _Toggle(
                  title: s.t('Auto invoice numbering', 'ترقيم تلقائي'),
                  subtitle: s.t('Prefix + year + sequence (INV-2026-0001)', 'بادئة + سنة + تسلسل'),
                  value: o.autoInvoiceNo,
                  onChanged: (v) => _patch(context, (c) => c.copyWith(autoInvoiceNo: v)),
                ),
                TextField(
                  decoration: InputDecoration(labelText: s.t('Invoice prefix', 'بادئة الفاتورة'), hintText: 'INV'),
                  controller: TextEditingController(text: o.invoicePrefix),
                  onSubmitted: (v) => _patch(context, (c) => c.copyWith(invoicePrefix: v.trim().isEmpty ? 'INV' : v.trim())),
                ),
              ],
            ),
          ),
          UkCard(
            child: Column(
              children: [
                _Toggle(title: s.t('Add time to transaction', 'إظهار الوقت على الفاتورة'), value: o.printTime, onChanged: (v) => _patch(context, (c) => c.copyWith(printTime: v))),
                _Toggle(title: s.t('Round-off total to nearest riyal', 'تقريب الإجمالي لريال صحيح'), value: o.roundOff, onChanged: (v) => _patch(context, (c) => c.copyWith(roundOff: v))),
                _Toggle(title: s.t('Item-wise discount', 'خصم على الصنف'), value: o.itemDiscount, onChanged: (v) => _patch(context, (c) => c.copyWith(itemDiscount: v))),
                _Toggle(title: s.t('Overall bill discount', 'خصم على الفاتورة'), value: o.billDiscount, onChanged: (v) => _patch(context, (c) => c.copyWith(billDiscount: v))),
                _Toggle(title: s.t('Delivery / shipping / packaging charges', 'رسوم توصيل / تغليف'), value: o.deliveryCharges, onChanged: (v) => _patch(context, (c) => c.copyWith(deliveryCharges: v))),
                _Toggle(title: s.t('PoS / quick billing (barcode)', 'بيع سريع / باركود'), value: o.posMode, onChanged: (v) => _patch(context, (c) => c.copyWith(posMode: v))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InvoicePrintSettingsScreen extends StatelessWidget {
  const InvoicePrintSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final o = billing.settings.options;
    final paper = billing.settings.paper;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Invoice Print Settings', 'إعدادات طباعة الفاتورة'))),
      body: _SettingsBody(
        children: [
          UkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('Printer / layout', 'الطابعة / التخطيط'), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in PaperProfile.values)
                      ChoiceChip(
                        label: Text(p == PaperProfile.a4 ? 'A4 PDF' : p == PaperProfile.thermal58 ? '58mm Bluetooth' : '80mm Bluetooth'),
                        selected: paper == p,
                        onSelected: (_) => billing.saveSettings(billing.settings.copyWith(paper: p)),
                      ),
                  ],
                ),
                _Toggle(
                  title: s.t('Auto-print invoice on save', 'طباعة تلقائية بعد الحفظ'),
                  value: billing.settings.autoPrint,
                  onChanged: (v) => billing.saveSettings(billing.settings.copyWith(autoPrint: v)),
                ),
              ],
            ),
          ),
          UkCard(
            child: Column(
              children: [
                _Toggle(title: s.t('Show company logo', 'إظهار الشعار'), value: o.showLogo, onChanged: (v) => _patch(context, (c) => c.copyWith(showLogo: v))),
                _Toggle(title: s.t('Show TRN & CR on header', 'إظهار الرقم الضريبي والسجل'), value: o.showTrnCr, onChanged: (v) => _patch(context, (c) => c.copyWith(showTrnCr: v))),
                _Toggle(title: s.t('Show footer note', 'إظهار التذييل'), value: o.showFooter, onChanged: (v) => _patch(context, (c) => c.copyWith(showFooter: v))),
                _Toggle(title: s.t('Show terms & conditions', 'إظهار الشروط'), value: o.showTerms, onChanged: (v) => _patch(context, (c) => c.copyWith(showTerms: v))),
                _Toggle(title: s.t('Show bank details', 'إظهار بيانات البنك'), value: o.showBank, onChanged: (v) => _patch(context, (c) => c.copyWith(showBank: v))),
                _Toggle(title: s.t('Show authorized signature', 'إظهار التوقيع'), value: o.showSignature, onChanged: (v) => _patch(context, (c) => c.copyWith(showSignature: v))),
                TextField(
                  maxLines: 2,
                  decoration: InputDecoration(labelText: s.t('Terms & conditions', 'الشروط')),
                  controller: TextEditingController(text: o.termsText),
                  onSubmitted: (v) => _patch(context, (c) => c.copyWith(termsText: v)),
                ),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 2,
                  decoration: InputDecoration(labelText: s.t('Bank details', 'بيانات البنك')),
                  controller: TextEditingController(text: o.bankDetails),
                  onSubmitted: (v) => _patch(context, (c) => c.copyWith(bankDetails: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TaxSettingsScreen extends StatelessWidget {
  const TaxSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final o = billing.settings.options;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Taxes & VAT', 'الضرائب وضريبة القيمة'))),
      body: _SettingsBody(
        children: [
          UkCard(
            child: Column(
              children: [
                _Toggle(title: s.t('Enable VAT', 'تفعيل الضريبة'), value: o.vatEnabled, onChanged: (v) => _patch(context, (c) => c.copyWith(vatEnabled: v))),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.t('Default VAT rate % (ZATCA 15)', 'نسبة الضريبة٪')),
                  controller: TextEditingController(text: o.vatPercent.toStringAsFixed(0)),
                  onSubmitted: (v) => _patch(context, (c) => c.copyWith(vatPercent: double.tryParse(v) ?? 15)),
                ),
                _Toggle(
                  title: s.t('Price inclusive of tax', 'السعر شامل الضريبة'),
                  subtitle: s.t('Off = exclusive (qty × price, then 15% VAT)', 'إيقاف = غير شامل ثم 15٪'),
                  value: o.priceInclusive,
                  onChanged: (v) => _patch(context, (c) => c.copyWith(priceInclusive: v)),
                ),
                _Toggle(title: s.t('Display TRN / VAT & CR on invoice', 'عرض الرقم الضريبي والسجل'), value: o.showTrnCr, onChanged: (v) => _patch(context, (c) => c.copyWith(showTrnCr: v))),
                TextField(
                  decoration: InputDecoration(labelText: s.t('Tax / TRN number', 'الرقم الضريبي')),
                  controller: TextEditingController(text: billing.settings.vatTrn),
                  onSubmitted: (v) => billing.saveSettings(billing.settings.copyWith(vatTrn: v.trim())),
                ),
                TextField(
                  decoration: InputDecoration(labelText: s.t('Commercial Registration (CR)', 'السجل التجاري')),
                  controller: TextEditingController(text: billing.settings.crNumber),
                  onSubmitted: (v) => billing.saveSettings(billing.settings.copyWith(crNumber: v.trim())),
                ),
                TextField(
                  decoration: InputDecoration(labelText: s.t('IBAN / bank transfer', 'آيبان / تحويل بنكي')),
                  controller: TextEditingController(text: billing.settings.iban),
                  onSubmitted: (v) => billing.saveSettings(billing.settings.copyWith(iban: v.trim())),
                ),
                TextField(
                  maxLines: 2,
                  decoration: InputDecoration(labelText: s.t('Bank details (printed on invoices)', 'بيانات البنك على الفاتورة')),
                  controller: TextEditingController(text: o.bankDetails),
                  onSubmitted: (v) => _patch(context, (c) => c.copyWith(bankDetails: v, showBank: true)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageSettingsScreen extends StatelessWidget {
  const MessageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final o = billing.settings.options;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Transaction Message', 'رسالة المعاملة'))),
      body: _SettingsBody(
        children: [
          UkCard(
            child: Column(
              children: [
                _Toggle(title: s.t('Auto WhatsApp / SMS on invoice', 'واتساب تلقائي بعد الفاتورة'), value: o.autoWhatsApp, onChanged: (v) => _patch(context, (c) => c.copyWith(autoWhatsApp: v))),
                TextField(
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: s.t('WhatsApp template', 'قالب واتساب'),
                    helperText: '{Customer_Name} {Bill_Amount} {Invoice_No}',
                  ),
                  controller: TextEditingController(text: o.whatsappTemplate),
                  onSubmitted: (v) => _patch(context, (c) => c.copyWith(whatsappTemplate: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReminderSettingsScreen extends StatelessWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final o = billing.settings.options;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Reminders', 'التذكيرات'))),
      body: _SettingsBody(
        children: [
          UkCard(
            child: Column(
              children: [
                _Toggle(title: s.t('Payment collection alerts', 'تنبيه تحصيل الديون'), value: o.paymentReminders, onChanged: (v) => _patch(context, (c) => c.copyWith(paymentReminders: v))),
                Text(s.t('Alert after overdue days', 'التنبيه بعد أيام التأخير')),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final d in [7, 15, 30])
                      ChoiceChip(
                        label: Text('$d'),
                        selected: o.reminderDays == d,
                        onSelected: (_) => _patch(context, (c) => c.copyWith(reminderDays: d)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PartySettingsScreen extends StatelessWidget {
  const PartySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final o = billing.settings.options;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Party Settings', 'إعدادات العملاء'))),
      body: _SettingsBody(
        children: [
          UkCard(
            child: Column(
              children: [
                _Toggle(
                  title: s.t('Enforce customer credit limit', 'تطبيق حد الائتمان'),
                  subtitle: s.t('Block billing when the limit is exceeded', 'منع الفاتورة عند التجاوز'),
                  value: o.enforceCreditLimit,
                  onChanged: (v) => _patch(context, (c) => c.copyWith(enforceCreditLimit: v)),
                ),
                _Toggle(
                  title: s.t('Show outstanding balance while billing', 'إظهار المديونية أثناء الفاتورة'),
                  value: o.showOutstandingOnBill,
                  onChanged: (v) => _patch(context, (c) => c.copyWith(showOutstandingOnBill: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ItemSettingsScreen extends StatelessWidget {
  const ItemSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final o = billing.settings.options;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Item / Stock Settings', 'إعدادات الأصناف'))),
      body: _SettingsBody(
        children: [
          UkCard(
            child: Column(
              children: [
                _Toggle(title: s.t('Item categories & sub-categories', 'فئات الأصناف'), value: o.itemCategories, onChanged: (v) => _patch(context, (c) => c.copyWith(itemCategories: v))),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.t('Low stock alert threshold', 'حد تنبيه المخزون')),
                  controller: TextEditingController(text: o.lowStockThreshold.toStringAsFixed(0)),
                  onSubmitted: (v) => _patch(context, (c) => c.copyWith(lowStockThreshold: double.tryParse(v) ?? 5)),
                ),
                _Toggle(title: s.t('Batch number & expiry tracking', 'رقم التشغيلة والصلاحية'), value: o.batchExpiry, onChanged: (v) => _patch(context, (c) => c.copyWith(batchExpiry: v))),
                _Toggle(title: s.t('Barcode generator & scanner', 'باركود'), value: o.barcodeEnabled, onChanged: (v) => _patch(context, (c) => c.copyWith(barcodeEnabled: v))),
                _Toggle(
                  title: s.t('Wholesale vs retail price fields', 'سعر الجملة والتجزئة'),
                  subtitle: s.t('Carton rate = wholesale, piece = retail', 'سعر الكرتون جملة والقطعة تجزئة'),
                  value: o.multiPricing,
                  onChanged: (v) => _patch(context, (c) => c.copyWith(multiPricing: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CurrencySettingsScreen extends StatelessWidget {
  const CurrencySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final o = billing.settings.options;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('Multi-Currency', 'العملات'))),
      body: _SettingsBody(
        children: [
          UkCard(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: o.baseCurrency,
                  decoration: InputDecoration(labelText: s.t('Base currency', 'العملة الأساسية')),
                  items: const [
                    DropdownMenuItem(value: 'SAR', child: Text('SAR — Saudi Riyal')),
                    DropdownMenuItem(value: 'AED', child: Text('AED')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    DropdownMenuItem(value: 'INR', child: Text('INR')),
                  ],
                  onChanged: (v) => _patch(context, (c) => c.copyWith(baseCurrency: v ?? 'SAR')),
                ),
                _Toggle(title: s.t('Multi-currency mode', 'وضع متعدد العملات'), value: o.multiCurrency, onChanged: (v) => _patch(context, (c) => c.copyWith(multiCurrency: v))),
                if (o.multiCurrency) ...[
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(labelText: s.t('Quote currency', 'عملة التسعير')),
                    controller: TextEditingController(text: o.quoteCurrency),
                    onSubmitted: (v) => _patch(context, (c) => c.copyWith(quoteCurrency: v.trim().isEmpty ? 'USD' : v.trim())),
                  ),
                  TextField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: s.t('Exchange rate (1 quote = x base)', 'سعر الصرف')),
                    controller: TextEditingController(text: o.exchangeRate.toString()),
                    onSubmitted: (v) => _patch(context, (c) => c.copyWith(exchangeRate: double.tryParse(v) ?? 1)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

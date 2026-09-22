import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/enums.dart';
import '../models/invoice.dart';
import '../models/shop_settings.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/vyapar.dart';
import 'shell.dart';

class PrintSetupScreen extends StatefulWidget {
  const PrintSetupScreen({super.key});

  @override
  State<PrintSetupScreen> createState() => _PrintSetupScreenState();
}

class _PrintSetupScreenState extends State<PrintSetupScreen> {
  late final TextEditingController shopName;
  late final TextEditingController address;
  late final TextEditingController phone;
  late final TextEditingController trn;
  late final TextEditingController cr;
  late final TextEditingController footer;
  late final TextEditingController commission;
  late final TextEditingController partnerShare;
  late final TextEditingController email;
  late final TextEditingController printerName;
  late final TextEditingController printerMac;
  late PaperProfile paper;
  bool autoPrint = false;
  bool loaded = false;
  bool testing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loaded) return;
    final settings = AppScope.of(context).settings;
    shopName = TextEditingController(text: settings.shopName);
    address = TextEditingController(text: settings.streetLine);
    phone = TextEditingController(text: settings.phone);
    email = TextEditingController(text: settings.email);
    trn = TextEditingController(text: settings.vatTrn);
    cr = TextEditingController(text: settings.crNumber);
    footer = TextEditingController(text: settings.footerNote);
    commission = TextEditingController(text: settings.commissionRate.toString());
    partnerShare = TextEditingController(text: settings.partnerSharePct.toString());
    printerName = TextEditingController(text: settings.printerName);
    printerMac = TextEditingController(text: settings.printerMac);
    paper = settings.paper;
    autoPrint = settings.autoPrint;
    loaded = true;
  }

  @override
  void dispose() {
    shopName.dispose();
    address.dispose();
    phone.dispose();
    email.dispose();
    trn.dispose();
    cr.dispose();
    footer.dispose();
    commission.dispose();
    partnerShare.dispose();
    printerName.dispose();
    printerMac.dispose();
    super.dispose();
  }

  ShopSettings get current {
    final base = AppScope.of(context).settings;
    return base.copyWith(
      shopName: shopName.text.trim().isEmpty ? base.shopName : shopName.text.trim(),
      address: address.text.trim(),
      phone: phone.text.trim(),
      email: email.text.trim(),
      vatTrn: trn.text.trim(),
      crNumber: cr.text.trim(),
      footerNote: footer.text.trim(),
      paper: paper,
      commissionRate: double.tryParse(commission.text) ?? 2,
      partnerSharePct: double.tryParse(partnerShare.text) ?? 50,
      printerName: printerName.text.trim(),
      printerMac: printerMac.text.trim(),
      autoPrint: autoPrint,
    );
  }

  Invoice _sample({required bool a4}) {
    return Invoice(
      id: a4 ? 'sample-a4' : 'sample',
      invoiceNo: 'INV-TEST-0001',
      docType: DocType.taxInvoice,
      customerName: a4 ? 'Sample customer' : 'Walk-in',
      customerPhone: a4 ? '0500000000' : '',
      customerTrn: a4 ? '310000000000003' : '',
      notes: '',
      discount: 0,
      status: 'paid',
      location: StockLocation.van1,
      sellerName: current.zatcaSellerName,
      vatTrn: current.vatTrn,
      crNumber: current.crNumber,
      shopName: a4 ? 'Sample customer' : '',
      amountPaid: 86.25,
      zatcaQr: ZatcaQr.encode(
        sellerName: current.zatcaSellerName,
        vatNumber: current.vatTrn,
        timestamp: DateTime.now(),
        totalWithVat: 86.25,
        vatAmount: 11.25,
      ),
      lines: [
        InvoiceLine(
          id: '1',
          itemName: 'Sample item',
          sku: 'SKU-1',
          quantity: 1,
          unitPrice: 75,
        ),
      ],
    );
  }

  Future<void> _save() async {
    await AppScope.of(context).saveSettings(current);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppScope.of(context).s.t('Printer settings saved.', 'تم حفظ إعدادات الطابعة.'))),
    );
  }

  Future<void> _testPrint() async {
    setState(() => testing = true);
    try {
      await AppScope.of(context).saveSettings(current);
      final sample = _sample(a4: paper == PaperProfile.a4);
      if (paper.isThermal) {
        await const PdfService().printThermal(sample, current);
      } else {
        await const PdfService().preview(sample, current);
      }
      if (!mounted) return;
      final target = printerName.text.trim().isEmpty
          ? (paper.isThermal ? 'Bluetooth / system printer' : 'A4 PDF printer')
          : printerName.text.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test print sent · $target')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    } finally {
      if (mounted) setState(() => testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final s = AppScope.of(context).s;
    const infoBlue = Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(s.print)),
      body: Material(
        color: AppTheme.canvas,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: infoBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.print_outlined, size: 20, color: Color(0xFF1565C0)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.t(
                        'Pair the thermal printer in Bluetooth settings, then tap Test Print. Receipts include ZATCA QR, TRN, CR, and 15% VAT.',
                        'اربط الطابعة الحرارية بالبلوتوث ثم اضغط اختبار الطباعة. الإيصال يتضمن رمز زاتكا والضريبة 15%.',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.t('Output format', 'صيغة الإخراج'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FormatChip(
                  selected: paper == PaperProfile.thermal58,
                  icon: Icons.receipt_outlined,
                  label: s.t('58mm Bluetooth', 'بلوتوث 58مم'),
                  onTap: () => setState(() => paper = PaperProfile.thermal58),
                ),
                _FormatChip(
                  selected: paper == PaperProfile.thermal80,
                  icon: Icons.receipt_long_outlined,
                  label: s.t('80mm Bluetooth', 'بلوتوث 80مم'),
                  onTap: () => setState(() => paper = PaperProfile.thermal80),
                ),
                _FormatChip(
                  selected: paper == PaperProfile.a4,
                  icon: Icons.description_outlined,
                  label: s.t('A4 PDF', 'PDF A4'),
                  onTap: () => setState(() => paper = PaperProfile.a4),
                ),
              ],
            ),
            UkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('Printer settings', 'إعدادات الطابعة'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: printerName,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: s.t('Saved Bluetooth printer name', 'اسم طابعة البلوتوث'),
                      prefixIcon: const Icon(Icons.print_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: printerMac,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f:.\-]')),
                    ],
                    decoration: InputDecoration(
                      labelText: s.t('MAC address', 'عنوان MAC'),
                      hintText: 'AA:BB:CC:DD:EE:FF',
                      prefixIcon: const Icon(Icons.bluetooth),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s.t('Paper size', 'حجم الورق'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final option in PaperProfile.values) ...[
                        if (option != PaperProfile.values.first) const SizedBox(width: 8),
                        Expanded(
                          child: _FormatChip(
                            selected: paper == option,
                            icon: option == PaperProfile.a4
                                ? Icons.description_outlined
                                : Icons.receipt_outlined,
                            label: option.label,
                            onTap: () => setState(() => paper = option),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: autoPrint,
                    onChanged: (value) => setState(() => autoPrint = value),
                    title: Text(
                      s.t('Auto-print invoice', 'طباعة الفاتورة تلقائياً'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    subtitle: Text(
                      s.t(
                        'Send to the thermal printer right after posting a sale.',
                        'إرسال للطباعة الحرارية فور اعتماد البيع.',
                      ),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: testing ? null : _testPrint,
                      icon: testing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bluetooth_searching),
                      label: Text(
                        s.t('Test Print', 'اختبار الطباعة'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            UkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('Seller profile (ZATCA)', 'بيانات البائع (زاتكا)'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: shopName, decoration: InputDecoration(labelText: s.t('Seller name', 'اسم البائع'))),
                  const SizedBox(height: 10),
                  TextField(
                    controller: address,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: s.t('Address', 'العنوان')),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: phone, decoration: InputDecoration(labelText: s.t('Phone', 'الهاتف'))),
                  const SizedBox(height: 10),
                  TextField(controller: email, decoration: InputDecoration(labelText: s.t('Email', 'البريد'))),
                  const SizedBox(height: 10),
                  TextField(controller: trn, decoration: InputDecoration(labelText: s.t('VAT TRN', 'الرقم الضريبي'))),
                  const SizedBox(height: 10),
                  TextField(controller: cr, decoration: InputDecoration(labelText: s.t('CR number', 'السجل التجاري'))),
                  const SizedBox(height: 10),
                  TextField(controller: footer, decoration: InputDecoration(labelText: s.t('Footer', 'التذييل'))),
                  const SizedBox(height: 10),
                  Text(
                    s.t(
                      'Access PINs are managed in Master Admin settings.',
                      'رموز الدخول تُدار من إعدادات المدير الرئيسي.',
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: commission,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: s.t('Salesman commission %', 'عمولة المندوب %')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: partnerShare,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: s.t('Partner profit share %', 'نسبة ربح الشريك %'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(s.t('Save settings', 'حفظ الإعدادات'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await AppScope.of(context).saveSettings(current);
                        await const PdfService().shareA4(_sample(a4: true), current);
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(s.t('Preview A4 Tax Invoice', 'معاينة فاتورة A4')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF1E3A5F) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? const Color(0xFF1E3A5F) : const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : AppTheme.navy),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

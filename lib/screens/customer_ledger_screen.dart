import 'package:flutter/material.dart';

import '../models/crm.dart';
import '../models/invoice.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_share.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/collect_payment_sheet.dart';
import '../widgets/common.dart';
import '../widgets/vyapar.dart';
import 'invoice_editor_screen.dart';
import 'shell.dart';

class CustomerLedgerScreen extends StatelessWidget {
  const CustomerLedgerScreen({super.key, this.customerId});

  final String? customerId;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final customer = billing.customerById(customerId);

    if (customer == null) {
      return Scaffold(
        backgroundColor: AppTheme.canvas,
        appBar: AppBar(title: Text(s.t('Customer Ledger', 'كشف حساب العميل'))),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              s.t(
                'Open a customer statement: invoices, items, billed amount, payments, and running balance.',
                'افتح كشف العميل: الفواتير والأصناف والمبلغ والمقبوض والرصيد.',
              ),
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            if (billing.customers.isEmpty)
              EmptyHint(
                icon: Icons.menu_book_outlined,
                message: s.t('Add a customer first.', 'أضف عميلاً أولاً.'),
              )
            else
              for (final c in billing.customers)
                UkCard(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CustomerLedgerScreen(customerId: c.id),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.display, style: const TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                              '${s.t("You'll Get", 'ستحصل')} ${sar.format(billing.customerDue(c.id))}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
          ],
        ),
      );
    }

    final rows = billing.customerLedger(customer.id);
    final billed = billing.customerBilled(customer.id);
    final paid = billing.customerPaid(customer.id);
    final balance = billing.customerBalance(customer.id);
    final due = balance > 0 ? balance : 0.0;
    final youPay = balance < -0.05;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(s.t('Customer Ledger', 'كشف حساب العميل')),
        actions: [
          if (!billing.isPartner && due > 0.05)
            IconButton(
              tooltip: s.t('Collect Payment', 'تحصيل دفعة'),
              onPressed: () => CollectPaymentSheet.open(context, billing: billing, customer: customer),
              icon: const Icon(Icons.payments_outlined),
            ),
          IconButton(
            tooltip: s.t('Download PDF', 'تحميل PDF'),
            onPressed: () => const PdfService().shareCustomerLedger(
              customer: customer,
              rows: rows,
              billed: billed,
              paid: paid,
              due: due,
              settings: billing.settings,
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
            tooltip: s.t('Share via WhatsApp', 'مشاركة واتساب'),
            onPressed: () => const WhatsAppShare().customerLedger(
              customer: customer,
              due: due,
              arabic: s.isAr,
              rows: rows,
              billed: billed,
              paid: paid,
              settings: billing.settings,
            ),
            icon: const Icon(Icons.chat),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(customer.display, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (customer.phone.isNotEmpty)
            Text(customer.phone, style: const TextStyle(color: Color(0xFF64748B))),
          if (customer.vatNumber.isNotEmpty || customer.crNumber.isNotEmpty)
            Text(
              [
                if (customer.vatNumber.isNotEmpty) 'VAT ${customer.vatNumber}',
                if (customer.crNumber.isNotEmpty) 'CR ${customer.crNumber}',
              ].join(' · '),
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          if (customer.address.isNotEmpty || customer.hasGps)
            Text(
              customer.address.isNotEmpty
                  ? customer.address
                  : '${customer.lat.toStringAsFixed(5)}, ${customer.lng.toStringAsFixed(5)}',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: s.t('Billed', 'المفوتر'),
                  value: sar.format(billed),
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: s.t('Received', 'المقبوض'),
                  value: sar.format(paid),
                  icon: Icons.payments_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatCard(
            label: youPay ? s.t("You'll Pay", 'ستدفع') : s.t("You'll Get", 'ستحصل'),
            value: sar.format(youPay ? -balance : due),
            icon: Icons.account_balance_wallet_outlined,
            tint: youPay || due <= 0.05 ? const Color(0xFF15803D) : AppTheme.fabRed,
          ),
          if (!billing.isPartner && due > 0.05) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => CollectPaymentSheet.open(context, billing: billing, customer: customer),
              icon: const Icon(Icons.payments_outlined),
              label: Text(s.t('Collect Payment', 'تحصيل دفعة')),
            ),
          ],
          SectionHeader(s.t('Transaction statement', 'كشف العمليات')),
          if (rows.isEmpty)
            EmptyHint(
              icon: Icons.receipt_long_outlined,
              message: s.t('No invoices or payments yet.', 'لا توجد فواتير أو دفعات بعد.'),
            )
          else
            for (final row in rows)
              _LedgerTile(entry: row, customer: customer),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry, required this.customer});

  final CustomerLedgerEntry entry;
  final Customer customer;

  Future<void> _open(BuildContext context) async {
    final billing = AppScope.of(context);
    final s = billing.s;
    if (entry.kind == 'payment' && entry.paymentId.isNotEmpty) {
      LedgerPayment? payment;
      for (final row in billing.payments) {
        if (row.id == entry.paymentId) payment = row;
      }
      if (payment == null) return;
      final after = entry.balance > 0 ? entry.balance : 0.0;
      await CollectPaymentSheet.showReceipt(
        context,
        billing: billing,
        customer: customer,
        payment: payment,
        remainingDue: after,
      );
      return;
    }
    if (entry.invoiceId.isEmpty) return;
    Invoice? invoice;
    for (final row in billing.invoices) {
      if (row.id == entry.invoiceId) invoice = row;
    }
    if (invoice == null || !context.mounted) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('Original bill is not on this device.', 'الفاتورة الأصلية غير موجودة على هذا الجهاز.'))),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceEditorScreen(
          controller: billing,
          existing: invoice,
          viewOnly: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    final movement = entry.kind == 'payment' ? -entry.received : entry.billed;
    return UkCard(
      onTap: () => _open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.invoiceNo,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              StatusBadge(
                label: switch (entry.kind) {
                  'payment' => s.t('PAYMENT', 'دفعة'),
                  'credit' => s.t('RETURN', 'مرتجع'),
                  _ => s.t('SOLD / DELIVERED', 'مباع / مُسلّم'),
                },
                tone: switch (entry.kind) {
                  'payment' => BadgeTone.paid,
                  'credit' => BadgeTone.credit,
                  _ => BadgeTone.sale,
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            entry.kind == 'payment'
                ? '${dayTime.format(entry.date)} · ${s.t('Payment Received', 'دفعة مستلمة')} ${sar.format(movement)} · ${s.t('Running Balance', 'الرصيد الجاري')} ${sar.format(entry.balance)}'
                : '${dayTime.format(entry.date)} · ${entry.kind == 'credit' ? s.t('Credit note', 'إشعار دائن') : s.t('New Sale', 'بيع جديد')} ${sar.format(movement)} · ${s.t('Running Balance', 'الرصيد الجاري')} ${sar.format(entry.balance)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          StatusBadge(
            label: switch (entry.method) {
              'bank' => s.t('BANK', 'بنك'),
              'credit' => s.t('CREDIT', 'آجل'),
              _ => s.t('CASH', 'كاش'),
            },
            tone: entry.method == 'credit' ? BadgeTone.due : BadgeTone.paid,
          ),
          if (entry.items.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${s.t('Purchased items', 'الأصناف المشتراة')}: ${entry.items}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _kv(s.t('Amount', 'المبلغ'), entry.billed),
              ),
              Expanded(
                child: _kv(s.t('Paid', 'المدفوع'), entry.received),
              ),
              Expanded(
                child: _kv(s.t('Balance', 'الرصيد'), entry.balance),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          sar.format(value),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    );
  }
}

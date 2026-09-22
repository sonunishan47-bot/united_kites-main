import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/crm.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_share.dart';
import '../state/billing_controller.dart';
import '../utils/formatters.dart';

class CollectPaymentSheet {
  static Future<void> open(
    BuildContext context, {
    required BillingController billing,
    required Customer customer,
  }) async {
    final host = context;
    await SchedulerBinding.instance.endOfFrame;
    if (!host.mounted) return;

    final due = billing.customerDue(customer.id);
    final result = await showModalBottomSheet<_CollectDraft>(
      context: host,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: _CollectPaymentForm(
            billing: billing,
            customer: customer,
            due: due,
          ),
        );
      },
    );

    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    if (!host.mounted || result == null || result.amount <= 0) return;

    late LedgerPayment payment;
    try {
      payment = await billing.collectOutstanding(
        customerId: customer.id,
        amount: result.amount,
        method: result.method,
      );
    } on RbacException catch (e) {
      if (!host.mounted) return;
      ScaffoldMessenger.of(host).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    await SchedulerBinding.instance.endOfFrame;
    if (!host.mounted) return;

    final remaining = billing.customerDue(customer.id);
    final s = billing.s;
    ScaffoldMessenger.of(host).showSnackBar(
      SnackBar(
        content: Text(
          s.t(
            'Payment of ${sar.format(payment.amount)} recorded. Remaining ${sar.format(remaining)}.',
            'تم تسجيل ${sar.format(payment.amount)}. المتبقي ${sar.format(remaining)}.',
          ),
        ),
      ),
    );

    await showReceipt(
      host,
      billing: billing,
      customer: customer,
      payment: payment,
      remainingDue: remaining,
    );
  }

  static Future<void> showReceipt(
    BuildContext context, {
    required BillingController billing,
    required Customer customer,
    required LedgerPayment payment,
    required double remainingDue,
  }) {
    return _receiptActions(
      context,
      billing: billing,
      customer: customer,
      payment: payment,
      remainingDue: remainingDue,
    );
  }

  static Future<void> _receiptActions(
    BuildContext context, {
    required BillingController billing,
    required Customer customer,
    required LedgerPayment payment,
    required double remainingDue,
  }) {
    final s = billing.s;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.t('Payment received', 'تم استلام الدفعة'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text('${s.t('Amount', 'المبلغ')} ${sar.format(payment.amount)}'),
                Text('${s.t('Remaining balance', 'الرصيد المتبقي')} ${sar.format(remainingDue)}'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => const PdfService().printPaymentReceipt(
                    payment: payment,
                    customer: customer,
                    settings: billing.settings,
                    remainingDue: remainingDue,
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(s.t('Print receipt (58/80mm)', 'طباعة الإيصال')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => const PdfService().sharePaymentReceipt(
                    payment: payment,
                    customer: customer,
                    settings: billing.settings,
                    remainingDue: remainingDue,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(s.t('Download PDF', 'تحميل PDF')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => const WhatsAppShare().paymentReceipt(
                    customer: customer,
                    payment: payment,
                    remainingDue: remainingDue,
                    arabic: s.isAr,
                    settings: billing.settings,
                  ),
                  icon: const Icon(Icons.chat),
                  label: Text(s.t('Share via WhatsApp', 'مشاركة واتساب')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CollectDraft {
  const _CollectDraft({required this.amount, required this.method});
  final double amount;
  final String method;
}

class _CollectPaymentForm extends StatefulWidget {
  const _CollectPaymentForm({
    required this.billing,
    required this.customer,
    required this.due,
  });

  final BillingController billing;
  final Customer customer;
  final double due;

  @override
  State<_CollectPaymentForm> createState() => _CollectPaymentFormState();
}

class _CollectPaymentFormState extends State<_CollectPaymentForm> {
  late final TextEditingController amount;
  String method = 'cash';
  String? error;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    amount = TextEditingController(
      text: widget.due > 0 ? widget.due.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  void _close([_CollectDraft? draft]) {
    if (!mounted) return;
    Navigator.of(context).pop(draft);
  }

  void _submit() {
    if (submitting) return;
    final value = moneyRound(double.tryParse(amount.text) ?? 0);
    if (value <= 0) {
      setState(() => error = widget.billing.s.t('Enter a payment amount.', 'أدخل مبلغ التحصيل.'));
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    _close(_CollectDraft(amount: value, method: method));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.billing.s;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.t('Collect Payment', 'تحصيل دفعة'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              '${s.t('Outstanding', 'المستحق')} ${sar.format(widget.due)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              enabled: !submitting,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: s.t('Received amount (SAR)', 'المبلغ المستلم'),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'cash', label: Text(s.t('Cash', 'كاش'))),
                ButtonSegment(value: 'bank', label: Text(s.t('Bank', 'بنك'))),
                ButtonSegment(value: 'cheque', label: Text(s.t('Cheque', 'شيك'))),
              ],
              selected: {method},
              onSelectionChanged: submitting ? null : (v) => setState(() => method = v.first),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: submitting ? null : () => _close(),
                    child: Text(s.t('Cancel', 'إلغاء')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: submitting ? null : _submit,
                    child: Text(s.t('Collect', 'تحصيل')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

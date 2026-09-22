import 'package:flutter/material.dart';

import '../models/crm.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_share.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/collect_payment_sheet.dart';
import '../widgets/vyapar.dart';
import 'customer_ledger_screen.dart';
import 'shell.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final owing = billing.customers.where((c) => billing.customerDue(c.id) > 0.05).toList();

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(s.t('Collections & ledgers', 'التحصيل وكشوف الحساب'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            s.t('Collect outstanding dues and share a receipt or ledger on WhatsApp.', 'حصّل المديونية وشارك إيصال أو كشف حساب عبر واتساب.'),
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          if (owing.isEmpty)
            UkCard(child: Text(s.t('No outstanding dues.', 'لا توجد مديونية قائمة.'))),
          for (final customer in owing)
            UkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.display, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('${s.t('Due', 'مستحق')} ${sar.format(billing.customerDue(customer.id))}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!billing.isPartner)
                        FilledButton(
                          onPressed: () => CollectPaymentSheet.open(context, billing: billing, customer: customer),
                          child: Text(s.t('Collect Payment', 'تحصيل دفعة')),
                        ),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CustomerLedgerScreen(customerId: customer.id),
                            ),
                          );
                        },
                        child: Text(s.t('View ledger', 'عرض الكشف')),
                      ),
                      OutlinedButton(
                        onPressed: () => _ledger(context, billing, customer),
                        child: Text(s.t('Ledger PDF', 'كشف PDF')),
                      ),
                      OutlinedButton(
                        onPressed: () => _whatsappLedger(billing, customer),
                        child: Text(s.t('WhatsApp ledger', 'كشف واتساب')),
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

  Future<void> _ledger(BuildContext context, BillingController billing, Customer customer) {
    return const PdfService().shareCustomerLedger(
      customer: customer,
      rows: billing.customerLedger(customer.id),
      billed: billing.customerBilled(customer.id),
      paid: billing.customerPaid(customer.id),
      due: billing.customerDue(customer.id),
      settings: billing.settings,
    );
  }

  Future<void> _whatsappLedger(BillingController billing, Customer customer) {
    return const WhatsAppShare().customerLedger(
      customer: customer,
      due: billing.customerDue(customer.id),
      arabic: billing.s.isAr,
      rows: billing.customerLedger(customer.id),
      billed: billing.customerBilled(customer.id),
      paid: billing.customerPaid(customer.id),
      settings: billing.settings,
    );
  }
}

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/invoice.dart';
import '../services/pdf_service.dart';
import '../services/whatsapp_share.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/vyapar.dart';
import 'invoice_editor_screen.dart';
import 'shell.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key, this.todayOnly = false});

  final bool todayOnly;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final today = DateTime.now();
    final invoices = billing.scopedInvoices.where((i) {
      if (!todayOnly) return true;
      return i.createdAt.year == today.year &&
          i.createdAt.month == today.month &&
          i.createdAt.day == today.day;
    }).toList();

    return invoices.isEmpty
        ? EmptyHint(
            icon: Icons.receipt_long_outlined,
            message: billing.s.t('No invoices yet.', 'لا توجد فواتير بعد.'),
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: invoices.length,
            itemBuilder: (context, index) => InvoiceTxnCard(invoice: invoices[index]),
          );
  }
}

void showInvoiceActionsSheet(BuildContext context, Invoice invoice) {
  final billing = AppScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: Text(
                billing.canEditPostedInvoices ? billing.s.openEditAdmin : billing.s.viewOnly,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => InvoiceEditorScreen(
                      controller: billing,
                      existing: invoice,
                      viewOnly: !billing.canEditPostedInvoices,
                    ),
                  ),
                );
              },
            ),
            if (billing.canEditPostedInvoices && invoice.docType == DocType.taxInvoice)
              ListTile(
                leading: const Icon(Icons.keyboard_return),
                title: Text(billing.s.issueCredit),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => InvoiceEditorScreen(
                        controller: billing,
                        creditFor: invoice,
                      ),
                    ),
                  );
                },
              ),
            if (billing.canDeleteInvoices)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.fabRed),
                title: Text(billing.s.deleteAdmin),
                onTap: () async {
                  Navigator.pop(context);
                  await billing.deleteInvoice(invoice.id);
                },
              ),
          ],
        ),
      );
    },
  );
}

class InvoiceTxnCard extends StatelessWidget {
  const InvoiceTxnCard({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final dueAmount = billing.balanceDueOf(invoice);
    final due = !invoice.isCreditNote && dueAmount > 0.009;
    final party = invoice.shopName.isNotEmpty ? invoice.shopName : invoice.customerName;
    final hash = displayInvoiceNo(invoice.invoiceNo, icv: invoice.icv);

    return UkCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => showInvoiceActionsSheet(context, invoice),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        party.isEmpty ? s.t('Walk-in', 'عميل نقدي') : party,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$hash  ${txnDate.format(invoice.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StatusBadge(
                  label: invoice.isCreditNote ? s.t('RETURN', 'مرتجع') : s.sale,
                  tone: invoice.isCreditNote ? BadgeTone.credit : BadgeTone.sale,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _amtBlock(
                        s.t('Total Amount', 'الإجمالي'),
                        formatSarRs(invoice.grandTotal),
                        const Color(0xFF0F172A),
                        CrossAxisAlignment.start,
                      ),
                    ),
                    Expanded(
                      child: _amtBlock(
                        s.t('Balance Amount', 'المتبقي'),
                        formatSarRs(dueAmount),
                        due ? const Color(0xFF5B4B8A) : const Color(0xFF15803D),
                        CrossAxisAlignment.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TxnSideActions(
              onPrint: () async {
                final dup = invoice.printCount > 0;
                await const PdfService().printThermal(
                  invoice,
                  billing.settings,
                  duplicate: dup,
                );
                await billing.markPrinted(invoice.id);
              },
              onShare: () => const WhatsAppShare().zatcaBill(
                invoice: invoice,
                settings: billing.settings,
                arabic: s.isAr,
              ),
              onPdf: () async {
                final dup = invoice.printCount > 0;
                await const PdfService().shareA4(
                  invoice,
                  billing.settings,
                  duplicate: dup,
                );
                await billing.markPrinted(invoice.id);
              },
              onMenu: () => showInvoiceActionsSheet(context, invoice),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amtBlock(String label, String value, Color valueColor, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor),
        ),
      ],
    );
  }
}

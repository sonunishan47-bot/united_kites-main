import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/inventory.dart';
import '../services/pdf_service.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/route_safety.dart';
import '../widgets/vyapar.dart';
import 'shell.dart';

String returnStatusLabel(dynamic s, StockReturnRequest req) {
  if (req.isApproved) return s.t('Approved', 'معتمد');
  if (req.isRejected) return s.t('Rejected', 'مرفوض');
  return s.t('Pending Approval', 'بانتظار الاعتماد');
}

class PendingApprovalsBell extends StatelessWidget {
  const PendingApprovalsBell({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    if (!billing.isAdmin) return const SizedBox.shrink();
    final count = billing.pendingReturnCount;
    return IconButton(
      tooltip: count == 0
          ? billing.s.t('Pending Approvals', 'الاعتمادات المعلقة')
          : billing.s.t('$count Request Pending', '$count طلب معلّق'),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PendingApprovalsScreen()),
        );
      },
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: const Color(0xFFE53935),
        textColor: Colors.white,
        label: Text('$count'),
        child: const Icon(Icons.notifications_outlined, color: Color(0xFF334155)),
      ),
    );
  }
}

class PendingApprovalsScreen extends StatelessWidget {
  const PendingApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final pending = billing.pendingReturnRequests;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(s.t('Pending Approvals', 'الاعتمادات المعلقة'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (pending.isEmpty)
            UkCard(
              child: Text(
                s.t('No sales return requests waiting for approval.', 'لا توجد مرتجعات بانتظار الاعتماد.'),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            Text(
              pending.length == 1
                  ? s.t('1 Request Pending', 'طلب واحد معلّق')
                  : s.t('${pending.length} Requests Pending', '${pending.length} طلبات معلّقة'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            for (final req in pending) SalesReturnRequestCard(request: req, adminActions: true),
          ],
        ],
      ),
    );
  }
}

class SalesReturnRequestCard extends StatelessWidget {
  const SalesReturnRequestCard({
    super.key,
    required this.request,
    this.adminActions = false,
  });

  final StockReturnRequest request;
  final bool adminActions;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final status = returnStatusLabel(s, request);
    return UkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s.t('Sales Return', 'مرتجع مبيعات')} #${request.shortId}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              StatusBadge(
                label: status.toUpperCase(),
                tone: request.isApproved
                    ? BadgeTone.paid
                    : request.isRejected
                        ? BadgeTone.due
                        : BadgeTone.credit,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${s.t('Van', 'فان')}: ${request.van.label}'),
          Text(
            '${s.t('Customer', 'العميل')}: ${request.customerName.trim().isEmpty ? '—' : request.customerName}',
          ),
          Text('${s.t('Date', 'التاريخ')}: ${invoiceDate.format(request.createdAt)} · ${dayTime.format(request.createdAt)}'),
          if (request.originalInvoiceNo != null && request.originalInvoiceNo!.isNotEmpty)
            Text('${s.t('Invoice', 'الفاتورة')}: ${request.originalInvoiceNo}'),
          Text(
            '${s.t('Reason', 'السبب')}: ${request.note.trim().isEmpty ? (request.isDamaged ? s.t('Damaged / expired', 'تالف / منتهي') : s.t('Customer return', 'مرتجع عميل')) : request.note}',
          ),
          if (request.reviewNote.trim().isNotEmpty)
            Text('${s.t('Admin note', 'ملاحظة المدير')}: ${request.reviewNote}'),
          const SizedBox(height: 8),
          Text(s.t('Returned items', 'الأصناف المرتجعة'), style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final line in request.lines)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${line.name}  ·  ${s.t('Qty', 'الكمية')} ${line.qty.toStringAsFixed(0)} ${line.unit == 'dozen' ? s.t('dozen', 'دزينة') : s.t('pcs', 'قطعة')} (${line.pieces.toStringAsFixed(0)} ${s.t('pcs', 'قطعة')})  ·  ${sar.format(line.lineValue)}',
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '${s.t('Total value', 'القيمة الإجمالية')} ${sar.format(request.totalValue)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (request.isApproved) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printCreditNote(context, billing, preview: true),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(s.t('View PDF', 'عرض PDF')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _printCreditNote(context, billing, preview: false),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text(s.t('Print / PDF', 'طباعة / PDF')),
                  ),
                ),
              ],
            ),
          ],
          if (adminActions && request.isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                      side: const BorderSide(color: Color(0xFFE53935)),
                    ),
                    onPressed: () => _reject(context, billing),
                    child: Text(s.t('Reject', 'رفض')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _approve(context, billing),
                    child: Text(s.t('Approve', 'اعتماد')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _printCreditNote(
    BuildContext context,
    BillingController billing, {
    required bool preview,
  }) async {
    final cn = billing.creditNoteForReturn(request);
    if (cn == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            billing.s.t(
              'No credit note found for this return.',
              'لا يوجد إشعار دائن لهذا المرتجع.',
            ),
          ),
        ),
      );
      return;
    }
    if (preview) {
      await const PdfService().preview(cn, billing.settings);
    } else {
      await const PdfService().shareA4(cn, billing.settings);
    }
  }

  Future<void> _approve(BuildContext context, BillingController billing) async {
    try {
      await billing.reviewReturnRequest(request.id, approve: true);
      await waitForOverlaySettle();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            billing.s.t(
              'Approved. Van stock restored and customer ledger updated.',
              'تم الاعتماد. أُعيد مخزون الفان وحُدّث كشف العميل.',
            ),
          ),
        ),
      );
    } on RbacException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _reject(BuildContext context, BillingController billing) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(billing.s.t('Reject return', 'رفض المرتجع')),
          content: TextField(
            controller: reason,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: billing.s.t('Reason (optional)', 'السبب (اختياري)'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => popAfterFrame(dialogContext, false),
              child: Text(billing.s.t('Cancel', 'إلغاء')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
              onPressed: () => popAfterFrame(dialogContext, true),
              child: Text(billing.s.t('Reject', 'رفض')),
            ),
          ],
        );
      },
    );
    final note = reason.text.trim();
    await waitForOverlaySettle();
    reason.dispose();
    if (ok != true) return;
    try {
      await billing.reviewReturnRequest(request.id, approve: false, note: note);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(billing.s.t('Return rejected. Van stock unchanged.', 'رُفض المرتجع. مخزون الفان لم يتغير.'))),
      );
    } on RbacException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

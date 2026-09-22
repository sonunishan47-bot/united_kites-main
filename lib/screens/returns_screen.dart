import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/inventory.dart';
import '../models/invoice.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/vyapar.dart';
import 'pending_approvals_screen.dart';
import 'shell.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  Invoice? original;
  String? originalId;
  String kind = 'salable';
  final Map<String, TextEditingController> qtyByItem = {};
  final Map<String, String> unitByItem = {};
  final reason = TextEditingController();

  @override
  void dispose() {
    for (final c in qtyByItem.values) {
      c.dispose();
    }
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    var source = billing.invoices.where((i) => i.docType == DocType.taxInvoice && i.submitted);
    if (billing.isSalesman) {
      source = source.where((i) => i.location == billing.session?.sellingLocation);
    }
    final invoices = source.take(80).toList();
    final mine = billing.scopedReturnRequests;
    final pending = mine.where((r) => r.isPending).toList();
    final history = mine.where((r) => !r.isPending).take(20).toList();

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(s.t('Returns & damage', 'المرتجعات والتالف'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            billing.isAdmin
                ? s.t(
                    'Approve salesman sales returns to restore van stock and issue a credit note.',
                    'اعتمد مرتجعات المندوب لإعادة مخزون الفان وإصدار إشعار دائن.',
                  )
                : s.t(
                    'Submit a sales return linked to the original invoice. Stock and ledger change only after Admin approval.',
                    'أرسل مرتجع مبيعات مربوط بالفاتورة الأصلية. المخزون والكشف يتغيران بعد اعتماد المدير فقط.',
                  ),
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          if (billing.isAdmin && billing.pendingReturnCount > 0) ...[
            const SizedBox(height: 12),
            UkCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PendingApprovalsScreen()),
              ),
              child: Text(
                billing.pendingReturnCount == 1
                    ? s.t('1 Request Pending — open Pending Approvals', 'طلب واحد معلّق — افتح الاعتمادات')
                    : s.t(
                        '${billing.pendingReturnCount} Requests Pending — open Pending Approvals',
                        '${billing.pendingReturnCount} طلبات معلّقة — افتح الاعتمادات',
                      ),
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A73E8)),
              ),
            ),
          ],
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(s.t('Pending Approval', 'بانتظار الاعتماد'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            for (final req in pending)
              SalesReturnRequestCard(request: req, adminActions: billing.isAdmin),
          ],
          const SizedBox(height: 16),
          UkCard(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey(originalId),
                  initialValue: originalId,
                  decoration: InputDecoration(
                    labelText: s.t('Original sales invoice *', 'فاتورة البيع الأصلية *'),
                  ),
                  items: [
                    for (final inv in invoices)
                      DropdownMenuItem(value: inv.id, child: Text('${inv.invoiceNo} · ${inv.customerName}')),
                  ],
                  onChanged: billing.isPartner
                      ? null
                      : (v) {
                          Invoice? match;
                          for (final i in billing.invoices) {
                            if (i.id == v) match = i;
                          }
                          setState(() {
                            originalId = v;
                            original = match;
                            for (final c in qtyByItem.values) {
                              c.clear();
                            }
                            unitByItem.clear();
                          });
                        },
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'salable', label: Text(s.t('Salable return', 'مرتجع قابل للبيع'))),
                    ButtonSegment(value: 'damaged', label: Text(s.t('Damaged / expired', 'تالف / منتهي'))),
                  ],
                  selected: {kind},
                  onSelectionChanged: (v) => setState(() => kind = v.first),
                ),
                const SizedBox(height: 12),
                if (original == null)
                  Text(
                    s.t(
                      'Pick the original sales invoice. Return qty cannot exceed what was sold on that invoice.',
                      'اختر فاتورة البيع الأصلية. لا يمكن إرجاع كمية أكبر مما بيع في تلك الفاتورة.',
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  )
                else
                  for (final line in original!.lines)
                    _qtyField(billing, line),
                const SizedBox(height: 12),
                TextField(
                  controller: reason,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: s.t('Reason', 'السبب')),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: billing.isPartner ? null : _submit,
                    child: Text(
                      billing.isAdmin
                          ? s.t('Submit request', 'إرسال الطلب')
                          : s.t('Submit sales return', 'إرسال مرتجع مبيعات'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(s.t('Recent requests', 'الطلبات الأخيرة'), style: const TextStyle(fontWeight: FontWeight.w800)),
            for (final req in history) SalesReturnRequestCard(request: req),
          ],
        ],
      ),
    );
  }

  Widget _qtyField(BillingController billing, InvoiceLine line) {
    final id = line.itemId;
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    qtyByItem.putIfAbsent(id, () => TextEditingController());
    unitByItem.putIfAbsent(id, () => 'pcs');
    final maxPcs = billing.returnablePieces(original!, id);
    final dozen = billing.dozenSizeFor(id);
    final maxDozen = (maxPcs / dozen).floorToDouble();
    final unit = unitByItem[id]!;
    final s = billing.s;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.itemName, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            s.t(
              'Sold ${line.stockPieces.toStringAsFixed(0)} pcs · max return ${maxPcs.toStringAsFixed(0)} pcs (${maxDozen.toStringAsFixed(0)} dozen)',
              'بيع ${line.stockPieces.toStringAsFixed(0)} قطعة · حد الإرجاع ${maxPcs.toStringAsFixed(0)} قطعة (${maxDozen.toStringAsFixed(0)} دزينة)',
            ),
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: qtyByItem[id],
                  enabled: maxPcs > 0,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: unit == 'dozen' ? s.t('Qty (dozen)', 'الكمية (دزينة)') : s.t('Qty (pcs)', 'الكمية (قطعة)'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'pcs', label: Text(s.t('Pcs', 'قطعة'))),
                  ButtonSegment(value: 'dozen', label: Text(s.t('Dozen', 'دزينة'))),
                ],
                selected: {unit},
                onSelectionChanged: (v) {
                  if (maxPcs <= 0) return;
                  setState(() => unitByItem[id] = v.first);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final billing = AppScope.of(context);
    if (original == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            billing.s.t('Pick the original sales invoice.', 'اختر فاتورة البيع الأصلية.'),
          ),
        ),
      );
      return;
    }
    final van = billing.isSalesman
        ? billing.session!.sellingLocation
        : original!.location;
    final lines = <StockReturnLine>[];
    for (final line in original!.lines) {
      final id = line.itemId;
      if (id == null) continue;
      final entered = moneyRound(double.tryParse(qtyByItem[id]?.text ?? '') ?? 0);
      if (entered <= 0) continue;
      final unit = unitByItem[id] ?? 'pcs';
      final dozen = billing.dozenSizeFor(id);
      final pieces = unit == 'dozen' ? moneyRound(entered * dozen) : entered;
      final maxPcs = billing.returnablePieces(original!, id);
      if (pieces > maxPcs + 0.001) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              billing.s.t(
                '${line.itemName}: max returnable is ${maxPcs.toStringAsFixed(0)} pcs from invoice ${original!.invoiceNo}.',
                '${line.itemName}: الحد الأقصى للإرجاع ${maxPcs.toStringAsFixed(0)} قطعة من الفاتورة ${original!.invoiceNo}.',
              ),
            ),
          ),
        );
        return;
      }
      final perUnit = line.quantity.abs() < 0.001 ? 1.0 : line.stockPieces / line.quantity;
      final billedQty = moneyRound(pieces / perUnit);
      lines.add(
        StockReturnLine(
          itemId: id,
          sku: line.sku,
          name: line.itemName,
          pieces: pieces,
          enteredQty: billedQty,
          unit: unit,
          unitPrice: line.unitPrice,
          taxRate: line.taxRate,
          taxInclusive: line.taxInclusive,
          unitCost: line.unitCost,
        ),
      );
    }
    try {
      await billing.submitReturnRequest(
        StockReturnRequest(
          id: newId(),
          van: van,
          kind: kind,
          lines: lines,
          originalInvoiceId: original?.id,
          originalInvoiceNo: original?.invoiceNo,
          customerId: original?.customerId,
          customerName: original?.customerName ?? '',
          note: reason.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            billing.s.t(
              'Sales Return submitted for Admin Approval',
              'تم إرسال مرتجع المبيعات لاعتماد المدير',
            ),
          ),
        ),
      );
      setState(() {
        original = null;
        originalId = null;
        reason.clear();
        unitByItem.clear();
        for (final c in qtyByItem.values) {
          c.clear();
        }
      });
    } on RbacException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

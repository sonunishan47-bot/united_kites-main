import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/inventory.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/vyapar.dart';
import 'item_editor_sheet.dart';
import 'shell.dart';

class ItemDetailsScreen extends StatelessWidget {
  const ItemDetailsScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final item = billing.itemById(itemId);
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: Text(s.t('Item Details', 'تفاصيل الصنف'))),
        body: Center(child: Text(s.t('Item not found.', 'الصنف غير موجود.'))),
      );
    }
    final qty = billing.itemOnHand(item.id);
    final inStock = qty > 0.001;
    final stockValue = item.stockValueOf(qty);
    final txns = billing.itemTransactions(item.id);
    final sales = txns.where((row) => row.sale || row.label == 'Return').toList();
    var openingPieces = 0.0;
    var sawOpening = false;
    for (final movement in billing.movements) {
      if (movement.itemId != item.id) continue;
      final reason = movement.reason.toLowerCase();
      if (!reason.contains('opening') && !reason.contains('adjust')) continue;
      sawOpening = true;
      openingPieces += movement.delta;
    }
    openingPieces = moneyRound(openingPieces);
    final soldQty = moneyRound(sales.where((row) => row.sale).fold(0.0, (sum, row) => sum + row.qty));
    final soldValue = moneyRound(sales.where((row) => row.sale).fold(0.0, (sum, row) => sum + row.amount));
    final qtyText = qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(item.name),
        actions: [
          if (billing.isAdmin)
            IconButton(
              tooltip: s.t('Edit', 'تعديل'),
              onPressed: () => ItemEditorSheet.open(context, billing, existing: item),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          UkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (item.sku.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(item.sku, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _metric(
                        s.t('Purchase Cost', 'تكلفة الشراء'),
                        billing.canSeeCosts ? sar.format(item.purchaseCost) : '—',
                      ),
                    ),
                    Expanded(
                      child: _metric(s.t('Sales Price', 'سعر البيع'), sar.format(item.sellingPrice)),
                    ),
                    Expanded(
                      child: _metric(
                        s.t('Current Stock', 'المخزون الحالي'),
                        qtyText,
                        valueColor: inStock ? const Color(0xFF15803D) : AppTheme.fabRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _metric(
                        s.t('Stock Value', 'قيمة المخزون'),
                        billing.canSeeCosts ? sar.format(stockValue) : '—',
                      ),
                    ),
                    Expanded(
                      child: _metric(
                        s.t('Units Sold', 'الوحدات المباعة'),
                        soldQty.toStringAsFixed(soldQty == soldQty.roundToDouble() ? 0 : 1),
                      ),
                    ),
                    Expanded(
                      child: _metric(s.t('Sale Value', 'قيمة المبيعات'), sar.format(soldValue)),
                    ),
                  ],
                ),
                if (billing.canSeeCosts &&
                    (stockValue - moneyRound(qty * item.purchaseCost)).abs() < 0.02) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.t(
                      '$qtyText × ${sar.format(item.purchaseCost)} = ${sar.format(stockValue)}',
                      '$qtyText × ${sar.format(item.purchaseCost)} = ${sar.format(stockValue)}',
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          if (billing.isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                onPressed: () => _openAdjustment(context, billing, item.id),
                icon: const Icon(Icons.tune, color: AppTheme.accent),
                label: Text(s.t('Opening Stock / Adjustments', 'رصيد افتتاحي / تسويات')),
              ),
            ),
          SectionHeader(s.t('Item Transactions', 'حركات الصنف')),
          if (sales.isEmpty)
            UkCard(
              child: Text(
                s.t('No sales for this item yet.', 'لا توجد مبيعات لهذا الصنف بعد.'),
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            )
          else
            for (final row in sales)
              UkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.party,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                        Text(
                          row.sale ? s.sale : s.t('RETURN', 'مرتجع'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: row.sale ? const Color(0xFF15803D) : AppTheme.fabRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      txnDate.format(row.at),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _metric(s.t('Quantity', 'الكمية'), _qtyLabel(row))),
                        Expanded(child: _metric(s.t('Unit Rate', 'سعر الوحدة'), sar.format(row.rate))),
                        Expanded(
                          child: _metric(s.t('Total Amount', 'المبلغ'), sar.format(row.amount)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          if (sawOpening)
            UkCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.t('Opening Stock', 'الرصيد الافتتاحي'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${openingPieces.toStringAsFixed(openingPieces == openingPieces.roundToDouble() ? 0 : 1)} ${s.t('Pcs', 'قطعة')}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _qtyLabel(ItemTxn row) {
    final billed = row.billedQty > 0 ? row.billedQty : row.qty;
    final shown = billed.toStringAsFixed(billed == billed.roundToDouble() ? 0 : 1);
    if (row.unit == 'Pcs' || (row.qty - billed).abs() < 0.001) return '$shown ${row.unit}';
    final pieces = row.qty.toStringAsFixed(row.qty == row.qty.roundToDouble() ? 0 : 1);
    return '$shown ${row.unit} ($pieces Pcs)';
  }

  Widget _metric(String label, String value, {Color valueColor = const Color(0xFF0F172A)}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor)),
      ],
    );
  }

  Future<void> _openAdjustment(BuildContext context, BillingController billing, String id) async {
    final s = billing.s;
    final qty = TextEditingController();
    var opening = true;
    var add = true;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: StatefulBuilder(
            builder: (context, setLocal) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      s.t('Opening Stock / Adjustments', 'رصيد افتتاحي / تسويات'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(value: true, label: Text(s.t('Opening Stock', 'رصيد افتتاحي'))),
                        ButtonSegment(value: false, label: Text(s.t('Adjustment', 'تسوية'))),
                      ],
                      selected: {opening},
                      onSelectionChanged: (value) => setLocal(() => opening = value.first),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qty,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: s.t('Quantity (Pcs)', 'الكمية (قطعة)')),
                    ),
                    if (!opening) ...[
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(value: true, label: Text(s.t('Add', 'إضافة'))),
                          ButtonSegment(value: false, label: Text(s.t('Remove', 'خصم'))),
                        ],
                        selected: {add},
                        onSelectionChanged: (value) => setLocal(() => add = value.first),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: Text(s.t('Save', 'حفظ')),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    final pieces = moneyRound(double.tryParse(qty.text) ?? 0);
    qty.dispose();
    if (saved != true || pieces <= 0 || !context.mounted) return;
    final delta = opening || add ? pieces : -pieces;
    final reason = opening ? 'Opening Stock' : 'Adjustment';
    try {
      await billing.adjustStock(
        itemId: id,
        location: StockLocation.warehouse,
        delta: delta,
        reason: reason,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('Stock updated.', 'تم تحديث المخزون.'))),
      );
    } on RbacException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

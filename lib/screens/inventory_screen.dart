import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/vyapar.dart';
import 'shell.dart';
import 'van_loading_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  StockLocation location = StockLocation.warehouse;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final loc = billing.isSalesman ? billing.session!.sellingLocation : location;
    final rows = [...billing.items]
      ..sort(
        (a, b) => billing
            .stockAt(loc, a.id)
            .quantity
            .compareTo(billing.stockAt(loc, b.id).quantity),
      );

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(s.stock),
        actions: [
          if (billing.isAdmin)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const VanLoadingScreen()),
                );
              },
              icon: const Icon(Icons.swap_horiz, color: AppTheme.fabRed),
              label: Text(
                s.t('Transfer', 'تحويل'),
                style: const TextStyle(color: AppTheme.fabRed, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!billing.isSalesman)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final loc in StockLocation.values)
                      ChoiceChip(
                        label: Text(loc.label),
                        selected: location == loc,
                        selectedColor: const Color(0xFFFFEBEE),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: location == loc ? AppTheme.fabRed : const Color(0xFF334155),
                        ),
                        onSelected: (_) => setState(() => location = loc),
                      ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Builder(
              builder: (context) {
                final metrics = billing.stockMetrics(loc);
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: s.t('Total stock quantity', 'إجمالي كمية المخزون'),
                            value: '${metrics.quantity.toStringAsFixed(2)} pcs',
                            icon: Icons.inventory_2_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: s.t('Expected selling value', 'قيمة البيع المتوقعة'),
                            value: sar.format(metrics.sellingValue),
                            icon: Icons.sell_outlined,
                          ),
                        ),
                      ],
                    ),
                    if (billing.canSeeCosts) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: s.t('Purchase cost value', 'قيمة تكلفة الشراء'),
                              value: sar.format(metrics.purchaseValue),
                              icon: Icons.warehouse_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: s.t('Potential profit', 'الربح المتوقع'),
                              value: sar.format(metrics.potentialProfit),
                              icon: Icons.trending_up,
                              tint: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? EmptyHint(
                    icon: Icons.warehouse_outlined,
                    message: s.t(
                      'No stock yet. Add products, then transfer warehouse qty to a van.',
                      'لا يوجد مخزون بعد. أضف المنتجات ثم انقل الكمية إلى الفان.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final item = rows[index];
                      final vanQty = billing.stockAt(loc.isVan ? loc : StockLocation.van1, item.id).quantity;
                      final whQty = billing.stockAt(StockLocation.warehouse, item.id).quantity;
                      final stock = billing.stockAt(loc, item.id);
                      final low = billing.isLowAt(loc, item.id);
                      return UkCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: low ? const Color(0xFFFFCDD2) : const Color(0xFFE8EEF4),
                              child: Text(
                                stock.quantity.toStringAsFixed(0),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: low ? AppTheme.fabRed : AppTheme.navy,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${s.itemCode} ${item.sku} · ${item.variantLabel}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.stockBreakdown(stock.quantity),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    billing.canSeeCosts
                                        ? '${s.t('Cost', 'تكلفة')} ${sar.format(item.purchaseCost)} · ${s.t('Sell', 'بيع')} ${sar.format(item.sellingPrice)}'
                                        : '${s.t('Sell', 'بيع')} ${sar.format(item.sellingPrice)} · ${s.t('Van', 'فان')} ${vanQty.toStringAsFixed(0)} · ${s.t('Warehouse', 'مستودع')} ${whQty.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                ],
                              ),
                            ),
                            if (billing.isAdmin && loc == StockLocation.warehouse)
                              Column(
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => billing.adjustStock(
                                      itemId: item.id,
                                      location: loc,
                                      delta: 1,
                                      reason: 'Manual in',
                                    ),
                                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.navy),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: stock.quantity > 0
                                        ? () => billing.adjustStock(
                                              itemId: item.id,
                                              location: loc,
                                              delta: -1,
                                              reason: 'Manual out',
                                            )
                                        : null,
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                ],
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  stock.quantity.toStringAsFixed(0),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

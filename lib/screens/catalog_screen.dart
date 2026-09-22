import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/item.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/search_text.dart';
import '../widgets/common.dart';
import '../widgets/vyapar.dart';
import 'item_details_screen.dart';
import 'item_editor_sheet.dart';
import 'shell.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String query = '';
  ProductDept? dept;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final seen = <String>{};
    final filtered = <CatalogItem>[];
    for (final item in CatalogItem.unique(billing.items)) {
      if (dept != null && item.department != dept) continue;
      if (!matchesSearch(query, [item.name, item.sku, item.variantLabel])) continue;
      if (!seen.add(item.id)) continue;
      filtered.add(item);
    }

    return Stack(
      children: [
        ColoredBox(
      color: AppTheme.canvas,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: billing.s.t('Search items', 'بحث الأصناف'),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          if (billing.settings.options.itemCategories)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  FilterChip(
                    label: Text(billing.s.t('All', 'الكل')),
                    selected: dept == null,
                    onSelected: (_) => setState(() => dept = null),
                  ),
                  const SizedBox(width: 8),
                  for (final value in ProductDeptX.catalogChoices)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(value.label),
                        selected: dept == value,
                        onSelected: (_) => setState(() => dept = value),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? EmptyHint(
                    icon: Icons.inventory_2_outlined,
                    message: billing.items.isEmpty
                        ? billing.s.t('No products yet. Tap + to add.', 'لا توجد منتجات بعد. اضغط + للإضافة.')
                        : billing.s.t('No products match.', 'لا توجد منتجات مطابقة.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final qty = billing.itemOnHand(item.id);
                      final stockColor = qty <= 0.001 ? AppTheme.fabRed : const Color(0xFF15803D);
                      final saleLabel = item.pricesArePerPack
                          ? billing.s.t('Sales Price / pack', 'سعر البيع / العبوة')
                          : billing.s.t('Sales Price', 'سعر البيع');
                      final purchaseLabel = item.pricesArePerPack
                          ? billing.s.t('Purchase Cost / pack', 'تكلفة الشراء / العبوة')
                          : billing.s.t('Purchase Cost', 'تكلفة الشراء');
                      return UkCard(
                        key: ValueKey(item.id),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ItemDetailsScreen(itemId: item.id),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _col(
                                    saleLabel,
                                    sar.format(item.sellingPrice),
                                    const Color(0xFF0F172A),
                                  ),
                                ),
                                Expanded(
                                  child: _col(
                                    purchaseLabel,
                                    billing.canSeeCosts ? sar.format(item.purchaseCost) : '—',
                                    const Color(0xFF334155),
                                  ),
                                ),
                                Expanded(
                                  child: _col(
                                    billing.s.t('Stock', 'المخزون'),
                                    qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1),
                                    stockColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
        ),
        if (billing.isAdmin)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              backgroundColor: AppTheme.fabRed,
              foregroundColor: Colors.white,
              onPressed: () => ItemEditorSheet.open(context, billing),
              icon: const Icon(Icons.add),
              label: Text(billing.s.t('Add New Item', 'إضافة صنف جديد')),
            ),
          ),
      ],
    );
  }

  Widget _col(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valueColor),
        ),
      ],
    );
  }
}

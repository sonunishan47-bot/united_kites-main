import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/inventory.dart';
import '../models/item.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/route_safety.dart';
import '../widgets/common.dart';
import '../widgets/vyapar.dart';
import 'shell.dart';

class VanLoadingScreen extends StatefulWidget {
  const VanLoadingScreen({super.key});

  @override
  State<VanLoadingScreen> createState() => _VanLoadingScreenState();
}

class _VanLoadingScreenState extends State<VanLoadingScreen> {
  StockLocation van = StockLocation.van1;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final loads = billing.loads.where((l) => l.van == van).toList();

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(s.load)),
      floatingActionButton: billing.isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.fabRed,
              foregroundColor: Colors.white,
              onPressed: billing.items.isEmpty ? null : () => _openTransfer(),
              icon: const Icon(Icons.add),
              label: Text(
                s.t('+ Load Stock', '+ تحميل مخزون'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Text(
            s.t('Transfer warehouse → van', 'نقل من المستودع إلى الفان'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final loc in const [StockLocation.van1, StockLocation.van2])
                ChoiceChip(
                  label: Text(loc.label),
                  selected: van == loc,
                  selectedColor: const Color(0xFFFFEBEE),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: van == loc ? AppTheme.fabRed : const Color(0xFF334155),
                  ),
                  onSelected: (_) => setState(() => van = loc),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final wh = billing.stockMetrics(StockLocation.warehouse);
              final vm = billing.stockMetrics(van);
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: s.t('Warehouse qty', 'كمية المستودع'),
                          value: '${wh.quantity.toStringAsFixed(2)} pcs',
                          icon: Icons.warehouse_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: s.t('${van.label} qty', 'كمية ${van.label}'),
                          value: '${vm.quantity.toStringAsFixed(2)} pcs',
                          icon: Icons.local_shipping_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: s.t('Van selling value', 'قيمة بيع الفان'),
                          value: sar.format(vm.sellingValue),
                          icon: Icons.sell_outlined,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCard(
                          label: billing.canSeeCosts
                              ? s.t('Van purchase cost', 'تكلفة شراء الفان')
                              : s.t('Van stock value', 'قيمة مخزون الفان'),
                          value: sar.format(
                            billing.canSeeCosts ? vm.purchaseValue : vm.sellingValue,
                          ),
                          icon: Icons.payments_outlined,
                        ),
                      ),
                    ],
                  ),
                  if (billing.canSeeCosts) ...[
                    const SizedBox(height: 10),
                    StatCard(
                      label: s.t('Warehouse potential profit', 'ربح المستودع المتوقع'),
                      value: sar.format(wh.potentialProfit),
                      icon: Icons.trending_up,
                      tint: const Color(0xFF15803D),
                    ),
                  ],
                ],
              );
            },
          ),
          SectionHeader(s.t('Warehouse products', 'أصناف المستودع')),
          if (billing.items.isEmpty)
            EmptyHint(
              icon: Icons.inventory_2_outlined,
              message: s.t(
                'Add products first, then transfer stock to a van.',
                'أضف المنتجات أولاً ثم انقل المخزون إلى الفان.',
              ),
            )
          else
            for (final item in billing.items)
              _SkuStockCard(
                item: item,
                warehouseQty: billing.stockAt(StockLocation.warehouse, item.id).quantity,
                vanQty: billing.stockAt(van, item.id).quantity,
                vanLabel: van.label,
                skuLabel: '${billing.s.itemCode} ${item.sku} · ${item.variantLabel}',
                onTransfer: billing.isAdmin ? () => _openTransfer(preset: item) : null,
              ),
          SectionHeader(s.t('Van Stock History', 'سجل مخزون الفان')),
          Builder(
            builder: (context) {
              final rows = billing.movements.where((m) => m.location == van).take(25).toList();
              if (rows.isEmpty) {
                return UkCard(
                  child: Text(
                    s.t('No van stock movements yet.', 'لا توجد حركات مخزون للفان بعد.'),
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                );
              }
              return Column(
                children: [
                  for (final m in rows)
                    UkCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  billing.itemById(m.itemId)?.name ?? m.itemId,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  m.reason,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                ),
                                Text(
                                  dayTime.format(m.createdAt),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${m.delta >= 0 ? '+' : ''}${m.delta.toStringAsFixed(0)} pcs',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: m.delta >= 0 ? const Color(0xFF15803D) : AppTheme.fabRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          SectionHeader(s.t('Recent transfers', 'آخر التحويلات')),
          if (loads.isEmpty)
            UkCard(
              child: Text(
                s.t('No van loads yet.', 'لا توجد تحميلات بعد.'),
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            )
          else
            for (final load in loads.take(12))
              UkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${load.van.label} · ${load.lines.length} ${s.t('items', 'أصناف')}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dayTime.format(load.createdAt)} · ${s.t('Sell', 'بيع')} ${sar.format(load.totalSell)}'
                      '${billing.canSeeCosts ? ' · ${s.t('Cost', 'تكلفة')} ${sar.format(load.totalCost)}' : ''}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),
                    for (final line in load.lines.take(6))
                      Text(
                        '${line.quantity.toStringAsFixed(0)} × ${line.name}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _openTransfer({CatalogItem? preset}) async {
    if (!mounted) return;
    final billing = AppScope.read(context);
    if (billing.items.isEmpty) return;
    final draft = await showModalBottomSheet<_TransferDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: _TransferStockSheet(
            billing: billing,
            initialVan: van,
            preset: preset,
          ),
        );
      },
    );
    if (!mounted || draft == null) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _submitTransfer(draft);
  }

  Future<void> _submitTransfer(_TransferDraft draft) async {
    if (!mounted) return;
    final billing = AppScope.read(context);
    final s = billing.s;
    final source = draft.toVan ? StockLocation.warehouse : draft.van;
    final available = billing.stockAt(source, draft.item.id).quantity;
    if (draft.pieces <= 0 || draft.pieces > available + 0.001) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(s.t('Cannot transfer', 'تعذر التحويل')),
          content: Text(
            s.t(
              '${source.label} stock is lower than the requested quantity for ${draft.item.name}.\nAvailable ${available.toStringAsFixed(2)} pcs · requested ${draft.pieces.toStringAsFixed(2)} pcs.',
              'مخزون ${source.label} أقل من الكمية المطلوبة لـ ${draft.item.name}.\nالمتوفر ${available.toStringAsFixed(2)} قطعة · المطلوب ${draft.pieces.toStringAsFixed(2)} قطعة.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(s.t('OK', 'حسناً')),
            ),
          ],
        ),
      );
      return;
    }
    try {
      final line = VanLoadLine(
        itemId: draft.item.id,
        sku: draft.item.sku,
        name: '${draft.item.name} ${draft.item.variantLabel}',
        quantity: draft.pieces,
        purchaseCost: draft.item.purchasePerPiece,
        sellingPrice: draft.item.sellingPerPiece,
      );
      if (draft.toVan) {
        await billing.loadVan(van: draft.van, lines: [line]);
      } else {
        await billing.unloadVan(van: draft.van, lines: [line]);
      }
      if (!mounted) return;
      setState(() => van = draft.van);
      final whLeft = billing.stockAt(StockLocation.warehouse, draft.item.id).quantity;
      final vanNow = billing.stockAt(draft.van, draft.item.id).quantity;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(s.t('Transfer complete', 'تم التحويل')),
          content: Text(
            s.t(
              draft.toVan
                  ? 'Moved ${draft.pieces.toStringAsFixed(0)} pcs of ${draft.item.name} to ${draft.van.label}.\n\nWarehouse now: ${draft.item.stockBreakdown(whLeft)}\n${draft.van.label} now: ${draft.item.stockBreakdown(vanNow)}'
                  : 'Returned ${draft.pieces.toStringAsFixed(0)} pcs of ${draft.item.name} from ${draft.van.label} to the warehouse.\n\nWarehouse now: ${draft.item.stockBreakdown(whLeft)}\n${draft.van.label} now: ${draft.item.stockBreakdown(vanNow)}',
              draft.toVan
                  ? 'تم نقل ${draft.pieces.toStringAsFixed(0)} قطعة من ${draft.item.name} إلى ${draft.van.label}.\n\nالمستودع الآن: ${draft.item.stockBreakdown(whLeft)}\n${draft.van.label} الآن: ${draft.item.stockBreakdown(vanNow)}'
                  : 'تمت إعادة ${draft.pieces.toStringAsFixed(0)} قطعة من ${draft.item.name} من ${draft.van.label} إلى المستودع.\n\nالمستودع الآن: ${draft.item.stockBreakdown(whLeft)}\n${draft.van.label} الآن: ${draft.item.stockBreakdown(vanNow)}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(s.t('OK', 'حسناً')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(s.t('Cannot transfer', 'تعذر التحويل')),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(s.t('OK', 'حسناً')),
            ),
          ],
        ),
      );
    }
  }
}

class _TransferDraft {
  const _TransferDraft({
    required this.item,
    required this.van,
    required this.pieces,
    required this.toVan,
  });

  final CatalogItem item;
  final StockLocation van;
  final double pieces;
  final bool toVan;
}

class _TransferStockSheet extends StatefulWidget {
  const _TransferStockSheet({
    required this.billing,
    required this.initialVan,
    this.preset,
  });

  final BillingController billing;
  final StockLocation initialVan;
  final CatalogItem? preset;

  @override
  State<_TransferStockSheet> createState() => _TransferStockSheetState();
}

class _TransferStockSheetState extends State<_TransferStockSheet> {
  late CatalogItem item;
  late StockLocation dest;
  late StockQtyUnit unit;
  late final TextEditingController qty;
  bool toVan = true;

  BillingController get billing => widget.billing;

  @override
  void initState() {
    super.initState();
    item = widget.preset ?? billing.items.first;
    dest = widget.initialVan.isVan ? widget.initialVan : StockLocation.van1;
    unit = StockQtyUnit.piece;
    qty = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    qty.dispose();
    super.dispose();
  }

  void _confirm() {
    final entered = double.tryParse(qty.text.trim()) ?? 0;
    final pieces = moneyRound(unit.toPieces(entered, item.unitsPerCarton));
    final source = toVan ? StockLocation.warehouse : dest;
    final available = billing.stockAt(source, item.id).quantity;
    if (pieces <= 0 || pieces > available + 0.001) return;
    popAfterFrame(
      context,
      _TransferDraft(item: item, van: dest, pieces: pieces, toVan: toVan),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = billing.s;
    final source = toVan ? StockLocation.warehouse : dest;
    final available = billing.stockAt(source, item.id).quantity;
    final entered = double.tryParse(qty.text.trim()) ?? 0;
    final pieces = moneyRound(unit.toPieces(entered, item.unitsPerCarton));
    final tooMuch = pieces <= 0 || pieces > available + 0.001;
    final itemIds = [for (final row in billing.items) row.id];
    final selectedId = itemIds.contains(item.id) ? item.id : itemIds.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('Transfer Stock', 'تحويل مخزون'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            toVan
                ? s.t('Move quantity from warehouse into a van.', 'انقل كمية من المستودع إلى الفان.')
                : s.t('Return quantity from a van to the warehouse.', 'أعد كمية من الفان إلى المستودع.'),
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(s.t('To van', 'إلى الفان'))),
              ButtonSegment(value: false, label: Text(s.t('To warehouse', 'إلى المستودع'))),
            ],
            selected: {toVan},
            onSelectionChanged: (value) => setState(() => toVan = value.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            decoration: InputDecoration(labelText: s.t('Product', 'الصنف')),
            items: [
              for (final row in billing.items)
                DropdownMenuItem(
                  value: row.id,
                  child: Text(
                    '${row.name} · WH ${billing.stockAt(StockLocation.warehouse, row.id).quantity.toStringAsFixed(0)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              final next = billing.itemById(id);
              if (next == null) return;
              setState(() => item = next);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<StockLocation>(
            initialValue: dest,
            decoration: InputDecoration(labelText: s.t('Van', 'فان')),
            items: const [
              DropdownMenuItem(value: StockLocation.van1, child: Text('Van 1')),
              DropdownMenuItem(value: StockLocation.van2, child: Text('Van 2')),
            ],
            onChanged: (v) => setState(() => dest = v ?? dest),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: qty,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: s.t('Quantity', 'الكمية'),
              helperText: s.t(
                'Warehouse: ${item.stockBreakdown(available)}',
                'المستودع: ${item.stockBreakdown(available)}',
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<StockQtyUnit>(
            initialValue: unit,
            decoration: InputDecoration(labelText: s.t('Unit', 'الوحدة')),
            items: [
              DropdownMenuItem(
                value: StockQtyUnit.piece,
                child: Text(s.t('Pieces', 'قطع')),
              ),
              DropdownMenuItem(
                value: StockQtyUnit.carton,
                child: Text(s.t('Cartons / boxes', 'كرتون / صناديق')),
              ),
              DropdownMenuItem(
                value: StockQtyUnit.dozen,
                child: Text(s.t('Dozens', 'دزينات')),
              ),
            ],
            onChanged: (v) => setState(() => unit = v ?? unit),
          ),
          const SizedBox(height: 8),
          Text(
            '${s.t('Will transfer', 'سيتم نقل')} ${pieces.toStringAsFixed(0)} ${s.t('pcs', 'قطعة')}'
            '${tooMuch ? ' — ${s.t('Not enough warehouse stock', 'مخزون المستودع غير كافٍ')}' : ''}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: tooMuch ? const Color(0xFFB91C1C) : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.fabRed),
              onPressed: tooMuch ? null : _confirm,
              icon: const Icon(Icons.local_shipping_outlined),
              label: Text(
                s.t('Transfer to van', 'نقل إلى الفان'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkuStockCard extends StatelessWidget {
  const _SkuStockCard({
    required this.item,
    required this.warehouseQty,
    required this.vanQty,
    required this.vanLabel,
    required this.skuLabel,
    this.onTransfer,
  });

  final CatalogItem item;
  final double warehouseQty;
  final double vanQty;
  final String vanLabel;
  final String skuLabel;
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    return UkCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  skuLabel,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.stockBreakdown(warehouseQty)}  ·  $vanLabel ${vanQty.toStringAsFixed(0)} pcs',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.navy),
                ),
              ],
            ),
          ),
          if (onTransfer != null)
            FilledButton.tonal(
              onPressed: warehouseQty > 0 ? onTransfer : null,
              child: const Text('Load'),
            ),
        ],
      ),
    );
  }
}

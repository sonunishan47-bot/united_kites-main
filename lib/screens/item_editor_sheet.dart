import 'dart:async';

import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/item.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/route_safety.dart';

class ItemEditorSheet {
  static Future<void> open(
    BuildContext context,
    BillingController billing, {
    CatalogItem? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _ItemForm(billing: billing, existing: existing),
      ),
    );
  }
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({required this.billing, this.existing});

  final BillingController billing;
  final CatalogItem? existing;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  late ProductDept department;
  late bool packingDozen;
  late bool pricePerPack;
  late final String _itemId;
  bool _saving = false;
  late final TextEditingController sku;
  late final TextEditingController name;
  late final TextEditingController volume;
  late final TextEditingController cost;
  late final TextEditingController sell;
  late final TextEditingController cartonQty;
  late final TextEditingController warehouseQty;
  late final TextEditingController warehouseDozens;

  static const volumes = ['50ml', '100ml'];

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _itemId = item?.id ?? newId();
    department = item == null
        ? ProductDept.footwear
        : (ProductDeptX.catalogChoices.contains(item.department)
            ? item.department
            : ProductDept.apparel);
    packingDozen = item != null &&
        (item.unit.toLowerCase() == 'dozen' || item.unit.toLowerCase() == 'doz');
    pricePerPack = item?.pricesArePerPack ?? false;
    sku = TextEditingController(
      text: item?.sku ?? CatalogItem.nextProductCode(widget.billing.items, department),
    );
    name = TextEditingController(text: item?.name ?? '');
    volume = TextEditingController(text: item?.volume ?? '50ml');
    cost = TextEditingController(text: item?.purchaseCost.toString() ?? '0');
    sell = TextEditingController(text: item?.sellingPrice.toString() ?? '0');
    cartonQty = TextEditingController(
      text: packingDozen ? '12' : (item?.unitsPerCarton.toStringAsFixed(0) ?? '12'),
    );
    final existingQty = item == null
        ? 0.0
        : widget.billing.stockAt(StockLocation.warehouse, item.id).quantity;
    final dozens = (existingQty / CatalogItem.dozenPieces).floorToDouble();
    final remainder = moneyRound(existingQty - dozens * CatalogItem.dozenPieces);
    warehouseQty = TextEditingController(text: remainder.toStringAsFixed(0));
    warehouseDozens = TextEditingController(text: dozens.toStringAsFixed(0));
  }

  @override
  void dispose() {
    sku.dispose();
    name.dispose();
    volume.dispose();
    cost.dispose();
    sell.dispose();
    cartonQty.dispose();
    warehouseQty.dispose();
    warehouseDozens.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.billing.s;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null
                ? s.t('New product', 'منتج جديد')
                : s.t('Edit product', 'تعديل المنتج'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProductDept>(
            initialValue: department,
            decoration: InputDecoration(labelText: s.t('Department', 'القسم')),
            items: [
              for (final dept in ProductDeptX.catalogChoices)
                DropdownMenuItem(value: dept, child: Text(dept.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                department = value;
                if (widget.existing == null) {
                  sku.text = CatalogItem.nextProductCode(widget.billing.items, department);
                }
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(controller: name, decoration: InputDecoration(labelText: s.t('Name', 'الاسم'))),
          const SizedBox(height: 8),
          TextField(
            controller: sku,
            readOnly: true,
            decoration: InputDecoration(
              labelText: s.productCode,
              helperText: s.t('Generated automatically', 'يُنشأ تلقائياً'),
            ),
          ),
          if (department == ProductDept.perfume) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: volumes.contains(volume.text) ? volume.text : '50ml',
              decoration: const InputDecoration(labelText: 'Volume'),
              items: [for (final v in volumes) DropdownMenuItem(value: v, child: Text(v))],
              onChanged: (value) => volume.text = value ?? volume.text,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            s.t('Purchase cost & selling price are', 'تكلفة الشراء وسعر البيع حسب'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(s.t('Per Piece', 'للقطعة'))),
              ButtonSegment(value: true, label: Text(s.t('Per Dozen / Carton', 'للدزينة / الكرتون'))),
            ],
            selected: {pricePerPack},
            onSelectionChanged: (value) => setState(() => pricePerPack = value.first),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              pricePerPack
                  ? s.t(
                      'Enter pack prices as-is. Stock value uses full cartons at this cost plus leftover pieces at cost ÷ pieces per carton.',
                      'أدخل سعر العبوة كما هو. قيمة المخزون = الكراتين الكاملة بهذه التكلفة + القطع المتبقية ÷ عدد القطع في الكرتون.',
                    )
                  : s.t(
                      'Enter prices for a single piece. Stock value = pieces × purchase cost.',
                      'أدخل الأسعار للقطعة الواحدة. قيمة المخزون = القطع × تكلفة الشراء.',
                    ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 8),
          if (widget.billing.canSeeCosts)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: cost,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: pricePerPack
                          ? s.t('Purchase cost / pack', 'تكلفة الشراء / العبوة')
                          : s.t('Purchase cost / pc', 'تكلفة الشراء / قطعة'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: sell,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: pricePerPack
                          ? s.t('Selling price / pack', 'سعر البيع / العبوة')
                          : s.t('Selling price / pc', 'سعر البيع / قطعة'),
                    ),
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: sell,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: pricePerPack
                    ? s.t('Selling price / pack', 'سعر البيع / العبوة')
                    : s.t('Selling price / pc', 'سعر البيع / قطعة'),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: cartonQty,
                  enabled: !packingDozen,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: s.t('Pieces per carton / box', 'قطع في الكرتون / الصندوق'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 118,
                child: DropdownButtonFormField<bool>(
                  initialValue: packingDozen,
                  decoration: InputDecoration(labelText: s.t('Unit', 'الوحدة')),
                  items: [
                    DropdownMenuItem(value: false, child: Text(s.t('Pcs', 'قطعة'))),
                    DropdownMenuItem(value: true, child: Text(s.t('Dozen', 'دزينة'))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      packingDozen = value ?? false;
                      if (packingDozen) cartonQty.text = '12';
                    });
                  },
                ),
              ),
            ],
          ),
          if (packingDozen)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                s.t('1 dozen = 12 pcs', 'الدزينة = 12 قطعة'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            s.t('Warehouse quantity', 'كمية المستودع'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: warehouseQty,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.t('Pieces', 'قطع')),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: warehouseDozens,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: s.t('Dozens', 'دزينات')),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${s.t('Total warehouse stock', 'إجمالي مخزون المستودع')}: ${_warehousePieces().toStringAsFixed(0)} ${s.t('pcs', 'قطعة')}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.fabRed),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      SizedBox(width: 10),
                      Text('Saving...'),
                    ],
                  )
                : Text(s.t('Save product', 'حفظ المنتج')),
          ),
        ],
      ),
    );
  }

  double _unitsPerCarton() {
    if (packingDozen) return CatalogItem.dozenPieces;
    final n = double.tryParse(cartonQty.text) ?? 12;
    return n <= 0 ? 1 : n;
  }

  double _warehousePieces() {
    return CatalogItem.toBasePieces(
      pieces: double.tryParse(warehouseQty.text) ?? 0,
      cartons: 0,
      dozens: double.tryParse(warehouseDozens.text) ?? 0,
      unitsPerCarton: _unitsPerCarton(),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    if (name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final upc = _unitsPerCarton();
    final price = moneyRound(double.tryParse(sell.text) ?? 0);
    final costVal = moneyRound(double.tryParse(cost.text) ?? 0);
    final item = CatalogItem(
      id: _itemId,
      sku: sku.text.trim().isEmpty
          ? CatalogItem.nextProductCode(widget.billing.items, department)
          : sku.text.trim(),
      name: name.text.trim(),
      department: department,
      size: '',
      color: '',
      volume: department == ProductDept.perfume ? volume.text.trim() : '',
      unit: !pricePerPack ? 'pcs' : (packingDozen ? 'dozen' : 'carton'),
      purchaseCost: costVal,
      sellingPrice: price,
      unitsPerCarton: upc,
      cartonPrice: pricePerPack ? price : moneyRound(price * upc),
    );
    final s = widget.billing.s;
    try {
      await widget.billing.saveItem(
        item,
        opening: {
          StockLocation.warehouse: _warehousePieces(),
        },
      ).timeout(const Duration(seconds: 20));
    } on RbacException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } on TimeoutException {
      if (widget.billing.itemById(_itemId) == null) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('Saving took too long. Try again.', 'استغرق الحفظ وقتاً طويلاً. حاول مرة أخرى.'))),
        );
        return;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('Could not save this product. Try again.', 'تعذر حفظ المنتج. حاول مرة أخرى.'))),
      );
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    popAfterFrame(context);
    messenger.showSnackBar(
      SnackBar(content: Text(s.t('Product saved successfully!', 'تم حفظ المنتج بنجاح!'))),
    );
  }
}

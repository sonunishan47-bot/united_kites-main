import 'package:flutter/material.dart';

import '../models/crm.dart';
import '../models/enums.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/route_safety.dart';
import '../widgets/common.dart';
import '../widgets/vyapar.dart';
import 'shell.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final rows = [...billing.scopedExpenses]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final total = rows.fold<double>(0, (sum, e) => sum + e.amount);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(s.expenses)),
      floatingActionButton: billing.isPartner
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.fabRed,
              foregroundColor: Colors.white,
              onPressed: () => _add(context),
              icon: const Icon(Icons.add),
              label: Text(
                s.t('Add expense', 'إضافة مصروف'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          StatCard(
            label: s.t('Total expenses', 'إجمالي المصروفات'),
            value: sar.format(total),
            icon: Icons.local_gas_station_outlined,
            tint: AppTheme.fabRed,
          ),
          SectionHeader(s.t('Expense history', 'سجل المصروفات')),
          if (rows.isEmpty)
            EmptyHint(
              icon: Icons.receipt_long_outlined,
              message: s.t(
                'No expenses yet. Tap + to log fuel, allowance, or other costs.',
                'لا توجد مصروفات بعد. اضغط + لتسجيل الوقود أو البدل أو غيرها.',
              ),
            )
          else
            for (final e in rows) _ExpenseTile(expense: e),
        ],
      ),
    );
  }

  static String categoryLabel(dynamic s, String category) {
    return switch (category) {
      'fuel' => s.t('Fuel', 'وقود'),
      'allowance' => s.t('Allowance', 'بدل'),
      _ => s.t('Other', 'أخرى'),
    };
  }

  static IconData categoryIcon(String category) {
    return switch (category) {
      'fuel' => Icons.local_gas_station_outlined,
      'allowance' => Icons.payments_outlined,
      _ => Icons.receipt_outlined,
    };
  }

  static String vanLabel(String van) {
    return StockLocationX.fromId(van).label;
  }

  Future<void> _add(BuildContext context) async {
    final host = context;
    final billing = AppScope.read(host);
    final s = billing.s;
    final draft = await showModalBottomSheet<_ExpenseDraft>(
      context: host,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: _ExpenseForm(
            billing: billing,
            defaultVan: billing.isSalesman ? billing.session!.sellingLocation : StockLocation.van1,
          ),
        );
      },
    );
    await waitForOverlaySettle();
    if (!host.mounted || draft == null || draft.amount <= 0) return;
    await billing.addExpense(
      VanExpense(
        id: newId(),
        van: draft.van.name,
        category: draft.category,
        amount: draft.amount,
        note: draft.note,
      ),
    );
    await waitForOverlaySettle();
    if (!host.mounted) return;
    ScaffoldMessenger.of(host).showSnackBar(
      SnackBar(content: Text(s.t('Expense saved.', 'تم حفظ المصروف.'))),
    );
  }
}

class _ExpenseDraft {
  const _ExpenseDraft({required this.van, required this.category, required this.amount, required this.note});
  final StockLocation van;
  final String category;
  final double amount;
  final String note;
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({required this.billing, required this.defaultVan});

  final BillingController billing;
  final StockLocation defaultVan;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late StockLocation van;
  String category = 'fuel';
  late final TextEditingController amount;
  late final TextEditingController note;

  @override
  void initState() {
    super.initState();
    van = widget.defaultVan;
    amount = TextEditingController();
    note = TextEditingController();
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(amount.text.trim()) ?? 0;
    if (value <= 0) return;
    popAfterFrame(
      context,
      _ExpenseDraft(van: van, category: category, amount: value, note: note.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.billing.s;
    final salesman = widget.billing.isSalesman;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('Add expense', 'إضافة مصروف'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (!salesman)
              DropdownButtonFormField<StockLocation>(
                initialValue: van,
                decoration: InputDecoration(labelText: s.t('Van', 'فان')),
                items: const [
                  DropdownMenuItem(value: StockLocation.van1, child: Text('Van 1')),
                  DropdownMenuItem(value: StockLocation.van2, child: Text('Van 2')),
                ],
                onChanged: (v) => setState(() => van = v ?? van),
              ),
            if (!salesman) const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: InputDecoration(labelText: s.t('Category', 'الفئة')),
              items: [
                DropdownMenuItem(value: 'fuel', child: Text(s.t('Fuel', 'وقود'))),
                DropdownMenuItem(value: 'allowance', child: Text(s.t('Allowance', 'بدل'))),
                DropdownMenuItem(value: 'other', child: Text(s.t('Other', 'أخرى'))),
              ],
              onChanged: (v) => setState(() => category = v ?? category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: s.t('Amount (SAR)', 'المبلغ (ر.س)')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: InputDecoration(labelText: s.t('Notes', 'ملاحظات')),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.fabRed),
                onPressed: _submit,
                child: Text(s.t('Save expense', 'حفظ المصروف'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense});

  final VanExpense expense;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    return UkCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFFFEBEE),
            child: Icon(
              ExpensesScreen.categoryIcon(expense.category),
              color: AppTheme.fabRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ExpensesScreen.categoryLabel(s, expense.category),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ExpensesScreen.vanLabel(expense.van)} · ${dayTime.format(expense.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                if (expense.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    expense.note,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                  ),
                ],
              ],
            ),
          ),
          Text(
            sar.format(expense.amount),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

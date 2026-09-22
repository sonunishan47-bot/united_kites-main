import 'package:flutter/material.dart';

import '../models/crm.dart';
import '../models/enums.dart';
import '../services/pdf_service.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/route_safety.dart';
import '../widgets/common.dart';
import '../widgets/vyapar.dart';
import 'shell.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  late final TextEditingController _handover;
  late final TextEditingController _note;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    final billing = AppScope.of(context);
    final van = billing.isSalesman ? billing.session?.sellingLocation : null;
    _handover = TextEditingController(
      text: billing.dayClose(van: van ?? StockLocation.van1).netDeposit.toStringAsFixed(2),
    );
    _note = TextEditingController();
    _ready = true;
  }

  @override
  void dispose() {
    if (_ready) {
      _handover.dispose();
      _note.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final van = billing.isSalesman ? billing.session?.sellingLocation : null;
    final snap = billing.dayClose(van: van ?? (billing.isAdmin ? StockLocation.van1 : null));
    final loc = van ?? StockLocation.van1;
    final label = van?.label ?? loc.label;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: Text(s.t('Daily Closing', 'إقفال اليوم')),
        actions: [
          IconButton(
            tooltip: s.t('Share report', 'مشاركة التقرير'),
            onPressed: () => const PdfService().shareDayClose(
              snap: snap,
              settings: billing.settings,
              vanLabel: label,
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            s.t('End-of-day van reconciliation', 'مطابقة الفان نهاية اليوم'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            s.t('Shift: $label', 'الوردية: $label'),
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: s.t('Total cash sales', 'مبيعات الكاش'),
                  value: sar.format(snap.cashSales),
                  icon: Icons.payments_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: s.t('Credit / bank sales', 'مبيعات آجل / بنك'),
                  value: sar.format(snap.creditSales + snap.bankSales),
                  icon: Icons.account_balance_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: s.t('Bank sales', 'مبيعات البنك'),
                  value: sar.format(snap.bankSales),
                  icon: Icons.account_balance,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: s.t('Credit sales', 'مبيعات الآجل'),
                  value: sar.format(snap.creditSales),
                  icon: Icons.credit_card_outlined,
                  tint: AppTheme.fabRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: s.t('Approved expenses', 'المصروفات المعتمدة'),
                  value: sar.format(snap.expenses),
                  icon: Icons.local_gas_station_outlined,
                  tint: AppTheme.fabRed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatCard(
                  label: s.t('Remaining van stock value', 'قيمة مخزون الفان المتبقي'),
                  value: sar.format(snap.vanStockSell),
                  icon: Icons.local_shipping_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatCard(
            label: s.t('Credit collections', 'تحصيل الآجل'),
            value: sar.format(snap.creditCollections),
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 10),
          StatCard(
            label: s.t('Net cash to deposit at warehouse', 'صافي الكاش للتسليم للمستودع'),
            value: sar.format(snap.netDeposit),
            icon: Icons.savings_outlined,
            tint: const Color(0xFF15803D),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Text(
              s.t(
                'Cash sales + credit collections − approved expenses = net handover.',
                'مبيعات الكاش + تحصيل الآجل − المصروفات المعتمدة = صافي التسليم.',
              ),
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ),
          UkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _handover,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: s.t('Cash handed to warehouse (SAR)', 'الكاش المسلم للمستودع'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: s.t('Note (optional)', 'ملاحظة (اختياري)'),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: billing.isPartner
                        ? null
                        : () async {
                            final handed = double.tryParse(_handover.text) ?? 0;
                            try {
                              await billing.recordSettlement(
                                CashSettlement(
                                  id: newId(),
                                  van: loc.name,
                                  cashCollected: snap.cashCollected,
                                  outstandingDues: snap.outstandingDues,
                                  handedOver: handed,
                                  note: _note.text.trim(),
                                  salesTotal: snap.salesTotal,
                                  chequeCollected: snap.chequeCollected,
                                  bankSales: snap.bankSales,
                                  creditSales: snap.creditSales,
                                  expensesDeducted: snap.expenses,
                                  vanStockValue: snap.vanStockSell,
                                  netDeposit: snap.netDeposit,
                                ),
                              );
                            } on RbacException catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                              return;
                            }
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  s.t('Handover recorded.', 'تم تسجيل التسليم.'),
                                ),
                              ),
                            );
                            popAfterFrame(context);
                          },
                    child: Text(s.t('Confirm handover', 'تأكيد التسليم')),
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(s.t('Saved closing reports', 'تقارير الإقفال المحفوظة')),
          if (billing.settlements.isEmpty)
            UkCard(child: Text(s.t('No daily closings yet.', 'لا يوجد إقفال يومي بعد.'))),
          for (final row in billing.settlements)
            UkCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${sar.format(row.netDeposit != 0 ? row.netDeposit : row.handedOver)} · ${row.van}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${s.t('Cash', 'كاش')} ${sar.format(row.cashCollected)} · ${s.t('Bank', 'بنك')} ${sar.format(row.bankSales)} · ${s.t('Credit', 'آجل')} ${sar.format(row.creditSales)}\n'
                  '${s.t('Expenses', 'مصروفات')} ${sar.format(row.expensesDeducted)} · ${s.t('Van stock', 'مخزون الفان')} ${sar.format(row.vanStockValue)}\n'
                  '${s.t('Handed', 'مسلم')} ${sar.format(row.handedOver)} · ${dayTime.format(row.createdAt)}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

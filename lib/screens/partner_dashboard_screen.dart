import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/vyapar.dart';
import 'shell.dart';

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  bool todayOnly = true;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final snap = billing.profit(todayOnly: todayOnly);
    final sharePct = billing.settings.partnerSharePct.clamp(0, 100);
    final partnerCut = billing.partnerShareOf(snap.net);
    final houseCut = moneyRound(snap.net - partnerCut);
    final marginPct = snap.revenue <= 0 ? 0.0 : moneyRound(snap.net / snap.revenue * 100);
    final godown = billing.vanStockValue(StockLocation.warehouse, atCost: true);
    final dues = billing.customers
        .map((c) => (customer: c, due: billing.customerDue(c.id)))
        .where((row) => row.due > 0.009)
        .toList()
      ..sort((a, b) => b.due.compareTo(a.due));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        VyaparOverview(billing: billing),
        Text(
          s.t('Partner dashboard', 'لوحة الشريك'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          s.t(
            'Business totals only. Maps, GPS, and route planning are hidden for this role.',
            'أرقام الأعمال فقط. الخرائط وتتبع GPS والمسار مخفية لهذا الدور.',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(s.live)),
            Chip(label: Text(billing.usingSupabase ? 'Supabase' : s.t('Local cache', 'محلي'))),
            LocaleToggleButton(billing),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(s.t('Today', 'اليوم'))),
            ButtonSegment(value: false, label: Text(s.t('All time', 'كل الفترات'))),
          ],
          selected: {todayOnly},
          onSelectionChanged: (set) => setState(() => todayOnly = set.first),
        ),
        const SizedBox(height: 16),
        StatCard(
          label: s.t('Total sales', 'إجمالي المبيعات'),
          value: sar.format(snap.revenue),
          icon: Icons.trending_up,
        ),
        const SizedBox(height: 8),
        StatCard(
          label: s.t('Purchase costs (COGS)', 'تكاليف الشراء'),
          value: sar.format(snap.cogs),
          icon: Icons.shopping_bag_outlined,
        ),
        const SizedBox(height: 8),
        StatCard(
          label: s.t('Net profit margin', 'هامش صافي الربح'),
          value: '${sar.format(snap.net)}  (${marginPct.toStringAsFixed(2)}%)',
          icon: Icons.savings_outlined,
        ),
        const SizedBox(height: 8),
        UkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('Partner profit-sharing split', 'توزيع أرباح الشريك'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                s.t(
                  'Partner ${sharePct.toStringAsFixed(0)}%  ·  House ${(100 - sharePct).toStringAsFixed(0)}%',
                  'الشريك ${sharePct.toStringAsFixed(0)}٪  ·  الشركة ${(100 - sharePct).toStringAsFixed(0)}٪',
                ),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 10),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.t('Partner share', 'حصة الشريك')),
                trailing: MoneyText(partnerCut),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(s.t('House share', 'حصة الشركة')),
                trailing: MoneyText(houseCut),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        StatCard(
          label: s.t('Godown inventory valuation', 'تقييم مخزون المستودع'),
          value: sar.format(godown),
          icon: Icons.warehouse_outlined,
        ),
        const SizedBox(height: 8),
        StatCard(
          label: s.t("You'll Get", 'ستحصل'),
          value: sar.format(snap.dues),
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 16),
        Text(
          s.t('Salesman collection summaries', 'ملخص تحصيل المناديب'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        UkCard(
          child: Column(
            children: [
              for (final van in [StockLocation.van1, StockLocation.van2])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.local_shipping_outlined, color: AppTheme.navy),
                  title: Text(van.label),
                  subtitle: Text(
                    s.t(
                      'Sales ${sar.format(billing.salesFor(van, todayOnly: todayOnly))}',
                      'مبيعات ${sar.format(billing.salesFor(van, todayOnly: todayOnly))}',
                    ),
                  ),
                  trailing: MoneyText(billing.collectionsToday(van: van)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          s.t('Customer debt ledger', 'دفتر ديون العملاء'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (dues.isEmpty)
          EmptyHint(
            icon: Icons.check_circle_outline,
            message: s.t('No open customer dues.', 'لا توجد ديون مفتوحة.'),
          )
        else
          UkCard(
            child: Column(
              children: [
                for (final row in dues.take(40))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(row.customer.name),
                    subtitle: Text(
                      row.customer.shopName.isEmpty ? row.customer.phone : row.customer.shopName,
                    ),
                    trailing: MoneyText(row.due),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

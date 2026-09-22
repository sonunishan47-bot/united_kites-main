import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../services/analytics_engine.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/vyapar.dart';
import 'shell.dart';
import 'pending_approvals_screen.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final today = billing.profit(todayOnly: true);
    final all = billing.profit(todayOnly: false);
    final signals = const AnalyticsEngine().movement(
      items: billing.items,
      invoices: billing.scopedInvoices,
      onHand: (id) {
        if (billing.isSalesman) {
          return billing.stockAt(billing.session!.sellingLocation, id).quantity;
        }
        return StockLocation.values
            .where((loc) => loc != StockLocation.damage)
            .fold(0, (sum, loc) => sum + billing.stockAt(loc, id).quantity);
      },
    );
    final fast = signals.where((x) => x.kind == 'fast').take(5);
    final dead = signals.where((x) => x.kind == 'dead').take(5);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        VyaparOverview(billing: billing),
        if (billing.isAdmin) ...[
          SectionHeader(s.t('Pending Approvals', 'الاعتمادات المعلقة')),
          UkCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PendingApprovalsScreen()),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined, color: Color(0xFFE53935)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    billing.pendingReturnCount == 0
                        ? s.t('No pending sales returns', 'لا توجد مرتجعات معلّقة')
                        : billing.pendingReturnCount == 1
                            ? s.t('1 Request Pending', 'طلب واحد معلّق')
                            : s.t(
                                '${billing.pendingReturnCount} Requests Pending',
                                '${billing.pendingReturnCount} طلبات معلّقة',
                              ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (billing.canSeeCosts) ...[
        SectionHeader(s.profitLoss),
        StatCard(
          label: s.t('Revenue − COGS − van expenses − commission', 'الإيراد − التكلفة − مصروف الفان − العمولة'),
          value: sar.format(today.net),
          icon: Icons.savings_outlined,
        ),
        ],
        Row(
          children: [
            Expanded(
              child: StatCard(
                label: s.t('Collections', 'التحصيل'),
                value: sar.format(today.collections),
                icon: Icons.payments_outlined,
              ),
            ),
          ],
        ),
        if (billing.canSeeCosts) ...[
        StatCard(label: s.t('Purchase cost (COGS)', 'تكلفة البضاعة'), value: sar.format(today.cogs), icon: Icons.shopping_bag_outlined),
        StatCard(label: s.t('Fuel / allowance', 'وقود / بدل'), value: sar.format(today.expenses), icon: Icons.local_gas_station_outlined),
        StatCard(
          label: '${s.t('Commission', 'عمولة')} ${billing.settings.commissionRate.toStringAsFixed(0)}%',
          value: sar.format(today.commission),
          icon: Icons.badge_outlined,
        ),
        StatCard(label: s.t('All-time net', 'صافي تراكمي'), value: sar.format(all.net), icon: Icons.timeline),
        SectionHeader(s.t('Van commission', 'عمولة الفان')),
        UkCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Van 1'),
                trailing: MoneyText(billing.salesmanCommission(StockLocation.van1)),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Van 2'),
                trailing: MoneyText(billing.salesmanCommission(StockLocation.van2)),
              ),
            ],
          ),
        ),
        ],
        if (billing.isSalesman)
          StatCard(
            label: s.t("Today's sales volume", 'حجم مبيعات اليوم'),
            value: sar.format(billing.salesFor(billing.session?.sellingLocation, todayOnly: true)),
            icon: Icons.trending_up_rounded,
          ),
        SectionHeader(s.t('Fast-moving products (30 days)', 'المنتجات سريعة الحركة')),
        ...fast.map(
          (x) => UkCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_fire_department_outlined, color: Color(0xFFE65100)),
              title: Text('${x.item.name} · ${x.item.variantLabel}'),
              subtitle: Text(s.t('Sold ${x.sold.toStringAsFixed(0)}', 'مباع ${x.sold.toStringAsFixed(0)}')),
            ),
          ),
        ),
        SectionHeader(s.t('Dead stock', 'راكد')),
        ...dead.map(
          (x) => UkCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text('${x.item.name} · ${x.item.variantLabel}'),
              subtitle: Text(
                s.t(
                  'On hand ${x.onHand.toStringAsFixed(0)}, no recent sales',
                  'رصيد ${x.onHand.toStringAsFixed(0)} بدون مبيعات',
                ),
              ),
            ),
          ),
        ),
        SectionHeader(s.t('Promo schemes', 'عروض الكمية')),
        ...billing.promos.map(
          (p) => UkCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.name),
              subtitle: Text(
                s.t(
                  'From ${p.minPieces.toStringAsFixed(0)} pcs · ${p.discountPct.toStringAsFixed(0)}% off · sample ${p.sampleQty.toStringAsFixed(0)}',
                  'من ${p.minPieces.toStringAsFixed(0)} قطعة · خصم ${p.discountPct.toStringAsFixed(0)}٪ · عينة ${p.sampleQty.toStringAsFixed(0)}',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

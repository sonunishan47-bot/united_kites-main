import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'shell.dart';

class VanReportsScreen extends StatelessWidget {
  const VanReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Van sales & revenue', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final van in const [StockLocation.van1, StockLocation.van2]) ...[
          Text(van.label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          StatCard(
            label: "Today's sales",
            value: sar.format(billing.salesFor(van, todayOnly: true)),
            icon: Icons.today_outlined,
          ),
          const SizedBox(height: 8),
          StatCard(
            label: 'All-time sales',
            value: sar.format(billing.salesFor(van)),
            icon: Icons.payments_outlined,
          ),
          const SizedBox(height: 8),
          StatCard(
            label: 'Credit notes',
            value: sar.format(billing.creditsFor(van)),
            icon: Icons.keyboard_return,
          ),
          const SizedBox(height: 8),
          StatCard(
            label: 'Live van stock (sell)',
            value: sar.format(billing.vanStockValue(van, atCost: false)),
            icon: Icons.inventory_2_outlined,
          ),
          const SizedBox(height: 16),
          ...billing.invoices.where((i) => i.location == van).take(6).map(
                (inv) => ListTile(
                  dense: true,
                  title: Text('${inv.invoiceNo} · ${inv.docType == DocType.creditNote ? 'CN' : 'INV'}'),
                  trailing: MoneyText(inv.grandTotal),
                ),
              ),
          const Divider(),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'analytics_screen.dart';
import 'crm_screen.dart';
import 'expenses_screen.dart';
import 'inventory_screen.dart';
import 'invoices_screen.dart';
import 'print_setup_screen.dart';
import 'returns_screen.dart';
import 'shell.dart';
import 'van_loading_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final entries = <_MoreEntry>[
      _MoreEntry(s.bills, Icons.receipt_long_outlined, const InvoicesScreen()),
      _MoreEntry(s.crm, Icons.storefront_outlined, const CrmScreen()),
      if (!billing.isPartner)
        _MoreEntry(s.t('Returns', 'مرتجعات'), Icons.assignment_return_outlined, const ReturnsScreen()),
      if (billing.isAdmin || billing.isPartner)
        _MoreEntry(s.stock, Icons.warehouse_outlined, const InventoryScreen()),
      if (billing.isSalesman)
        _MoreEntry(s.vanStock, Icons.inventory_2_outlined, const InventoryScreen()),
      if (billing.isAdmin)
        _MoreEntry(s.load, Icons.local_shipping_outlined, const VanLoadingScreen()),
      if (billing.isAdmin || billing.isPartner)
        _MoreEntry(s.analytics, Icons.insights_outlined, const AnalyticsScreen()),
      if (!billing.isPartner)
        _MoreEntry(s.expenses, Icons.local_gas_station_outlined, const ExpensesScreen()),
      if (billing.isAdmin)
        _MoreEntry(s.print, Icons.print_outlined, const PrintSetupScreen()),
    ];

    return ColoredBox(
      color: AppTheme.canvas,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Material(
            color: Colors.white,
            elevation: 1,
            shadowColor: const Color(0x140F172A),
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: Icon(entry.icon, color: AppTheme.accent),
              title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(entry.title)),
                    body: entry.page,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MoreEntry {
  const _MoreEntry(this.title, this.icon, this.page);

  final String title;
  final IconData icon;
  final Widget page;
}

import 'package:flutter/material.dart';

import 'analytics_screen.dart';
import 'partner_dashboard_screen.dart';
import 'shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    if (billing.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (billing.isPartner) {
      return const PartnerDashboardScreen();
    }
    return const AnalyticsScreen();
  }
}

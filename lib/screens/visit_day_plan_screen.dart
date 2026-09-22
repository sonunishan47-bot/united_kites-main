import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/crm.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/route_safety.dart';
import '../widgets/vyapar.dart';
import 'invoice_editor_screen.dart';
import 'shell.dart';

const _nonSaleReasons = [
  'Stock Full',
  'Shop Closed',
  'No Need',
  'Competitor',
  'Owner Absent',
  'Other',
];

class VisitDayPlanScreen extends StatelessWidget {
  const VisitDayPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final today = DateTime.now();
    bool sameDay(DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;
    final visited = billing.visits.where((v) => sameDay(v.createdAt)).map((v) => v.customerId).toSet();

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(s.t('Route & day plan', 'خطة المسار واليوم'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            s.t('Today’s customer calls', 'زيارات العملاء اليوم'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            s.t(
              'Log GPS when you invoice or record a non-sale visit.',
              'يُسجل الموقع عند الفاتورة أو عند زيارة بلا بيع.',
            ),
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          if (billing.customers.isEmpty)
            UkCard(child: Text(s.t('No customers on file.', 'لا يوجد عملاء.'))),
          for (final customer in billing.customers)
            UkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(customer.display, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${customer.address.isEmpty ? customer.phone : customer.address}\n'
                      '${s.t('Due', 'مستحق')} ${sar.format(billing.customerDue(customer.id))}'
                      '${visited.contains(customer.id) ? ' · ${s.t('Visited', 'تمت الزيارة')}' : ''}',
                    ),
                    trailing: visited.contains(customer.id)
                        ? const Icon(Icons.check_circle, color: Color(0xFF16A34A))
                        : const Icon(Icons.storefront_outlined),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (!billing.isPartner)
                        FilledButton.tonal(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => InvoiceEditorScreen(
                                controller: billing,
                                forCustomer: customer,
                              ),
                            ),
                          ),
                          child: Text(s.t('Start sale', 'بدء بيع')),
                        ),
                      if (!billing.isPartner)
                        OutlinedButton(
                          onPressed: () => _nonSale(context, billing, customer),
                          child: Text(s.t('Non-sale visit', 'زيارة بلا بيع')),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          SectionHeader(s.t('Visit log', 'سجل الزيارات')),
          if (billing.visits.isEmpty)
            UkCard(child: Text(s.t('No visits logged yet.', 'لا توجد زيارات بعد.'))),
          for (final visit in billing.visits.take(40))
            UkCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${billing.customerById(visit.customerId)?.display ?? visit.customerId} · ${visit.outcome}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${visit.reason.isEmpty ? '' : '${visit.reason} · '}'
                  '${visit.lat.abs() > 0.01 ? '${visit.lat.toStringAsFixed(4)}, ${visit.lng.toStringAsFixed(4)} · ' : ''}'
                  '${dayTime.format(visit.createdAt)}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _nonSale(BuildContext context, BillingController billing, Customer customer) async {
    var reason = _nonSaleReasons.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(billing.s.t('Non-sale reason', 'سبب عدم البيع')),
              content: DropdownButtonFormField<String>(
                initialValue: reason,
                items: [
                  for (final r in _nonSaleReasons) DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) => setLocal(() => reason = v ?? reason),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(billing.s.t('Cancel', 'إلغاء'))),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(billing.s.t('Save visit', 'حفظ الزيارة'))),
              ],
            );
          },
        );
      },
    );
    if (ok != true) return;
    await waitForOverlaySettle();
    if (!context.mounted) return;
    var lat = 0.0;
    var lng = 0.0;
    try {
      final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 4));
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}
    try {
      await billing.addVisit(
        VisitLog(
          id: newId(),
          customerId: customer.id,
          van: billing.session?.sellingLocation.name ?? 'van1',
          outcome: 'nonsale',
          reason: reason,
          lat: lat,
          lng: lng,
        ),
      );
    } on RbacException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

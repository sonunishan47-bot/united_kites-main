import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/company_header.dart';
import '../widgets/vyapar.dart';
import 'analytics_screen.dart';
import 'business_profile_screen.dart';
import 'customer_ledger_screen.dart';
import 'invoice_editor_screen.dart';
import 'invoices_screen.dart';
import 'pending_approvals_screen.dart';
import 'settings_hub_screen.dart';
import 'shell.dart';

enum _TxnFilter { all, unpaid, today, returns }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool txnTab = true;
  String query = '';
  _TxnFilter filter = _TxnFilter.all;

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    if (billing.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ColoredBox(
      color: AppTheme.canvas,
      child: Column(
        children: [
          VyaparCompanyBar(
            settings: billing.settings,
            fallbackName: s.app,
            onProfile: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BusinessProfileScreen()),
            ),
            onSettings: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsHubScreen()),
            ),
            extraAction: const PendingApprovalsBell(),
            onAlerts: () => _openTelegramAlerts(context),
          ),
          VyaparToggleTabs(
            left: s.txnDetails,
            right: s.partyDetails,
            selectedLeft: txnTab,
            onChanged: (left) => setState(() => txnTab = left),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 108),
              children: [
                if (billing.settings.options.paymentReminders) _ReminderBanner(),
                _QuickLinksRow(),
                const SizedBox(height: 12),
                _SearchFilterBar(
                  hint: txnTab ? s.searchTxn : s.searchParty,
                  onQuery: (value) => setState(() => query = value),
                  onFilter: txnTab ? () => _pickFilter(context) : null,
                ),
                const SizedBox(height: 12),
                if (txnTab) ..._txnFeed(context) else ..._partyFeed(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _txnFeed(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final today = DateTime.now();
    final q = query.trim().toLowerCase();
    final rows = billing.scopedInvoices.where((inv) {
      if (filter == _TxnFilter.unpaid && !inv.isDue) return false;
      if (filter == _TxnFilter.returns && !inv.isCreditNote) return false;
      if (filter == _TxnFilter.today &&
          (inv.createdAt.year != today.year ||
              inv.createdAt.month != today.month ||
              inv.createdAt.day != today.day)) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay =
          '${inv.shopName} ${inv.customerName} ${inv.invoiceNo} ${inv.customerPhone}'.toLowerCase();
      return hay.contains(q);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (rows.isEmpty) {
      return [
        UkCard(
          child: Text(
            s.t('No invoices yet.', 'لا توجد فواتير بعد.'),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }
    return [for (final invoice in rows) InvoiceTxnCard(invoice: invoice)];
  }

  List<Widget> _partyFeed(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final q = query.trim().toLowerCase();
    final rows = billing.customers.where((c) {
      if (q.isEmpty) return true;
      final hay = '${c.name} ${c.phone} ${c.shopName} ${c.address} ${c.vatNumber} ${c.crNumber}'.toLowerCase();
      return hay.contains(q);
    }).toList()
      ..sort((a, b) {
        final ia = billing.latestInvoiceFor(a.id);
        final ib = billing.latestInvoiceFor(b.id);
        if (ia != null && ib != null) return ib.createdAt.compareTo(ia.createdAt);
        if (ia != null) return -1;
        if (ib != null) return 1;
        return billing.customers.indexOf(a).compareTo(billing.customers.indexOf(b));
      });

    if (rows.isEmpty) {
      return [
        UkCard(
          child: Text(
            s.t('No customers yet.', 'لا يوجد عملاء بعد.'),
            textAlign: TextAlign.center,
          ),
        ),
      ];
    }

    return [
      for (final customer in rows)
        UkCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CustomerLedgerScreen(customerId: customer.id),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name.isNotEmpty ? customer.name : customer.display,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    if (customer.phone.isNotEmpty)
                      Text(customer.phone, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    if (customer.vatNumber.isNotEmpty || customer.crNumber.isNotEmpty)
                      Text(
                        [
                          if (customer.vatNumber.isNotEmpty) 'VAT ${customer.vatNumber}',
                          if (customer.crNumber.isNotEmpty) 'CR ${customer.crNumber}',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    if (customer.address.isNotEmpty || customer.hasGps)
                      Text(
                        customer.address.isNotEmpty
                            ? customer.address
                            : '${customer.lat.toStringAsFixed(5)}, ${customer.lng.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Builder(
                    builder: (context) {
                      final balance = billing.customerBalance(customer.id);
                      final youPay = balance < -0.05;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            youPay ? s.t("You'll Pay", 'ستدفع') : s.t("You'll Get", 'ستحصل'),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          Text(
                            formatSarRs(youPay ? -balance : balance),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: youPay ? const Color(0xFF15803D) : AppTheme.fabRed,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  Future<void> _pickFilter(BuildContext context) async {
    final s = AppScope.of(context).s;
    final picked = await showModalBottomSheet<_TxnFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        Widget tile(String label, _TxnFilter value) {
          return ListTile(
            title: Text(label),
            trailing: filter == value ? const Icon(Icons.check, color: AppTheme.fabRed) : null,
            onTap: () => Navigator.pop(context, value),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(s.t('All transactions', 'كل العمليات'), _TxnFilter.all),
              tile(s.t('Today', 'اليوم'), _TxnFilter.today),
              tile(s.t('Unpaid / balance', 'غير مدفوع'), _TxnFilter.unpaid),
              tile(s.t('Returns', 'مرتجعات'), _TxnFilter.returns),
            ],
          ),
        );
      },
    );
    if (picked != null) setState(() => filter = picked);
  }

  Future<void> _openTelegramAlerts(BuildContext context) async {
    final billing = AppScope.of(context);
    final s = billing.s;
    final overdue = billing.customers.where((c) => billing.customerDue(c.id) > 0.05).toList();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.t('Notifications', 'التنبيهات'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  overdue.isEmpty
                      ? s.t('No outstanding party balances.', 'لا توجد أرصدة مستحقة.')
                      : s.t(
                          '${overdue.length} parties with open balance',
                          '${overdue.length} عملاء برصيد مستحق',
                        ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final uri = Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(billing.settings.displayName)}');
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.telegram),
                  label: Text(s.t('Open Telegram', 'فتح تليجرام')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickLinksRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    return Row(
      children: [
        Expanded(
          child: QuickLinkTile(
            label: s.addTxn,
            icon: Icons.add,
            background: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1A73E8),
            onTap: billing.isPartner
                ? () {}
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => InvoiceEditorScreen(controller: billing),
                      ),
                    ),
          ),
        ),
        Expanded(
          child: QuickLinkTile(
            label: s.saleReport,
            icon: Icons.assignment_outlined,
            background: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF7B1FA2),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(s.saleReport)),
                  body: const AnalyticsScreen(),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: QuickLinkTile(
            label: s.dayBook,
            icon: Icons.menu_book_outlined,
            background: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(s.dayBook)),
                  body: const InvoicesScreen(todayOnly: true),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: QuickLinkTile(
            label: s.profitLoss,
            icon: Icons.swap_vert_rounded,
            background: const Color(0xFFFFEBEE),
            iconColor: AppTheme.fabRed,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(s.profitLoss)),
                  body: const AnalyticsScreen(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchFilterBar extends StatelessWidget {
  const _SearchFilterBar({
    required this.hint,
    required this.onQuery,
    this.onFilter,
  });

  final String hint;
  final ValueChanged<String> onQuery;
  final VoidCallback? onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onQuery,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        ),
        if (onFilter != null)
          IconButton(
            onPressed: onFilter,
            icon: const Icon(Icons.tune, color: Color(0xFF334155)),
          ),
      ],
    );
  }
}

class _ReminderBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final days = billing.settings.options.reminderDays;
    final overdue = billing.customers.where((c) {
      final due = billing.customerDue(c.id);
      if (due <= 0.05) return false;
      final inv = billing.latestInvoiceFor(c.id);
      if (inv == null) return false;
      return DateTime.now().difference(inv.createdAt).inDays >= days;
    }).toList();
    if (overdue.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UkCard(
        child: Text(
          billing.s.t(
            '${overdue.length} collection reminder(s) · $days+ days overdue',
            '${overdue.length} تذكير تحصيل · أكثر من $days يوم',
          ),
          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
        ),
      ),
    );
  }
}

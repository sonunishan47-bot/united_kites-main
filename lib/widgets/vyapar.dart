import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class UkCard extends StatelessWidget {
  const UkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: onTap == null
          ? body
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: body,
              ),
            ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.paid,
  });

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone.foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

enum BadgeTone {
  sale(Color(0xFF2E7D32), Color(0xFFFFFFFF)),
  paid(Color(0xFFE8F5E9), Color(0xFF2E7D32)),
  due(Color(0xFFFFEBEE), Color(0xFFC62828)),
  partial(Color(0xFFFFF3E0), Color(0xFFE65100)),
  credit(Color(0xFFFFF3E0), Color(0xFFE65100)),
  info(Color(0xFFE3F2FD), Color(0xFF1565C0));

  const BadgeTone(this.background, this.foreground);
  final Color background;
  final Color foreground;
}

class QuickLinkTile extends StatelessWidget {
  const QuickLinkTile({
    super.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: const Color(0x140F172A),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TxnSideActions extends StatelessWidget {
  const TxnSideActions({
    super.key,
    required this.onPrint,
    required this.onShare,
    required this.onPdf,
    required this.onMenu,
  });

  final VoidCallback onPrint;
  final VoidCallback onShare;
  final VoidCallback onPdf;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconBtn(Icons.print_outlined, const Color(0xFF1A73E8), onPrint),
        _iconBtn(Icons.chat, const Color(0xFF25D366), onShare),
        InkWell(
          onTap: onPdf,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.fabRed,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        _iconBtn(Icons.more_vert, const Color(0xFF64748B), onMenu),
      ],
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
      icon: Icon(icon, size: 22, color: color),
    );
  }
}

class TxnActionBar extends StatelessWidget {
  const TxnActionBar({
    super.key,
    required this.onPrint,
    required this.onShare,
    required this.onPdf,
  });

  final VoidCallback onPrint;
  final VoidCallback onShare;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    return TxnSideActions(
      onPrint: onPrint,
      onShare: onShare,
      onPdf: onPdf,
      onMenu: () {},
    );
  }
}

class VyaparToggleTabs extends StatelessWidget {
  const VyaparToggleTabs({
    super.key,
    required this.left,
    required this.right,
    required this.selectedLeft,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool selectedLeft;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.card,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(child: _tab(left, selectedLeft, () => onChanged(true))),
            Expanded(child: _tab(right, !selectedLeft, () => onChanged(false))),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppTheme.accent,
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}

class VyaparOverview extends StatelessWidget {
  const VyaparOverview({super.key, required this.billing});

  final BillingController billing;

  @override
  Widget build(BuildContext context) {
    final s = billing.s;
    final close = billing.dayClose();
    final stockLoc = billing.isSalesman && billing.session != null
        ? billing.session!.sellingLocation
        : StockLocation.warehouse;
    final stockValue = billing.vanStockValue(stockLoc, atCost: true);
    final itemCount = billing.stockedProductCount(stockLoc);
    final pieces = billing.stockPieceCount(stockLoc);
    final months = _monthSales(billing);
    final peak = months.fold<double>(1, (max, row) => row.amount > max ? row.amount : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _statBox(
                s.t("You'll Get", 'ستحصل'),
                sar.format(billing.totalDues),
                AppTheme.fabRed,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statBox(
                s.t("You'll Give", 'ستدفع'),
                sar.format(billing.totalPayable),
                const Color(0xFF15803D),
              ),
            ),
          ],
        ),
        UkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('Sale Overview', 'نظرة المبيعات'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                s.t(
                  'This month ${sar.format(months.last.amount)} · Last month ${sar.format(months[months.length - 2].amount)}',
                  'هذا الشهر ${sar.format(months.last.amount)} · الشهر الماضي ${sar.format(months[months.length - 2].amount)}',
                ),
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final row in months)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const SizedBox(height: 4),
                              Container(
                                height: 6 + (72 * (row.amount / peak)),
                                decoration: BoxDecoration(
                                  color: row == months.last ? AppTheme.accent : const Color(0xFF90CAF9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(row.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _statBox(
                s.t('Expenses', 'المصروفات'),
                sar.format(close.expenses),
                const Color(0xFF6D4C41),
                hint: s.t('Today', 'اليوم'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statBox(
                s.t('Cash in Hand', 'النقدية'),
                sar.format(billing.cashInHand),
                AppTheme.accent,
              ),
            ),
          ],
        ),
        UkCard(
          child: Row(
            children: [
              Expanded(
                child: _statColumn(
                  s.t('Stock Value', 'قيمة المخزون'),
                  billing.canSeeCosts ? sar.format(stockValue) : '—',
                ),
              ),
              Expanded(
                child: _statColumn(
                  s.t('Items', 'الأصناف'),
                  '$itemCount',
                ),
              ),
              Expanded(
                child: _statColumn(
                  s.t('Stock', 'المخزون'),
                  pieces.toStringAsFixed(pieces == pieces.roundToDouble() ? 0 : 1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color, {String? hint}) {
    return UkCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          if (hint != null)
            Text(hint, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _MonthBar {
  const _MonthBar(this.label, this.amount);
  final String label;
  final double amount;
}

List<_MonthBar> _monthSales(BillingController billing) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final now = DateTime.now();
  final rows = <_MonthBar>[];
  for (var back = 5; back >= 0; back--) {
    final month = DateTime(now.year, now.month - back, 1);
    var halalas = 0;
    for (final inv in billing.scopedInvoices) {
      if (inv.docType != DocType.taxInvoice) continue;
      if (inv.createdAt.year != month.year || inv.createdAt.month != month.month) continue;
      halalas += toHalalas(inv.grandTotal);
    }
    rows.add(_MonthBar(names[month.month - 1], fromHalalas(halalas)));
  }
  return rows;
}

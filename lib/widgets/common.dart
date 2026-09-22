import 'package:flutter/material.dart';

import '../state/billing_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/route_safety.dart';
import 'vyapar.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(this.value, {super.key, this.style, this.color});

  final double value;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      sar.format(value),
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return UkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tint ?? AppTheme.navy),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class LocaleToggleButton extends StatelessWidget {
  const LocaleToggleButton(this.billing, {super.key});

  final BillingController billing;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        final next = billing.localeCode.startsWith('ar')
            ? 'ml'
            : billing.localeCode.startsWith('ml')
                ? 'en'
                : 'ar';
        billing.setLocale(next);
      },
      child: Text(
        billing.s.isAr
            ? billing.s.languageMl
            : billing.s.isMl
                ? billing.s.languageEn
                : billing.s.languageAr,
      ),
    );
  }
}

Future<bool> confirmAdminPin(BuildContext context, String expected) async {
  final pin = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Admin PIN'),
      content: TextField(
        controller: pin,
        obscureText: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'PIN'),
        onSubmitted: (_) => Navigator.pop(context, true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unlock')),
      ],
    ),
  );
  final match = ok == true && pin.text.trim() == expected.trim();
  await waitForOverlaySettle();
  pin.dispose();
  return match;
}

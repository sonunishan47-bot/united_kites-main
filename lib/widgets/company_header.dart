import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/shop_settings.dart';
import '../theme/app_theme.dart';

const kAppBrandLogoAsset = 'assets/logo.jpg';

class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.size = 36,
    this.borderRadius = 10,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        kAppBrandLogoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          color: const Color(0xFFF8FAFC),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.hexagon_outlined, size: size * 0.45, color: AppTheme.navy),
          ),
        ),
      ),
    );
  }
}

class CompanyLogoAvatar extends StatelessWidget {
  const CompanyLogoAvatar({
    super.key,
    required this.settings,
    this.radius = 18,
  });

  final ShopSettings settings;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = settings.logoBytes;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE8EEF4),
      child: bytes != null && bytes.isNotEmpty
          ? ClipOval(
              child: Image.memory(
                bytes,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
              ),
            )
          : Text(
              _initials(settings.shopName),
              style: TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.7,
              ),
            ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters;
  }
}

class VyaparCompanyBar extends StatelessWidget {
  const VyaparCompanyBar({
    super.key,
    required this.settings,
    required this.fallbackName,
    required this.onProfile,
    required this.onSettings,
    this.onAlerts,
    this.extraAction,
  });

  final ShopSettings settings;
  final String fallbackName;
  final VoidCallback onProfile;
  final VoidCallback onSettings;
  final VoidCallback? onAlerts;
  final Widget? extraAction;

  @override
  Widget build(BuildContext context) {
    final name = settings.displayName.trim().isEmpty ? fallbackName : settings.displayName;
    return Material(
      color: AppTheme.card,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onProfile,
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      settings.logoBytes != null && settings.logoBytes!.isNotEmpty
                          ? CompanyLogoAvatar(settings: settings, radius: 20)
                          : const AppBrandLogo(size: 40, borderRadius: 10),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: onSettings,
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF334155)),
              ),
              ?extraAction,
              if (onAlerts != null)
                IconButton(
                  tooltip: 'Telegram',
                  onPressed: onAlerts,
                  icon: const Icon(Icons.telegram, color: Color(0xFF229ED9), size: 28),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompanyHeaderButton extends StatelessWidget {
  const CompanyHeaderButton({
    super.key,
    required this.settings,
    required this.appTitle,
    required this.onTap,
  });

  final ShopSettings settings;
  final String appTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            const AppBrandLogo(size: 36, borderRadius: 10),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    appTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.15,
                    ),
                  ),
                  if (settings.shopName.trim().isNotEmpty)
                    Text(
                      settings.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }
}

ImageProvider? signatureImageProvider(String base64) {
  if (base64.trim().isEmpty) return null;
  try {
    return MemoryImage(base64Decode(base64.trim()));
  } catch (_) {
    return null;
  }
}

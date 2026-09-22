import 'package:flutter/material.dart';

import '../screens/shell.dart';
import '../theme/app_theme.dart';
import 'vyapar.dart';

class CloudSyncCard extends StatelessWidget {
  const CloudSyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    final billing = AppScope.of(context);
    final s = billing.s;
    final offline = billing.pendingCloudSync;
    final cloud = billing.usingSupabase;
    final status = !cloud
        ? s.t('Local save only', 'حفظ محلي فقط')
        : offline
            ? s.t('Offline — pending upload', 'غير متصل — بانتظار الرفع')
            : s.t('Online — data synced', 'متصل — البيانات مزامنة');
    final color = !cloud
        ? const Color(0xFF64748B)
        : offline
            ? const Color(0xFFB45309)
            : const Color(0xFF15803D);

    return UkCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(
              !cloud
                  ? Icons.phone_android_outlined
                  : offline
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('Cloud sync', 'مزامنة السحابة'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(status, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size(88, 40),
            ),
            onPressed: billing.syncing
                ? null
                : () async {
                    final ok = await billing.syncNow();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? s.t('Sync complete.', 'اكتملت المزامنة.')
                              : s.t(
                                  'Saved on this device. Cloud upload will retry.',
                                  'حُفظ على الجهاز. ستُعاد محاولة الرفع.',
                                ),
                        ),
                      ),
                    );
                  },
            child: billing.syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(s.t('Sync', 'مزامنة'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../providers/router_provider.dart';
import '../services/hilink_api_service.dart';
import '../theme/app_theme.dart';

final routerStatusProvider = FutureProvider.autoDispose<RouterStatus>((ref) async {
  final service = ref.watch(hilinkServiceProvider);
  return service.fetchStatus();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceListProvider);
    final statusAsync = ref.watch(routerStatusProvider);
    final connected = devices.length;
    final blocked = devices.where((d) => d.isBlocked).length;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await ref.read(deviceListProvider.notifier).refresh();
          ref.invalidate(routerStatusProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('أهلاً بيك 👋',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('لوحة تحكم الراوتر (HiLink)',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _StatusCard(statusAsync: statusAsync),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _StatTile(
                        label: 'أجهزة متصلة',
                        value: '$connected',
                        color: AppColors.success)),
                const SizedBox(width: 12),
                Expanded(
                    child: _StatTile(
                        label: 'أجهزة محظورة',
                        value: '$blocked',
                        color: AppColors.danger)),
              ],
            ),
            const SizedBox(height: 20),
            Text('إجراءات سريعة',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: const [
                _QuickActionCard(
                    icon: Icons.devices_other,
                    label: 'إدارة الأجهزة',
                    tabIndex: 1),
                _QuickActionCard(
                    icon: Icons.shield_moon,
                    label: 'وضع الرعب',
                    tabIndex: 2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final AsyncValue<RouterStatus> statusAsync;
  const _StatusCard({required this.statusAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: statusAsync.when(
        data: (s) => Row(
          children: [
            const Icon(Icons.router, color: AppColors.accent, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('B535 HiLink Gateway',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('الشبكة: ${s.networkType}  •  الإشارة: ${s.signalLevel}/5',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                          fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('متصل',
                  style: TextStyle(color: AppColors.success, fontSize: 12)),
            ),
          ],
        ),
        loading: () => const SizedBox(
            height: 32,
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))),
        error: (e, _) => const Text('تعذر تحميل حالة الراوتر',
            style: TextStyle(color: AppColors.danger)),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int tabIndex; // informational; ShellScreen owns real navigation
  const _QuickActionCard(
      {required this.icon, required this.label, required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.accent, size: 28),
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

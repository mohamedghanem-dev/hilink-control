import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/router_provider.dart';
import '../theme/app_theme.dart';
import 'connect_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final service = ref.watch(hilinkServiceProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('الإعدادات',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'المظهر',
            children: [
              _ThemeOption(
                label: 'داكن',
                icon: Icons.dark_mode_outlined,
                selected: themeMode == ThemeMode.dark,
                onTap: () =>
                    ref.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
              ),
              _ThemeOption(
                label: 'فاتح',
                icon: Icons.light_mode_outlined,
                selected: themeMode == ThemeMode.light,
                onTap: () =>
                    ref.read(themeModeProvider.notifier).setMode(ThemeMode.light),
              ),
              _ThemeOption(
                label: 'حسب النظام',
                icon: Icons.settings_suggest_outlined,
                selected: themeMode == ThemeMode.system,
                onTap: () => ref
                    .read(themeModeProvider.notifier)
                    .setMode(ThemeMode.system),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'الراوتر',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.router_outlined),
                title: const Text('عنوان الراوتر'),
                subtitle: Text(service.routerIp),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wifi_outlined),
                title: const Text('واي فاي 2.4G / 5G'),
                subtitle: const Text('تشغيل / إيقاف كل شبكة'),
                onTap: () => _showWifiToggles(context, ref),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text('قطع الاتصال بالتطبيق',
                    style: TextStyle(color: AppColors.danger)),
                onTap: () async {
                  final store = await ref.read(localStoreProvider.future);
                  await store.clearPassword();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const ConnectScreen()),
                      (_) => false,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'عن التطبيق',
            children: [
              Text(
                'HiLink Control Hub — لوحة تحكم غير رسمية لراوترات Huawei B535 عبر HiLink API. '
                'التسمية المخصصة للأجهزة تُحفظ محلياً على تليفونك فقط (الراوتر مايدعمش تسمية الأجهزة).',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                    fontSize: 12,
                    height: 1.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWifiToggles(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تحكم في شبكات الواي فاي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('2.4G'),
              value: true,
              onChanged: (v) => ref
                  .read(hilinkServiceProvider)
                  .setWifiBandEnabled('2.4G', v),
            ),
            SwitchListTile(
              title: const Text('5G'),
              value: true,
              onChanged: (v) =>
                  ref.read(hilinkServiceProvider).setWifiBandEnabled('5G', v),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

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
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: selected ? AppColors.accent : null),
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.accent)
          : null,
      onTap: onTap,
    );
  }
}

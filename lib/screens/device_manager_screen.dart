import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../providers/router_provider.dart';
import '../theme/app_theme.dart';

class DeviceManagerScreen extends ConsumerStatefulWidget {
  const DeviceManagerScreen({super.key});
  @override
  ConsumerState<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends ConsumerState<DeviceManagerScreen> {
  String _query = '';
  String _filter = 'الكل'; // الكل / سلكي / 2.4G / 5G

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(deviceListProvider);

    final filtered = devices.where((d) {
      final matchesQuery = _query.isEmpty ||
          d.displayName.toLowerCase().contains(_query.toLowerCase()) ||
          d.ipAddress.contains(_query) ||
          d.macAddress.toLowerCase().contains(_query.toLowerCase());
      final matchesFilter = switch (_filter) {
        'سلكي' => !d.isWireless,
        '2.4G' => d.ssidBand == '2.4G',
        '5G' => d.ssidBand == '5G',
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('إدارة الأجهزة',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.read(deviceListProvider.notifier).refresh(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'ابحث عن جهاز...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['الكل', 'سلكي', '2.4G', '5G'].map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: AppColors.accent.withOpacity(0.25),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('مفيش أجهزة',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _DeviceTile(device: filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  final RouterDevice device;
  const _DeviceTile({required this.device});

  void _rename(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController(text: device.displayName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة تسمية الجهاز'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثال: موبايل أحمد'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              ref
                  .read(deviceListProvider.notifier)
                  .renameDevice(device.macAddress, ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: device.isBlocked
            ? Border.all(color: AppColors.danger.withOpacity(0.4))
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.accent.withOpacity(0.15),
            child: Icon(
              device.isWireless ? Icons.smartphone : Icons.computer,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${device.ipAddress} • ${device.macAddress}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                        fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _rename(context, ref),
          ),
          Switch(
            value: !device.isBlocked,
            activeColor: AppColors.success,
            onChanged: (_) =>
                ref.read(deviceListProvider.notifier).toggleBlock(device),
          ),
        ],
      ),
    );
  }
}

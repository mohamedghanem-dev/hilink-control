import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../providers/router_provider.dart';
import '../theme/app_theme.dart';

class SecurityPanicScreen extends ConsumerWidget {
  const SecurityPanicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(deviceListProvider);
    final panicOn = ref.watch(panicControllerProvider);
    final blockedDevices = devices.where((d) => d.isBlocked).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('الأمان ووضع الرعب',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: panicOn
                  ? AppColors.danger.withOpacity(0.15)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: panicOn ? AppColors.danger : Colors.transparent,
                  width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: panicOn
                        ? AppColors.danger
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                    size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('وضع الرعب (Panic Mode)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        panicOn
                            ? 'شغال — كل الأجهزة متقطوعة ما عدا المسموح لها'
                            : 'يقطع النت عن كل الأجهزة ما عدا اللي تختارهم',
                        style: TextStyle(
                            color: panicOn
                                ? AppColors.danger
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: panicOn,
                  activeColor: AppColors.danger,
                  onChanged: (v) async {
                    if (v) {
                      final confirmed = await _confirmPanic(context);
                      if (confirmed != true) return;
                      await ref.read(panicControllerProvider.notifier).enable();
                    } else {
                      await ref.read(panicControllerProvider.notifier).disable();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('الأجهزة المسموح لها دايماً (حتى مع وضع الرعب)',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _AlwaysAllowedList(devices: devices),
          const SizedBox(height: 24),
          Text('الأجهزة المحظورة حالياً (${blockedDevices.length})',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (blockedDevices.isEmpty)
            Text('مفيش أجهزة محظورة دلوقتي',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)))
          else
            ...blockedDevices.map((d) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.block, color: AppColors.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(d.displayName)),
                      TextButton(
                        onPressed: () =>
                            ref.read(deviceListProvider.notifier).toggleBlock(d),
                        child: const Text('فك الحظر'),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Future<bool?> _confirmPanic(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد وضع الرعب'),
        content: const Text(
            'هيتم قطع النت عن كل الأجهزة المتصلة ما عدا اللي في قائمة "المسموح لهم دايماً". متأكد؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تفعيل'),
          ),
        ],
      ),
    );
  }
}

/// Checkbox list of devices that stay online during panic mode. Own
/// StatefulWidget so toggling a checkbox only rebuilds this list, not the
/// whole screen.
class _AlwaysAllowedList extends ConsumerStatefulWidget {
  final List<RouterDevice> devices;
  const _AlwaysAllowedList({required this.devices});

  @override
  ConsumerState<_AlwaysAllowedList> createState() => _AlwaysAllowedListState();
}

class _AlwaysAllowedListState extends ConsumerState<_AlwaysAllowedList> {
  Set<String> _allowed = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = await ref.read(localStoreProvider.future);
    setState(() {
      _allowed = store.getAlwaysAllowed();
      _loaded = true;
    });
  }

  Future<void> _toggle(String mac, bool value) async {
    final store = await ref.read(localStoreProvider.future);
    final updated = Set<String>.from(_allowed);
    if (value) {
      updated.add(mac.toUpperCase());
    } else {
      updated.remove(mac.toUpperCase());
    }
    await store.setAlwaysAllowed(updated);
    setState(() => _allowed = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    return Column(
      children: widget.devices.map((d) {
        final isAllowed = _allowed.contains(d.macAddress.toUpperCase());
        return CheckboxListTile(
          value: isAllowed,
          title: Text(d.displayName),
          subtitle: Text(d.macAddress,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
          activeColor: AppColors.accent,
          onChanged: (v) => _toggle(d.macAddress, v == true),
        );
      }).toList(),
    );
  }
}

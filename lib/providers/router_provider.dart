import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../services/hilink_api_service.dart';
import '../services/local_store.dart';

final localStoreProvider = FutureProvider<LocalStore>((ref) {
  return LocalStore.create();
});

final hilinkServiceProvider = Provider<HiLinkApiService>((ref) {
  return HiLinkApiService();
});

enum ConnState { idle, connecting, connected, error }

class ConnectionState_ {
  final ConnState state;
  final String? message;
  const ConnectionState_(this.state, {this.message});
}

class RouterController extends StateNotifier<ConnectionState_> {
  final Ref ref;
  Timer? _pollTimer;

  RouterController(this.ref) : super(const ConnectionState_(ConnState.idle));

  Future<void> connect({
    required String ip,
    required String username,
    required String password,
    bool remember = true,
  }) async {
    state = const ConnectionState_(ConnState.connecting);
    final service = ref.read(hilinkServiceProvider);
    service.routerIp = ip;
    service.username = username;
    try {
      await service.login(password);
      state = const ConnectionState_(ConnState.connected);

      if (remember) {
        final store = await ref.read(localStoreProvider.future);
        await store.setRouterIp(ip);
        await store.setUsername(username);
        await store.setPassword(password);
      }

      await ref.read(deviceListProvider.notifier).refresh();
      _startPolling();
    } on HiLinkException catch (e) {
      state = ConnectionState_(ConnState.error, message: e.message);
    } catch (e) {
      state = ConnectionState_(ConnState.error, message: 'خطأ غير متوقع: $e');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (state.state == ConnState.connected) {
        ref.read(deviceListProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final routerControllerProvider =
    StateNotifierProvider<RouterController, ConnectionState_>((ref) {
  return RouterController(ref);
});

/// Live device list, merged with local custom names + block state from the
/// router's mac-filter list. Polled every 5s while connected (see
/// RouterController._startPolling).
class DeviceListNotifier extends StateNotifier<List<RouterDevice>> {
  final Ref ref;
  DeviceListNotifier(this.ref) : super([]);

  Future<void> refresh() async {
    final service = ref.read(hilinkServiceProvider);
    try {
      final devices = await service.fetchDeviceList();
      final blocked = await service.fetchBlockedMacs();
      final store = await ref.read(localStoreProvider.future);
      final names = store.getDeviceNames();

      for (final d in devices) {
        d.isBlocked = blocked.contains(d.macAddress.toUpperCase());
        d.customName = names[d.macAddress.toUpperCase()];
      }
      state = devices;
    } on HiLinkException {
      // Keep the last known list on transient failures; the connection
      // banner elsewhere reports the error state.
    }
  }

  Future<void> renameDevice(String mac, String newName) async {
    final store = await ref.read(localStoreProvider.future);
    await store.setDeviceName(mac, newName);
    state = [
      for (final d in state)
        if (d.macAddress == mac) (d..customName = newName) else d
    ];
  }

  Future<void> toggleBlock(RouterDevice device) async {
    final service = ref.read(hilinkServiceProvider);
    final blocked = await service.fetchBlockedMacs();
    if (device.isBlocked) {
      await service.unblockDevice(device.macAddress, blocked);
    } else {
      await service.blockDevice(device.macAddress, blocked);
    }
    await refresh();
  }
}

final deviceListProvider =
    StateNotifierProvider<DeviceListNotifier, List<RouterDevice>>((ref) {
  return DeviceListNotifier(ref);
});

/// Panic mode on/off + the "always allowed" MAC set (persisted locally).
class PanicController extends StateNotifier<bool> {
  final Ref ref;
  PanicController(this.ref) : super(false);

  Future<void> enable() async {
    final service = ref.read(hilinkServiceProvider);
    final devices = ref.read(deviceListProvider);
    final store = await ref.read(localStoreProvider.future);
    final allow = store.getAlwaysAllowed();
    await service.panicMode(allDevices: devices, allowList: allow);
    state = true;
    await ref.read(deviceListProvider.notifier).refresh();
  }

  Future<void> disable() async {
    final service = ref.read(hilinkServiceProvider);
    await service.disableAllFiltering();
    state = false;
    await ref.read(deviceListProvider.notifier).refresh();
  }
}

final panicControllerProvider =
    StateNotifierProvider<PanicController, bool>((ref) {
  return PanicController(ref);
});

/// Theme mode, persisted via LocalStore.
class ThemeModeController extends StateNotifier<ThemeMode> {
  final Ref ref;
  ThemeModeController(this.ref) : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    final store = await ref.read(localStoreProvider.future);
    state = _fromString(store.getThemeMode());
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final store = await ref.read(localStoreProvider.future);
    await store.setThemeMode(_toString(mode));
  }

  ThemeMode _fromString(String s) => switch (s) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  String _toString(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      };
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref);
});

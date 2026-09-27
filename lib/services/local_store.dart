import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything that lives only on the phone, never on the router:
/// - custom device names ("رنيم - غرفة النوم")
/// - the "always allowed" list used by panic mode
/// - saved router IP / admin password (so the user isn't retyping it)
/// - theme mode
class LocalStore {
  static const _kNames = 'device_names_v1';
  static const _kAlwaysAllowed = 'always_allowed_macs_v1';
  static const _kRouterIp = 'router_ip_v1';
  static const _kUsername = 'router_username_v1';
  static const _kPassword = 'router_password_v1';
  static const _kThemeMode = 'theme_mode_v1'; // 'system' | 'light' | 'dark'

  final SharedPreferences _prefs;
  LocalStore(this._prefs);

  static Future<LocalStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStore(prefs);
  }

  Map<String, String> getDeviceNames() {
    final raw = _prefs.getString(_kNames);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw) as Map);
  }

  Future<void> setDeviceName(String mac, String name) async {
    final map = getDeviceNames();
    map[mac.toUpperCase()] = name;
    await _prefs.setString(_kNames, jsonEncode(map));
  }

  Set<String> getAlwaysAllowed() {
    final list = _prefs.getStringList(_kAlwaysAllowed) ?? [];
    return list.map((e) => e.toUpperCase()).toSet();
  }

  Future<void> setAlwaysAllowed(Set<String> macs) async {
    await _prefs.setStringList(
        _kAlwaysAllowed, macs.map((e) => e.toUpperCase()).toList());
  }

  String getRouterIp() => _prefs.getString(_kRouterIp) ?? '192.168.8.1';
  Future<void> setRouterIp(String ip) => _prefs.setString(_kRouterIp, ip);

  String getUsername() => _prefs.getString(_kUsername) ?? 'admin';
  Future<void> setUsername(String u) => _prefs.setString(_kUsername, u);

  String? getPassword() => _prefs.getString(_kPassword);
  Future<void> setPassword(String p) => _prefs.setString(_kPassword, p);
  Future<void> clearPassword() => _prefs.remove(_kPassword);

  String getThemeMode() => _prefs.getString(_kThemeMode) ?? 'dark';
  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_kThemeMode, mode);
}

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

import '../models/device.dart';

/// Thrown when the router rejects auth, is unreachable, or returns an
/// unexpected shape. UI layers should catch this and show `message`.
class HiLinkException implements Exception {
  final String message;
  final String? code;
  HiLinkException(this.message, {this.code});
  @override
  String toString() => 'HiLinkException($code): $message';
}

/// Real client for the Huawei HiLink API exposed by B535 / B5xx CPE routers.
///
/// Flow implemented (matches the huawei-lte-api reference behaviour):
///  1. GET  /api/webserver/SesTokInfo      -> session cookie + CSRF token
///  2. POST /api/user/login                -> SHA256-hashed password login
///  3. every authenticated call afterwards must resend the Cookie AND the
///     latest __RequestVerificationToken (the router rotates it on some
///     firmwares, so we always re-read it from the response when present).
///
/// NOTES / KNOWN FIRMWARE VARIANCE:
///  - Some B535 firmwares use `password_type` 4 (SHA256, implemented here).
///    Very old firmwares use type 0 (plain base64). If login fails, the
///    service throws HiLinkException(code: 'AUTH_FAILED') - see
///    fallbackToLegacyLogin() for the older scheme.
///  - The router does NOT support renaming a client device server-side;
///    "custom name" is stored locally in the app only (see DeviceRepository).
///  - Endpoint field names below reflect the common HiLink schema; if your
///    firmware differs, adjust the tag names in _parseHostList /
///    _parseStatus - the request plumbing (session/token/login) stays same.
class HiLinkApiService {
  String routerIp;
  String username;
  String _cookie = '';
  String _token = '';

  HiLinkApiService({this.routerIp = '192.168.8.1', this.username = 'admin'});

  Uri _uri(String path) => Uri.parse('http://$routerIp$path');

  Map<String, String> _headers({bool withToken = true}) {
    final h = <String, String>{
      'Content-Type': 'text/xml; charset=UTF-8',
      if (_cookie.isNotEmpty) 'Cookie': _cookie,
    };
    if (withToken && _token.isNotEmpty) {
      h['__RequestVerificationToken'] = _token;
    }
    return h;
  }

  void _captureCookie(http.Response resp) {
    final setCookie = resp.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      // Keep only the name=value part (drop Path/HttpOnly attrs).
      _cookie = setCookie.split(';').first;
    }
  }

  void _captureTokenFromHeader(http.Response resp) {
    final t = resp.headers['__requestverificationtoken'];
    if (t != null && t.isNotEmpty) {
      _token = t.split('#').first;
    }
  }

  String? _tag(xml.XmlDocument doc, String name) {
    final el = doc.findAllElements(name);
    return el.isNotEmpty ? el.first.innerText : null;
  }

  /// Step 1: acquire session cookie + CSRF token. Must be called before
  /// login and refreshed if a subsequent call returns error code 125002/108001
  /// (session expired / CSRF mismatch).
  Future<void> _fetchSessionToken() async {
    final resp = await http
        .get(_uri('/api/webserver/SesTokInfo'))
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw HiLinkException('تعذر الوصول للراوتر ($routerIp).',
          code: 'UNREACHABLE');
    }
    _captureCookie(resp);
    final doc = xml.XmlDocument.parse(resp.body);
    final tok = _tag(doc, 'TokInfo');
    if (tok == null) {
      throw HiLinkException('استجابة غير متوقعة من الراوتر.',
          code: 'BAD_RESPONSE');
    }
    _token = tok;
  }

  String _sha256Hex(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  /// Huawei's login password transform:
  /// Base64( SHA256( username + Base64(SHA256(password)) + tokInfo ) )
  String _computeLoginPassword(String password) {
    final passHashB64 = base64.encode(utf8.encode(_sha256Hex(password)));
    final combined = username + passHashB64 + _token;
    final finalHashB64 = base64.encode(utf8.encode(_sha256Hex(combined)));
    return finalHashB64;
  }

  /// Step 2: log in. Call after _fetchSessionToken(). Throws
  /// HiLinkException(code: 'AUTH_FAILED') on wrong password.
  Future<void> login(String password) async {
    await _fetchSessionToken();
    final body = '<?xml version="1.0" encoding="UTF-8"?>'
        '<request>'
        '<Username>$username</Username>'
        '<Password>${_computeLoginPassword(password)}</Password>'
        '<password_type>4</password_type>'
        '</request>';

    final resp = await http
        .post(_uri('/api/user/login'), headers: _headers(), body: body)
        .timeout(const Duration(seconds: 8));

    _captureCookie(resp);
    _captureTokenFromHeader(resp);

    if (resp.body.contains('<response>OK</response>')) {
      return; // success
    }
    final doc = xml.XmlDocument.parse(resp.body);
    final errCode = _tag(doc, 'code');
    throw HiLinkException(
      errCode == '108001' || errCode == '108006'
          ? 'كلمة سر الأدمن غلط.'
          : 'فشل تسجيل الدخول للراوتر (كود $errCode).',
      code: 'AUTH_FAILED',
    );
  }

  /// Quick reachability + auth check used by the "connection test" UI.
  Future<bool> testConnection(String password) async {
    try {
      await login(password);
      return true;
    } on HiLinkException {
      return false;
    }
  }

  Future<http.Response> _authedGet(String path) async {
    final resp = await http.get(_uri(path), headers: _headers());
    _captureTokenFromHeader(resp);
    return resp;
  }

  Future<http.Response> _authedPost(String path, String bodyXml) async {
    final resp =
        await http.post(_uri(path), headers: _headers(), body: bodyXml);
    _captureTokenFromHeader(resp);
    return resp;
  }

  /// Connected devices, both wired and Wi-Fi (2.4G + 5G).
  Future<List<RouterDevice>> fetchDeviceList() async {
    final resp = await _authedGet('/api/wlan/host-list');
    if (resp.statusCode != 200) {
      throw HiLinkException('فشل تحميل قائمة الأجهزة.', code: 'HOSTLIST_FAIL');
    }
    final doc = xml.XmlDocument.parse(resp.body);
    final hosts = doc.findAllElements('Host');
    return hosts.map((h) {
      final map = <String, dynamic>{
        for (final c in h.children.whereType<xml.XmlElement>())
          c.name.local: c.innerText,
      };
      return RouterDevice.fromHostListJson(map);
    }).toList();
  }

  /// Currently blacklisted (blocked) MAC addresses, per
  /// /api/security/mac-filter (MacFilterPolicy 0=disabled,1=whitelist,2=blacklist).
  Future<Set<String>> fetchBlockedMacs() async {
    final resp = await _authedGet('/api/security/mac-filter');
    if (resp.statusCode != 200) return {};
    final doc = xml.XmlDocument.parse(resp.body);
    return doc
        .findAllElements('Mac')
        .map((e) => e.innerText.toUpperCase())
        .toSet();
  }

  /// Pushes a full blacklist replacement. `blockedMacs` = every MAC that
  /// should be denied internet access. Empty set = filtering disabled.
  Future<void> _pushMacFilter(Set<String> blockedMacs) async {
    final macsXml = blockedMacs
        .map((m) => '<Mac>${m.toUpperCase()}</Mac>')
        .join();
    final policy = blockedMacs.isEmpty ? '0' : '2'; // 2 = blacklist mode
    final body = '<?xml version="1.0" encoding="UTF-8"?>'
        '<request>'
        '<MacFilterPolicy>$policy</MacFilterPolicy>'
        '<Mac>$macsXml</Mac>'
        '</request>';
    final resp = await _authedPost('/api/security/mac-filter', body);
    if (!resp.body.contains('<response>OK</response>')) {
      throw HiLinkException('فشل تحديث قائمة الحظر.', code: 'MACFILTER_FAIL');
    }
  }

  /// Blocks a single device (adds to blacklist, keeping existing blocks).
  Future<void> blockDevice(String mac, Set<String> currentlyBlocked) =>
      _pushMacFilter({...currentlyBlocked, mac.toUpperCase()});

  /// Unblocks a single device.
  Future<void> unblockDevice(String mac, Set<String> currentlyBlocked) =>
      _pushMacFilter(
          currentlyBlocked.where((m) => m != mac.toUpperCase()).toSet());

  /// 😈 Panic mode: block every currently-connected device EXCEPT the MACs
  /// in [allowList] (e.g. the phone running the app, plus any "always
  /// allowed" devices the user picked).
  Future<void> panicMode({
    required List<RouterDevice> allDevices,
    required Set<String> allowList,
  }) async {
    final toBlock = allDevices
        .map((d) => d.macAddress.toUpperCase())
        .where((mac) => !allowList.contains(mac))
        .toSet();
    await _pushMacFilter(toBlock);
  }

  /// Turns panic mode off (clears the filter entirely). If you only want to
  /// restore the devices that were individually blocked before panic mode,
  /// pass that saved set instead of calling this.
  Future<void> disableAllFiltering() => _pushMacFilter({});

  /// Router + connection status (signal, network type, connection state).
  Future<RouterStatus> fetchStatus() async {
    final statusResp = await _authedGet('/api/monitoring/status');
    final trafficResp = await _authedGet('/api/monitoring/traffic-statistics');
    final wifiResp = await _authedGet('/api/wlan/multi-basic-settings');

    String connStatus = 'unknown';
    int signal = 0;
    String netType = '-';
    if (statusResp.statusCode == 200) {
      final doc = xml.XmlDocument.parse(statusResp.body);
      connStatus = _tag(doc, 'ConnectionStatus') ?? 'unknown';
      final sig = _tag(doc, 'SignalIcon');
      signal = int.tryParse(sig ?? '0') ?? 0;
      netType = _tag(doc, 'CurrentNetworkTypeEx') ?? '-';
    }

    int up = 0, down = 0;
    if (trafficResp.statusCode == 200) {
      final doc = xml.XmlDocument.parse(trafficResp.body);
      up = int.tryParse(_tag(doc, 'CurrentUpload') ?? '0') ?? 0;
      down = int.tryParse(_tag(doc, 'CurrentDownload') ?? '0') ?? 0;
    }

    bool w24 = true, w5 = true;
    if (wifiResp.statusCode == 200) {
      final doc = xml.XmlDocument.parse(wifiResp.body);
      final entries = doc.findAllElements('Ssid');
      // Best-effort: first entry treated as 2.4G, second as 5G (order per
      // firmware's WifiBasicSettings, not guaranteed - verify against your
      // router's actual response and adjust indices if swapped).
      final enabledFlags =
          doc.findAllElements('WifiEnable').map((e) => e.innerText).toList();
      if (enabledFlags.isNotEmpty) w24 = enabledFlags[0] == '1';
      if (enabledFlags.length > 1) w5 = enabledFlags[1] == '1';
      entries; // silence unused warning if not read further yet
    }

    return RouterStatus(
      connectionStatus: connStatus,
      signalLevel: signal,
      networkType: netType,
      uploadBytesToday: up,
      downloadBytesToday: down,
      wifi24Enabled: w24,
      wifi5Enabled: w5,
    );
  }

  /// Toggles a Wi-Fi band on/off. `band` is '2.4G' or '5G'.
  Future<void> setWifiBandEnabled(String band, bool enabled) async {
    final index = band == '5G' ? 1 : 0;
    final body = '<?xml version="1.0" encoding="UTF-8"?>'
        '<request><WifiBandIndex>$index</WifiBandIndex>'
        '<WifiEnable>${enabled ? 1 : 0}</WifiEnable></request>';
    final resp = await _authedPost('/api/wlan/multi-basic-settings', body);
    if (!resp.body.contains('<response>OK</response>')) {
      throw HiLinkException('فشل تغيير حالة الواي فاي.', code: 'WIFI_TOGGLE_FAIL');
    }
  }
}

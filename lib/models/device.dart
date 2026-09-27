/// A device seen by the router (from /api/wlan/host-list),
/// merged with local app-only data (custom alias, block state we track).
class RouterDevice {
  final String macAddress;
  final String ipAddress;
  final String hostName; // name the device broadcasts (DHCP hostname)
  final bool isWireless;
  final String? ssidBand; // "2.4G" / "5G" / null if wired
  bool isBlocked;
  String? customName; // set locally by the user ("رنيم - غرفة النوم")

  RouterDevice({
    required this.macAddress,
    required this.ipAddress,
    required this.hostName,
    required this.isWireless,
    this.ssidBand,
    this.isBlocked = false,
    this.customName,
  });

  String get displayName =>
      (customName != null && customName!.trim().isNotEmpty)
          ? customName!
          : (hostName.trim().isNotEmpty ? hostName : macAddress);

  factory RouterDevice.fromHostListJson(Map<String, dynamic> json) {
    return RouterDevice(
      macAddress: (json['MacAddress'] ?? '').toString(),
      ipAddress: (json['IpAddress'] ?? '').toString(),
      hostName: (json['HostName'] ?? '').toString(),
      isWireless: (json['AssociatedSsid'] ?? '').toString().isNotEmpty ||
          (json['InterfaceType'] ?? '') == '3',
      ssidBand: _bandFromInterfaceType(json['InterfaceType']?.toString()),
    );
  }

  static String? _bandFromInterfaceType(String? type) {
    // Huawei encodes wifi band in InterfaceType on most B535 firmwares:
    // "3" = 2.4G wifi, "4"/"5" = 5G wifi, "1" = wired (LAN). Varies by firmware -
    // treated as best-effort; falls back to null (shown as "Wi-Fi" generically).
    switch (type) {
      case '3':
        return '2.4G';
      case '4':
      case '5':
        return '5G';
      default:
        return null;
    }
  }

  Map<String, dynamic> toCacheJson() => {
        'mac': macAddress,
        'customName': customName,
      };
}

class RouterStatus {
  final String connectionStatus; // e.g. "901" connected code from monitoring/status
  final int signalLevel; // 0-5
  final String networkType; // "LTE", "3G", etc.
  final int uploadBytesToday;
  final int downloadBytesToday;
  final bool wifi24Enabled;
  final bool wifi5Enabled;

  const RouterStatus({
    this.connectionStatus = 'unknown',
    this.signalLevel = 0,
    this.networkType = '-',
    this.uploadBytesToday = 0,
    this.downloadBytesToday = 0,
    this.wifi24Enabled = true,
    this.wifi5Enabled = true,
  });
}

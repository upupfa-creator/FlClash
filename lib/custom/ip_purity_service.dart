import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum IpPurityLevel {
  clean,
  caution,
  highRisk,
}

class PlatformProbeResult {
  const PlatformProbeResult({
    required this.name,
    required this.statusLabel,
    required this.latencyMs,
    required this.ok,
  });

  final String name;
  final String statusLabel;
  final int? latencyMs;
  final bool ok;

  Map<String, dynamic> toJson() => {
        'name': name,
        'statusLabel': statusLabel,
        'latencyMs': latencyMs,
        'ok': ok,
      };

  factory PlatformProbeResult.fromJson(Map<String, dynamic> json) {
    return PlatformProbeResult(
      name: json['name'] as String? ?? '',
      statusLabel: json['statusLabel'] as String? ?? '',
      latencyMs: json['latencyMs'] as int?,
      ok: json['ok'] as bool? ?? false,
    );
  }
}

class IpPurityResult {
  const IpPurityResult({
    required this.ip,
    required this.ipv6Address,
    required this.country,
    required this.countryCode,
    required this.city,
    required this.isp,
    required this.asn,
    required this.orgType,
    required this.ipTimezone,
    required this.ipUtcOffsetHours,
    required this.isDatacenter,
    required this.isVpn,
    required this.isProxy,
    required this.isTor,
    required this.isAbuser,
    required this.abuserScoreText,
    required this.abuseIpdbScore,
    required this.abuseIpdbReports,
    required this.usageType,
    required this.checkedAt,
    required this.hasFullIpapiData,
    required this.platforms,
  });

  final String ip;
  final String? ipv6Address;
  final String country;
  final String countryCode;
  final String city;
  final String isp;
  final String asn;
  final String orgType;
  final String ipTimezone;
  final double? ipUtcOffsetHours;
  final bool isDatacenter;
  final bool isVpn;
  final bool isProxy;
  final bool isTor;
  final bool isAbuser;
  final String abuserScoreText;
  final int? abuseIpdbScore;
  final int? abuseIpdbReports;
  final String usageType;
  final DateTime checkedAt;
  final bool hasFullIpapiData;
  final List<PlatformProbeResult> platforms;

  bool get hasIpv6Leak => (ipv6Address ?? '').isNotEmpty;

  bool get isTimezoneAligned {
    if (ipUtcOffsetHours == null) return true;
    final deviceOffset = DateTime.now().timeZoneOffset.inMinutes / 60.0;
    return (deviceOffset - ipUtcOffsetHours!).abs() <= 1.0;
  }

  String get timezoneSummary {
    final deviceHours = DateTime.now().timeZoneOffset.inHours;
    final deviceLabel = 'UTC${deviceHours >= 0 ? '+$deviceHours' : '$deviceHours'}';
    if (ipUtcOffsetHours == null) {
      return ipTimezone.isNotEmpty ? ipTimezone : deviceLabel;
    }
    final ipH = ipUtcOffsetHours!.round();
    final ipLabel = 'UTC${ipH >= 0 ? '+$ipH' : '$ipH'}';
    return isTimezoneAligned ? '$ipLabel 一致' : '手机 $deviceLabel ≠ IP $ipLabel';
  }

  IpPurityLevel evaluateLevel({
    int riskThreshold = 25,
    String lockedIp = '',
    bool checkIpv6 = true,
  }) {
    final score = abuseIpdbScore ?? 0;
    final drifted = lockedIp.isNotEmpty && ip.isNotEmpty && ip != lockedIp;
    if (drifted ||
        (checkIpv6 && hasIpv6Leak) ||
        isDatacenter ||
        isProxy ||
        isVpn ||
        isTor ||
        isAbuser ||
        score >= riskThreshold) {
      return IpPurityLevel.highRisk;
    }
    final normalizedType = orgType.toLowerCase();
    final isHostingText = normalizedType.contains('hosting') ||
        usageType.toLowerCase().contains('data center');
    if (isHostingText || score > 0 || !isTimezoneAligned) {
      return IpPurityLevel.caution;
    }
    return IpPurityLevel.clean;
  }

  List<String> get riskTags {
    final tags = <String>[];
    if (isDatacenter) tags.add('机房 IP');
    if (isProxy) tags.add('Proxy 标记');
    if (isVpn) tags.add('VPN 标记');
    if (isTor) tags.add('Tor 出口');
    if (isAbuser) tags.add('滥用黑名单');
    if (hasIpv6Leak) tags.add('IPv6 透传泄漏');
    if (!isTimezoneAligned) tags.add('时区不一致');
    if ((abuseIpdbScore ?? 0) > 0) {
      tags.add('AbuseIPDB ${abuseIpdbScore}%');
    }
    if (tags.isEmpty) {
      tags.add(orgType.isNotEmpty ? '${orgType.toUpperCase()} 原生' : '无风险标记');
      tags.add('非机房段');
      tags.add('无 Proxy 标记');
    }
    return tags;
  }

  String buildCopyableReport({String appTitle = 'MyClash Pro'}) {
    final v6 = hasIpv6Leak ? '泄漏($ipv6Address)' : '已隔离';
    final abuse = abuseIpdbScore != null ? '$abuseIpdbScore%' : '未配置Key';
    final unlockedCount = platforms.where((p) => p.ok).length;
    return '[$appTitle体检] IP:$ip ($country $city) | 运营商:$isp $asn | '
        'IPv6:$v6 | 时区:$timezoneSummary | AbuseIPDB:$abuse | '
        '服务连通:$unlockedCount/${platforms.length}';
  }

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'ipv6Address': ipv6Address,
        'country': country,
        'countryCode': countryCode,
        'city': city,
        'isp': isp,
        'asn': asn,
        'orgType': orgType,
        'ipTimezone': ipTimezone,
        'ipUtcOffsetHours': ipUtcOffsetHours,
        'isDatacenter': isDatacenter,
        'isVpn': isVpn,
        'isProxy': isProxy,
        'isTor': isTor,
        'isAbuser': isAbuser,
        'abuserScoreText': abuserScoreText,
        'abuseIpdbScore': abuseIpdbScore,
        'abuseIpdbReports': abuseIpdbReports,
        'usageType': usageType,
        'checkedAt': checkedAt.toIso8601String(),
        'hasFullIpapiData': hasFullIpapiData,
        'platforms': platforms.map((e) => e.toJson()).toList(),
      };

  factory IpPurityResult.fromJson(Map<String, dynamic> json) {
    final rawPlatforms = (json['platforms'] as List<dynamic>?) ?? const [];
    final parsedPlatforms = <PlatformProbeResult>[];
    for (final item in rawPlatforms) {
      if (item is Map) {
        parsedPlatforms.add(
          PlatformProbeResult.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    return IpPurityResult(
      ip: json['ip'] as String? ?? '',
      ipv6Address: json['ipv6Address'] as String?,
      country: json['country'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      city: json['city'] as String? ?? '',
      isp: json['isp'] as String? ?? '',
      asn: json['asn'] as String? ?? '',
      orgType: json['orgType'] as String? ?? '',
      ipTimezone: json['ipTimezone'] as String? ?? '',
      ipUtcOffsetHours: (json['ipUtcOffsetHours'] as num?)?.toDouble(),
      isDatacenter: json['isDatacenter'] as bool? ?? false,
      isVpn: json['isVpn'] as bool? ?? false,
      isProxy: json['isProxy'] as bool? ?? false,
      isTor: json['isTor'] as bool? ?? false,
      isAbuser: json['isAbuser'] as bool? ?? false,
      abuserScoreText: json['abuserScoreText'] as String? ?? '',
      abuseIpdbScore: json['abuseIpdbScore'] as int?,
      abuseIpdbReports: json['abuseIpdbReports'] as int?,
      usageType: json['usageType'] as String? ?? '',
      checkedAt: DateTime.tryParse(json['checkedAt'] as String? ?? '') ??
          DateTime.now(),
      hasFullIpapiData: json['hasFullIpapiData'] as bool? ?? false,
      platforms: parsedPlatforms,
    );
  }
}

class IpPurityConfig {
  const IpPurityConfig({
    this.ipapiKey = '',
    this.abuseIpdbKey = '',
    this.autoCheck = true,
    this.riskThreshold = 25,
    this.cacheHours = 24,
    this.lockedIp = '',
    this.expiryDateIso = '',
    this.customTitle = 'Pro 极客监控台',
    this.showIpv6 = true,
    this.showTimezone = true,
    this.showExpiry = true,
  });

  final String ipapiKey;
  final String abuseIpdbKey;
  final bool autoCheck;
  final int riskThreshold;
  final int cacheHours;
  final String lockedIp;
  final String expiryDateIso;
  final String customTitle;
  final bool showIpv6;
  final bool showTimezone;
  final bool showExpiry;

  int? get remainingDays {
    if (expiryDateIso.trim().isEmpty) return null;
    final dt = DateTime.tryParse(expiryDateIso.trim());
    if (dt == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    return target.difference(today).inDays;
  }

  IpPurityConfig copyWith({
    String? ipapiKey,
    String? abuseIpdbKey,
    bool? autoCheck,
    int? riskThreshold,
    int? cacheHours,
    String? lockedIp,
    String? expiryDateIso,
    String? customTitle,
    bool? showIpv6,
    bool? showTimezone,
    bool? showExpiry,
  }) {
    return IpPurityConfig(
      ipapiKey: ipapiKey ?? this.ipapiKey,
      abuseIpdbKey: abuseIpdbKey ?? this.abuseIpdbKey,
      autoCheck: autoCheck ?? this.autoCheck,
      riskThreshold: riskThreshold ?? this.riskThreshold,
      cacheHours: cacheHours ?? this.cacheHours,
      lockedIp: lockedIp ?? this.lockedIp,
      expiryDateIso: expiryDateIso ?? this.expiryDateIso,
      customTitle: customTitle ?? this.customTitle,
      showIpv6: showIpv6 ?? this.showIpv6,
      showTimezone: showTimezone ?? this.showTimezone,
      showExpiry: showExpiry ?? this.showExpiry,
    );
  }
}

class IpPurityService {
  IpPurityService._();

  static final IpPurityService instance = IpPurityService._();

  static const _kIpapiKey = 'custom_pro_ipapi_key';
  static const _kAbuseKey = 'custom_pro_abuseipdb_key';
  static const _kAutoCheck = 'custom_pro_auto_check';
  static const _kRiskThreshold = 'custom_pro_risk_threshold';
  static const _kLockedIp = 'custom_pro_locked_ip';
  static const _kExpiryIso = 'custom_pro_expiry_iso';
  static const _kCustomTitle = 'custom_pro_title';
  static const _kShowIpv6 = 'custom_pro_show_ipv6';
  static const _kShowTz = 'custom_pro_show_tz';
  static const _kShowExpiry = 'custom_pro_show_expiry';
  static const _kHistoryLatencies = 'custom_pro_latency_history';
  static const _kCachePrefix = 'custom_pro_cache_';

  static const _probeTargets = [
    ['ChatGPT', 'https://chatgpt.com/cdn-cgi/trace'],
    ['Gemini', 'https://gemini.google.com/'],
    ['Claude', 'https://claude.ai/cdn-cgi/trace'],
    ['Netflix', 'https://www.netflix.com/title/80018499'],
    ['TikTok', 'https://www.tiktok.com/'],
    ['YouTube', 'https://www.youtube.com/generate_204'],
    ['X', 'https://x.com/'],
    ['IG', 'https://www.instagram.com/'],
  ];

  Future<IpPurityConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return IpPurityConfig(
      ipapiKey: prefs.getString(_kIpapiKey) ?? '',
      abuseIpdbKey: prefs.getString(_kAbuseKey) ?? '',
      autoCheck: prefs.getBool(_kAutoCheck) ?? true,
      riskThreshold: prefs.getInt(_kRiskThreshold) ?? 25,
      lockedIp: prefs.getString(_kLockedIp) ?? '',
      expiryDateIso: prefs.getString(_kExpiryIso) ?? '',
      customTitle: prefs.getString(_kCustomTitle) ?? 'Pro 极客监控台',
      showIpv6: prefs.getBool(_kShowIpv6) ?? true,
      showTimezone: prefs.getBool(_kShowTz) ?? true,
      showExpiry: prefs.getBool(_kShowExpiry) ?? true,
    );
  }

  Future<void> saveConfig(IpPurityConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIpapiKey, config.ipapiKey.trim());
    await prefs.setString(_kAbuseKey, config.abuseIpdbKey.trim());
    await prefs.setBool(_kAutoCheck, config.autoCheck);
    await prefs.setInt(_kRiskThreshold, config.riskThreshold);
    await prefs.setString(_kLockedIp, config.lockedIp.trim());
    await prefs.setString(_kExpiryIso, config.expiryDateIso.trim());
    await prefs.setString(_kCustomTitle, config.customTitle.trim());
    await prefs.setBool(_kShowIpv6, config.showIpv6);
    await prefs.setBool(_kShowTz, config.showTimezone);
    await prefs.setBool(_kShowExpiry, config.showExpiry);
  }

  Future<List<int>> loadLatencyHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kHistoryLatencies) ?? const [];
    return raw.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
  }

  Future<List<int>> _appendLatency(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadLatencyHistory();
    list.add(ms);
    final trimmed = list.length > 7 ? list.sublist(list.length - 7) : list;
    await prefs.setStringList(
      _kHistoryLatencies,
      trimmed.map((e) => e.toString()).toList(),
    );
    return trimmed;
  }

  Dio _buildDio({int? localProxyPort, int timeoutSeconds = 8}) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: Duration(seconds: timeoutSeconds),
        receiveTimeout: Duration(seconds: timeoutSeconds + 2),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (localProxyPort != null && localProxyPort > 0) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (_) => 'PROXY 127.0.0.1:$localProxyPort';
          return client;
        },
      );
    }
    return dio;
  }

  Future<String?> _detectIpv6(Dio dio) async {
    try {
      final res = await dio.get(
        'https://api6.ipify.org',
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      final ip = (res.data?.toString() ?? '').trim();
      if (ip.contains(':')) {
        return ip;
      }
    } catch (_) {}
    return null;
  }

  Future<List<PlatformProbeResult>> probePlatforms({int? localProxyPort}) async {
    final dio = _buildDio(localProxyPort: localProxyPort, timeoutSeconds: 6);
    final results = await Future.wait(
      _probeTargets.map((target) async {
        final name = target[0];
        final url = target[1];
        final sw = Stopwatch()..start();
        try {
          final res = await dio.get(
            url,
            options: Options(
              responseType: ResponseType.plain,
              followRedirects: true,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36',
              },
            ),
          );
          sw.stop();
          final code = res.statusCode ?? 0;
          if (code >= 200 && code < 400) {
            return PlatformProbeResult(
              name: name,
              statusLabel: '可直通',
              latencyMs: sw.elapsedMilliseconds,
              ok: true,
            );
          }
          if (code == 403 || code == 451) {
            return PlatformProbeResult(
              name: name,
              statusLabel: '风控/受限',
              latencyMs: sw.elapsedMilliseconds,
              ok: false,
            );
          }
          return PlatformProbeResult(
            name: name,
            statusLabel: 'HTTP $code',
            latencyMs: sw.elapsedMilliseconds,
            ok: false,
          );
        } catch (_) {
          sw.stop();
          return PlatformProbeResult(
            name: name,
            statusLabel: '超时',
            latencyMs: null,
            ok: false,
          );
        }
      }),
    );

    final validMs = <int>[];
    for (final r in results) {
      if (r.latencyMs != null) {
        validMs.add(r.latencyMs!);
      }
    }
    if (validMs.isNotEmpty) {
      final avg = validMs.reduce((a, b) => a + b) ~/ validMs.length;
      await _appendLatency(avg);
    }
    return results;
  }

  double? _parseUtcOffsetHours(dynamic rawOffset) {
    if (rawOffset is num) return rawOffset.toDouble();
    if (rawOffset is String) {
      final m = RegExp(r'^([+-]?)(\d{1,2}):?(\d{2})?$').firstMatch(rawOffset.trim());
      if (m != null) {
        final sign = m.group(1) == '-' ? -1.0 : 1.0;
        final h = double.tryParse(m.group(2) ?? '0') ?? 0;
        final min = double.tryParse(m.group(3) ?? '0') ?? 0;
        return sign * (h + min / 60.0);
      }
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is String && value.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  Future<IpPurityResult> checkAll({
    String? knownIp,
    int? localProxyPort,
    bool forceRefresh = false,
  }) async {
    final config = await loadConfig();
    final dio = _buildDio(localProxyPort: localProxyPort);

    String targetIp = (knownIp ?? '').trim();
    if (targetIp.isEmpty) {
      final ipRes = await dio.get(
        'https://api4.ipify.org',
        options: Options(responseType: ResponseType.plain),
      );
      targetIp = (ipRes.data?.toString() ?? '').trim();
    }
    if (targetIp.isEmpty) {
      throw Exception('无法获取当前出口 IPv4');
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_kCachePrefix$targetIp';
    if (!forceRefresh) {
      final rawCache = prefs.getString(cacheKey);
      if (rawCache != null) {
        try {
          final cached = IpPurityResult.fromJson(_asMap(rawCache));
          final age = DateTime.now().difference(cached.checkedAt);
          if (age.inHours < config.cacheHours) {
            return cached;
          }
        } catch (_) {}
      }
    }

    final ipapiQuery = <String, dynamic>{'q': targetIp};
    if (config.ipapiKey.isNotEmpty) {
      ipapiQuery['key'] = config.ipapiKey;
    }

    final ipv6Future = _detectIpv6(dio);
    final platformsFuture = probePlatforms(localProxyPort: localProxyPort);
    final ipapiFuture = dio.get(
      'https://api.ipapi.is/',
      queryParameters: ipapiQuery,
    );

    final ipapiRes = await ipapiFuture;
    final ipapiData = _asMap(ipapiRes.data);
    final location = _asMap(ipapiData['location']);
    final company = _asMap(ipapiData['company']);
    final asnMap = _asMap(ipapiData['asn']);

    int? abuseScore;
    int? abuseReports;
    String usageType = '';
    if (config.abuseIpdbKey.isNotEmpty) {
      try {
        final abuseRes = await dio.get(
          'https://api.abuseipdb.com/api/v2/check',
          queryParameters: {
            'ipAddress': targetIp,
            'maxAgeInDays': 90,
          },
          options: Options(
            headers: {
              'Key': config.abuseIpdbKey,
              'Accept': 'application/json',
            },
          ),
        );
        final abuseRoot = _asMap(abuseRes.data);
        final abuseData = _asMap(abuseRoot['data']);
        abuseScore = abuseData['abuseConfidenceScore'] as int?;
        abuseReports = abuseData['totalReports'] as int?;
        usageType = abuseData['usageType'] as String? ?? '';
      } catch (_) {}
    }

    final ipv6Address = await ipv6Future;
    final platforms = await platformsFuture;

    final result = IpPurityResult(
      ip: targetIp,
      ipv6Address: ipv6Address,
      country: location['country'] as String? ?? '',
      countryCode: location['country_code'] as String? ?? '',
      city: location['city'] as String? ?? '',
      isp: (company['name'] as String?) ??
          (asnMap['org'] as String?) ??
          '未知运营商',
      asn: asnMap['asn'] != null ? 'AS${asnMap['asn']}' : '',
      orgType: (company['type'] as String?) ??
          (asnMap['type'] as String?) ??
          '',
      ipTimezone: location['timezone'] as String? ?? '',
      ipUtcOffsetHours: _parseUtcOffsetHours(location['utc_offset']),
      isDatacenter: ipapiData['is_datacenter'] as bool? ?? false,
      isVpn: ipapiData['is_vpn'] as bool? ?? false,
      isProxy: ipapiData['is_proxy'] as bool? ?? false,
      isTor: ipapiData['is_tor'] as bool? ?? false,
      isAbuser: ipapiData['is_abuser'] as bool? ?? false,
      abuserScoreText: (company['abuser_score'] as String?) ??
          (asnMap['abuser_score'] as String?) ??
          '',
      abuseIpdbScore: abuseScore,
      abuseIpdbReports: abuseReports,
      usageType: usageType,
      checkedAt: DateTime.now(),
      hasFullIpapiData: config.ipapiKey.isNotEmpty,
      platforms: platforms,
    );

    await prefs.setString(cacheKey, jsonEncode(result.toJson()));
    return result;
  }
}

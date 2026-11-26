import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;

  bool get isNewer => isNewerAppVersion(currentVersion, latestVersion);
}

/// Compares dotted numeric versions such as 1.4.2 and v1.4.10.
///
/// Pre-release and build suffixes are ignored; malformed values never count as
/// an update.
bool isNewerAppVersion(String current, String latest) {
  final currentParts = _versionParts(current);
  final latestParts = _versionParts(latest);
  if (currentParts == null || latestParts == null) {
    return false;
  }
  final length = currentParts.length > latestParts.length
      ? currentParts.length
      : latestParts.length;
  for (var i = 0; i < length; i++) {
    final a = i < currentParts.length ? currentParts[i] : 0;
    final b = i < latestParts.length ? latestParts[i] : 0;
    if (b != a) {
      return b > a;
    }
  }
  return false;
}

List<int>? _versionParts(String version) {
  var value = version.trim();
  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }
  value = value.split('+').first.split('-').first;
  final parts = value.split('.');
  if (parts.length < 2 || parts.length > 4) {
    return null;
  }
  final output = <int>[];
  for (final part in parts) {
    final parsed = int.tryParse(part);
    if (parsed == null || parsed < 0) {
      return null;
    }
    output.add(parsed);
  }
  return output;
}

class AppUpdateChecker {
  static const repositoryApi =
      'https://api.github.com/repos/lyx7725/ChameleonUltraGUI/releases/latest';
  static const releasePage =
      'https://github.com/lyx7725/ChameleonUltraGUI/releases';
  static const _releasePrefix =
      'https://github.com/lyx7725/ChameleonUltraGUI/releases/';

  Future<AppUpdateInfo?> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await http
          .get(
            Uri.parse(repositoryApi),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'ChameleonUltraGUIPlus',
            },
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return null;
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        return null;
      }
      final tag = body['tag_name'];
      if (tag is! String || tag.isEmpty) {
        return null;
      }
      final latestVersion = tag.startsWith('v') || tag.startsWith('V')
          ? tag.substring(1)
          : tag;
      final rawUrl = body['html_url'];
      final releaseUrl = rawUrl is String && rawUrl.startsWith(_releasePrefix)
          ? rawUrl
          : releasePage;
      final info = AppUpdateInfo(
        currentVersion: packageInfo.version,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
      );
      return info.isNewer ? info : null;
    } catch (_) {
      return null;
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Copies the original app's local data into the Plus data directory once.
///
/// This is a copy-only migration: the original directory is never written,
/// moved or deleted. If the Plus directory already has any entry, or the old
/// preferences file is not a compatible SharedPreferences map, nothing happens.
Future<void> migrateOriginalDataIfNeeded({String? appDataOverride}) async {
  if (!Platform.isWindows && appDataOverride == null) {
    return;
  }
  final appData = appDataOverride ?? Platform.environment['APPDATA'];
  if (appData == null || appData.isEmpty) {
    return;
  }

  final oldDir = Directory(
    p.join(appData, 'Chameleon Development', 'chameleonultragui'),
  );
  final newDir = Directory(
    p.join(appData, 'lyx7725', 'Chameleon Ultra GUI Plus'),
  );
  if (!await oldDir.exists()) {
    return;
  }
  if (await newDir.exists() && !(await newDir.list().isEmpty)) {
    return;
  }

  final source = File(p.join(oldDir.path, 'shared_preferences.json'));
  if (!await source.exists()) {
    return;
  }

  final bytes = await source.readAsBytes();
  final decoded = _compatiblePreferences(bytes);
  if (decoded == null) {
    return;
  }

  await newDir.create(recursive: true);
  final target = File(p.join(newDir.path, 'shared_preferences.json'));
  if (!await target.exists()) {
    await target.writeAsBytes(bytes, flush: true);
  }

  final secureSource = File(p.join(oldDir.path, 'flutter_secure_storage.dat'));
  final secureTarget = File(p.join(newDir.path, 'flutter_secure_storage.dat'));
  if (await secureSource.exists() && !await secureTarget.exists()) {
    await secureSource.copy(secureTarget.path);
  }
}

/// Returns the decoded map only when it matches the SharedPreferences file
/// format. The format check is deliberately separate so it can be tested.
Map<String, dynamic>? _compatiblePreferences(List<int> bytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      return null;
    }
    final map = <String, dynamic>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String || !_compatibleValue(entry.value)) {
        return null;
      }
      map[entry.key as String] = entry.value;
    }
    return map;
  } catch (_) {
    return null;
  }
}

bool _compatibleValue(Object? value) {
  if (value is String || value is bool || value is int || value is double) {
    return true;
  }
  if (value is List) {
    return value.every((item) => item is String);
  }
  return false;
}

/// Test seam for the format check used by [migrateOriginalDataIfNeeded].
bool isCompatiblePreferencesJson(Object? value) {
  if (value is! Map) {
    return false;
  }
  for (final entry in value.entries) {
    if (entry.key is! String || !_compatibleValue(entry.value)) {
      return false;
    }
  }
  return true;
}

import 'dart:convert';
import 'dart:io';

import 'package:chameleonultragui/helpers/plus_data_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('accepts SharedPreferences scalar and string-list values', () {
    expect(
      isCompatiblePreferencesJson({
        'flutter.cards': ['{"uid":"000000000000"}'],
        'flutter.theme': 1,
        'flutter.dark': true,
        'flutter.opacity': 0.5,
        'flutter.locale': 'en',
      }),
      isTrue,
    );
  });

  test('rejects nested maps and non-string lists', () {
    expect(isCompatiblePreferencesJson({'nested': {}}), isFalse);
    expect(
      isCompatiblePreferencesJson({
        'cards': [1, 2],
      }),
      isFalse,
    );
    expect(isCompatiblePreferencesJson({'cards': null}), isFalse);
  });

  test('copies compatible data once without touching the original', () async {
    final root = await Directory.systemTemp.createTemp('plus_migration_');
    addTearDown(() => root.delete(recursive: true));
    final oldDir = Directory(
      p.join(root.path, 'Chameleon Development', 'chameleonultragui'),
    );
    await oldDir.create(recursive: true);
    final oldPrefs = File(p.join(oldDir.path, 'shared_preferences.json'));
    await oldPrefs.writeAsString(
      jsonEncode({
        'flutter.cards': ['{"uid":"000000000000"}'],
      }),
    );
    final oldSecure = File(p.join(oldDir.path, 'flutter_secure_storage.dat'));
    await oldSecure.writeAsBytes([1, 2, 3]);

    await migrateOriginalDataIfNeeded(appDataOverride: root.path);
    final newDir = Directory(
      p.join(root.path, 'lyx7725', 'Chameleon Ultra GUI Plus'),
    );
    final newPrefs = File(p.join(newDir.path, 'shared_preferences.json'));
    expect(await newPrefs.exists(), isTrue);
    expect(await newPrefs.readAsString(), await oldPrefs.readAsString());
    expect(
      await File(p.join(newDir.path, 'flutter_secure_storage.dat'))
          .readAsBytes(),
      [1, 2, 3],
    );
    expect(await oldPrefs.exists(), isTrue);

    await newPrefs.writeAsString('{}');
    await migrateOriginalDataIfNeeded(appDataOverride: root.path);
    expect(await newPrefs.readAsString(), '{}');
  });

  test('rejects non-map JSON', () {
    expect(isCompatiblePreferencesJson([]), isFalse);
    expect(isCompatiblePreferencesJson('text'), isFalse);
    expect(isCompatiblePreferencesJson(null), isFalse);
  });
}

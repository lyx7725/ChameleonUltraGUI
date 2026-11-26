import 'package:chameleonultragui/helpers/app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares dotted numeric versions', () {
    expect(isNewerAppVersion('1.4.2', '1.4.3'), isTrue);
    expect(isNewerAppVersion('1.4.2', 'v1.4.10'), isTrue);
    expect(isNewerAppVersion('1.4.2', '1.5.0'), isTrue);
    expect(isNewerAppVersion('1.4.2', '1.4.2'), isFalse);
    expect(isNewerAppVersion('1.4.3', '1.4.2'), isFalse);
  });

  test('ignores build and pre-release suffixes', () {
    expect(isNewerAppVersion('1.4.2+20260101', '1.4.3'), isTrue);
    expect(isNewerAppVersion('1.4.2', '1.4.2-beta.1'), isFalse);
    expect(isNewerAppVersion('1.4.2', '1.4.3-beta.1'), isTrue);
  });

  test('rejects malformed versions instead of reporting an update', () {
    expect(isNewerAppVersion('1.4.2', 'latest'), isFalse);
    expect(isNewerAppVersion('1.4.2', ''), isFalse);
    expect(isNewerAppVersion('1.4', ''), isFalse);
    expect(isNewerAppVersion('1.4.2', '1.4.x'), isFalse);
  });
}

import 'package:chameleonultragui/helpers/lifecycle_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paused and inactive keep the device connection', () {
    expect(shouldShutdownOnLifecycle(AppLifecycleState.paused), isFalse);
    expect(shouldShutdownOnLifecycle(AppLifecycleState.inactive), isFalse);
    expect(shouldShutdownOnLifecycle(AppLifecycleState.resumed), isFalse);
  });

  test('detached is the only shutdown state', () {
    expect(shouldShutdownOnLifecycle(AppLifecycleState.detached), isTrue);
  });
}

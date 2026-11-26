import 'package:chameleonultragui/connector/ble_watch_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('suspended watching can start again', () {
    final watch = BleWatchState();
    expect(watch.start(), isTrue);
    expect(watch.begin(), isTrue);
    expect(watch.active, isTrue);

    watch.stop();
    watch.end();
    expect(watch.desired, isFalse);
    expect(watch.active, isFalse);

    expect(watch.start(), isTrue);
    expect(watch.begin(), isTrue);
    expect(watch.active, isTrue);
  });

  test('duplicate start and begin are rejected', () {
    final watch = BleWatchState();
    expect(watch.start(), isTrue);
    expect(watch.start(), isFalse);
    expect(watch.begin(), isTrue);
    expect(watch.begin(), isFalse);
    watch.end();
    expect(watch.begin(), isTrue);
  });

  test('a stopped watch cannot begin', () {
    final watch = BleWatchState();
    expect(watch.begin(), isFalse);
    watch.start();
    watch.stop();
    expect(watch.begin(), isFalse);
  });
}

import 'dart:typed_data';

import 'package:chameleonultragui/connector/serial_abstract.dart';
import 'package:chameleonultragui/main.dart';
import 'package:chameleonultragui/sharedprefsprovider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

class GenerationSerial extends AbstractSerial {
  GenerationSerial() : super(log: Logger(level: Level.off));

  @override
  bool isManualConnectionSupported() => false;

  @override
  Future<List<Chameleon>> availableChameleons(bool onlyDFU) async => [];

  @override
  Future<bool> connectSpecificDevice(dynamic devicePort) async => false;

  @override
  Future<bool> write(Uint8List command, {bool firmware = false}) async => true;
}

void main() {
  test('a physical link generation change replaces the communicator', () {
    final serial = GenerationSerial()
      ..connected = true
      ..connectionGeneration = 1;
    final state = ChameleonGUIState(SharedPreferencesProvider())
      ..log = Logger(level: Level.off)
      ..connector = serial;

    state.onConnectorStateChanged();
    final first = state.communicator;
    expect(first, isNotNull);

    state.onConnectorStateChanged();
    expect(identical(first, state.communicator), isTrue);

    serial.connectionGeneration = 2;
    state.onConnectorStateChanged();
    expect(identical(first, state.communicator), isFalse);
    expect(state.communicator, isNotNull);

    serial.connected = false;
    state.onConnectorStateChanged();
    expect(state.communicator, isNull);
  });
}

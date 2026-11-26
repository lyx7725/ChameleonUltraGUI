import 'dart:async';
import 'dart:typed_data';

import 'package:chameleonultragui/bridge/chameleon.dart';
import 'package:chameleonultragui/connector/serial_abstract.dart';
import 'package:chameleonultragui/helpers/definitions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

class ControlledSerial extends AbstractSerial {
  ControlledSerial() : super(log: Logger(level: Level.off));

  final frames = <Uint8List>[];

  @override
  Future<bool> performDisconnect() async => true;

  @override
  bool isManualConnectionSupported() => false;

  @override
  Future<bool> connectSpecificDevice(dynamic devicePort) async => false;

  @override
  Future<List<Chameleon>> availableChameleons(bool onlyDFU) async => [];

  @override
  Future<bool> write(Uint8List command, {bool firmware = false}) async {
    frames.add(command);
    return true;
  }

  Future<void> reply(Uint8List request, List<int> data) async {
    final command = [request[2], request[3]];
    final frame = <int>[
      0x11,
      0,
      command[0],
      command[1],
      0,
      0,
      0,
      data.length,
      0,
      ...data,
      0,
    ];
    frame[1] = _lrc(frame.sublist(0, 1));
    frame[8] = _lrc(frame.sublist(2, 8));
    frame[frame.length - 1] = _lrc(frame.sublist(0, frame.length - 1));
    await messageCallback(frame);
  }

  int _lrc(List<int> values) {
    var sum = 0;
    for (final value in values) {
      sum = (sum + value) & 0xFF;
    }
    return (0x100 - sum) & 0xFF;
  }
}

Future<void> _waitForFrames(ControlledSerial serial, int count) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (serial.frames.length < count) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for frame $count');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('keep-alive and a normal battery read keep their own replies', () async {
    final serial = ControlledSerial();
    final bridge = ChameleonCommunicator(serial.log, port: serial);

    final keepAlive = bridge.keepAlive();
    await _waitForFrames(serial, 1);
    final normal = bridge.sendCmd(ChameleonCommand.getBatteryCharge);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(serial.frames, hasLength(1));

    await serial.reply(serial.frames[0], [0x0D, 0x00, 0x50, 0x03]);
    await keepAlive;
    await _waitForFrames(serial, 2);
    await serial.reply(serial.frames[1], [0x0E, 0x00, 0x55, 0x03]);

    final response = await normal;
    expect(response!.command, ChameleonCommand.getBatteryCharge.value);
    expect(response.data, [0x0E, 0x00, 0x55, 0x03]);
    expect(bridge.commandQueue, isEmpty);
    expect(bridge.messageQueue, isEmpty);
  });

  test('keep-alive is skipped while another command is in flight', () async {
    final serial = ControlledSerial();
    final bridge = ChameleonCommunicator(serial.log, port: serial);

    final normal = bridge.sendCmd(ChameleonCommand.getBatteryCharge);
    await _waitForFrames(serial, 1);
    await bridge.keepAlive();
    expect(serial.frames, hasLength(1));

    await serial.reply(serial.frames.single, [0x0D, 0x00, 0x50, 0x03]);
    await normal;
  });

  test('keep-alive does not clear a timed-out battery guard', () async {
    final serial = ControlledSerial();
    final bridge = ChameleonCommunicator(serial.log, port: serial);

    await expectLater(
      bridge.sendCmd(
        ChameleonCommand.getBatteryCharge,
        timeout: const Duration(milliseconds: 5),
      ),
      throwsA(isA<TimeoutException>()),
    );
    await expectLater(bridge.keepAlive(), throwsStateError);
  });
}

import 'dart:typed_data';

import 'package:chameleonultragui/connector/serial_abstract.dart';
import 'package:chameleonultragui/generated/i18n/app_localizations.dart';
import 'package:chameleonultragui/gui/page/connect.dart';
import 'package:chameleonultragui/main.dart';
import 'package:chameleonultragui/sharedprefsprovider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSerial extends AbstractSerial {
  FakeSerial() : super(log: Logger(level: Level.off));

  List<Chameleon> devices = [];
  dynamic connectedPort;

  @override
  bool isManualConnectionSupported() => true;

  @override
  Future<List<Chameleon>> availableChameleons(bool onlyDFU) async => devices;

  @override
  Future<bool> connectSpecificDevice(dynamic devicePort) async {
    connectedPort = devicePort;
    connected = true;
    activeDevicePort = devicePort;
    return true;
  }

  @override
  Future<bool> performDisconnect() async {
    connected = false;
    activeDevicePort = null;
    return true;
  }

  @override
  Future<bool> write(Uint8List command, {bool firmware = false}) async => true;
}

Future<ChameleonGUIState> _state(FakeSerial serial) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = SharedPreferencesProvider();
  await prefs.load();
  prefs.setAutoScanEnabled(false);
  final state = ChameleonGUIState(prefs)
    ..log = Logger(level: Level.off)
    ..connector = serial;
  return state;
}

Future<void> _pump(WidgetTester tester, ChameleonGUIState state) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ConnectPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('manual list stays available when auto connect is off', (
    tester,
  ) async {
    final serial = FakeSerial()
      ..devices = [
        const Chameleon(
          port: 'COM7',
          device: ChameleonDevice.ultra,
          type: ConnectionType.usb,
          dfu: false,
        ),
      ];
    final state = await _state(serial);
    await _pump(tester, state);

    expect(find.byKey(const ValueKey('connect_device_COM7')), findsOneWidget);
    expect(find.byKey(const ValueKey('connect_manual_entry')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('connect_device_COM7')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(serial.connectedPort, 'COM7');
  });

  testWidgets('DFU device opens the recovery dialog', (tester) async {
    final serial = FakeSerial()
      ..devices = [
        const Chameleon(
          port: 'COM9',
          device: ChameleonDevice.ultra,
          type: ConnectionType.usb,
          dfu: true,
        ),
      ];
    final state = await _state(serial);
    await _pump(tester, state);

    await tester.tap(find.byKey(const ValueKey('connect_device_COM9')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Chameleon is in DFU mode.'), findsOneWidget);
    expect(find.text('Flash'), findsOneWidget);
  });

  testWidgets('manual connect entry opens the port dialog', (tester) async {
    final serial = FakeSerial();
    final state = await _state(serial);
    await _pump(tester, state);

    await tester.tap(find.byKey(const ValueKey('connect_manual_entry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Connect manually'),
      ),
      findsOneWidget,
    );
  });
}

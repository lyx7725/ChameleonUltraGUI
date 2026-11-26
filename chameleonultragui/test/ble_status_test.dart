import 'package:chameleonultragui/generated/i18n/app_localizations.dart';
import 'package:chameleonultragui/gui/component/connection_status.dart';
import 'package:chameleonultragui/helpers/ble_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no device and background direct wait stay waiting', () {
    final controller = BlePhaseController();
    addTearDown(controller.dispose);
    expect(controller.phase.value, BlePhase.waiting);
    controller.backgroundWaiting();
    expect(controller.phase.value, BlePhase.waiting);
  });

  test('a real advertisement/connect shows connecting', () {
    final controller = BlePhaseController();
    addTearDown(controller.dispose);
    controller.connecting();
    expect(controller.phase.value, BlePhase.connecting);
  });

  test('a real failure expires back to waiting', () async {
    final controller = BlePhaseController(
      retryWindow: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);
    controller.attemptFailed();
    expect(controller.phase.value, BlePhase.failedRetrying);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(controller.phase.value, BlePhase.waiting);
  });

  test('a new connection cancels the failure window', () async {
    final controller = BlePhaseController(
      retryWindow: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);
    controller.attemptFailed();
    controller.connecting();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(controller.phase.value, BlePhase.connecting);
  });

  testWidgets('connect page labels follow the phase events', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: ConnectionStatus(connected: false, connecting: false),
        ),
      ),
    );
    expect(find.text('Waiting for device…'), findsOneWidget);

    BleStatus.connecting();
    await tester.pump();
    expect(find.text('Connecting…'), findsOneWidget);

    BleStatus.attemptFailed();
    await tester.pump();
    expect(find.text('Connection failed, retrying…'), findsOneWidget);

    BleStatus.manualDisconnect();
    await tester.pump();
    expect(find.text('Waiting for device…'), findsOneWidget);
  });

  test('manual disconnect clears a failure and waits', () {
    final controller = BlePhaseController(
      retryWindow: const Duration(seconds: 5),
    );
    addTearDown(controller.dispose);
    controller.attemptFailed();
    controller.manualDisconnect();
    expect(controller.phase.value, BlePhase.waiting);
  });
}

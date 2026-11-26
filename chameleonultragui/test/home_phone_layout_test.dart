import 'dart:io';

import 'package:chameleonultragui/connector/serial_abstract.dart';
import 'package:chameleonultragui/generated/i18n/app_localizations.dart';
import 'package:chameleonultragui/gui/page/home_overview.dart';
import 'package:chameleonultragui/helpers/definitions.dart';
import 'package:chameleonultragui/sharedprefsprovider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _widths = [240.0, 280.0, 320.0, 360.0, 412.0];
const _scales = [1.0, 1.3, 1.5];

Future<void> _loadFonts() async {
  const candidates = [
    r'C:\Windows\Fonts\segoeui.ttf',
    '/System/Library/Fonts/SFNS.ttf',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final loader = FontLoader(
        'TestSans',
      )..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
      await loader.load();
      break;
    }
  }
  await (FontLoader(
    'RobotoMono',
  )..addFont(rootBundle.load('assets/fonts/RobotoMono-Regular.ttf'))).load();
  final sep = Platform.pathSeparator;
  final exe = Platform.resolvedExecutable;
  final marker = '${sep}bin${sep}cache$sep';
  final idx = exe.toLowerCase().indexOf(marker.toLowerCase());
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      (idx > 0 ? exe.substring(0, idx) : null);
  if (root != null) {
    final file = File(
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
          ))
          .load();
    }
  }
}

HomeViewData _data() {
  final types = [
    SlotTypes(hf: TagType.mifare1K, lf: TagType.em410X),
    SlotTypes(hf: TagType.ntag215),
    SlotTypes(),
    SlotTypes(hf: TagType.hf14a4),
    SlotTypes(lf: TagType.hidProx),
    SlotTypes(hf: TagType.mifare4K),
    SlotTypes(hf: TagType.ultralight),
    SlotTypes(),
  ];
  final names = List.generate(8, (_) => SlotNames());
  names[0].hf = 'Office';
  names[1].hf = 'Gym';
  names[3].hf = 'Hotel room';
  names[4].lf = 'Garage';
  names[5].hf = 'Apartment building main entrance';
  names[6].hf = 'Membership';
  final enabled = List.generate(8, (_) => EnabledSlotInfo(hf: true, lf: true));
  enabled[5] = EnabledSlotInfo();

  return HomeViewData(
    deviceName: 'Chameleon Ultra',
    device: ChameleonDevice.ultra,
    connectionType: ConnectionType.ble,
    portName: 'SN-000000',
    batteryPercent: 84,
    firmwareVersion: '2.3.0 (v2.3.0-1234567890abcdef)',
    firmwareCommit: '1234567890abcdef',
    updateAvailable: true,
    isReaderMode: false,
    isDemo: false,
    capabilitiesSupported: true,
    activeSlot: 0,
    slotsReady: true,
    slotTypes: types,
    slotNames: names,
    enabledSlots: enabled,
    recentCards: const [],
  );
}

HomeViewData _desktopData() {
  final types = [
    SlotTypes(hf: TagType.mifare1K, lf: TagType.em410X),
    SlotTypes(hf: TagType.ntag215),
    SlotTypes(),
    SlotTypes(hf: TagType.hf14a4),
    SlotTypes(lf: TagType.hidProx),
    SlotTypes(hf: TagType.mifare4K),
    SlotTypes(hf: TagType.ultralight),
    SlotTypes(),
  ];
  final names = List.generate(8, (_) => SlotNames());
  names[0].hf = 'Office';
  names[1].hf = 'Gym';
  names[3].hf = 'Hotel room';
  names[4].lf = 'Garage';
  names[5].hf = 'Apartment building main entrance';
  names[6].hf = 'Membership';
  final enabled = List.generate(8, (_) => EnabledSlotInfo(hf: true, lf: true));
  enabled[5] = EnabledSlotInfo();

  return HomeViewData(
    deviceName: 'Chameleon Ultra',
    device: ChameleonDevice.ultra,
    connectionType: ConnectionType.ble,
    portName: 'SN-000000',
    batteryPercent: 84,
    firmwareVersion: '2.3.0 (abc1234)',
    firmwareCommit: 'abc1234',
    updateAvailable: true,
    isReaderMode: false,
    isDemo: false,
    capabilitiesSupported: true,
    activeSlot: 0,
    slotsReady: true,
    slotTypes: types,
    slotNames: names,
    enabledSlots: enabled,
    recentCards: [
      CardSave(uid: '04A1B2C3D4E5F6', name: 'Office', tag: TagType.mifare1K),
      CardSave(uid: '010203040506', name: 'Gym', tag: TagType.em410X),
      CardSave(
        uid: 'AABBCCDDEEFF001122334455',
        name: 'Membership card with a long name',
        tag: TagType.ntag215,
      ),
    ],
  );
}

ThemeData _theme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepOrange,
      brightness: Brightness.light,
    ),
    fontFamily: 'TestSans',
  );
}

Widget _overviewFor(HomeViewData data) {
  return HomeOverview(
    data: data,
    loading: false,
    onSelectSlot: (_) {},
    onOpenSavedCards: () {},
    onSettings: () {},
    onDisconnect: () {},
    onToggleReaderMode: () {},
    onUpdate: () {},
    onCopy: (_) {},
  );
}

Widget _overview() => _overviewFor(_data());

Widget _app(Widget child, Locale locale, double scale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: _theme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  );
}

Widget _desktopShell(
  GlobalKey key, {
  required bool rail,
  required Locale locale,
}) {
  final body = HomeOverview(
    data: _desktopData(),
    loading: false,
    onSelectSlot: (_) {},
    onOpenSavedCards: () {},
    onSettings: () {},
    onDisconnect: () {},
    onToggleReaderMode: () {},
    onUpdate: () {},
    onCopy: (_) {},
  );
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: _theme(),
    home: RepaintBoundary(
      key: key,
      child: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: rail
            ? Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: NavigationRail(
                      selectedIndex: 0,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.home),
                          label: Text('Home'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.settings),
                          label: Text('Settings'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: body),
                ],
              )
            : body,
      ),
    ),
  );
}

Widget _phoneShell(GlobalKey key, Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: _theme(),
    home: RepaintBoundary(
      key: key,
      child: Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: Row(
          children: [
            SizedBox(
              width: 72,
              child: NavigationRail(
                selectedIndex: 0,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings),
                    label: Text('Settings'),
                  ),
                ],
              ),
            ),
            Expanded(child: _overview()),
          ],
        ),
      ),
    ),
  );
}

Future<void> _precache(WidgetTester tester) async {
  await tester.runAsync(() async {
    if (find.byType(HomeOverview).evaluate().isNotEmpty) {
      await precacheImage(
        const AssetImage('assets/black-ultra-standing-front.webp'),
        tester.element(find.byType(HomeOverview)),
      );
    }
  });
}

void _assertNoOverflow(WidgetTester tester, String reason) {
  final error = tester.takeException();
  expect(error, isNull, reason: reason);
}

void _assertPhoneCard(WidgetTester tester, String reason) {
  final card = tester.getRect(find.byKey(const ValueKey('home_phone_card')));
  final top = tester.getRect(find.byKey(const ValueKey('home_phone_top')));
  final image = tester.getRect(find.byKey(const ValueKey('home_phone_image')));

  for (final key in [
    'home_phone_mode',
    'home_phone_settings',
    'home_phone_disconnect',
  ]) {
    final rect = tester.getRect(find.byKey(ValueKey(key)));
    expect(rect.left >= card.left, isTrue, reason: '$reason $key left');
    expect(rect.right <= card.right, isTrue, reason: '$reason $key right');
    expect(rect.top >= card.top, isTrue, reason: '$reason $key top');
    expect(rect.bottom <= card.bottom, isTrue, reason: '$reason $key bottom');
  }

  expect(
    (image.center.dy - top.center.dy).abs(),
    lessThanOrEqualTo(4),
    reason: '$reason image is not vertically centred',
  );

  for (final key in [
    'home_phone_model',
    'home_phone_firmware',
    'home_phone_mac',
  ]) {
    final widget = tester.widget<Text>(find.byKey(ValueKey(key)));
    expect(
      widget.overflow == TextOverflow.ellipsis,
      isFalse,
      reason: '$reason $key uses ellipsis',
    );
  }
  final model = tester.widget<Text>(
    find.byKey(const ValueKey('home_phone_model')),
  );
  expect(model.maxLines, 2, reason: '$reason model must be at most two lines');
  final firmware = tester.widget<Text>(
    find.byKey(const ValueKey('home_phone_firmware')),
  );
  expect(firmware.maxLines, isNull, reason: '$reason firmware is line-limited');
}

Future<void> _renderAt(
  WidgetTester tester, {
  required double width,
  required Locale locale,
  required double scale,
  required GlobalKey key,
}) async {
  tester.view.physicalSize = Size(width + 64, 1000);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    _app(RepaintBoundary(key: key, child: _overview()), locale, scale),
  );
  await tester.pump();
  await _precache(tester);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('phone device card matrix', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final locales = AppLocalizations.supportedLocales;
    var combinations = 0;
    for (final width in _widths) {
      for (final scale in _scales) {
        for (final locale in locales) {
          final key = GlobalKey();
          await _renderAt(
            tester,
            width: width,
            locale: locale,
            scale: scale,
            key: key,
          );
          final label =
              'width=$width scale=$scale locale=${locale.toLanguageTag()}';
          _assertNoOverflow(tester, label);
          _assertPhoneCard(tester, label);
          combinations++;
        }
      }
    }
    expect(combinations, _widths.length * _scales.length * locales.length);
  });

  testWidgets('phone card fits compact viewports', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(390, 844), const Size(360, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      final key = GlobalKey();
      await tester.pumpWidget(_phoneShell(key, const Locale('en')));
      await tester.pump();
      await _precache(tester);
      await tester.pumpAndSettle();

      _assertNoOverflow(tester, 'compact ${size.width.toInt()}');
      _assertPhoneCard(tester, 'compact ${size.width.toInt()}');
      final card = tester.getRect(
        find.byKey(const ValueKey('home_phone_card')),
      );
      expect(card.left >= 0, isTrue);
      expect(card.right <= size.width, isTrue);
    }
  });

  testWidgets('desktop and medium layouts keep keyed regions in bounds', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final entry in [
      (const Size(1280, 800), true),
      (const Size(800, 800), false),
    ]) {
      tester.view.physicalSize = entry.$1;
      tester.view.devicePixelRatio = 1.0;
      final key = GlobalKey();
      await tester.pumpWidget(
        _desktopShell(key, rail: entry.$2, locale: const Locale('en')),
      );
      await tester.pump();
      await _precache(tester);
      await tester.pumpAndSettle();

      final label = 'desktop ${entry.$1}';
      _assertNoOverflow(tester, label);
      expect(find.byKey(const ValueKey('home_device_panel')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_current_slot')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_phone_card')), findsNothing);

      final device = tester.getRect(
        find.byKey(const ValueKey('home_device_panel')),
      );
      final slot = tester.getRect(
        find.byKey(const ValueKey('home_current_slot')),
      );
      expect(device.left >= 0, isTrue, reason: label);
      expect(device.right <= entry.$1.width, isTrue, reason: label);
      expect(slot.left >= device.right, isTrue, reason: label);
      expect(slot.right <= entry.$1.width, isTrue, reason: label);
    }
  });

  testWidgets('home shows demo and unsupported firmware notices', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      _app(
        _overviewFor(_data().copyWith(isDemo: true)),
        const Locale('en'),
        1.0,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home_demo_warning')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home_capabilities_warning')),
      findsNothing,
    );

    await tester.pumpWidget(
      _app(
        _overviewFor(
          _data().copyWith(isDemo: false, capabilitiesSupported: false),
        ),
        const Locale('en'),
        1.0,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home_demo_warning')), findsNothing);
    expect(
      find.byKey(const ValueKey('home_capabilities_warning')),
      findsOneWidget,
    );
  });
}

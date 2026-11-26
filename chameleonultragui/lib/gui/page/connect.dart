import 'dart:async';

import 'package:chameleonultragui/bridge/chameleon.dart';
import 'package:chameleonultragui/connector/serial_abstract.dart';
import 'package:chameleonultragui/connector/serial_android.dart';
import 'package:chameleonultragui/gui/component/connection_status.dart';
import 'package:chameleonultragui/gui/component/error_page.dart';
import 'package:chameleonultragui/gui/menu/dialogs/manual_connect.dart';
import 'package:chameleonultragui/helpers/flash.dart';
import 'package:chameleonultragui/helpers/general.dart';
import 'package:chameleonultragui/main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Localizations
import 'package:chameleonultragui/generated/i18n/app_localizations.dart';

class ConnectPage extends StatefulWidget {
  const ConnectPage({
    super.key,
    this.autoScanInterval = const Duration(seconds: 3),
  });

  final Duration autoScanInterval;

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  List<Chameleon> _devices = [];
  Timer? _scanTimer;
  Object? _error;
  bool _initialScanCompleted = false;
  bool _scanInProgress = false;
  bool _connectionInProgress = false;
  bool _showedPermissionsSnackbar = false;
  dynamic _lastAutoConnectAttemptPort;

  ChameleonGUIState get _appState =>
      Provider.of<ChameleonGUIState>(context, listen: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scanNow());
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  bool _shouldScan(ChameleonGUIState appState) {
    return mounted &&
        !_connectionInProgress &&
        !appState.connector!.connected &&
        !appState.connector!.pendingConnection;
  }

  List<Chameleon> _normalizeDevices(List<Chameleon> devices) {
    final output = <Chameleon>[];
    final seen = <String>{};

    for (final device in devices) {
      final key = '${device.port}|${device.type.name}|${device.dfu}';
      if (seen.add(key)) {
        output.add(device);
      }
    }

    return output;
  }

  void _scheduleNextScan() {
    _scanTimer?.cancel();

    if (!_shouldScan(_appState) ||
        !_appState.sharedPreferencesProvider.getAutoScanEnabled()) {
      return;
    }

    _scanTimer = Timer(widget.autoScanInterval, _scanNow);
  }

  void _showPermissionsWarningIfNeeded(List<Chameleon> devices) {
    final appState = _appState;
    if (appState.connector is! AndroidSerial) {
      _showedPermissionsSnackbar = false;
      return;
    }

    final androidSerial = appState.connector as AndroidSerial;
    final shouldShow = devices.isEmpty && !androidSerial.hasAllPermissions;
    if (!shouldShow) {
      _showedPermissionsSnackbar = false;
      return;
    }

    if (_showedPermissionsSnackbar) {
      return;
    }

    _showedPermissionsSnackbar = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final localizations = AppLocalizations.of(context)!;
      final snackBar = SnackBar(
        content: Text(localizations.android_ble_permissions_missing),
        action: SnackBarAction(label: localizations.close, onPressed: () {}),
      );

      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(snackBar);
    });
  }

  Future<void> _scanNow() async {
    final appState = _appState;
    if (_scanInProgress || !_shouldScan(appState)) {
      return;
    }

    _scanTimer?.cancel();

    setState(() {
      _scanInProgress = true;
      _error = null;
    });

    try {
      final devices = _normalizeDevices(
        await appState.connector!.availableChameleons(false),
      );
      if (!mounted) {
        return;
      }

      appState.syncAutoReconnectSuppression(
        devices.map((device) => device.port),
      );

      if (!devices.any(
        (device) => device.port == _lastAutoConnectAttemptPort,
      )) {
        _lastAutoConnectAttemptPort = null;
      }

      setState(() {
        _devices = devices;
        _initialScanCompleted = true;
      });

      _showPermissionsWarningIfNeeded(devices);
      await _maybeAutoConnect(devices);
    } catch (error) {
      await appState.connector!.performDisconnect();
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error;
        _initialScanCompleted = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _scanInProgress = false;
        });
        _scheduleNextScan();
      }
    }
  }

  Future<void> _maybeAutoConnect(List<Chameleon> devices) async {
    final appState = _appState;
    if (!_shouldScan(appState)) {
      return;
    }
    // BLE has no manual device picker on Windows, so a found BLE Chameleon is
    // always connected. USB keeps honouring the auto-connect preference.
    final autoConnect =
        appState.sharedPreferencesProvider.getAutoConnectFirstFoundDevice() ||
        devices.any((device) => device.type == ConnectionType.ble);
    if (!autoConnect) {
      return;
    }

    Chameleon? connectableDevice;
    Chameleon? dfuDevice;
    for (final device in devices) {
      if (device.dfu) {
        dfuDevice ??= device;
        continue;
      }
      if (!appState.isAutoReconnectSuppressed(device.port)) {
        connectableDevice = device;
        break;
      }
    }

    if (connectableDevice == null) {
      if (dfuDevice != null && _lastAutoConnectAttemptPort != dfuDevice.port) {
        _lastAutoConnectAttemptPort = dfuDevice.port;
        _showDfuDialog(dfuDevice);
      }
      return;
    }

    if (_lastAutoConnectAttemptPort == connectableDevice.port) {
      return;
    }

    _lastAutoConnectAttemptPort = connectableDevice.port;
    await _connectToDevice(connectableDevice);
  }

  Future<void> _connectToDevice(Chameleon chameleonDevice) async {
    final appState = _appState;

    if (_connectionInProgress) {
      return;
    }

    if (chameleonDevice.dfu) {
      _showDfuDialog(chameleonDevice);
      return;
    }

    _scanTimer?.cancel();
    if (mounted) {
      setState(() {
        _connectionInProgress = true;
      });
    }

    try {
      if (chameleonDevice.type == ConnectionType.ble) {
        appState.connector!.pendingConnection = true;
        appState.changesMade();
      }

      final connected = await appState.connector!.connectSpecificDevice(
        chameleonDevice.port,
      );
      if (connected) {
        appState.connector!.pendingConnection = false;
        appState.clearAutoReconnectSuppression(chameleonDevice.port);
        appState.communicator = ChameleonCommunicator(
          appState.log!,
          port: appState.connector,
        );
      } else {
        appState.connector!.pendingConnection = false;
        _lastAutoConnectAttemptPort = null;
      }

      appState.changesMade();
    } catch (error) {
      appState.connector!.pendingConnection = false;
      appState.changesMade();
      if (mounted) {
        setState(() {
          _error = error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _connectionInProgress = false;
        });
      }

      if (!appState.connector!.connected) {
        _scheduleNextScan();
      }
    }
  }

  void _showDfuDialog(Chameleon chameleonDevice) {
    final appState = _appState;
    final localizations = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(localizations.chameleon_is_dfu),
        content: Text(localizations.firmware_is_corrupted),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, localizations.cancel),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext, localizations.flash);
              appState.changesMade();

              scaffoldMessenger.hideCurrentSnackBar();
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text(
                    localizations.downloading_fw(
                      chameleonDeviceName(chameleonDevice.device),
                    ),
                  ),
                  action: SnackBarAction(
                    label: localizations.close,
                    onPressed: scaffoldMessenger.hideCurrentSnackBar,
                  ),
                ),
              );

              await flashFirmware(
                appState,
                scaffoldMessenger: scaffoldMessenger,
                device: chameleonDevice.device,
                enterDFU: false,
              );

              appState.changesMade();
              if (mounted) {
                _scanNow();
              }
            },
            child: Text(localizations.flash),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(AppLocalizations localizations) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isBle = device.type == ConnectionType.ble;
        return Card(
          key: ValueKey('connect_device_${device.port}'),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(isBle ? Icons.bluetooth : Icons.usb),
            title: Text(
              'Chameleon ${chameleonDeviceName(device.device)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${device.port}${device.dfu ? localizations.dfu : ''}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _connectToDevice(device),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<ChameleonGUIState>();
    final localizations = AppLocalizations.of(context)!;

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.connect)),
        body: ErrorPage(errorMessage: _error.toString()),
      );
    }

    final connecting =
        appState.connector!.pendingConnection || _connectionInProgress;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.connect)),
      body: Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 132,
            child: ConnectionStatus(
              connected: appState.connector!.connected,
              connecting: connecting,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: (_scanInProgress && !_initialScanCompleted)
                ? const Center(child: CircularProgressIndicator())
                : _buildDeviceList(localizations),
          ),
          if (appState.connector!.isManualConnectionSupported())
            SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextButton.icon(
                    key: const ValueKey('connect_manual_entry'),
                    onPressed: () => showDialog<String>(
                      context: context,
                      builder: (BuildContext dialogContext) =>
                          const ManualConnect(),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(localizations.connect_manually),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

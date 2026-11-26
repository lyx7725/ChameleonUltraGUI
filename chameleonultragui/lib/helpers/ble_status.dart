import 'dart:async';

import 'package:flutter/foundation.dart';

/// One-line state shown by the connect page.
enum BlePhase { waiting, connecting, pinRequired, pinError, failedRetrying }

/// Keeps the UI phase tied to observable events and expires a real failure
/// back to waiting after a bounded retry window.
class BlePhaseController {
  BlePhaseController({this.retryWindow = const Duration(seconds: 3)});

  final Duration retryWindow;
  final ValueNotifier<BlePhase> phase = ValueNotifier<BlePhase>(
    BlePhase.waiting,
  );
  Timer? _retryTimer;

  void set(BlePhase value) {
    if (value == BlePhase.failedRetrying) {
      attemptFailed();
      return;
    }
    _cancelRetry();
    phase.value = value;
  }

  /// No device has been reported and no real connection is running.
  void waiting() => set(BlePhase.waiting);

  /// Kept explicit so the background remembered-address path is tested as a
  /// waiting state, never as a failure.
  void backgroundWaiting() => set(BlePhase.waiting);

  void connecting() => set(BlePhase.connecting);

  /// A real attempt failed; show the failure only for [retryWindow].
  void attemptFailed() {
    _retryTimer?.cancel();
    phase.value = BlePhase.failedRetrying;
    _retryTimer = Timer(retryWindow, () {
      if (phase.value == BlePhase.failedRetrying) {
        phase.value = BlePhase.waiting;
      }
    });
  }

  void manualDisconnect() {
    _cancelRetry();
    phase.value = BlePhase.waiting;
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void dispose() {
    _cancelRetry();
    phase.dispose();
  }
}

class BleStatus {
  BleStatus._();

  static final BlePhaseController _controller = BlePhaseController();

  static ValueNotifier<BlePhase> get phase => _controller.phase;

  static void set(BlePhase value) => _controller.set(value);

  static void waiting() => _controller.waiting();

  static void backgroundWaiting() => _controller.backgroundWaiting();

  static void connecting() => _controller.connecting();

  static void attemptFailed() => _controller.attemptFailed();

  static void manualDisconnect() => _controller.manualDisconnect();
}

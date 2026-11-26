/// Tracks whether BLE watching is wanted and whether a scan is currently
/// running. Suspending must stop the active scan and let a later resume start a
/// fresh one instead of leaving a five-minute waiter behind.
class BleWatchState {
  bool _desired = false;
  bool _active = false;

  bool get desired => _desired;
  bool get active => _active;

  /// Returns false when watching was already requested.
  bool start() {
    if (_desired) {
      return false;
    }
    _desired = true;
    return true;
  }

  void stop() {
    _desired = false;
  }

  /// Returns false when a watch loop is already running.
  bool begin() {
    if (!_desired || _active) {
      return false;
    }
    _active = true;
    return true;
  }

  void end() {
    _active = false;
  }
}

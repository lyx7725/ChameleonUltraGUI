import 'package:flutter/widgets.dart';

/// Only a detached engine is an exit. Android pauses the activity while the
/// firmware file picker is open, and that must keep the device connected.
bool shouldShutdownOnLifecycle(AppLifecycleState state) {
  return state == AppLifecycleState.detached;
}

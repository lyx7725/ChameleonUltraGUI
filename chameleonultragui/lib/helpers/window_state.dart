import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _Rect extends Struct {
  @Int32()
  external int left;
  @Int32()
  external int top;
  @Int32()
  external int right;
  @Int32()
  external int bottom;
}

final class _Point extends Struct {
  @Int32()
  external int x;
  @Int32()
  external int y;
}

final class _WindowPlacement extends Struct {
  @Uint32()
  external int length;
  @Uint32()
  external int flags;
  @Uint32()
  external int showCmd;

  external _Point ptMinPosition;
  external _Point ptMaxPosition;
  external _Rect rcNormalPosition;
}

typedef _EnumWindowsNative = Int32 Function(
  Pointer<NativeFunction<Int32 Function(IntPtr, IntPtr)>>,
  IntPtr,
);
typedef _EnumWindowsDart = int Function(
  Pointer<NativeFunction<Int32 Function(IntPtr, IntPtr)>>,
  int,
);
typedef _EnumProcNative = Int32 Function(IntPtr, IntPtr);
typedef _GetWindowThreadProcessIdNative = Uint32 Function(
  IntPtr,
  Pointer<Uint32>,
);
typedef _GetWindowThreadProcessIdDart = int Function(int, Pointer<Uint32>);
typedef _GetClassNameNative = Int32 Function(IntPtr, Pointer<Utf16>, Int32);
typedef _GetClassNameDart = int Function(int, Pointer<Utf16>, int);
typedef _GetWindowPlacementNative = Int32 Function(
  IntPtr,
  Pointer<_WindowPlacement>,
);
typedef _GetWindowPlacementDart = int Function(int, Pointer<_WindowPlacement>);
typedef _SetWindowPosNative = Int32 Function(
  IntPtr,
  IntPtr,
  Int32,
  Int32,
  Int32,
  Int32,
  Uint32,
);
typedef _SetWindowPosDart = int Function(int, int, int, int, int, int, int);
typedef _ShowWindowNative = Int32 Function(IntPtr, Int32);
typedef _ShowWindowDart = int Function(int, int);
typedef _MonitorFromRectNative = IntPtr Function(Pointer<_Rect>, Uint32);
typedef _MonitorFromRectDart = int Function(Pointer<_Rect>, int);
typedef _GetCurrentProcessIdNative = Uint32 Function();
typedef _GetCurrentProcessIdDart = int Function();

const int _swpNoZOrder = 0x0004;
const int _swpNoActivate = 0x0010;
const int _monitorDefaultToNull = 0;
const int _swShowMaximized = 3;

DynamicLibrary? _user32Lib;
DynamicLibrary? _kernel32Lib;

DynamicLibrary get _user32 => _user32Lib ??= DynamicLibrary.open('user32.dll');
DynamicLibrary get _kernel32 =>
    _kernel32Lib ??= DynamicLibrary.open('kernel32.dll');

int _targetProcessId = 0;
int _foundWindow = 0;

int _enumWindowsCallback(int hwnd, int lParam) {
  final pidPtr = calloc<Uint32>();
  try {
    _user32.lookupFunction<
      _GetWindowThreadProcessIdNative,
      _GetWindowThreadProcessIdDart
    >('GetWindowThreadProcessId')(hwnd, pidPtr);
    if (pidPtr.value != _targetProcessId) {
      return 1;
    }
  } finally {
    calloc.free(pidPtr);
  }

  final namePtr = calloc<Uint16>(128);
  try {
    _user32.lookupFunction<_GetClassNameNative, _GetClassNameDart>(
      'GetClassNameW',
    )(hwnd, namePtr.cast<Utf16>(), 128);
    if (namePtr.cast<Utf16>().toDartString() == 'FLUTTER_RUNNER_WIN32_WINDOW') {
      _foundWindow = hwnd;
      return 0;
    }
  } finally {
    calloc.free(namePtr);
  }
  return 1;
}

int _findOwnWindow() {
  _targetProcessId = _kernel32
      .lookupFunction<_GetCurrentProcessIdNative, _GetCurrentProcessIdDart>(
        'GetCurrentProcessId',
      )();
  _foundWindow = 0;
  final callback = Pointer.fromFunction<_EnumProcNative>(
    _enumWindowsCallback,
    1,
  );
  _user32.lookupFunction<_EnumWindowsNative, _EnumWindowsDart>('EnumWindows')(
    callback,
    0,
  );
  return _foundWindow;
}

class WindowStateKeeper {
  WindowStateKeeper._();

  static final WindowStateKeeper instance = WindowStateKeeper._();

  static const _kX = 'window_rect_x';
  static const _kY = 'window_rect_y';
  static const _kWidth = 'window_rect_width';
  static const _kHeight = 'window_rect_height';
  static const _kMaximized = 'window_rect_maximized';
  static const _kState = 'window_rect_state';

  static (int, int, int, int, bool)? _decodeState(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final x = decoded['x'];
      final y = decoded['y'];
      final width = decoded['width'];
      final height = decoded['height'];
      final maximized = decoded['maximized'];
      if (x is! int ||
          y is! int ||
          width is! int ||
          height is! int ||
          width < 400 ||
          height < 300 ||
          width > 16384 ||
          height > 16384) {
        return null;
      }
      return (x, y, width, height, maximized is bool && maximized);
    } catch (_) {
      return null;
    }
  }

  int _hwnd = 0;
  Timer? _timer;
  SharedPreferences? _prefs;

  int _savedX = 0;
  int _savedY = 0;
  int _savedWidth = 0;
  int _savedHeight = 0;
  bool _savedMaximized = false;

  int _pendingX = 0;
  int _pendingY = 0;
  int _pendingWidth = 0;
  int _pendingHeight = 0;
  bool _pendingMaximized = false;
  DateTime? _pendingSince;

  Future<void> restore() async {
    if (!Platform.isWindows) {
      return;
    }

    _hwnd = _findOwnWindow();
    if (_hwnd == 0) {
      return;
    }

    final prefs = _prefs = await SharedPreferences.getInstance();
    final encoded = _decodeState(prefs.getString(_kState));
    final int width;
    final int height;
    final int x;
    final int y;
    final bool maximized;
    if (encoded != null) {
      x = encoded.$1;
      y = encoded.$2;
      width = encoded.$3;
      height = encoded.$4;
      maximized = encoded.$5;
    } else {
      width = prefs.getInt(_kWidth) ?? 0;
      height = prefs.getInt(_kHeight) ?? 0;
      if (width < 400 || height < 300) {
        return;
      }
      x = prefs.getInt(_kX) ?? 0;
      y = prefs.getInt(_kY) ?? 0;
      maximized = prefs.getBool(_kMaximized) ?? false;
    }
    final restoredWidth = math.max(width, 640);
    final restoredHeight = math.max(height, 480);

    final rect = calloc<_Rect>();
    rect.ref
      ..left = x
      ..top = y
      ..right = x + restoredWidth
      ..bottom = y + restoredHeight;
    final monitor = _user32
        .lookupFunction<_MonitorFromRectNative, _MonitorFromRectDart>(
          'MonitorFromRect',
        )(rect, _monitorDefaultToNull);
    calloc.free(rect);
    if (monitor == 0) {
      // The saved position no longer intersects any monitor.
      return;
    }

    _user32.lookupFunction<_SetWindowPosNative, _SetWindowPosDart>(
      'SetWindowPos',
    )(
      _hwnd,
      0,
      x,
      y,
      restoredWidth,
      restoredHeight,
      _swpNoZOrder | _swpNoActivate,
    );

    if (maximized) {
      _user32.lookupFunction<_ShowWindowNative, _ShowWindowDart>('ShowWindow')(
        _hwnd,
        _swShowMaximized,
      );
    }

    _savedX = x;
    _savedY = y;
    _savedWidth = restoredWidth;
    _savedHeight = restoredHeight;
    _savedMaximized = maximized;
  }

  void start() {
    if (!Platform.isWindows || _hwnd == 0) {
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _captureWindowState(),
    );
  }

  void _captureWindowState() {
    final placement = calloc<_WindowPlacement>();
    try {
      placement.ref.length = sizeOf<_WindowPlacement>();
      final ok = _user32
          .lookupFunction<_GetWindowPlacementNative, _GetWindowPlacementDart>(
            'GetWindowPlacement',
          )(_hwnd, placement);
      if (ok == 0) {
        return;
      }

      final rect = placement.ref.rcNormalPosition;
      final width = rect.right - rect.left;
      final height = rect.bottom - rect.top;
      if (width < 200 || height < 200) {
        return;
      }

      final maximized = placement.ref.showCmd == _swShowMaximized;
      final sameAsPending =
          rect.left == _pendingX &&
          rect.top == _pendingY &&
          width == _pendingWidth &&
          height == _pendingHeight &&
          maximized == _pendingMaximized;

      if (!sameAsPending) {
        _pendingX = rect.left;
        _pendingY = rect.top;
        _pendingWidth = width;
        _pendingHeight = height;
        _pendingMaximized = maximized;
        _pendingSince = DateTime.now();
        return;
      }

      final since = _pendingSince;
      if (since == null ||
          DateTime.now().difference(since) <
              const Duration(milliseconds: 700)) {
        return;
      }

      _pendingSince = null;
      if (rect.left == _savedX &&
          rect.top == _savedY &&
          width == _savedWidth &&
          height == _savedHeight &&
          maximized == _savedMaximized) {
        return;
      }
      _savedX = _pendingX;
      _savedY = _pendingY;
      _savedWidth = _pendingWidth;
      _savedHeight = _pendingHeight;
      _savedMaximized = _pendingMaximized;

      final prefs = _prefs;
      if (prefs == null) {
        return;
      }
      prefs.setString(
        _kState,
        jsonEncode({
          'x': _savedX,
          'y': _savedY,
          'width': _savedWidth,
          'height': _savedHeight,
          'maximized': _savedMaximized,
        }),
      );
    } finally {
      calloc.free(placement);
    }
  }
}

/// Hides the runner window. Used by the headless BLE stress harness.
void hideApplicationWindow() {
  if (!Platform.isWindows) {
    return;
  }
  final hwnd = _findOwnWindow();
  if (hwnd == 0) {
    return;
  }
  try {
    _user32.lookupFunction<_ShowWindowNative, _ShowWindowDart>('ShowWindow')(
      hwnd,
      0,
    );
  } catch (_) {}
}

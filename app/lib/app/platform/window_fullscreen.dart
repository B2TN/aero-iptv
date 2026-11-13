import 'dart:ffi';
import 'dart:io' show pid;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const int _gwlStyle = -16;
const int _wsOverlappedWindow = 0x00CF0000;
const int _monitorDefaultToPrimary = 1;
const int _swpNoSize = 0x0001;
const int _swpNoMove = 0x0002;
const int _swpNoZOrder = 0x0004;
const int _swpFrameChanged = 0x0020;
const int _swpNoOwnerZOrder = 0x0200;

/// Tailles fixes de `WINDOWPLACEMENT` et de `MONITORINFO`.
const int _placementBytes = 44;
const int _monitorInfoBytes = 40;

final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');

final int Function(int, int, Pointer<Utf16>, Pointer<Utf16>) _findWindow =
    _user32.lookupFunction<
      IntPtr Function(IntPtr, IntPtr, Pointer<Utf16>, Pointer<Utf16>),
      int Function(int, int, Pointer<Utf16>, Pointer<Utf16>)
    >('FindWindowExW');
final int Function(int, Pointer<Uint32>) _windowProcess = _user32
    .lookupFunction<
      Uint32 Function(IntPtr, Pointer<Uint32>),
      int Function(int, Pointer<Uint32>)
    >('GetWindowThreadProcessId');
final int Function(int, int) _getStyle = _user32
    .lookupFunction<IntPtr Function(IntPtr, Int32), int Function(int, int)>(
      'GetWindowLongPtrW',
    );
final int Function(int, int, int) _setStyle = _user32
    .lookupFunction<
      IntPtr Function(IntPtr, Int32, IntPtr),
      int Function(int, int, int)
    >('SetWindowLongPtrW');
final int Function(int, Pointer<Uint8>) _getPlacement = _user32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint8>),
      int Function(int, Pointer<Uint8>)
    >('GetWindowPlacement');
final int Function(int, Pointer<Uint8>) _setPlacement = _user32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint8>),
      int Function(int, Pointer<Uint8>)
    >('SetWindowPlacement');
final int Function(int, int) _monitorFromWindow = _user32
    .lookupFunction<IntPtr Function(IntPtr, Uint32), int Function(int, int)>(
      'MonitorFromWindow',
    );
final int Function(int, Pointer<Uint8>) _getMonitorInfo = _user32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Uint8>),
      int Function(int, Pointer<Uint8>)
    >('GetMonitorInfoW');
final int Function(int, int, int, int, int, int, int) _setWindowPos = _user32
    .lookupFunction<
      Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
      int Function(int, int, int, int, int, int, int)
    >('SetWindowPos');

/// Plein écran de la fenêtre Windows, sans modification du lanceur natif.
final class WindowFullscreen {
  Uint8List? _placement;
  int _style = 0;

  bool get isActive => _placement != null;

  void toggle() => isActive ? exit() : enter();

  void enter() {
    final window = _flutterWindow();
    if (window == 0 || isActive) return;
    final placement = calloc<Uint8>(_placementBytes);
    final monitor = calloc<Uint8>(_monitorInfoBytes);
    try {
      placement.cast<Uint32>().value = _placementBytes;
      monitor.cast<Uint32>().value = _monitorInfoBytes;
      if (_getPlacement(window, placement) == 0) return;
      final screen = _monitorFromWindow(window, _monitorDefaultToPrimary);
      if (_getMonitorInfo(screen, monitor) == 0) return;

      _style = _getStyle(window, _gwlStyle);
      _placement = Uint8List.fromList(placement.asTypedList(_placementBytes));
      // `rcMonitor` suit immédiatement `cbSize` dans `MONITORINFO`.
      final bounds = monitor.cast<Int32>().asTypedList(5);
      _setStyle(window, _gwlStyle, _style & ~_wsOverlappedWindow);
      _setWindowPos(
        window,
        0,
        bounds[1],
        bounds[2],
        bounds[3] - bounds[1],
        bounds[4] - bounds[2],
        _swpFrameChanged | _swpNoOwnerZOrder,
      );
    } finally {
      calloc
        ..free(placement)
        ..free(monitor);
    }
  }

  void exit() {
    final saved = _placement;
    final window = _flutterWindow();
    if (saved == null || window == 0) return;
    final placement = calloc<Uint8>(_placementBytes);
    try {
      placement.asTypedList(_placementBytes).setAll(0, saved);
      _setStyle(window, _gwlStyle, _style);
      _setPlacement(window, placement);
      _setWindowPos(
        window,
        0,
        0,
        0,
        0,
        0,
        _swpNoMove |
            _swpNoSize |
            _swpNoZOrder |
            _swpNoOwnerZOrder |
            _swpFrameChanged,
      );
      _placement = null;
    } finally {
      calloc.free(placement);
    }
  }

  /// Fenêtre de cette application. Toute application Flutter ouverte à côté a
  /// une fenêtre de la même classe : seul le numéro de processus les distingue.
  int _flutterWindow() {
    final name = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
    final owner = calloc<Uint32>();
    try {
      var window = _findWindow(0, 0, name, nullptr);
      while (window != 0) {
        _windowProcess(window, owner);
        if (owner.value == pid) return window;
        window = _findWindow(0, window, name, nullptr);
      }
      return 0;
    } finally {
      calloc
        ..free(name)
        ..free(owner);
    }
  }
}

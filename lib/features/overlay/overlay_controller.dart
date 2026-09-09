import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class OverlayController extends ChangeNotifier {
  static final OverlayController _instance = OverlayController._internal();
  factory OverlayController() => _instance;
  OverlayController._internal();

  final SystemTray _systemTray = SystemTray();
  bool _isVisible = true;
  bool _isInitialized = false;

  bool get isVisible => _isVisible;

  Future<void> initialize({required VoidCallback onToggleRequested}) async {
    if (!Platform.isWindows || _isInitialized) return;
    _isInitialized = true;

    // 1. Configure Window Styling & Acrylic Effect
    try {
      await windowManager.setAsFrameless();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSkipTaskbar(false);
      try {
        await Window.setEffect(
          effect: WindowEffect.acrylic,
          color: const Color(0xD90A0F1D),
        );
      } catch (e) {
        debugPrint('[OverlayController] Acrylic effect fallback: $e');
      }
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
      _isVisible = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[OverlayController] Window setup error: $e');
    }

    // 2. Initialize System Tray with bundled assets/icons/app_icon.ico
    try {
      await _initSystemTray(onToggleRequested);
    } catch (e) {
      debugPrint('[OverlayController] System tray error: $e');
    }

    // 3. Register Global Hotkeys: Alt + Q, F9, Ctrl + Shift + A
    try {
      await _registerHotkeys(onToggleRequested);
    } catch (e) {
      debugPrint('[OverlayController] Hotkeys error: $e');
    }

    // 4. In-App Key Handler as resilient backup
    HardwareKeyboard.instance.addHandler((event) {
      if (event is KeyDownEvent) {
        final isAltQ = HardwareKeyboard.instance.isAltPressed &&
            event.logicalKey == LogicalKeyboardKey.keyQ;
        final isF9 = event.logicalKey == LogicalKeyboardKey.f9;
        final isCtrlShiftA = HardwareKeyboard.instance.isControlPressed &&
            HardwareKeyboard.instance.isShiftPressed &&
            event.logicalKey == LogicalKeyboardKey.keyA;

        if (isAltQ || isF9 || isCtrlShiftA) {
          debugPrint('[OverlayController] In-app hotkey detected');
          toggleOverlay();
          return true;
        }
      }
      return false;
    });
  }

  Future<void> _initSystemTray(VoidCallback onToggleRequested) async {
    try {
      const iconPath = 'assets/icons/app_icon.ico';
      debugPrint('[OverlayController] Initializing system tray with asset: $iconPath');

      await _systemTray.initSystemTray(
        title: "AirP2P",
        iconPath: iconPath,
        toolTip: "AirP2P Local File Sharing (Alt+Q / F9)",
      );

      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: 'Show AirP2P (Alt + Q / F9)',
          onClicked: (menuItem) => showOverlay(),
        ),
        MenuItemLabel(
          label: 'Hide Overlay (Esc)',
          onClicked: (menuItem) => hideOverlay(),
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: 'Exit AirP2P',
          onClicked: (menuItem) async {
            await hideOverlay();
            exit(0);
          },
        ),
      ]);

      await _systemTray.setContextMenu(menu);

      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick ||
            eventName == kSystemTrayEventDoubleClick) {
          toggleOverlay();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });
      debugPrint('[OverlayController] System tray initialized successfully');
    } catch (e) {
      debugPrint('[OverlayController] System tray error: $e');
    }
  }

  Future<void> _registerHotkeys(VoidCallback onToggleRequested) async {
    try {
      await hotKeyManager.unregisterAll();

      // Primary: Alt + Q
      final altQ = HotKey(
        key: LogicalKeyboardKey.keyQ,
        modifiers: [HotKeyModifier.alt],
        scope: HotKeyScope.system,
      );

      // Fallback 1: F9 (Single key, zero conflict)
      final f9 = HotKey(
        key: LogicalKeyboardKey.f9,
        modifiers: [],
        scope: HotKeyScope.system,
      );

      // Fallback 2: Ctrl + Shift + A
      final ctrlShiftA = HotKey(
        key: LogicalKeyboardKey.keyA,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );

      for (final hk in [altQ, f9, ctrlShiftA]) {
        try {
          await hotKeyManager.register(
            hk,
            keyDownHandler: (hotKey) {
              debugPrint('[OverlayController] System Hotkey ${hotKey.key} triggered!');
              toggleOverlay();
            },
          );
          debugPrint('[OverlayController] Registered hotkey: ${hk.key?.keyLabel}');
        } catch (err) {
          debugPrint('[OverlayController] Could not register ${hk.key}: $err');
        }
      }

      debugPrint('[OverlayController] Global hotkeys registered (Alt+Q, F9, Ctrl+Shift+A)');
    } catch (e) {
      debugPrint('[OverlayController] Hotkeys registration error: $e');
    }
  }

  Future<void> showOverlay() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.restore();
      await windowManager.setAlwaysOnTop(true);
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
      _isVisible = true;
      notifyListeners();
      debugPrint('[OverlayController] Overlay shown');
    } catch (e) {
      debugPrint('[OverlayController] Show overlay error: $e');
    }
  }

  Future<void> hideOverlay() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.minimize();
      _isVisible = false;
      notifyListeners();
      debugPrint('[OverlayController] Overlay hidden');
    } catch (e) {
      debugPrint('[OverlayController] Hide overlay error: $e');
    }
  }

  Future<void> toggleOverlay() async {
    if (!Platform.isWindows) return;
    try {
      final isMin = await windowManager.isMinimized();
      final isVis = await windowManager.isVisible();
      debugPrint('[OverlayController] toggleOverlay (state: _isVisible=$_isVisible, isVis=$isVis, isMin=$isMin)');
      if (!isMin && isVis && _isVisible) {
        await hideOverlay();
      } else {
        await showOverlay();
      }
    } catch (e) {
      debugPrint('[OverlayController] toggleOverlay fallback: $e');
      if (_isVisible) {
        await hideOverlay();
      } else {
        await showOverlay();
      }
    }
  }
}

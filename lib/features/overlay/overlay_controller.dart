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
  bool _isVisible = false;
  bool _isInitialized = false;

  bool get isVisible => _isVisible;

  Future<void> initialize({required VoidCallback onToggleRequested}) async {
    if (!Platform.isWindows || _isInitialized) return;
    _isInitialized = true;

    try {
      // 1. Initialize Window Manager
      await windowManager.ensureInitialized();
      await Window.initialize();

      // Configure window geometry and transparency
      await windowManager.waitUntilReadyToShow(
        const WindowOptions(
          center: true,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.hidden,
          alwaysOnTop: true,
        ),
        () async {
          await windowManager.setAsFrameless();
          try {
            await Window.setEffect(
              effect: WindowEffect.acrylic,
              color: const Color(0xCC0A0F1D),
            );
          } catch (e) {
            debugPrint('[OverlayController] Acrylic effect fallback: $e');
          }
          await windowManager.maximize();
          await windowManager.show();
          await windowManager.focus();
          _isVisible = true;
          notifyListeners();
        },
      );

      // 2. Initialize System Tray
      await _initSystemTray(onToggleRequested);

      // 3. Register Global Hotkey Win + Q
      await _registerHotkey(onToggleRequested);
    } catch (e) {
      debugPrint('[OverlayController] Initialization error: $e');
    }
  }

  Future<void> _initSystemTray(VoidCallback onToggleRequested) async {
    try {
      var iconPath = 'windows/runner/resources/app_icon.ico';
      final devIcon = File('windows/runner/resources/app_icon.ico');
      if (devIcon.existsSync()) {
        iconPath = devIcon.absolute.path;
      }

      await _systemTray.initSystemTray(
        title: "AirP2P",
        iconPath: iconPath,
      );

      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: 'Show AirP2P (Alt + Q)',
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
        if (eventName == kSystemTrayEventClick) {
          toggleOverlay();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });
    } catch (e) {
      debugPrint('[OverlayController] System tray error: $e');
    }
  }

  Future<void> _registerHotkey(VoidCallback onToggleRequested) async {
    try {
      await hotKeyManager.unregisterAll();

      // Alt + Q hotkey
      final hotKey = HotKey(
        key: LogicalKeyboardKey.keyQ,
        modifiers: [HotKeyModifier.alt],
        scope: HotKeyScope.system,
      );

      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) {
          debugPrint('[OverlayController] Hotkey Alt + Q triggered');
          toggleOverlay();
        },
      );
      debugPrint('[OverlayController] Global hotkey Alt + Q registered');
    } catch (e) {
      debugPrint('[OverlayController] Failed to register Alt+Q hotkey: $e');
    }
  }

  Future<void> showOverlay() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.setAlwaysOnTop(true);
      await windowManager.maximize();
      await windowManager.show();
      await windowManager.focus();
      _isVisible = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[OverlayController] Show overlay error: $e');
    }
  }

  Future<void> hideOverlay() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.hide();
      _isVisible = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[OverlayController] Hide overlay error: $e');
    }
  }

  void toggleOverlay() {
    if (_isVisible) {
      hideOverlay();
    } else {
      showOverlay();
    }
  }
}

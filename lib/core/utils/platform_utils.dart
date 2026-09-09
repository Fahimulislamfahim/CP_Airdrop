import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PlatformUtils {
  static bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static String get osName {
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static String get devType => isDesktop ? 'desktop' : 'mobile';

  /// Derive or retrieve a clean default device name
  static String getDefaultDeviceName() {
    final hostname = Platform.localHostname;
    if (hostname.isNotEmpty) {
      // Clean up common suffix like .local
      return hostname.replaceAll(RegExp(r'\.local$'), '');
    }
    if (Platform.isWindows) return 'Windows PC';
    if (Platform.isAndroid) return 'Android Phone';
    if (Platform.isIOS) return 'iPhone';
    return 'AirP2P Device';
  }

  /// Get the standard directory where received files should be stored.
  static Future<Directory> getSaveDirectory() async {
    if (Platform.isWindows) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        final airDropDir = Directory(p.join(downloadsDir.path, 'AirP2P'));
        if (!await airDropDir.exists()) {
          await airDropDir.create(recursive: true);
        }
        return airDropDir;
      }
    }

    // Android/iOS or fallback
    final docDir = await getApplicationDocumentsDirectory();
    final receivedDir = Directory(p.join(docDir.path, 'AirP2P'));
    if (!await receivedDir.exists()) {
      await receivedDir.create(recursive: true);
    }
    return receivedDir;
  }
}

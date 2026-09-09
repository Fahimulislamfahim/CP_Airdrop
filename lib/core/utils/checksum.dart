import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Utilities for calculating SHA-256 hashes using streaming (without buffering entire file into memory).
class ChecksumUtils {
  /// Calculate SHA-256 hash of a file by streaming its contents.
  static Future<String> calculateSha256(File file) async {
    final stream = file.openRead();
    final digest = await sha256.bind(stream).first;
    return digest.toString();
  }

  /// Format byte counts into human-readable strings (KB, MB, GB).
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}

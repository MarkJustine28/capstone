// lib/config/env_web.dart
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

class Env {
  /// Returns ENV for web (reads from window.env)
  static String get env {
    try {
      final jsEnv = js.context['env'];
      if (jsEnv != null) {
        final value = jsEnv['ENV'];
        if (value != null) {
          debugPrint('🌐 ENV (web): $value');
          return value.toString();
        }
      }
    } catch (e) {
      debugPrint('❌ Error reading ENV: $e');
    }
    debugPrint('🌐 ENV (web fallback): production');
    return 'production';
  }

  /// Returns SERVER_IP for web (reads from window.env)
  static String get serverIp {
    try {
      final jsEnv = js.context['env'];
      if (jsEnv != null) {
        final value = jsEnv['SERVER_IP'];
        if (value != null) {
          final server = value.toString();
          final clean = server.endsWith('/') ? server.substring(0, server.length - 1) : server;
          debugPrint('🌐 SERVER_IP (web): $clean');
          return clean;
        }
      }
    } catch (e) {
      debugPrint('❌ Error reading SERVER_IP: $e');
    }
    debugPrint('🌐 SERVER_IP (web fallback): https://guidance-tracker-backend.onrender.com');
    return 'https://guidance-tracker-backend.onrender.com';
  }
}

// lib/config/env_mobile.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  /// Returns ENV for mobile (reads from .env file)
  static String get env {
    final envStr = dotenv.env['ENV'] ?? 'development';
    debugPrint('📱 ENV (mobile): $envStr');
    return envStr;
  }

  /// Returns SERVER_IP for mobile (reads from .env file)
  static String get serverIp {
    final server = dotenv.env['SERVER_IP'] ?? 'http://10.0.2.2:8000';
    final cleanServer = server.endsWith('/') ? server.substring(0, server.length - 1) : server;
    debugPrint('📱 SERVER_IP (mobile): $cleanServer');
    return cleanServer;
  }
}
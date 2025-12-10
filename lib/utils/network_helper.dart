import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NetworkHelper {
  /// Get the server IP address based on platform
  /// Returns the web URL if running on web, mobile URL if on mobile
  static Future<String> getServerIp() async {
    if (kIsWeb) {
      // For web builds, use the web environment
      return dotenv.env['API_BASE_URL'] ?? 'https://guidance-tracker.onrender.com';
    } else {
      // For mobile builds, use the mobile environment
      return dotenv.env['API_BASE_URL'] ?? 'https://guidance-tracker.onrender.com';
    }
  }

  /// Check if server is reachable
  static Future<bool> checkServerConnection(String serverUrl) async {
    try {
      // You can implement a ping/health check here if needed
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get full API endpoint URL
  static Future<String> getApiUrl(String endpoint) async {
    final serverIp = await getServerIp();
    // Remove trailing slash from serverIp and leading slash from endpoint
    final cleanServerIp = serverIp.replaceAll(RegExp(r'/$'), '');
    final cleanEndpoint = endpoint.replaceAll(RegExp(r'^/'), '');
    return '$cleanServerIp/$cleanEndpoint';
  }
}
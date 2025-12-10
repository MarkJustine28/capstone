import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ✅ FIXED: Use only Env class
import '../config/env.dart';

class ApiService {
  // Private constructor for singleton pattern
  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  // ✅ FIXED: Use Env.env (works for web via env.js and for mobile via dotenv)
  static String get environment => Env.env;

  // ✅ FIXED: Build baseUrl using Env.serverIp only
  static String get baseUrl {
    final serverIp = Env.serverIp;
    final cleanUrl = serverIp.endsWith('/') ? serverIp.substring(0, serverIp.length - 1) : serverIp;
    return '$cleanUrl/api';
  }

  // 🔐 Get stored token from SharedPreferences
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      debugPrint('❌ Failed to read token: $e');
      return null;
    }
  }

  // 🔹 Build headers with token
  Map<String, String> _headers(String? token, {bool withJson = true}) {
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Token $token';
    }
    if (withJson) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  // 🔹 Build full URL
  Uri _buildUri(String endpoint) {
    // Ensure endpoint starts with /
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '$baseUrl$cleanEndpoint';
    debugPrint('🌐 Building URL: $fullUrl');
    return Uri.parse(fullUrl);
  }

  // 🔹 Handle HTTP response
  Map<String, dynamic> _handleResponse(http.Response response, {int successCode = 200}) {
    debugPrint('📩 Status Code: ${response.statusCode}');
    debugPrint('📩 Raw Response: ${response.body}');

    try {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      
      if (response.statusCode == successCode || response.statusCode == 200) {
        return {
          'success': true,
          'data': body,
          'status_code': response.statusCode,
        };
      } else {
        return {
          'success': false,
          'error': body['error'] ?? body['message'] ?? 'Request failed',
          'data': body,
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('❌ JSON decode error: $e');
      return {
        'success': false,
        'error': 'Invalid response: ${response.body}',
        'status_code': response.statusCode,
      };
    }
  }

  // 🔹 Generic GET method
  Future<Map<String, dynamic>> get({
    required String endpoint,
    String? token,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final authToken = token ?? await _getToken();
    final uri = _buildUri(endpoint);
    
    debugPrint('🌐 GET Request: $uri');
    debugPrint('🔐 Token: ${authToken != null ? "✅ Present" : "❌ Missing"}');

    try {
      final response = await http
          .get(uri, headers: _headers(authToken, withJson: false))
          .timeout(timeout);
      
      return _handleResponse(response);
    } on SocketException catch (e) {
      debugPrint('❌ Network error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.message}. Please check your connection.',
      };
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout error: $e');
      return {
        'success': false,
        'error': 'Request timeout. Server might be slow or unreachable.',
      };
    } on http.ClientException catch (e) {
      debugPrint('❌ HTTP client error: $e');
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {
        'success': false,
        'error': 'Unexpected error: $e',
      };
    }
  }

  // 🔹 Generic POST method
  Future<Map<String, dynamic>> post({
    required String endpoint,
    String? token,
    required Map<String, dynamic> data,
    int successCode = 201,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final authToken = token ?? await _getToken();
    final uri = _buildUri(endpoint);
    
    debugPrint('🌐 POST Request: $uri');
    debugPrint('🔐 Token: ${authToken != null ? "✅ Present" : "❌ Missing"}');
    debugPrint('🧾 Request Body: ${jsonEncode(data)}');

    try {
      final response = await http
          .post(
            uri,
            headers: _headers(authToken),
            body: jsonEncode(data),
          )
          .timeout(timeout);
      
      return _handleResponse(response, successCode: successCode);
    } on SocketException catch (e) {
      debugPrint('❌ Network error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.message}. Please check your connection.',
      };
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout error: $e');
      return {
        'success': false,
        'error': 'Request timeout. Server might be slow or unreachable.',
      };
    } on http.ClientException catch (e) {
      debugPrint('❌ HTTP client error: $e');
      return {
        'success': false,
        'error': 'Connection error: $e',
      };
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {
        'success': false,
        'error': 'Unexpected error: $e',
      };
    }
  }

  // 🔹 Generic PUT method
  Future<Map<String, dynamic>> put({
    required String endpoint,
    String? token,
    required Map<String, dynamic> data,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final authToken = token ?? await _getToken();
    final uri = _buildUri(endpoint);
    
    debugPrint('🌐 PUT Request: $uri');
    debugPrint('🔐 Token: ${authToken != null ? "✅ Present" : "❌ Missing"}');
    debugPrint('🧾 Request Body: ${jsonEncode(data)}');

    try {
      final response = await http
          .put(
            uri,
            headers: _headers(authToken),
            body: jsonEncode(data),
          )
          .timeout(timeout);
      
      return _handleResponse(response);
    } on SocketException catch (e) {
      debugPrint('❌ Network error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.message}',
      };
    } on TimeoutException catch (e) {
      debugPrint('❌ Timeout error: $e');
      return {
        'success': false,
        'error': 'Request timeout',
      };
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {
        'success': false,
        'error': 'Unexpected error: $e',
      };
    }
  }

  // 🔹 Generic PATCH method
  Future<Map<String, dynamic>> patch({
    required String endpoint,
    String? token,
    required Map<String, dynamic> data,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final authToken = token ?? await _getToken();
    final uri = _buildUri(endpoint);
    
    debugPrint('🌐 PATCH Request: $uri');

    try {
      final response = await http
          .patch(
            uri,
            headers: _headers(authToken),
            body: jsonEncode(data),
          )
          .timeout(timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {
        'success': false,
        'error': 'Request failed: $e',
      };
    }
  }

  // 🔹 Generic DELETE method
  Future<Map<String, dynamic>> delete({
    required String endpoint,
    String? token,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final authToken = token ?? await _getToken();
    final uri = _buildUri(endpoint);
    
    debugPrint('🌐 DELETE Request: $uri');

    try {
      final response = await http
          .delete(
            uri,
            headers: _headers(authToken, withJson: false),
          )
          .timeout(timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {
        'success': false,
        'error': 'Request failed: $e',
      };
    }
  }

  // 🔹 Debug: Print current configuration
  static void printConfig() {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🌍 API Configuration');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📍 Environment: $environment');
    debugPrint('🔗 Base URL: $baseUrl');
    debugPrint('🌐 Mode: ${environment == "production" ? "☁️ Production (Render)" : "💻 Local Development"}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  // ================== STUDENT ENDPOINTS ==================

  Future<Map<String, dynamic>> submitStudentReport({
    required String token,
    required String title,
    required String content,
  }) async {
    return post(
      endpoint: '/student/reports/',
      token: token,
      data: {'title': title, 'content': content},
    );
  }

  Future<Map<String, dynamic>> getStudentReports({required String token}) async {
    return get(endpoint: '/student/reports/', token: token);
  }

  Future<Map<String, dynamic>> getStudentNotifications({required String token}) async {
    return get(endpoint: '/notifications/', token: token);
  }

  Future<Map<String, dynamic>> getStudentProfile({required String token}) async {
    return get(endpoint: '/students/me/', token: token);
  }

  Future<Map<String, dynamic>> updateStudentProfile({
    required String token,
    required Map<String, dynamic> data,
  }) async {
    return put(
      endpoint: '/students/me/',
      token: token,
      data: data,
    );
  }

  // ================== TEACHER ENDPOINTS ==================

  Future<Map<String, dynamic>> submitTeacherReport({
    required String token,
    required String title,
    required String content,
  }) async {
    return post(
      endpoint: '/reports/',
      token: token,
      data: {'title': title, 'content': content},
    );
  }

  Future<Map<String, dynamic>> getTeacherReports({required String token}) async {
    return get(endpoint: '/reports/', token: token);
  }

  Future<Map<String, dynamic>> getTeacherNotifications({required String token}) async {
    return get(endpoint: '/notifications/', token: token);
  }

  // ================== COUNSELOR ENDPOINTS ==================

  Future<Map<String, dynamic>> getCounselorReports({required String token}) async {
    return get(endpoint: '/reports/', token: token);
  }

  Future<Map<String, dynamic>> getCounselorNotifications({required String token}) async {
    return get(endpoint: '/notifications/', token: token);
  }

  Future<Map<String, dynamic>> scheduleCounseling({
    required String token,
    required int reportId,
    required String scheduledDate,
    String? notes,
  }) async {
    return post(
      endpoint: '/counseling/schedule/$reportId/',
      token: token,
      data: {
        'scheduled_date': scheduledDate,
        if (notes != null) 'notes': notes,
      },
    );
  }

  Future<Map<String, dynamic>> skipCounseling({
    required String token,
    required int reportId,
    String? notes,
  }) async {
    return post(
      endpoint: '/counseling/skip/$reportId/',
      token: token,
      data: {
        if (notes != null) 'notes': notes,
      },
    );
  }

  Future<Map<String, dynamic>> completeCounseling({
    required String token,
    required int sessionId,
    required bool studentAttended,
    required bool reporterAttended,
    required bool caseVerified,
    required String sessionNotes,
  }) async {
    return post(
      endpoint: '/counseling/complete/$sessionId/',
      token: token,
      data: {
        'student_attended': studentAttended,
        'reporter_attended': reporterAttended,
        'case_verified': caseVerified,
        'session_notes': sessionNotes,
      },
    );
  }

  Future<Map<String, dynamic>> getCounselingSessions({required String token}) async {
    return get(endpoint: '/counseling/sessions/', token: token);
  }

  // ================== NOTIFICATION ENDPOINTS ==================

  Future<Map<String, dynamic>> markNotificationAsRead({
    required String token,
    required int notificationId,
  }) async {
    return patch(
      endpoint: '/notifications/$notificationId/mark-read/', // ✅ Changed from /read/ to /mark-read/
      token: token,
      data: {'is_read': true}, // ✅ Added data payload
    );
  }

  Future<Map<String, dynamic>> markAllNotificationsAsRead({
    required String token,
  }) async {
    return post(
      endpoint: '/notifications/mark-all-read/',
      token: token,
      data: {},
    );
  }

  Future<Map<String, dynamic>> deleteNotification({
    required String token,
    required int notificationId,
  }) async {
    return delete(
      endpoint: '/notifications/$notificationId/delete/',
      token: token,
    );
  }

  Future<Map<String, dynamic>> getUnreadNotificationCount({
    required String token,
  }) async {
    return get(
      endpoint: '/notifications/unread-count/',
      token: token,
    );
  }

  // ================== VIOLATION ENDPOINTS ==================

  Future<Map<String, dynamic>> getViolationTypes({required String token}) async {
    return get(endpoint: '/violation-types/', token: token);
  }

  Future<Map<String, dynamic>> recordViolation({
    required String token,
    required Map<String, dynamic> data,
  }) async {
    return post(
      endpoint: '/violations/',
      token: token,
      data: data,
    );
  }

  Future<Map<String, dynamic>> getStudentViolations({
    required String token,
    required int studentId,
  }) async {
    return get(endpoint: '/students/$studentId/violations/', token: token);
  }
}

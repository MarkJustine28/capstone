// services/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  // 🌍 Determine environment (auto-detect via .env or build mode)
  static final String environment = dotenv.env['ENV'] ?? (kReleaseMode ? 'production' : 'local');

  // 🌐 Dynamic base URL
  static final String baseUrl = environment == 'production'
      ? "${dotenv.env['PROD_SERVER_URL']}/api"
      : "http://${dotenv.env['LOCAL_SERVER_IP']}/api";

  // 🔹 Helper: Build headers
  static Map<String, String> _headers(String token, {bool withJson = true}) {
    final headers = {"Authorization": "Token $token"};
    if (withJson) headers["Content-Type"] = "application/json";
    return headers;
  }

  // 🔹 Helper: Handle response
  static Map<String, dynamic> _handleResponse(http.Response response, {int successCode = 200}) {
    try {
      final body = jsonDecode(response.body);
      if (response.statusCode == successCode) {
        return {"success": true, "data": body};
      } else {
        return {"success": false, "error": body};
      }
    } catch (e) {
      return {"success": false, "error": "Invalid JSON: ${response.body}"};
    }
  }

  // 🔹 Generic GET method
  static Future<Map<String, dynamic>> get({
    required String endpoint,
    required String token,
  }) async {
    final url = Uri.parse("$baseUrl$endpoint");
    try {
      final response = await http.get(url, headers: _headers(token, withJson: false));
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // 🔹 Generic POST method
  static Future<Map<String, dynamic>> post({
    required String endpoint,
    required String token,
    required Map<String, dynamic> data,
    int successCode = 201,
  }) async {
    final url = Uri.parse("$baseUrl$endpoint");
    try {
      final response = await http.post(
        url,
        headers: _headers(token),
        body: jsonEncode(data),
      );
      return _handleResponse(response, successCode: successCode);
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ================== STUDENT ENDPOINTS ==================

  static Future<Map<String, dynamic>> submitStudentReport({
    required String token,
    required String title,
    required String content,
  }) async {
    return post(
      endpoint: "/student/reports/",
      token: token,
      data: {"title": title, "content": content},
    );
  }

  static Future<Map<String, dynamic>> getStudentReports({required String token}) async {
    return get(endpoint: "/student/reports/", token: token);
  }

  static Future<Map<String, dynamic>> getStudentNotifications({required String token}) async {
    return get(endpoint: "/student/notifications/", token: token);
  }

  static Future<Map<String, dynamic>> getStudentProfile({required String token}) async {
    return get(endpoint: "/student/profile/", token: token);
  }

  static Future<Map<String, dynamic>> updateStudentProfile({
    required String token,
    required Map<String, dynamic> data,
  }) async {
    final url = Uri.parse("$baseUrl/student/profile/");
    try {
      final response = await http.put(
        url,
        headers: _headers(token),
        body: jsonEncode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ================== TEACHER ENDPOINTS ==================

  static Future<Map<String, dynamic>> submitTeacherReport({
    required String token,
    required String title,
    required String content,
  }) async {
    return post(
      endpoint: "/teacher/reports/",
      token: token,
      data: {"title": title, "content": content},
    );
  }

  static Future<Map<String, dynamic>> getTeacherReports({required String token}) async {
    return get(endpoint: "/teacher/reports/", token: token);
  }

  static Future<Map<String, dynamic>> getTeacherNotifications({required String token}) async {
    return get(endpoint: "/teacher/notifications/", token: token);
  }

  // ================== COUNSELOR ENDPOINTS ==================

  static Future<Map<String, dynamic>> getCounselorStudentReports({required String token}) async {
    return get(endpoint: "/counselor/student-reports/", token: token);
  }

  static Future<Map<String, dynamic>> getCounselorTeacherReports({required String token}) async {
    return get(endpoint: "/counselor/teacher-reports/", token: token);
  }

  static Future<Map<String, dynamic>> getCounselorNotifications({required String token}) async {
    return get(endpoint: "/counselor/notifications/", token: token);
  }

  static Future<Map<String, dynamic>> updateReportStatus({
    required String token,
    required int reportId,
    required String status,
  }) async {
    return post(
      endpoint: "/counselor/update-report-status/",
      token: token,
      data: {"report_id": reportId, "status": status},
      successCode: 200,
    );
  }

  // ================== GENERIC METHODS ==================

  static Future<Map<String, dynamic>> getNotifications({required String token}) async {
    return get(endpoint: "/student/notifications/", token: token);
  }

  static Future<Map<String, dynamic>> submitIncident({
    required String token,
    required String title,
    required String description,
    required String reportedBy,
  }) async {
    return submitStudentReport(
      token: token,
      title: title,
      content: description,
    );
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String token,
    required Map<String, dynamic> data,
  }) async {
    return updateStudentProfile(token: token, data: data);
  }
}

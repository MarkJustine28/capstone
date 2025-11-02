// services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static final String baseUrl = "http://${dotenv.env['SERVER_IP']}:8000/api";

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

  // 1️⃣ Submit Student Report
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

  // 2️⃣ Fetch Student Reports
  static Future<Map<String, dynamic>> getStudentReports({required String token}) async {
    return get(endpoint: "/student/reports/", token: token);
  }

  // 3️⃣ Fetch Student Notifications
  static Future<Map<String, dynamic>> getStudentNotifications({required String token}) async {
    return get(endpoint: "/student/notifications/", token: token);
  }

  // 4️⃣ Fetch Student Profile
  static Future<Map<String, dynamic>> getStudentProfile({required String token}) async {
    return get(endpoint: "/student/profile/", token: token);
  }

  // 5️⃣ Update Student Profile
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

  // 6️⃣ Submit Teacher Report
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

  // 7️⃣ Fetch Teacher Reports
  static Future<Map<String, dynamic>> getTeacherReports({required String token}) async {
    return get(endpoint: "/teacher/reports/", token: token);
  }

  // 8️⃣ Fetch Teacher Notifications
  static Future<Map<String, dynamic>> getTeacherNotifications({required String token}) async {
    return get(endpoint: "/teacher/notifications/", token: token);
  }

  // ================== COUNSELOR ENDPOINTS ==================

  // 9️⃣ Fetch Counselor Student Reports (correct endpoint)
  static Future<Map<String, dynamic>> getCounselorStudentReports({required String token}) async {
    return get(endpoint: "/counselor/student-reports/", token: token);
  }

  // 🔟 Fetch Counselor Teacher Reports (correct endpoint)
  static Future<Map<String, dynamic>> getCounselorTeacherReports({required String token}) async {
    return get(endpoint: "/counselor/teacher-reports/", token: token);
  }

  // 1️⃣1️⃣ Fetch Counselor Notifications
  static Future<Map<String, dynamic>> getCounselorNotifications({required String token}) async {
    return get(endpoint: "/counselor/notifications/", token: token);
  }

  // Add this method to the COUNSELOR ENDPOINTS section
  static Future<Map<String, dynamic>> updateReportStatus({
    required String token,
    required int reportId,
    required String status,
  }) async {
    return post(
      endpoint: "/counselor/update-report-status/",
      token: token,
      data: {"report_id": reportId, "status": status},
      successCode: 200, // Status updates typically return 200, not 201
    );
  }

  // ================== GENERIC METHODS ==================

  // 1️⃣2️⃣ Generic Notifications (auto-detect role)
  static Future<Map<String, dynamic>> getNotifications({required String token}) async {
    // This will try student notifications first, can be enhanced to detect role
    return get(endpoint: "/student/notifications/", token: token);
  }

  // 1️⃣3️⃣ Submit Incident Report (legacy support)
  static Future<Map<String, dynamic>> submitIncident({
    required String token,
    required String title,
    required String description,
    required String reportedBy,
  }) async {
    // Map to student report for now
    return submitStudentReport(
      token: token,
      title: title,
      content: description,
    );
  }

  // 1️⃣4️⃣ Update Profile (generic)
  static Future<Map<String, dynamic>> updateProfile({
    required String token,
    required Map<String, dynamic> data,
  }) async {
    return updateStudentProfile(token: token, data: data);
  }
}
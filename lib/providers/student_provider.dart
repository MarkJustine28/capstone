import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StudentProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _violationTypes = [];
  Map<String, dynamic>? _studentInfo; // ✅ NEW: Student info including school year
  bool _isLoading = false;
  bool _isLoadingViolationTypes = false;
  String? _error;
  String? _token;

  final String? serverIp = dotenv.env['SERVER_IP'];

  // -----------------------------
  // Getters
  // -----------------------------
  List<Map<String, dynamic>> get reports => _reports;
  List<Map<String, dynamic>> get notifications => _notifications;
  List<Map<String, dynamic>> get violationTypes => _violationTypes;
  Map<String, dynamic>? get studentInfo => _studentInfo; // ✅ NEW
  bool get isLoading => _isLoading;
  bool get isLoadingReports => _isLoading;
  bool get isLoadingViolationTypesGetter => _isLoadingViolationTypes;
  String? get error => _error;
  String? get token => _token;
  
  // ✅ NEW: Get current school year from student info
  String get currentSchoolYear => _studentInfo?['school_year'] ?? _calculateCurrentSchoolYear();
  String get gradeLevel => _studentInfo?['grade_level'] ?? 'N/A';
  String get section => _studentInfo?['section'] ?? 'N/A';

  // -----------------------------
  // Set token
  // -----------------------------
  void setToken(String token) {
    _token = token;
    notifyListeners();
  }

  // ✅ NEW: Calculate current school year based on date
  String _calculateCurrentSchoolYear() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    // School year starts in June (month 6)
    if (month >= 6) {
      return '$year-${year + 1}';
    } else {
      return '${year - 1}-$year';
    }
  }

  // ✅ NEW: Fetch Student Profile Info
  Future<void> fetchStudentInfo(String token) async {
    if (serverIp == null) {
      _error = "Server IP not configured";
      notifyListeners();
      return;
    }

    try {
      final url = Uri.parse("$serverIp/api/student/profile/");
      debugPrint("🌐 Fetching student profile from: $url");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Token $token",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint("📩 Profile Status Code: ${response.statusCode}");
      debugPrint("📩 Profile Response: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          _studentInfo = decoded['student'];
          debugPrint("✅ Student Info: $_studentInfo");
          debugPrint("📅 School Year: ${_studentInfo?['school_year']}");
          debugPrint("📚 Grade: ${_studentInfo?['grade_level']} - ${_studentInfo?['section']}");
        } else {
          _error = decoded['error'] ?? 'Failed to fetch profile';
        }
      } else {
        _error = "HTTP ${response.statusCode}";
      }
    } catch (e) {
      debugPrint("❌ Exception fetching student info: $e");
      _error = "Network error: $e";
    } finally {
      notifyListeners();
    }
  }

  // -----------------------------
  // Fetch Reports (with school year context)
  // -----------------------------
  Future<void> fetchReports(String token) async {
    if (serverIp == null) {
      _error = "Server IP not configured";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse("$serverIp/api/student/reports/");
      debugPrint("🌐 Fetching reports from: $url");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Token $token",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint("📩 Reports Status Code: ${response.statusCode}");
      debugPrint("📩 Reports Response: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          if (decoded['reports'] is List) {
            _reports = List<Map<String, dynamic>>.from(decoded['reports']);
            debugPrint("✅ Successfully loaded ${_reports.length} reports");
            
            // ✅ Filter reports by current school year (optional)
            if (_studentInfo != null && _studentInfo!['school_year'] != null) {
              final currentYear = _studentInfo!['school_year'];
              debugPrint("📅 Current school year: $currentYear");
            }
          } else {
            _reports = [];
            debugPrint("❌ Reports field is not a List: ${decoded['reports']}");
          }
        } else {
          _error = decoded['error'] ?? 'Failed to fetch reports';
          _reports = [];
        }
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          _error = errorBody['error'] ?? errorBody['detail'] ?? "HTTP ${response.statusCode}";
        } catch (_) {
          _error = "HTTP ${response.statusCode}: ${response.body}";
        }
        _reports = [];
      }
    } catch (e) {
      debugPrint("❌ Exception fetching reports: $e");
      _error = "Network error: $e";
      _reports = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // -----------------------------
  // Fetch Notifications
  // -----------------------------
  Future<void> fetchNotifications(String token) async {
    if (serverIp == null) {
      _error = "Server IP not configured";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse("$serverIp/api/student/notifications/");
      debugPrint("🌐 Fetching notifications from: $url");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Token $token",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint("📩 Notifications Status Code: ${response.statusCode}");
      debugPrint("📩 Notifications Response: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          if (decoded['notifications'] is List) {
            _notifications = List<Map<String, dynamic>>.from(decoded['notifications']);
            debugPrint("✅ Successfully loaded ${_notifications.length} notifications");
          } else {
            _notifications = [];
            debugPrint("❌ Notifications field is not a List: ${decoded['notifications']}");
          }
        } else {
          _error = decoded['error'] ?? 'Failed to fetch notifications';
          _notifications = [];
        }
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          _error = errorBody['error'] ?? errorBody['detail'] ?? "HTTP ${response.statusCode}";
        } catch (_) {
          _error = "HTTP ${response.statusCode}: ${response.body}";
        }
        _notifications = [];
      }
    } catch (e) {
      debugPrint("❌ Exception fetching notifications: $e");
      _error = "Network error: $e";
      _notifications = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // -----------------------------
  // Submit Report
  // -----------------------------
  Future<void> submitReport(Map<String, dynamic> reportData) async {
    if (serverIp == null || _token == null) {
      _error = "Server IP or token not configured";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = Uri.parse("$serverIp/api/student/reports/");
      debugPrint("🌐 Submitting report to: $url");
      debugPrint("📋 Report data: $reportData");

      final response = await http.post(
        url,
        headers: {
          "Authorization": "Token $_token",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(reportData),
      ).timeout(const Duration(seconds: 15));

      debugPrint("📩 Submit Report Status Code: ${response.statusCode}");
      debugPrint("📩 Submit Report Response: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          debugPrint("✅ Report submitted successfully");

          if (decoded.containsKey('report')) {
            _reports.insert(0, decoded['report']);
          }

          // Refresh reports
          try {
            await fetchReports(_token!);
          } catch (e) {
            debugPrint("⚠️ Warning: Could not refresh reports after submission: $e");
          }
        } else {
          _error = decoded['error'] ?? 'Failed to submit report';
          throw Exception(_error);
        }
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          _error = errorBody['error'] ?? errorBody['detail'] ?? "HTTP ${response.statusCode}";
        } catch (_) {
          _error = "HTTP ${response.statusCode}: ${response.body}";
        }
        throw Exception(_error);
      }
    } catch (e) {
      debugPrint("❌ Exception submitting report: $e");
      _error = "Network error: $e";
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // -----------------------------
  // Mark Notification as Read
  // -----------------------------
  Future<void> markNotificationAsRead(String token, int notificationId) async {
    if (serverIp == null) return;

    try {
      final url = Uri.parse("$serverIp/api/notifications/$notificationId/read/");

      final response = await http.post(
        url,
        headers: {
          "Authorization": "Token $token",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("❌ Error marking notification as read: $e");
    }
  }

  // -----------------------------
  // Fetch Violation Types
  // -----------------------------
  Future<void> fetchViolationTypes(String token) async {
    if (serverIp == null) return;

    _isLoadingViolationTypes = true;
    notifyListeners();

    try {
      final url = Uri.parse("$serverIp/api/reports/violation-types/");
      debugPrint("🌐 Fetching violation types from: $url");

      final response = await http.get(
        url,
        headers: {
          "Authorization": "Token $token",
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          _violationTypes = List<Map<String, dynamic>>.from(decoded);

          // Optionally append "Others"
          _violationTypes.add({
            'id': null,
            'name': 'Others',
          });

          debugPrint("✅ Loaded ${_violationTypes.length} violation types");
        } else {
          debugPrint("⚠️ Unexpected response format: $decoded");
          _violationTypes = [];
        }
      } else {
        debugPrint("❌ HTTP ${response.statusCode}: ${response.body}");
        _violationTypes = [];
      }
    } catch (e) {
      _violationTypes = [];
      debugPrint("❌ Exception fetching violation types: $e");
    } finally {
      _isLoadingViolationTypes = false;
      notifyListeners();
    }
  }

  // -----------------------------
  // Utilities
  // -----------------------------
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearData() {
    _reports = [];
    _notifications = [];
    _violationTypes = [];
    _studentInfo = null; // ✅ NEW
    _error = null;
    _isLoading = false;
    _isLoadingViolationTypes = false;
    notifyListeners();
  }
}
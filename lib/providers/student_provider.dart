import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';

// ✅ ADD: Exception class for system frozen
class SystemFrozenException implements Exception {
  final String message;
  final String? schoolYear;
  
  SystemFrozenException(this.message, {this.schoolYear});
  
  @override
  String toString() => message;
}

class StudentProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _violationTypes = [];
  Map<String, dynamic>? _studentInfo;
  bool _isLoading = false;
  bool _isLoadingViolationTypes = false;
  String? _error;
  String? _token;

  // ✅ ADD: System settings fields
  String? _systemSchoolYear;
  bool _isSystemActive = true;
  String? _systemMessage;

  // -----------------------------
  // Getters
  // -----------------------------
  List<Map<String, dynamic>> get reports => _reports;
  List<Map<String, dynamic>> get notifications => _notifications;
  List<Map<String, dynamic>> get violationTypes => _violationTypes;
  Map<String, dynamic>? get studentInfo => _studentInfo;
  bool get isLoading => _isLoading;
  bool get isLoadingReports => _isLoading;
  bool get isLoadingViolationTypesGetter => _isLoadingViolationTypes;
  String? get error => _error;
  String? get token => _token;
  
  // ✅ ADD: System settings getters
  String? get systemSchoolYear => _systemSchoolYear;
  bool get isSystemActive => _isSystemActive;
  String? get systemMessage => _systemMessage;
  
  // Get current school year from student info
  String get currentSchoolYear => _studentInfo?['school_year'] ?? _calculateCurrentSchoolYear();
  String get gradeLevel => _studentInfo?['grade_level'] ?? 'N/A';
  String get section => _studentInfo?['section'] ?? 'N/A';

  // Base URL helper
  String get _baseUrl {
  final serverIp = Env.serverIp; // ✅ Use Env class
  if (serverIp.isEmpty) {
    throw Exception('SERVER_IP not configured');
  }
  return serverIp.startsWith('http') ? serverIp : 'http://$serverIp';
}

  // -----------------------------
  // Set token
  // -----------------------------
  void setToken(String token) {
    _token = token;
    notifyListeners();
  }

  // Calculate current school year based on date
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

  // ✅ ADD: Helper method to make authenticated requests with system check
  Future<http.Response> _makeAuthenticatedRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (_token == null) {
      throw Exception('No authentication token available');
    }

    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = {
      'Authorization': 'Token $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    http.Response response;
    
    try {
      switch (method.toUpperCase()) {
        case 'POST':
          response = await http.post(
            uri, 
            headers: headers, 
            body: body != null ? jsonEncode(body) : null,
          ).timeout(const Duration(seconds: 15));
          break;
        case 'PUT':
          response = await http.put(
            uri, 
            headers: headers, 
            body: body != null ? jsonEncode(body) : null,
          ).timeout(const Duration(seconds: 15));
          break;
        case 'PATCH':
          response = await http.patch(
            uri, 
            headers: headers, 
            body: body != null ? jsonEncode(body) : null,
          ).timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers)
            .timeout(const Duration(seconds: 10));
          break;
        default:
          response = await http.get(uri, headers: headers)
            .timeout(const Duration(seconds: 10));
      }
      
      // ✅ Check if system is frozen
      if (response.statusCode == 503) {
        final data = jsonDecode(response.body);
        if (data['error'] == 'system_frozen') {
          _systemMessage = data['message'];
          _isSystemActive = false;
          notifyListeners();
          
          throw SystemFrozenException(
            data['message'] ?? 'System is currently frozen',
            schoolYear: data['current_school_year'],
          );
        }
      }
      
      return response;
      
    } catch (e) {
      if (e is SystemFrozenException) {
        rethrow;
      }
      debugPrint('❌ Request error: $e');
      rethrow;
    }
  }

  // ✅ ADD: Fetch system settings
  Future<void> fetchSystemSettings() async {
    try {
      debugPrint('🔍 Fetching system settings...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/system/settings/'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          _systemSchoolYear = data['settings']['current_school_year'];
          _isSystemActive = data['settings']['is_system_active'] ?? true;
          _systemMessage = data['settings']['system_message'];
          
          debugPrint('✅ System settings loaded:');
          debugPrint('   Current S.Y.: $_systemSchoolYear');
          debugPrint('   System Active: $_isSystemActive');
          
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching system settings: $e');
    }
  }

  // ✅ ADD: Initialize provider with system check
  Future<void> initializeProvider() async {
    try {
      debugPrint('🚀 Initializing StudentProvider...');
      
      // Load token
      await _loadToken();
      
      if (_token == null) {
        debugPrint('⚠️ No token found, skipping data fetch');
        return;
      }
      
      // ✅ FIRST: Fetch system settings to check if system is active
      await fetchSystemSettings();
      
      // ✅ If system is frozen, stop here
      if (!_isSystemActive) {
        debugPrint('🔒 System is frozen. User will see frozen dialog.');
        return;
      }
      
      // THEN: Fetch all other data
      await Future.wait([
        fetchStudentInfo(_token!),
        fetchReports(_token!),
        fetchNotifications(_token!),
        fetchViolationTypes(_token!),
      ]);
      
      debugPrint('✅ StudentProvider initialized successfully');
      
    } on SystemFrozenException catch (e) {
      debugPrint('🔒 System frozen: ${e.message}');
      // Don't throw - just leave system in frozen state
      return;
    } catch (e) {
      debugPrint('❌ Error initializing provider: $e');
    }
  }

  // ✅ ADD: Load token from SharedPreferences
  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      if (_token != null) {
        debugPrint('✅ Token loaded from storage');
      }
    } catch (e) {
      debugPrint('❌ Error loading token: $e');
    }
  }

  // ✅ ADD: Logout method
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      
      clearData();
      
      debugPrint('✅ User logged out successfully');
    } catch (e) {
      debugPrint('❌ Error during logout: $e');
    }
  }

  // -----------------------------
  // Fetch Student Profile Info
  // -----------------------------
  Future<void> fetchStudentInfo(String token) async {
    // ✅ FIXED: Use _baseUrl getter instead of serverIp
    try {
      final response = await _makeAuthenticatedRequest('/api/student/profile/');

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
    } on SystemFrozenException {
      rethrow;
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
    // ✅ FIXED: Use _baseUrl getter instead of serverIp
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _makeAuthenticatedRequest('/api/student/reports/');

      debugPrint("📩 Reports Status Code: ${response.statusCode}");
      debugPrint("📩 Reports Response: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          if (decoded['reports'] is List) {
            _reports = List<Map<String, dynamic>>.from(decoded['reports']);
            debugPrint("✅ Successfully loaded ${_reports.length} reports");
            
            // Filter reports by current school year (optional)
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
    } on SystemFrozenException {
      rethrow;
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
    // ✅ FIXED: Use _baseUrl getter instead of serverIp
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _makeAuthenticatedRequest('/api/student/notifications/');

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
    } on SystemFrozenException {
      rethrow;
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
    // ✅ FIXED: Use _baseUrl getter and _token instead of checking serverIp
    if (_token == null) {
      _error = "Authentication token not available";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _makeAuthenticatedRequest(
        '/api/student/reports/',
        method: 'POST',
        body: reportData,
      );

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
    } on SystemFrozenException {
      rethrow;
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
    try {
      final response = await _makeAuthenticatedRequest(
        '/api/notifications/$notificationId/read/',
        method: 'POST',
      );

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
    _isLoadingViolationTypes = true;
    notifyListeners();

    try {
      // ✅ FIX: Use the correct API endpoint
      final response = await _makeAuthenticatedRequest('/api/violation-types/');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // The backend may return {'violation_types': [...]}
        if (decoded is Map<String, dynamic> && decoded['violation_types'] is List) {
          _violationTypes = List<Map<String, dynamic>>.from(decoded['violation_types']);
        } else if (decoded is List) {
          _violationTypes = List<Map<String, dynamic>>.from(decoded);
        } else {
          debugPrint("⚠️ Unexpected response format: $decoded");
          _violationTypes = [];
        }

        // Optionally append "Others"
        _violationTypes.add({
          'id': null,
          'name': 'Others',
        });

        debugPrint("✅ Loaded ${_violationTypes.length} violation types");
      } else {
        debugPrint("❌ HTTP ${response.statusCode}: ${response.body}");
        _violationTypes = [];
      }
    } on SystemFrozenException {
      rethrow;
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
    _studentInfo = null;
    _error = null;
    _isLoading = false;
    _isLoadingViolationTypes = false;
    _token = null;
    // ✅ Reset system settings
    _systemSchoolYear = null;
    _isSystemActive = true;
    _systemMessage = null;
    notifyListeners();
  }
}
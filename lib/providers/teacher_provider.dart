import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/env.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ ADD: Exception class for system frozen
class SystemFrozenException implements Exception {
  final String message;
  final String? schoolYear;
  
  SystemFrozenException(this.message, {this.schoolYear});
  
  @override
  String toString() => message;
}

class TeacherProvider with ChangeNotifier {
  String? _token;
  bool _isLoading = false;
  String? _error;
  
  // ✅ ADD: System settings fields
  String? _systemSchoolYear;
  bool _isSystemActive = true;
  String? _systemMessage;
  
  String _selectedSchoolYear = '';
  List<String> _availableSchoolYears = [];

  String get selectedSchoolYear => _selectedSchoolYear;
  List<String> get availableSchoolYears => _availableSchoolYears;

  // Data
  Map<String, dynamic>? _teacherProfile;
  List<Map<String, dynamic>> _advisingStudents = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _violationTypes = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get teacherProfile => _teacherProfile;
  List<Map<String, dynamic>> get advisingStudents => _advisingStudents;
  List<Map<String, dynamic>> get students => _students;
  List<Map<String, dynamic>> get reports => _reports;
  List<Map<String, dynamic>> get notifications => _notifications;
  List<Map<String, dynamic>> get violationTypes => _violationTypes;

  // ✅ ADD: System settings getters
  String? get systemSchoolYear => _systemSchoolYear;
  bool get isSystemActive => _isSystemActive;
  String? get systemMessage => _systemMessage;

  // Base URL helper
  String get _baseUrl {
  final serverIp = Env.serverIp; // ✅ Use Env class
  if (serverIp.isEmpty) {
    throw Exception('SERVER_IP not configured');
  }
  return serverIp.startsWith('http') ? serverIp : 'http://$serverIp';
}

  // Set token
  void setToken(String token) {
    _token = token;
    notifyListeners();
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void setSelectedSchoolYear(String schoolYear) {
  _selectedSchoolYear = schoolYear;
  debugPrint('📅 Selected school year changed to: $schoolYear');
  notifyListeners();
  fetchAdvisingStudents(schoolYear: schoolYear);
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
      debugPrint('🚀 Initializing TeacherProvider...');
      
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
        fetchProfile(),
        fetchAdvisingStudents(),
        fetchReports(),
        fetchNotifications(),
        fetchViolationTypes(),
      ]);
      
      debugPrint('✅ TeacherProvider initialized successfully');
      
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

  // ✅ UPDATE: Fetch teacher profile with system check
  Future<void> fetchProfile() async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final response = await _makeAuthenticatedRequest('/api/teacher/profile/');

      debugPrint('🔍 Profile response: ${response.statusCode}');
      debugPrint('🔍 Profile body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _teacherProfile = Map<String, dynamic>.from(data['profile'] ?? {});
          
          final fullName = _teacherProfile?['full_name'] ?? 
                          '${_teacherProfile?['first_name'] ?? ''} ${_teacherProfile?['last_name'] ?? ''}'.trim();
          
          debugPrint('✅ Teacher profile loaded: $fullName');
          debugPrint('✅ Profile data: $_teacherProfile');
        } else {
          _setError(data['error'] ?? 'Failed to load profile');
        }
      } else {
        _setError('Failed to load profile: ${response.statusCode}');
      }
    } on SystemFrozenException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Profile fetch error: $e');
      _setError('Network error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Helper method to get full name
  String getFullName() {
    if (_teacherProfile == null) return 'Teacher';
    
    final fullName = _teacherProfile!['full_name']?.toString();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }
    
    final firstName = _teacherProfile!['first_name']?.toString() ?? '';
    final lastName = _teacherProfile!['last_name']?.toString() ?? '';
    final combined = '$firstName $lastName'.trim();
    
    if (combined.isEmpty) {
      return _teacherProfile!['username']?.toString() ?? 'Teacher';
    }
    
    return combined;
  }

  // ✅ UPDATE: Fetch advising students with system check
  Future<void> fetchAdvisingStudents({String? schoolYear}) async {
  if (_token == null) {
    _setError('Authentication token not found');
    return;
  }

  _setLoading(true);
  _setError(null);

  try {
    String endpoint = '/api/teacher/advising-students/';
    // Remove schoolYear param unless your backend supports it

    final response = await _makeAuthenticatedRequest(endpoint);

    debugPrint('🔍 Advising students response: ${response.statusCode}');
    debugPrint('🔍 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _advisingStudents = List<Map<String, dynamic>>.from(data['students'] ?? []);
        debugPrint('✅ Advising students loaded: ${_advisingStudents.length} students');
      } else {
        _setError(data['error'] ?? 'Failed to load advising students');
      }
    } else {
      _setError('Failed to load advising students: ${response.statusCode}');
    }
  } on SystemFrozenException {
    rethrow;
  } catch (e) {
    debugPrint('❌ Advising students fetch error: $e');
    _setError('Network error: $e');
  } finally {
    _setLoading(false);
  }
}

  Future<void> fetchAvailableSchoolYears() async {
  try {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/system/school-years/'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['school_years'] is List) {
        _availableSchoolYears = List<String>.from(data['school_years']);
        // Default to latest school year if not set
        if (_selectedSchoolYear.isEmpty && _availableSchoolYears.isNotEmpty) {
          _selectedSchoolYear = _availableSchoolYears.last;
        }
        notifyListeners();
      }
    }
  } catch (e) {
    debugPrint('❌ Error fetching school years: $e');
  }
}

  // ✅ UPDATE: Update student information with system check
  Future<bool> updateStudentInfo({
    required int studentId,
    required String gradeLevel,
    required String section,
    String? strand,
  }) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return false;
    }

    try {
      final updateData = {
        'updates': [
          {
            'student_id': studentId,
            'grade_level': gradeLevel,
            'section': section,
            if (strand != null && strand.isNotEmpty) 'strand': strand,
          }
        ]
      };

      debugPrint('🔄 Updating student info: $updateData');

      final response = await _makeAuthenticatedRequest(
        '/api/teacher/advisory-section/',
        method: 'POST',
        body: updateData,
      );

      debugPrint('📡 Update response: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Student info updated: ${data['updated_count']} student(s)');
          
          // Update local student data
          final index = _advisingStudents.indexWhere((s) => s['id'] == studentId);
          if (index != -1) {
            _advisingStudents[index]['grade_level'] = gradeLevel;
            _advisingStudents[index]['section'] = section;
            if (strand != null) {
              _advisingStudents[index]['strand'] = strand;
            }
            notifyListeners();
          }
          
          return true;
        } else {
          _setError(data['error'] ?? 'Failed to update student info');
          return false;
        }
      } else {
        _setError('Failed to update student info: ${response.statusCode}');
        return false;
      }
    } on SystemFrozenException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Update student info error: $e');
      _setError('Network error: $e');
      return false;
    }
  }

  // ✅ UPDATE: Batch update multiple students with system check
  Future<bool> batchUpdateStudents(List<Map<String, dynamic>> updates) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return false;
    }

    try {
      final updateData = {'updates': updates};

      debugPrint('🔄 Batch updating ${updates.length} students');

      final response = await _makeAuthenticatedRequest(
        '/api/teacher/advisory-section/',
        method: 'POST',
        body: updateData,
      );

      debugPrint('📡 Batch update response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Batch update completed: ${data['updated_count']} student(s)');
          
          // Refresh students list
          await fetchAdvisingStudents();
          
          return true;
        } else {
          _setError(data['error'] ?? 'Failed to batch update students');
          return false;
        }
      } else {
        _setError('Failed to batch update students: ${response.statusCode}');
        return false;
      }
    } on SystemFrozenException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Batch update error: $e');
      _setError('Network error: $e');
      return false;
    }
  }

  // ✅ UPDATE: Fetch student violation history with system check
  Future<Map<String, dynamic>?> fetchStudentViolationHistory(int studentId) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return null;
    }

    try {
      debugPrint('🔄 Fetching violation history for student $studentId');

      final response = await _makeAuthenticatedRequest(
        '/api/students/$studentId/violation-history/',
      );

      debugPrint('📡 Violation history response: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Violation history loaded: ${data['total_violations_all_time']} total violations');
          return Map<String, dynamic>.from(data);
        } else {
          _setError(data['error'] ?? 'Failed to load violation history');
          return null;
        }
      } else {
        _setError('Failed to load violation history: ${response.statusCode}');
        return null;
      }
    } on SystemFrozenException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Violation history fetch error: $e');
      _setError('Network error: $e');
      return null;
    }
  }

  // ✅ UPDATE: Fetch all students with system check
  Future<void> fetchStudents() async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    try {
      final response = await _makeAuthenticatedRequest('/api/students-list/');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _students = List<Map<String, dynamic>>.from(data['students'] ?? []);
          debugPrint('✅ All students loaded: ${_students.length} students');
        } else {
          _setError(data['error'] ?? 'Failed to load students');
        }
      } else {
        _setError('Failed to load students: ${response.statusCode}');
      }
    } on SystemFrozenException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Students fetch error: $e');
      _setError('Network error: $e');
    }
    notifyListeners();
  }

  // ✅ UPDATE: Fetch teacher reports with system check
  Future<void> fetchReports() async {
  if (_token == null) {
    _setError('Authentication token not found');
    return;
  }

  try {
    final response = await _makeAuthenticatedRequest('/api/teacher/reports/');

    debugPrint('📋 Reports response status: ${response.statusCode}');
    debugPrint('📋 Reports response body: ${response.body}'); // ✅ Add this line

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _reports = List<Map<String, dynamic>>.from(data['reports'] ?? []);
        
        // ✅ Debug each report to see what fields are available
        for (int i = 0; i < _reports.length; i++) {
          debugPrint('📋 Report $i fields: ${_reports[i].keys.toList()}');
          debugPrint('📋 Report $i description: "${_reports[i]['description']}"');
          debugPrint('📋 Report $i content: "${_reports[i]['content']}"');
        }
        
        debugPrint('✅ Reports loaded: ${_reports.length} reports');
      } else {
        _setError(data['error'] ?? 'Failed to load reports');
      }
    } else {
      _setError('Failed to load reports: ${response.statusCode}');
    }
  } on SystemFrozenException {
    rethrow;
  } catch (e) {
    debugPrint('❌ Reports fetch error: $e');
    _setError('Network error: $e');
  }
  notifyListeners();
}

  // ✅ UPDATE: Fetch notifications with system check
  Future<void> fetchNotifications() async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    try {
      final response = await _makeAuthenticatedRequest('/api/teacher/notifications/');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _notifications = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
          debugPrint('✅ Notifications loaded: ${_notifications.length} notifications');
        } else {
          _setError(data['error'] ?? 'Failed to load notifications');
        }
      } else {
        _setError('Failed to load notifications: ${response.statusCode}');
      }
    } on SystemFrozenException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Notifications fetch error: $e');
      _setError('Network error: $e');
    }
    notifyListeners();
  }

  // ✅ UPDATE: Fetch violation types with system check
  Future<void> fetchViolationTypes() async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    try {
      final response = await _makeAuthenticatedRequest('/api/violation-types/');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _violationTypes = List<Map<String, dynamic>>.from(data['violation_types'] ?? []);
          debugPrint('✅ Violation types loaded: ${_violationTypes.length} types');
        } else {
          _setError(data['error'] ?? 'Failed to load violation types');
        }
      } else {
        _setError('Failed to load violation types: ${response.statusCode}');
      }
    } on SystemFrozenException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Violation types fetch error: $e');
      _setError('Network error: $e');
    }
    notifyListeners();
  }

  // ✅ UPDATE: Submit student report with system check
  Future<bool> submitStudentReport(Map<String, dynamic> reportData) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return false;
    }

    try {
      debugPrint('🔄 Submitting teacher report');
      debugPrint('🔄 Report data: $reportData');
      
      final response = await _makeAuthenticatedRequest(
        '/api/teacher/reports/',
        method: 'POST',
        body: reportData,
      );

      debugPrint('📡 Submit report response: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true || response.statusCode == 201) {
          debugPrint('✅ Teacher report submitted successfully');
          await fetchReports();
          return true;
        } else {
          _setError(data['error'] ?? 'Failed to submit report');
          return false;
        }
      } else {
        try {
          final errorData = jsonDecode(response.body);
          _setError(errorData['error'] ?? 'Failed to submit report: ${response.statusCode}');
        } catch (e) {
          _setError('Failed to submit report: ${response.statusCode}');
        }
        return false;
      }
    } on SystemFrozenException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Submit report error: $e');
      _setError('Network error: $e');
      return false;
    }
  }

  // ✅ UPDATE: Mark notification as read with system check
  Future<void> markNotificationAsRead(int notificationId) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    try {
      final response = await _makeAuthenticatedRequest(
        '/api/notifications/mark-read/$notificationId/',
        method: 'PUT',
      );

      debugPrint('🔍 Mark notification read response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          for (int i = 0; i < _notifications.length; i++) {
            if (_notifications[i]['id'] == notificationId) {
              _notifications[i]['is_read'] = true;
              break;
            }
          }
          debugPrint('✅ Notification marked as read');
          notifyListeners();
        } else {
          _setError(data['error'] ?? 'Failed to mark notification as read');
        }
      } else {
        _setError('Failed to mark notification as read: ${response.statusCode}');
      }
    } on SystemFrozenException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Mark notification read error: $e');
      _setError('Network error: $e');
    }
  }

  // Get advising class info
  String getAdvisingInfo() {
    if (_teacherProfile == null) return '';
    
    final section = _teacherProfile!['advising_section']?.toString() ?? '';
    final grade = _teacherProfile!['advising_grade']?.toString() ?? '';
    final strand = _teacherProfile!['advising_strand']?.toString() ?? '';
    
    if (section.isEmpty) return '';
    
    String info = 'Section $section';
    
    if (grade.isNotEmpty) {
      if (['11', '12'].contains(grade) && strand.isNotEmpty) {
        info = 'Grade $grade $strand - Section $section';
      } else {
        info = 'Grade $grade - Section $section';
      }
    }
    
    return info;
  }

  // Clear all data (for logout)
  void clearData() {
    _token = null;
    _teacherProfile = null;
    _advisingStudents.clear();
    _students.clear();
    _reports.clear();
    _notifications.clear();
    _violationTypes.clear();
    _isLoading = false;
    _error = null;
    // ✅ Reset system settings
    _systemSchoolYear = null;
    _isSystemActive = true;
    _systemMessage = null;
    notifyListeners();
  }
}
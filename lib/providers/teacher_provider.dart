// providers/teacher_provider.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TeacherProvider with ChangeNotifier {
  String? _token;
  bool _isLoading = false;
  String? _error;
  
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

  // Base URL helper
  String get _baseUrl {
    final serverIp = dotenv.env['SERVER_IP'] ?? '';
    if (serverIp.isEmpty) {
      throw Exception('SERVER_IP not configured in .env file');
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

  // Fetch teacher profile
  Future<void> fetchProfile() async {
  if (_token == null) {
    _setError('Authentication token not found');
    return;
  }

  _setLoading(true);
  _setError(null);

  try {
    final url = Uri.parse('$_baseUrl/api/teacher/profile/');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
    );

    debugPrint('🔍 Profile response: ${response.statusCode}');
    debugPrint('🔍 Profile body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // ✅ Use 'profile' key instead of 'teacher'
        _teacherProfile = Map<String, dynamic>.from(data['profile'] ?? {});
        
        // ✅ Log the full name
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
  } catch (e) {
    debugPrint('❌ Profile fetch error: $e');
    _setError('Network error: $e');
  } finally {
    _setLoading(false);
  }
}

// ✅ Add helper method to get full name
String getFullName() {
  if (_teacherProfile == null) return 'Teacher';
  
  // Try full_name field first
  final fullName = _teacherProfile!['full_name']?.toString();
  if (fullName != null && fullName.isNotEmpty) {
    return fullName;
  }
  
  // Fallback to first + last name
  final firstName = _teacherProfile!['first_name']?.toString() ?? '';
  final lastName = _teacherProfile!['last_name']?.toString() ?? '';
  final combined = '$firstName $lastName'.trim();
  
  // If still empty, use username
  if (combined.isEmpty) {
    return _teacherProfile!['username']?.toString() ?? 'Teacher';
  }
  
  return combined;
}

  // Fetch advising students
  Future<void> fetchAdvisingStudents() async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final url = Uri.parse('$_baseUrl/api/teacher/advising-students/');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );

      debugPrint('🔍 Advising students response: ${response.statusCode}');

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
    } catch (e) {
      debugPrint('❌ Advising students fetch error: $e');
      _setError('Network error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Fetch all students (for reporting)
  Future<void> fetchStudents() async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/students-list/');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );

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
    } catch (e) {
      debugPrint('❌ Students fetch error: $e');
      _setError('Network error: $e');
    }
    notifyListeners();
  }

  // Fetch teacher reports
  Future<void> fetchReports() async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/teacher/reports/');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _reports = List<Map<String, dynamic>>.from(data['reports'] ?? []);
          debugPrint('✅ Reports loaded: ${_reports.length} reports');
        } else {
          _setError(data['error'] ?? 'Failed to load reports');
        }
      } else {
        _setError('Failed to load reports: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Reports fetch error: $e');
      _setError('Network error: $e');
    }
    notifyListeners();
  }

  // Fetch notifications
  Future<void> fetchNotifications() async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/teacher/notifications/');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );

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
    } catch (e) {
      debugPrint('❌ Notifications fetch error: $e');
      _setError('Network error: $e');
    }
    notifyListeners();
  }

  // Fetch violation types
  Future<void> fetchViolationTypes() async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/violation-types/');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );

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
    } catch (e) {
      debugPrint('❌ Violation types fetch error: $e');
      _setError('Network error: $e');
    }
    notifyListeners();
  }

  // Submit student report
  Future<bool> submitStudentReport(Map<String, dynamic> reportData) async {
  if (_token == null) {
    _setError('Authentication token not found');
    return false;
  }

  try {
    // Use the correct endpoint that exists in your Django urls
    final url = Uri.parse('$_baseUrl/api/teacher/reports/');
    
    debugPrint('🔄 Submitting teacher report to: $url');
    debugPrint('🔄 Report data: $reportData');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
      body: jsonEncode(reportData),
    );

    debugPrint('📡 Submit report response: ${response.statusCode}');
    debugPrint('📡 Response body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data['success'] == true || response.statusCode == 201) {
        debugPrint('✅ Teacher report submitted successfully');
        // Refresh reports after successful submission
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
  } catch (e) {
    debugPrint('❌ Submit report error: $e');
    _setError('Network error: $e');
    return false;
  }
}

  // Mark notification as read
  Future<void> markNotificationAsRead(int notificationId) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/notifications/mark-read/$notificationId/');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );

      debugPrint('🔍 Mark notification read response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Update local notification state
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
    
    // Build display based on available info
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
    notifyListeners();
  }
}

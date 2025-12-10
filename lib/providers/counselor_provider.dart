import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import '../config/env.dart';

class SystemFrozenException implements Exception {
  final String message;
  final String? schoolYear;
  
  SystemFrozenException(this.message, {this.schoolYear});
  
  @override
  String toString() => message;
}

class CounselorProvider with ChangeNotifier {
  String? _token;
  bool _isLoading = false;
  bool _isLoadingStudentsList = false;
  bool _isLoadingStudentViolations = false;
  bool _isLoadingCounselorStudentReports = false;
  String? _error;

  int? lastCreatedReportId;
  
  String? _systemSchoolYear;
  bool _isSystemActive = true;
  String? _systemMessage;

  // Data
  Map<String, dynamic>? _counselorProfile;
  List<Map<String, dynamic>> _studentReports = [];
  List<Map<String, dynamic>> _teacherReports = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _counselorStudentReports = [];
  List<Map<String, dynamic>> _studentsList = [];
  List<Map<String, dynamic>> _studentViolations = [];
  List<Map<String, dynamic>> _violationTypes = [];
  List<Map<String, dynamic>> _counselingSessions = [];
  bool _isLoadingCounselingSessions = false;

  // Caching
  DateTime? _lastFetchTime;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingStudentsList => _isLoadingStudentsList;
  bool get isLoadingStudentViolations => _isLoadingStudentViolations;
  bool get isLoadingCounselorStudentReports => _isLoadingCounselorStudentReports;
  String? get error => _error;
  String? get token => _token;
  Map<String, dynamic>? get counselorProfile => _counselorProfile;
  List<Map<String, dynamic>> get studentReports => _studentReports;
  List<Map<String, dynamic>> get teacherReports => _teacherReports;
  List<Map<String, dynamic>> get notifications => _notifications;
  List<Map<String, dynamic>> get counselorStudentReports => _counselorStudentReports;
  List<Map<String, dynamic>> get studentsList => _studentsList;
  List<Map<String, dynamic>> get studentViolations => _studentViolations;
  List<Map<String, dynamic>> get violationTypes => _violationTypes;
  List<Map<String, dynamic>> get counselingSessions => _counselingSessions;
  bool get isLoadingCounselingSessions => _isLoadingCounselingSessions;

  String? get systemSchoolYear => _systemSchoolYear;
  bool get isSystemActive => _isSystemActive;
  String? get systemMessage => _systemMessage;

  // School year filtering
  String _selectedSchoolYear = 'current';
  List<String> _availableSchoolYears = [];
  
  String get selectedSchoolYear => _selectedSchoolYear;
  List<String> get availableSchoolYears => _availableSchoolYears;

  // ✅ HTTP Client for proper connection management
  final http.Client _client = http.Client();

  // Base URL helper
  String get _baseUrl {
  final serverIp = Env.serverIp; // ✅ Use Env class
  if (serverIp.isEmpty) {
    throw Exception('SERVER_IP not configured');
  }
  return serverIp.startsWith('http') ? serverIp : 'http://$serverIp';
}

  // ✅ Headers helper
  Map<String, String> get _headers => {
    'Authorization': 'Token $_token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

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

  // ✅ Authenticated request helper
  Future<http.Response> _makeAuthenticatedRequest(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (_token == null) {
      throw Exception('No authentication token available');
    }

    final uri = Uri.parse('$_baseUrl$endpoint');

    http.Response response;
    
    try {
      switch (method.toUpperCase()) {
        case 'POST':
          response = await _client.post(uri, headers: _headers, body: jsonEncode(body));
          break;
        case 'PUT':
          response = await _client.put(uri, headers: _headers, body: jsonEncode(body));
          break;
        case 'PATCH':
          response = await _client.patch(uri, headers: _headers, body: jsonEncode(body));
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: _headers);
          break;
        default:
          response = await _client.get(uri, headers: _headers);
      }
      
      // Check if system is frozen
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

  // Fetch system settings
  Future<void> fetchSystemSettings() async {
    try {
      debugPrint('🔍 Fetching system settings...');
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/system/settings/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          _systemSchoolYear = data['settings']['current_school_year'];
          _isSystemActive = data['settings']['is_system_active'] ?? true;
          _systemMessage = data['settings']['system_message'];
          
          debugPrint('✅ System settings loaded:');
          debugPrint('   Current S.Y.: $_systemSchoolYear');
          debugPrint('   System Active: $_isSystemActive');
          
          if (_systemSchoolYear != null) {
            _selectedSchoolYear = _systemSchoolYear!;
            
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('selected_school_year', _systemSchoolYear!);
            
            debugPrint('✅ Auto-set selected school year to: $_systemSchoolYear');
          }
          
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching system settings: $e');
    }
  }

  // Logout method
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('selected_school_year');
      
      clearData();
      
      debugPrint('✅ User logged out successfully');
    } catch (e) {
      debugPrint('❌ Error during logout: $e');
    }
  }

  // Initialize with saved school year
  Future<void> initializeSchoolYear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedYear = prefs.getString('selected_school_year');
      
      if (savedYear != null) {
        _selectedSchoolYear = savedYear;
      } else {
        _selectedSchoolYear = _getCurrentSchoolYear();
      }
      
      debugPrint('📅 Initialized school year: $_selectedSchoolYear');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing school year: $e');
      _selectedSchoolYear = _getCurrentSchoolYear();
    }
  }

  // Fetch available school years
  Future<void> fetchAvailableSchoolYears() async {
    if (_token == null) return;

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/counselor/available-school-years/'),
        headers: _headers,
      );

      debugPrint('📅 Available school years response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _availableSchoolYears = List<String>.from(data['school_years'] ?? []);
          debugPrint('✅ Available school years: $_availableSchoolYears');
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching school years: $e');
    }
  }

  // Set selected school year
  void setSelectedSchoolYear(String schoolYear) {
    _selectedSchoolYear = schoolYear;
    debugPrint('📅 Selected school year filter changed to: $schoolYear');
    notifyListeners();
  }

  // Set school year and refresh data
  Future<bool> setSchoolYear(String schoolYear) async {
    try {
      _selectedSchoolYear = schoolYear;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_school_year', schoolYear);
      
      debugPrint('📅 School year changed to: $schoolYear');
      notifyListeners();
      
      await Future.wait([
        fetchCounselorStudentReports(forceRefresh: true),
        fetchStudentViolations(forceRefresh: true),
        fetchProfile(),
        fetchStudentsList(schoolYear: schoolYear),
      ]);
      
      debugPrint('✅ All data refreshed for school year: $schoolYear');
      return true;
    } catch (e) {
      debugPrint('❌ Error setting school year: $e');
      return false;
    }
  }

  // Get current school year helper
  String _getCurrentSchoolYear() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    return month >= 6 ? '$year-${year + 1}' : '${year - 1}-$year';
  }

  // Get current school year public
  String getCurrentSchoolYear() {
    return _getCurrentSchoolYear();
  }

  // ✅ FIXED: Fetch counselor student reports
  Future<void> fetchCounselorStudentReports({bool forceRefresh = false}) async {
    if (!forceRefresh && 
        _lastFetchTime != null && 
        DateTime.now().difference(_lastFetchTime!) < _cacheTimeout &&
        _counselorStudentReports.isNotEmpty) {
      debugPrint("📋 Using cached student reports data");
      return;
    }

    if (_token == null) {
      debugPrint("❌ No token available");
      return;
    }

    if (_isLoadingCounselorStudentReports) {
      debugPrint("⏳ Already loading, skipping duplicate call");
      return;
    }

    _isLoadingCounselorStudentReports = true;
    _error = null;
    notifyListeners();

    try {
      final url = _selectedSchoolYear == 'all'
          ? Uri.parse('$_baseUrl/api/counselor/student-reports/')
          : Uri.parse('$_baseUrl/api/counselor/student-reports/?school_year=$_selectedSchoolYear');
      
      debugPrint("📡 Fetching from: $url");
      
      final response = await _client
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 30));

      debugPrint("📊 Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data is Map && data.containsKey('success') && data['success'] == true) {
          _counselorStudentReports = List<Map<String, dynamic>>.from(data['reports'] ?? []);
          _studentReports = List<Map<String, dynamic>>.from(data['reports'] ?? []);
          
          _lastFetchTime = DateTime.now();
          debugPrint("✅ Successfully loaded ${_counselorStudentReports.length} reports");
        } else {
          throw Exception('API returned success=false: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
      
    } on TimeoutException {
      _error = 'Request timed out. Server might be cold starting.';
      debugPrint("❌ Timeout: $_error");
      _counselorStudentReports = [];
    } on SocketException {
      _error = 'No internet connection';
      debugPrint("❌ Network error: $_error");
      _counselorStudentReports = [];
    } catch (e) {
      _error = 'Error loading reports: $e';
      debugPrint("❌ Error: $_error");
      _counselorStudentReports = [];
    } finally {
      _isLoadingCounselorStudentReports = false;
      notifyListeners();
    }
  }
  
  // ✅ FIXED: Send guidance notice with named parameters
  Future<bool> sendGuidanceNotice({
    required int reportId,
    String? reportType,
    String? message,
    DateTime? scheduledDate,
  }) async {
    if (_token == null) {
      debugPrint('❌ No token available');
      return false;
    }

    try {
      debugPrint('📢 Sending guidance notice for report #$reportId');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/counselor/send-guidance-notice/$reportId/'),
        headers: _headers,
        body: jsonEncode({
          'report_type': reportType ?? 'student_report',
          'message': message ?? 'You have been summoned for counseling.',
          'scheduled_date': (scheduledDate ?? DateTime.now()).toIso8601String(),
        }),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          debugPrint('✅ Guidance notice sent successfully');
          
          // Update local report status
          final index = _counselorStudentReports.indexWhere((r) => r['id'] == reportId);
          if (index != -1) {
            _counselorStudentReports[index]['status'] = 'summoned';
          }
          
          final studentReportIndex = _studentReports.indexWhere((r) => r['id'] == reportId);
          if (studentReportIndex != -1) {
            _studentReports[studentReportIndex]['status'] = 'summoned';
          }
          
          notifyListeners();
          return true;
        }
      }
      
      debugPrint('❌ Failed to send guidance notice: ${response.statusCode}');
      _error = 'Failed to send guidance notice';
      notifyListeners();
      return false;
      
    } catch (e) {
      debugPrint('❌ Error sending guidance notice: $e');
      _error = 'Error: $e';
      notifyListeners();
      return false;
    }
  }

  // Fetch student reports
  Future<void> fetchStudentReports() async {
    if (_token == null) return;

    try {
      debugPrint('📡 Fetching student reports...');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final url = _selectedSchoolYear == 'all'
          ? Uri.parse('$_baseUrl/api/counselor/student-reports/?_t=$timestamp')
          : Uri.parse('$_baseUrl/api/counselor/student-reports/?school_year=$_selectedSchoolYear&_t=$timestamp');

      final response = await _client
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 10));

      debugPrint('📡 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('success') && data['success'] == true) {
          _studentReports = List<Map<String, dynamic>>.from(data['reports'] ?? []);

          final summonedCount = _studentReports.where((r) => r['status'] == 'summoned').length;
          debugPrint('✅ Fetched ${_studentReports.length} reports ($summonedCount summoned)');

          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching student reports: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Fetch counselor profile
  Future<void> fetchProfile() async {
    if (_token == null) return;
    
    _setLoading(true);
    _setError(null);

    try {
      final url = Uri.parse('$_baseUrl/api/counselor/profile/');
      final response = await _client.get(url, headers: _headers);

      debugPrint('🔍 Counselor profile response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _counselorProfile = Map<String, dynamic>.from(data);
        
        debugPrint('✅ Counselor profile loaded');
        notifyListeners();
      } else {
        _setError('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Counselor profile fetch error: $e');
      _setError('Network error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Fetch students list
  Future<void> fetchStudentsList({String? schoolYear}) async {
    if (_token == null) return;

    _isLoadingStudentsList = true;
    notifyListeners();

    try {
      final year = schoolYear ?? _selectedSchoolYear;
      
      final url = year == 'all'
          ? Uri.parse('$_baseUrl/api/counselor/students-list/')
          : Uri.parse('$_baseUrl/api/counselor/students-list/?school_year=$year');
      
      debugPrint('📊 Fetching students for school year: $year');

      final response = await _client.get(url, headers: _headers);

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _studentsList = List<Map<String, dynamic>>.from(data['students'] ?? []);
          debugPrint('✅ Fetched ${_studentsList.length} students for S.Y. $year');
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching students: $e');
    } finally {
      _isLoadingStudentsList = false;
      notifyListeners();
    }
  }

  // Fetch student violations
  Future<void> fetchStudentViolations({String? schoolYear, bool forceRefresh = false}) async {
    if (_token == null) return;
    
    if (!forceRefresh && _studentViolations.isNotEmpty && schoolYear == null) {
      debugPrint('🔍 Using cached student violations: ${_studentViolations.length}');
      return;
    }

    _isLoadingStudentViolations = true;
    notifyListeners();

    try {
      final url = _selectedSchoolYear == 'all'
          ? Uri.parse('$_baseUrl/api/counselor/student-violations/')
          : Uri.parse('$_baseUrl/api/counselor/student-violations/?school_year=$_selectedSchoolYear');
      
      debugPrint('🔍 Fetching student violations for school year: ${schoolYear ?? "all"}');
      
      final response = await _client.get(url, headers: _headers);

      debugPrint('🔍 Student violations response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          _studentViolations = List<Map<String, dynamic>>.from(responseData['violations'] ?? []);
          _error = null;
          
          debugPrint('✅ Student violations loaded: ${_studentViolations.length} violations');
        } else {
          _error = responseData['message'] ?? 'Failed to load student violations';
          debugPrint('❌ Error in response: $_error');
        }
      } else {
        _error = 'Failed to load student violations: HTTP ${response.statusCode}';
        debugPrint('❌ HTTP Error: $_error');
      }
    } catch (e) {
      _error = 'Error loading student violations: $e';
      debugPrint('❌ Exception: $_error');
    }

    _isLoadingStudentViolations = false;
    notifyListeners();
  }

  List<Map<String, dynamic>> get students => _studentsList;

  // Fetch violation types
  Future<void> fetchViolationTypes() async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    try {
      debugPrint('🔍 Fetching violation types...');
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/violation-types/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _violationTypes = List<Map<String, dynamic>>.from(data['violation_types'] ?? []);
          debugPrint('✅ Violation types loaded: ${_violationTypes.length} types');
        } else {
          _error = data['error'] ?? 'Failed to load violation types';
          _violationTypes = [];
        }
      } else {
        _error = 'Failed to load violation types: ${response.statusCode}';
        _violationTypes = [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching violation types: $e');
      _error = 'Network error: $e';
      _violationTypes = [];
    }
    notifyListeners();
  }

  // Fetch teacher reports
  Future<void> fetchTeacherReports() async {
    try {
      debugPrint('🔍 Fetching teacher reports...');
      
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/api/counselor/teacher-reports/'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('📡 Teacher reports response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          _teacherReports = List<Map<String, dynamic>>.from(
            data['reports']?.map((report) => Map<String, dynamic>.from(report)) ?? []
          );
          
          debugPrint('✅ Teacher reports loaded: ${_teacherReports.length} reports');
          notifyListeners();
        } else {
          throw Exception(data['message'] ?? 'Failed to load teacher reports');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching teacher reports: $e');
      _error = 'Failed to load teacher reports: $e';
      _teacherReports = [];
      notifyListeners();
    }
  }

  // Export students list
  Future<bool> exportStudentsList({
    String? gradeFilter, 
    String? sectionFilter,
    String? schoolYear,
  }) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return false;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/counselor/export-students/');
      final response = await _client.post(
        url,
        headers: _headers,
        body: jsonEncode({
          'grade_filter': gradeFilter != 'All' ? gradeFilter : null,
          'section_filter': sectionFilter != 'All' ? sectionFilter : null,
          'school_year': schoolYear,
          'format': 'csv',
        }),
      );

      debugPrint('🔍 Export students response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Students list exported successfully');
          return true;
        } else {
          _setError(data['error'] ?? 'Failed to export students list');
          return false;
        }
      } else {
        _setError('Failed to export students list: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Export students error: $e');
      _setError('Network error: $e');
      return false;
    }
  }

  // Create system report
  Future<bool> createSystemReport(Map<String, dynamic> reportData) async {
    if (_token == null) {
      _error = 'Authentication token not found';
      return false;
    }

    try {
      debugPrint('📝 Recording counselor violation: ${reportData['title']}');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/counselor/system-reports/'),
        headers: _headers,
        body: jsonEncode(reportData),
      );

      debugPrint('📝 Record violation response: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          lastCreatedReportId = data['violation_id'];
          debugPrint('✅ Violation recorded: ID $lastCreatedReportId');
          
          await fetchStudentViolations(forceRefresh: true);
          
          return true;
        } else {
          _error = data['error'] ?? 'Failed to record violation';
          return false;
        }
      } else {
        _error = 'Failed to record violation: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _error = 'Error recording violation: $e';
      debugPrint('❌ Exception: $_error');
      return false;
    }
  }

  // Tally violation
  Future<bool> tallyViolation(int reportId, Map<String, dynamic> violationData) async {
    if (_token == null) {
      _error = 'Authentication token not found';
      return false;
    }

    try {
      debugPrint('📊 Tallying violation for report #$reportId');
      
      if (!violationData.containsKey('school_year')) {
        violationData['school_year'] = _selectedSchoolYear;
      }
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/counselor/tally-violation/$reportId/'),
        headers: _headers,
        body: jsonEncode(violationData),
      );

      debugPrint('📊 Tally violation response: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Violation tallied successfully');
          
          await Future.wait([
            fetchStudentViolations(forceRefresh: true),
            fetchCounselorStudentReports(forceRefresh: true),
          ]);
          
          return true;
        } else {
          _error = data['error'] ?? 'Failed to tally violation';
          return false;
        }
      } else {
        _error = 'Failed to tally violation: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _error = 'Error tallying violation: $e';
      debugPrint('❌ Exception: $_error');
      return false;
    }
  }

  // Log counseling action
  Future<bool> logCounselingAction(Map<String, dynamic> actionData) async {
    if (_token == null) {
      _error = 'Authentication token not found';
      return false;
    }

    try {
      debugPrint('📝 Logging counseling action: ${actionData['action_type']}');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/counseling-logs/create/'),
        headers: _headers,
        body: jsonEncode(actionData),
      );

      debugPrint('📝 Log counseling action response: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Counseling action logged successfully');
          
          await Future.wait([
            fetchStudentViolations(forceRefresh: true),
            fetchCounselorStudentReports(forceRefresh: true),
          ]);
          
          return true;
        } else {
          _error = data['error'] ?? 'Failed to log counseling action';
          return false;
        }
      } else {
        _error = 'Failed to log counseling action: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      _error = 'Error logging counseling action: $e';
      debugPrint('❌ Exception: $_error');
      return false;
    }
  }

  // Get counseling logs
  Future<List<Map<String, dynamic>>> getCounselingLogs({
  int? studentId,
  String? schoolYear,
  bool includeHighRisk = true,
}) async {
  if (_token == null) {
    debugPrint('❌ No token available');
    return [];
  }

  try {
    final queryParams = <String, String>{};
    if (studentId != null) {
      queryParams['student_id'] = studentId.toString();
    }
    if (schoolYear != null && schoolYear != 'all') {
      queryParams['school_year'] = schoolYear;
    } else {
      queryParams['school_year'] = _selectedSchoolYear;
    }
    
    final uri = queryParams.isEmpty
        ? Uri.parse('$_baseUrl/api/counseling-logs/')
        : Uri.parse('$_baseUrl/api/counseling-logs/').replace(queryParameters: queryParams);
    
    debugPrint('📋 Fetching counseling logs from: $uri');
    
    final response = await _client.get(uri, headers: _headers);

    debugPrint('📋 Counseling logs response: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final logs = List<Map<String, dynamic>>.from(data['logs'] ?? []);
        debugPrint('✅ Fetched ${logs.length} counseling logs');
        
        // ✅ If includeHighRisk is true, add virtual sessions for high-risk students
        if (includeHighRisk) {
          final highRiskStudents = await getHighRiskStudentsForCounseling();
          
          for (final student in highRiskStudents) {
            // Check if student already has a recent counseling log
            final hasRecentSession = logs.any((log) => 
              log['student_id'] == student['id'] &&
              (log['status'] == 'scheduled' || log['status'] == 'completed') &&
              _isRecentSession(log['created_at'])
            );
            
            if (!hasRecentSession) {
              // Add virtual urgent session for high-risk student
              logs.insert(0, {
                'id': 'urgent_${student['id']}_${DateTime.now().millisecondsSinceEpoch}',
                'student_id': student['id'],
                'student_name': student['name'],
                'student': {
                  'id': student['id'],
                  'name': student['name'],
                  'first_name': student['first_name'],
                  'last_name': student['last_name'],
                  'grade_level': student['grade_level'],
                  'section': student['section'],
                  'student_id': student['student_id'],
                },
                'action_type': 'Critical Intervention Required',
                'description': 'Student with ${student['violation_count']} active violations requires immediate counseling.\n\nViolations: ${(student['violation_types'] as List).take(3).join(', ')}${(student['violation_types'] as List).length > 3 ? ' and ${(student['violation_types'] as List).length - 3} more...' : ''}',
                'status': 'urgent',
                'priority': student['priority'],
                'violation_count': student['violation_count'],
                'violation_types': student['violation_types'],
                'created_at': DateTime.now().toIso8601String(),
                'scheduled_date': DateTime.now().toIso8601String(),
                'is_virtual': true,
                'notes': 'Auto-generated due to high violation count. Immediate counseling intervention required.',
                'school_year': _selectedSchoolYear,
              });
            }
          }
          
          debugPrint('📊 Added ${highRiskStudents.length} high-risk students to counseling queue');
        }
        
        return logs;
      }
    }
    
    debugPrint('❌ Failed to fetch counseling logs');
    return [];
  } catch (e) {
    debugPrint('❌ Error fetching counseling logs: $e');
    return [];
  }
}

  // Get recently handled student IDs
  Future<Set<int>> getRecentlyHandledStudentIds() async {
    try {
      final logs = await getCounselingLogs(schoolYear: _selectedSchoolYear);
      
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final recentlyHandled = logs
          .where((log) {
            if (log['status'] != 'completed') return false;
            
            try {
              final logDate = DateTime.parse(log['created_at']);
              return logDate.isAfter(sevenDaysAgo);
            } catch (e) {
              return false;
            }
          })
          .map((log) => log['student_id'] as int)
          .toSet();
      
      debugPrint('📊 Found ${recentlyHandled.length} students with recent counseling');
      return recentlyHandled;
    } catch (e) {
      debugPrint('❌ Error getting recently handled students: $e');
      return {};
    }
  }

  // Update counseling session
  Future<bool> updateCounselingSession(int sessionId, Map<String, dynamic> updateData) async {
    if (_token == null) {
      _error = 'Authentication token not found';
      return false;
    }

    try {
      debugPrint('🔄 Updating counseling session #$sessionId');
      
      final response = await _client.patch(
        Uri.parse('$_baseUrl/api/counseling-logs/$sessionId/update/'),
        headers: _headers,
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Session updated successfully');
          
          if (updateData['status'] == 'completed') {
            debugPrint('🔄 Session completed - refreshing dashboard data...');
            
            await Future.wait([
              fetchStudentViolations(forceRefresh: true),
              fetchCounselorStudentReports(forceRefresh: true),
              fetchTeacherReports(),
            ]);
            
            debugPrint('✅ Dashboard data refreshed');
          }
          
          return true;
        }
      }
      
      _error = 'Failed to update session';
      return false;
    } catch (e) {
      _error = 'Error updating session: $e';
      debugPrint('❌ $_error');
      return false;
    }
  }

  // Fetch violation analytics
  Future<Map<String, dynamic>?> fetchViolationAnalytics() async {
    try {
      debugPrint('📊 Fetching violation analytics...');
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/counselor/violation-analytics/'),
        headers: _headers,
      );

      debugPrint('📊 Analytics response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          debugPrint('✅ Analytics data received successfully');
          
          final analytics = data['analytics'] ?? {};
          final summary = analytics['summary'] ?? {};
          
          final processedData = {
            'success': true,
            'violation_analytics': {
              for (var item in (analytics['violations_by_category'] ?? []))
                item['violation_type__category'] ?? 'Unknown': {
                  'count': item['count'] ?? 0,
                  'percentage': 0.0
                },
            },
            'status_distribution': [
              {'status': 'active', 'count': summary['active_violations'] ?? 0},
              {'status': 'resolved', 'count': summary['resolved_violations'] ?? 0},
            ],
            'monthly_trends': analytics['violations_by_grade'] ?? [],
            'total_reports': summary['total_violations'] ?? 0,
            'frequent_violations': analytics['frequent_violations'] ?? [],
          };
          
          return processedData;
        } else {
          debugPrint('❌ Analytics API returned error');
          return null;
        }
      } else {
        debugPrint('❌ Analytics API failed');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Analytics fetch error: $e');
      return null;
    }
  }

  // Fetch dashboard analytics
  Future<Map<String, dynamic>> fetchDashboardAnalytics() async {
    if (_token == null) {
      throw Exception('Authentication token not found');
    }

    try {
      debugPrint('📊 Fetching comprehensive dashboard analytics...');
      
      await Future.wait([
        fetchCounselorStudentReports(forceRefresh: true),
        fetchTeacherReports(),
        fetchStudentViolations(),
        fetchViolationTypes(),
      ]);

      final totalStudentReports = _counselorStudentReports.length;
      final totalTeacherReports = _teacherReports.length;
      final totalReports = totalStudentReports + totalTeacherReports;
      
      final pendingStudentReports = _counselorStudentReports.where((r) => r['status'] == 'pending').length;
      final pendingTeacherReports = _teacherReports.where((r) => r['status'] == 'pending').length;
      final reviewedStudentReports = _counselorStudentReports.where((r) => r['status'] == 'reviewed').length;
      final reviewedTeacherReports = _teacherReports.where((r) => r['status'] == 'reviewed').length;
      
      final statusDistribution = {
        'pending': pendingStudentReports + pendingTeacherReports,
        'reviewed': reviewedStudentReports + reviewedTeacherReports,
        'total_student_reports': totalStudentReports,
        'total_teacher_reports': totalTeacherReports,
      };

      final violationsByType = <String, int>{};
      final violationsByStatus = <String, int>{};
      final violationsBySeverity = <String, int>{};
      
      for (final violation in _studentViolations) {
        final violationType = violation['violation_type']?['name']?.toString() ?? 
                             violation['violation_type']?.toString() ?? 'Unknown';
        violationsByType[violationType] = (violationsByType[violationType] ?? 0) + 1;
        
        final status = violation['status']?.toString() ?? 'unknown';
        violationsByStatus[status] = (violationsByStatus[status] ?? 0) + 1;
        
        final severity = violation['severity']?.toString() ?? 
                        violation['violation_type']?['severity_level']?.toString() ?? 'medium';
        violationsBySeverity[severity] = (violationsBySeverity[severity] ?? 0) + 1;
      }

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentStudentReports = _counselorStudentReports.where((report) {
        try {
          final reportDate = DateTime.parse(report['created_at'] ?? '');
          return reportDate.isAfter(thirtyDaysAgo);
        } catch (e) {
          return false;
        }
      }).length;
      
      final recentTeacherReports = _teacherReports.where((report) {
        try {
          final reportDate = DateTime.parse(report['created_at'] ?? report['date'] ?? '');
          return reportDate.isAfter(thirtyDaysAgo);
        } catch (e) {
          return false;
        }
      }).length;

      final analytics = {
        'success': true,
        'total_reports': totalReports,
        'status_distribution': statusDistribution,
        'violations_by_type': violationsByType,
        'violations_by_status': violationsByStatus,
        'violations_by_severity': violationsBySeverity,
        'recent_activity': {
          'student_reports_30_days': recentStudentReports,
          'teacher_reports_30_days': recentTeacherReports,
          'total_violations': _studentViolations.length,
        },
        'summary': {
          'total_students': _studentsList.length,
          'total_violations': _studentViolations.length,
          'active_violations': violationsByStatus['active'] ?? 0,
          'resolved_violations': violationsByStatus['resolved'] ?? 0,
          'pending_reports': statusDistribution['pending'],
          'high_severity_violations': violationsBySeverity['high'] ?? 0,
        }
      };

      debugPrint('📊 Dashboard analytics calculated');
      return analytics;
      
    } catch (e) {
      debugPrint('❌ Error fetching dashboard analytics: $e');
      rethrow;
    }
  }

  // Get combined recent reports
  List<Map<String, dynamic>> getCombinedRecentReports({int limit = 10}) {
    final combinedReports = <Map<String, dynamic>>[];
    
    for (final report in _counselorStudentReports) {
      combinedReports.add({
        ...report,
        'source_type': 'student_report',
        'reporter_type': 'Student',
        'icon': 'person',
      });
    }
    
    for (final report in _teacherReports) {
      combinedReports.add({
        ...report,
        'source_type': 'teacher_report',
        'reporter_type': 'Teacher', 
        'icon': 'school',
      });
    }
    
    combinedReports.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['created_at'] ?? a['date'] ?? '');
        final dateB = DateTime.parse(b['created_at'] ?? b['date'] ?? '');
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });
    
    return combinedReports.take(limit).toList();
  }

  // Update report status
  Future<bool> updateReportStatus(
    int reportId,
    String newStatus, {
    String? notes,
    String? reportType,
  }) async {
    if (_token == null) {
      _error = 'Authentication token not found';
      return false;
    }

    try {
      debugPrint('🔄 Updating report #$reportId to status: $newStatus');
      
      final type = reportType ?? 'student_report';
      
      String endpoint;
      Map<String, dynamic> body;
      
      if (newStatus == 'summoned') {
        endpoint = '/api/counselor/send-guidance-notice/$reportId/';
        body = {
          'report_type': type,
          'notes': notes ?? '',
        };
      } else {
        endpoint = '/api/counselor/update-report-status/$reportId/';
        body = {
          'status': newStatus,
          'notes': notes ?? '',
          'report_type': type,
        };
      }

      final response = await _makeAuthenticatedRequest(
        endpoint,
        method: 'POST',
        body: body,
      );

      debugPrint('📡 Update report response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Report status updated successfully');
          
          await Future.wait([
            if (type == 'student_report' || type == 'peer_report' || type == 'self_report')
              fetchCounselorStudentReports(),
            if (type == 'teacher_report')
              fetchTeacherReports(),
          ]);
          
          return true;
        } else {
          _error = data['error'] ?? 'Failed to update report status';
          return false;
        }
      } else {
        _error = 'Failed to update report: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      debugPrint('❌ Update report error: $e');
      _error = 'Network error: $e';
      return false;
    }
  }

  // Update teacher report status
  Future<bool> updateTeacherReportStatus(int reportId, String status, {String? notes}) async {
    try {
      debugPrint('🔄 Updating teacher report $reportId status to: $status');
      
      final response = await _client.patch(
        Uri.parse('$_baseUrl/api/counselor/teacher-reports/$reportId/update-status/'),
        headers: _headers,
        body: json.encode({
          'status': status,
          'counselor_notes': notes ?? '',
        }),
      ).timeout(const Duration(seconds: 10));

      debugPrint('📡 Update response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          debugPrint('✅ Teacher report status updated');
          
          final reportIndex = _teacherReports.indexWhere((r) => r['id'] == reportId);
          if (reportIndex != -1) {
            _teacherReports[reportIndex]['status'] = status;
            if (notes != null) {
              _teacherReports[reportIndex]['counselor_notes'] = notes;
            }
            notifyListeners();
          }
          
          return true;
        } else {
          _error = data['message'] ?? 'Failed to update';
          notifyListeners();
          return false;
        }
      } else {
        _error = 'Server error: ${response.statusCode}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error: $e';
      debugPrint('❌ $_error');
      notifyListeners();
      return false;
    }
  }

  // Create tally record
  Future<bool> createTallyRecord(Map<String, dynamic> tallyData) async {
    if (_token == null) return false;
    
    try {
      debugPrint('📊 Creating tally record');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/counselor/tally-records/'),
        headers: _headers,
        body: jsonEncode(tallyData),
      );

      debugPrint('📊 Response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          debugPrint('✅ Tally record created');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  // Record violation from tally
  Future<bool> recordViolationFromTally(Map<String, dynamic> violationData) async {
    if (_token == null) return false;
    
    try {
      debugPrint('⚠️ Recording violation from tally');
      
      if (!violationData.containsKey('school_year')) {
        violationData['school_year'] = _getCurrentSchoolYear();
      }
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/counselor/violations/from-tally/'),
        headers: _headers,
        body: jsonEncode(violationData),
      );

      debugPrint('⚠️ Response: ${response.statusCode}');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          debugPrint('✅ Violation recorded');
          
          await fetchStudentViolations(
            schoolYear: violationData['school_year'],
            forceRefresh: true,
          );
          return true;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  // Fetch tally records
  Future<List<Map<String, dynamic>>> fetchTallyRecords() async {
    if (_token == null) return [];
    
    try {
      debugPrint('📊 Fetching tally records...');
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/counselor/tally-records/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tallyRecords = List<Map<String, dynamic>>.from(data['results'] ?? data ?? []);
        
        debugPrint('✅ Fetched ${tallyRecords.length} tally records');
        return tallyRecords;
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ Error: $e');
      return [];
    }
  }

  // Fetch notifications
  Future<void> fetchNotifications() async {
    if (_token == null) return;

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/notifications/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _notifications = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
          debugPrint('✅ Notifications loaded: ${_notifications.length}');
        }
      }
    } catch (e) {
      debugPrint('❌ Notifications fetch error: $e');
    }
    notifyListeners();
  }

  // Mark student report as reviewed
  Future<bool> markStudentReportAsReviewed(int index) async {
    if (_token == null || index >= _counselorStudentReports.length) {
      return false;
    }

    try {
      final report = _counselorStudentReports[index];
      final reportId = report['id'];
      
      if (reportId == null) {
        debugPrint('❌ Report ID is null');
        return false;
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/api/mark-report-reviewed/'),
        headers: _headers,
        body: jsonEncode({
          'report_id': reportId,
          'status': 'reviewed',
        }),
      );

      debugPrint('🔍 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _counselorStudentReports[index]['status'] = 'reviewed';
          debugPrint('✅ Report marked as reviewed');
          notifyListeners();
          return true;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Error marking report as reviewed: $e');
      return false;
    }
  }

  // Mark report as invalid
  Future<bool> markReportAsInvalid({
    required int reportId,
    required String reason,
  }) async {
    if (_token == null) {
      _error = 'No token available';
      notifyListeners();
      return false;
    }

    try {
      debugPrint('🔄 Marking report #$reportId as invalid...');

      // Infer report type from local state; default to student_report
      String reportType = 'student_report';
      final idx = _counselorStudentReports.indexWhere((r) => r['id'] == reportId);
      if (idx != -1 && (_counselorStudentReports[idx]['report_type'] is String)) {
        reportType = (_counselorStudentReports[idx]['report_type'] as String).toLowerCase();
      } else if (_teacherReports.any((r) => r['id'] == reportId)) {
        reportType = 'teacher_report';
      }

      final uri = Uri.parse('$_baseUrl/api/counselor/mark-report-invalid/$reportId/');
      final response = await _client.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'reason': reason,
          'report_type': reportType, // backend defaults to student_report, but we pass what we infer
        }),
      );

      debugPrint('📡 Mark invalid response: ${response.statusCode}');
      final contentType = (response.headers['content-type'] ?? '').toLowerCase();

      if (response.statusCode == 200) {
        final data = contentType.contains('application/json') ? jsonDecode(response.body) : {'success': true};
        if (data['success'] == true) {
          void updateList(List<Map<String, dynamic>> list) {
            final i = list.indexWhere((r) => r['id'] == reportId);
            if (i != -1) {
              list[i]['status'] = 'invalid';
              list[i]['counselor_notes'] = reason;
            }
          }
          updateList(_counselorStudentReports);
          updateList(_studentReports);
          updateList(_teacherReports);
          notifyListeners();
          return true;
        }
        _error = (data['error'] ?? 'Failed to mark report as invalid').toString();
        notifyListeners();
        return false;
      }

      // Non-200 responses: avoid decoding HTML
      if (response.statusCode == 404) {
        _error = 'Endpoint not found. Expected /api/counselor/mark-report-invalid/$reportId/';
      } else if (contentType.contains('application/json')) {
        try {
          final data = jsonDecode(response.body);
          _error = (data['error'] ?? 'Failed to mark report as invalid').toString();
        } catch (_) {
          _error = 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Error'}';
        }
      } else {
        _error = 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Error'}';
      }
      debugPrint('❌ $_error');
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ Error marking report as invalid: $e');
      _error = 'Error: $e';
      notifyListeners();
      return false;
    }
  }

  // Fetch counseling sessions
  Future<void> fetchCounselingSessions({String? schoolYear}) async {
    if (_token == null) return;
    
    _isLoadingCounselingSessions = true;
    
    try {
      final year = schoolYear ?? _selectedSchoolYear;
      
      final url = year == 'all'
          ? Uri.parse('$_baseUrl/api/counseling-logs/')
          : Uri.parse('$_baseUrl/api/counseling-logs/?school_year=$year');
      
      debugPrint('📋 Fetching counseling sessions for S.Y.: $year');

      final response = await _client.get(url, headers: _headers);
      debugPrint('📋 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _counselingSessions = List<Map<String, dynamic>>.from(data['logs'] ?? []);
          debugPrint('✅ Fetched ${_counselingSessions.length} real counseling sessions');
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching counseling sessions: $e');
      _error = e.toString();
    } finally {
      _isLoadingCounselingSessions = false;
      notifyListeners();
    }
  }

  // Get student violation summary
  Future<Map<String, dynamic>> getStudentViolationSummary(int studentId) async {
    if (_token == null) {
      return {'success': false, 'error': 'No token available'};
    }

    try {
      debugPrint('📊 Fetching violation summary for student #$studentId');
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/counselor/students/$studentId/violation-summary/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Violation summary fetched');
        return data;
      } else {
        debugPrint('❌ Failed to fetch summary: ${response.statusCode}');
        return {'success': false, 'error': 'Failed to fetch summary'};
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

Future<List<Map<String, dynamic>>> getHighRiskStudentsForCounseling() async {
    if (_token == null) {
      debugPrint('❌ No token available');
      return [];
    }

    try {
      debugPrint('📊 Fetching high-risk students for counseling...');
      
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/counselor/high-risk-students/'),
        headers: _headers,
      );

      debugPrint('📊 High-risk students response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final students = List<Map<String, dynamic>>.from(data['students'] ?? []);
          debugPrint('✅ Found ${students.length} high-risk students requiring counseling');
          return students;
        } else {
          debugPrint('❌ API returned error: ${data['error']}');
          return [];
        }
      } else {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching high-risk students: $e');
      return [];
    }
  }

// ✅ NEW: Get students with violation counts for counseling priority
Future<List<Map<String, dynamic>>> getStudentsWithViolationCounts() async {
  if (_token == null) {
    debugPrint('❌ No token available');
    return [];
  }

  try {
    debugPrint('📊 Fetching students with violation counts...');
    
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/counselor/students-with-violation-counts/?school_year=$_selectedSchoolYear'),
      headers: _headers,
    );

    debugPrint('📊 Students with violations response: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final students = List<Map<String, dynamic>>.from(data['students'] ?? []);
        debugPrint('✅ Found ${students.length} students with violation data');
        return students;
      }
    }
    
    return [];
  } catch (e) {
    debugPrint('❌ Error fetching students with violation counts: $e');
    return [];
  }
}

// ✅ NEW: Helper method to check if a session is recent (within 7 days)
bool _isRecentSession(String? dateString) {
  if (dateString == null) return false;
  
  try {
    final sessionDate = DateTime.parse(dateString);
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return sessionDate.isAfter(sevenDaysAgo);
  } catch (e) {
    return false;
  }
}

// ✅ NEW: Schedule emergency counseling for high-risk student
Future<bool> scheduleEmergencyCounseling({
  required int studentId,
  required String studentName,
  required int violationCount,
  required List<String> violationTypes,
  DateTime? scheduledDate,
  String? notes,
}) async {
  if (_token == null) {
    _error = 'Authentication token not found';
    return false;
  }

  try {
    debugPrint('🚨 Scheduling emergency counseling for student #$studentId');
    
    final sessionData = {
      'student_id': studentId,
      'action_type': 'Emergency Counseling',
      'description': 'Emergency counseling session scheduled due to $violationCount active violations.\n\nStudent: $studentName\nViolations: ${violationTypes.take(3).join(', ')}${violationTypes.length > 3 ? ' and ${violationTypes.length - 3} more...' : ''}',
      'notes': notes ?? 'High-risk student with $violationCount violations. Immediate intervention required.',
      'scheduled_date': (scheduledDate ?? DateTime.now()).toIso8601String(),
      'priority': violationCount >= 5 ? 'high' : 'medium',
      'status': 'scheduled',
      'action_taken': 'emergency_scheduling',
      'session_type': 'emergency',
      'school_year': _selectedSchoolYear,
    };
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/counseling-logs/create/'),
      headers: _headers,
      body: jsonEncode(sessionData),
    );

    debugPrint('🚨 Emergency session response: ${response.statusCode}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        debugPrint('✅ Emergency counseling session scheduled successfully');
        
        // Add to local list
        if (data['session'] != null) {
          _counselingSessions.insert(0, Map<String, dynamic>.from(data['session']));
        }
        
        // Refresh the counseling sessions
        await fetchCounselingSessions();
        
        notifyListeners();
        return true;
      } else {
        _error = data['error'] ?? 'Failed to schedule emergency counseling';
        debugPrint('❌ Failed: $_error');
        notifyListeners();
        return false;
      }
    } else {
      final errorData = jsonDecode(response.body);
      _error = errorData['error'] ?? 'Failed to schedule emergency session: ${response.statusCode}';
      debugPrint('❌ HTTP ${response.statusCode}: $_error');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error scheduling emergency counseling: $e';
    debugPrint('❌ Exception: $_error');
    notifyListeners();
    return false;
  }
}

// ✅ NEW: Convert virtual urgent session to proper scheduled session
Future<bool> convertUrgentToScheduledSession({
  required String virtualSessionId,
  required int studentId,
  required DateTime scheduledDate,
  String? notes,
  String? sessionType,
}) async {
  if (_token == null) {
    _error = 'Authentication token not found';
    return false;
  }

  try {
    debugPrint('🔄 Converting urgent session to scheduled: $virtualSessionId');
    
    // Find the virtual session
    final virtualSession = _counselingSessions.firstWhere(
      (s) => s['id'] == virtualSessionId,
      orElse: () => {},
    );
    
    if (virtualSession.isEmpty) {
      _error = 'Virtual session not found';
      return false;
    }
    
    // Create a proper counseling session
    final sessionData = {
      'student_id': studentId,
      'action_type': sessionType ?? 'Counseling Session',
      'description': virtualSession['description'] ?? 'Counseling session for high-risk student',
      'notes': notes ?? 'Converted from urgent intervention requirement',
      'scheduled_date': scheduledDate.toIso8601String(),
      'priority': virtualSession['priority'] ?? 'high',
      'status': 'scheduled',
      'action_taken': 'converted_from_urgent',
      'school_year': _selectedSchoolYear,
    };
    
    final success = await createCounselingSession(sessionData);
    
    if (success) {
      // Remove the virtual session from local list
      _counselingSessions.removeWhere((s) => s['id'] == virtualSessionId);
      notifyListeners();
      
      debugPrint('✅ Successfully converted urgent to scheduled session');
      return true;
    } else {
      debugPrint('❌ Failed to create scheduled session');
      return false;
    }
  } catch (e) {
    _error = 'Error converting urgent session: $e';
    debugPrint('❌ Exception: $_error');
    notifyListeners();
    return false;
  }
}

// ✅ NEW: Mark urgent session as handled (dismiss from urgent list)
Future<bool> dismissUrgentSession(String virtualSessionId, String reason) async {
  try {
    debugPrint('🔄 Dismissing urgent session: $virtualSessionId');
    
    // Remove the virtual session from local list
    _counselingSessions.removeWhere((s) => s['id'] == virtualSessionId);
    
    // Optionally log this dismissal
    debugPrint('📝 Urgent session dismissed: $reason');
    
    notifyListeners();
    return true;
  } catch (e) {
    debugPrint('❌ Error dismissing urgent session: $e');
    return false;
  }
}

// ✅ NEW: Get counseling sessions by status (including urgent)
List<Map<String, dynamic>> getCounselingSessionsByStatus(String status) {
  if (status == 'scheduled') {
    // Include both 'scheduled' and 'urgent' in scheduled tab
    return _counselingSessions.where((session) => 
      session['status'] == 'scheduled' || session['status'] == 'urgent'
    ).toList();
  } else if (status == 'urgent') {
    // Only urgent sessions
    return _counselingSessions.where((session) => 
      session['status'] == 'urgent'
    ).toList();
  } else {
    // Other statuses (completed, cancelled)
    return _counselingSessions.where((session) => 
      session['status'] == status
    ).toList();
  }
}

// ✅ NEW: Get urgent sessions count
int getUrgentSessionsCount() {
  return _counselingSessions.where((session) => 
    session['status'] == 'urgent'
  ).length;
}

// ✅ NEW: Get high-priority students needing immediate attention
Future<List<Map<String, dynamic>>> getHighPriorityStudents() async {
  try {
    final highRiskStudents = await getHighRiskStudentsForCounseling();
    
    // Filter students with 5+ violations as high priority
    return highRiskStudents.where((student) => 
      (student['violation_count'] ?? 0) >= 5
    ).toList();
  } catch (e) {
    debugPrint('❌ Error getting high priority students: $e');
    return [];
  }
}

  // Search students
  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    if (_token == null || query.isEmpty) {
      return [];
    }

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/counselor/students/search/?q=$query'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['students'] ?? []);
        }
      }
      return [];
    } catch (e) {
      debugPrint('❌ Search error: $e');
      return [];
    }
  }

  // Get student details
  Future<Map<String, dynamic>?> getStudentDetails(int studentId) async {
    if (_token == null) return null;

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/counselor/students/$studentId/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['student'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return null;
    }
  }

  // Verify report
  Future<bool> verifyReport(int reportId, {String? notes}) async {
    if (_token == null) return false;

    try {
      debugPrint('✅ Verifying report #$reportId');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/counselor/student-reports/$reportId/verify/'),
        headers: _headers,
        body: jsonEncode({
          'status': 'verified',
          'notes': notes ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Report verified');
          
          // Update local state
          final index = _counselorStudentReports.indexWhere((r) => r['id'] == reportId);
          if (index != -1) {
            _counselorStudentReports[index]['status'] = 'verified';
            if (notes != null) {
              _counselorStudentReports[index]['counselor_notes'] = notes;
            }
          }
          
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  // Reject report
  Future<bool> rejectReport(int reportId, {required String reason}) async {
    if (_token == null) return false;

    try {
      debugPrint('❌ Rejecting report #$reportId');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/counselor/student-reports/$reportId/reject/'),
        headers: _headers,
        body: jsonEncode({
          'status': 'rejected',
          'reason': reason,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Report rejected');
          
          // Update local state
          final index = _counselorStudentReports.indexWhere((r) => r['id'] == reportId);
          if (index != -1) {
            _counselorStudentReports[index]['status'] = 'rejected';
            _counselorStudentReports[index]['counselor_notes'] = reason;
          }
          
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  // Bulk update report statuses
  Future<bool> bulkUpdateReportStatus(
    List<int> reportIds,
    String newStatus, {
    String? notes,
  }) async {
    if (_token == null) return false;

    try {
      debugPrint('🔄 Bulk updating ${reportIds.length} reports to: $newStatus');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/counselor/student-reports/bulk-update/'),
        headers: _headers,
        body: jsonEncode({
          'report_ids': reportIds,
          'status': newStatus,
          'notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Bulk update successful');
          
          // Update local state
          for (final reportId in reportIds) {
            final index = _counselorStudentReports.indexWhere((r) => r['id'] == reportId);
            if (index != -1) {
              _counselorStudentReports[index]['status'] = newStatus;
              if (notes != null) {
                _counselorStudentReports[index]['counselor_notes'] = notes;
              }
            }
          }
          
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  // Export violations report
  Future<bool> exportViolationsReport({
    String? format = 'csv',
    String? schoolYear,
    String? gradeLevel,
  }) async {
    if (_token == null) return false;

    try {
      final queryParams = <String, String>{
        'format': format ?? 'csv',
      };
      
      if (schoolYear != null && schoolYear != 'all') {
        queryParams['school_year'] = schoolYear;
      }
      if (gradeLevel != null && gradeLevel != 'all') {
        queryParams['grade_level'] = gradeLevel;
      }
      
      final uri = Uri.parse('$_baseUrl/api/counselor/export-violations/')
          .replace(queryParameters: queryParams);
      
      debugPrint('📊 Exporting violations report...');
      
      final response = await _client.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        debugPrint('✅ Export successful');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Export error: $e');
      return false;
    }
  }

  Future<bool> createCounselingSession(Map<String, dynamic> sessionData) async {
    if (_token == null) {
      _error = 'Authentication token not found';
      return false;
    }

    try {
      debugPrint('📝 Creating real counseling session...');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/counseling-logs/create/'),
        headers: _headers,
        body: jsonEncode(sessionData),
      );

      debugPrint('📝 Create session response: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Real counseling session created successfully');
          
          // Add to local list if session data is returned
          if (data['counseling_log'] != null) {
            _counselingSessions.insert(0, Map<String, dynamic>.from(data['counseling_log']));
          }
          
          notifyListeners();
          return true;
        } else {
          _error = data['error'] ?? 'Failed to create counseling session';
          debugPrint('❌ Failed: $_error');
          notifyListeners();
          return false;
        }
      } else {
        final errorData = jsonDecode(response.body);
        _error = errorData['error'] ?? 'Failed to create session: ${response.statusCode}';
        debugPrint('❌ HTTP ${response.statusCode}: $_error');
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Error creating counseling session: $e';
      debugPrint('❌ Exception: $_error');
      notifyListeners();
      return false;
    }
  }

Future<bool> sendCounselingNotification({
    required int studentId,
    required String message,
    String? scheduledDate,
  }) async {
    if (_token == null) {
      _error = 'Authentication token not found';
      return false;
    }

    try {
      debugPrint('📨 Sending counseling notification to student #$studentId');
      
      final response = await _client.post(
        Uri.parse('$_baseUrl/api/counseling/send-notification/'),
        headers: _headers,
        body: jsonEncode({
          'student_id': studentId,
          'message': message,
          'scheduled_date': scheduledDate,
        }),
      );

      debugPrint('📨 Send notification response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Notification sent successfully');
          return true;
        } else {
          _error = data['error'] ?? 'Failed to send notification';
          debugPrint('❌ Failed: $_error');
          return false;
        }
      } else {
        _error = 'Failed to send notification: ${response.statusCode}';
        debugPrint('❌ HTTP ${response.statusCode}: $_error');
        return false;
      }
    } catch (e) {
      _error = 'Error sending notification: $e';
      debugPrint('❌ Exception: $_error');
      return false;
    }
  }

// Update counseling session status
Future<bool> updateCounselingSessionStatus(int sessionId, String newStatus) async {
  if (_token == null) {
    _error = 'Authentication token not found';
    return false;
  }

  try {
    debugPrint('🔄 Updating counseling session #$sessionId to status: $newStatus');
    
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/counseling-logs/$sessionId/update/'),
      headers: _headers,
      body: jsonEncode({
        'status': newStatus,
      }),
    );

    debugPrint('🔄 Update session response: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        debugPrint('✅ Session status updated successfully');
        
        // Update local state
        final index = _counselingSessions.indexWhere((s) => s['id'] == sessionId);
        if (index != -1) {
          _counselingSessions[index]['status'] = newStatus;
          
          // If marked as completed, update completed_at timestamp
          if (newStatus == 'completed') {
            _counselingSessions[index]['completed_at'] = DateTime.now().toIso8601String();
          }
        }
        
        // If session is completed, refresh related data
        if (newStatus == 'completed') {
          debugPrint('🔄 Session completed - refreshing dashboard data...');
          await Future.wait([
            fetchStudentViolations(forceRefresh: true),
            fetchCounselorStudentReports(forceRefresh: true),
          ]);
        }
        
        notifyListeners();
        return true;
      } else {
        _error = data['error'] ?? 'Failed to update session status';
        debugPrint('❌ Failed: $_error');
        notifyListeners();
        return false;
      }
    } else {
      final errorData = jsonDecode(response.body);
      _error = errorData['error'] ?? 'Failed to update session: ${response.statusCode}';
      debugPrint('❌ HTTP ${response.statusCode}: $_error');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error updating counseling session: $e';
    debugPrint('❌ Exception: $_error');
    notifyListeners();
    return false;
  }
}

// Delete counseling session (optional but useful)
Future<bool> deleteCounselingSession(int sessionId) async {
  if (_token == null) {
    _error = 'Authentication token not found';
    return false;
  }

  try {
    debugPrint('🗑️ Deleting counseling session #$sessionId');
    
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/counseling-logs/$sessionId/delete/'),
      headers: _headers,
    );

    debugPrint('🗑️ Delete session response: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 204) {
      debugPrint('✅ Session deleted successfully');
      
      // Remove from local state
      _counselingSessions.removeWhere((s) => s['id'] == sessionId);
      
      notifyListeners();
      return true;
    } else {
      final data = jsonDecode(response.body);
      _error = data['error'] ?? 'Failed to delete session: ${response.statusCode}';
      debugPrint('❌ $_error');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error deleting counseling session: $e';
    debugPrint('❌ Exception: $_error');
    notifyListeners();
    return false;
  }
}

// Add student
Future<bool> addStudent(Map<String, dynamic> studentData) async {
  if (_token == null) {
    _error = 'Authentication token not found';
    return false;
  }

  try {
    debugPrint('➕ Adding new student: ${studentData['first_name']} ${studentData['last_name']}');
    
    // Ensure school_year is included
    if (!studentData.containsKey('school_year')) {
      studentData['school_year'] = _selectedSchoolYear;
    }
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/counselor/students/add/'),
      headers: _headers,
      body: jsonEncode(studentData),
    );

    debugPrint('➕ Add student response: ${response.statusCode}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        debugPrint('✅ Student added successfully');
        
        // Add to local list if student data is returned
        if (data['student'] != null) {
          _studentsList.add(Map<String, dynamic>.from(data['student']));
        }
        
        // Refresh the list
        await fetchStudentsList(schoolYear: _selectedSchoolYear);
        
        notifyListeners();
        return true;
      } else {
        _error = data['error'] ?? 'Failed to add student';
        debugPrint('❌ Failed: $_error');
        notifyListeners();
        return false;
      }
    } else {
      final errorData = jsonDecode(response.body);
      _error = errorData['error'] ?? 'Failed to add student: ${response.statusCode}';
      debugPrint('❌ HTTP ${response.statusCode}: $_error');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error adding student: $e';
    debugPrint('❌ Exception: $_error');
    notifyListeners();
    return false;
  }
}

// Update student
Future<bool> updateStudent(int studentId, Map<String, dynamic> studentData) async {
  if (_token == null) {
    _error = 'Authentication token not found';
    return false;
  }

  try {
    debugPrint('✏️ Updating student #$studentId');
    
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/counselor/students/$studentId/update/'),
      headers: _headers,
      body: jsonEncode(studentData),
    );

    debugPrint('✏️ Update student response: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        debugPrint('✅ Student updated successfully');
        
        // Update local state
        final index = _studentsList.indexWhere((s) => s['id'] == studentId);
        if (index != -1) {
          // Merge updated data
          _studentsList[index] = {
            ..._studentsList[index],
            ...studentData,
            'id': studentId,
          };
        }
        
        // Refresh the list to get latest data
        await fetchStudentsList(schoolYear: _selectedSchoolYear);
        
        notifyListeners();
        return true;
      } else {
        _error = data['error'] ?? 'Failed to update student';
        debugPrint('❌ Failed: $_error');
        notifyListeners();
        return false;
      }
    } else {
      final errorData = jsonDecode(response.body);
      _error = errorData['error'] ?? 'Failed to update student: ${response.statusCode}';
      debugPrint('❌ HTTP ${response.statusCode}: $_error');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error updating student: $e';
    debugPrint('❌ Exception: $_error');
    notifyListeners();
    return false;
  }
}

// Delete student
Future<bool> deleteStudent(int studentId) async {
  if (_token == null) {
    _error = 'Authentication token not found';
    return false;
  }

  try {
    debugPrint('🗑️ Deleting student #$studentId');
    
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/counselor/students/$studentId/delete/'),
      headers: _headers,
    );

    debugPrint('🗑️ Delete student response: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 204) {
      debugPrint('✅ Student deleted successfully');
      
      // Remove from local state
      _studentsList.removeWhere((s) => s['id'] == studentId);
      
      // Also remove from violations if present
      _studentViolations.removeWhere((v) => 
        v['student_id']?.toString() == studentId.toString() ||
        v['student']?['id']?.toString() == studentId.toString()
      );
      
      notifyListeners();
      return true;
    } else {
      final data = jsonDecode(response.body);
      _error = data['error'] ?? 'Failed to delete student: ${response.statusCode}';
      debugPrint('❌ $_error');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error deleting student: $e';
    debugPrint('❌ Exception: $_error');
    notifyListeners();
    return false;
  }
}

// Bulk add students
Future<bool> bulkAddStudents(List<Map<String, dynamic>> students) async {
  if (_token == null) {
    _error = 'Authentication token not found';
    return false;
  }

  try {
    debugPrint('📦 Bulk adding ${students.length} students');
    
    // Ensure all students have school_year
    final studentsWithYear = students.map((student) {
      if (!student.containsKey('school_year')) {
        student['school_year'] = _selectedSchoolYear;
      }
      return student;
    }).toList();
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/counselor/students/bulk-add/'),
      headers: _headers,
      body: jsonEncode({
        'students': studentsWithYear,
      }),
    );

    debugPrint('📦 Bulk add response: ${response.statusCode}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final addedCount = data['added_count'] ?? students.length;
        debugPrint('✅ Successfully added $addedCount students');
        
        // Refresh the list
        await fetchStudentsList(schoolYear: _selectedSchoolYear);
        
        notifyListeners();
        return true;
      } else {
        _error = data['error'] ?? 'Failed to bulk add students';
        debugPrint('❌ Failed: $_error');
        notifyListeners();
        return false;
      }
    } else {
      final errorData = jsonDecode(response.body);
      _error = errorData['error'] ?? 'Failed to bulk add students: ${response.statusCode}';
      debugPrint('❌ HTTP ${response.statusCode}: $_error');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error bulk adding students: $e';
    debugPrint('❌ Exception: $_error');
    notifyListeners();
    return false;
  }
}

// Send counseling summons
Future<bool> sendCounselingSummons({
  required int reportId,
  required String reportType,
  String? scheduledDate,
  String? message,
}) async {
  if (_token == null) {
    _error = 'Authentication token not found';
    return false;
  }

  try {
    debugPrint('📢 Sending counseling summons for report #$reportId (type: $reportType)');
    
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/counselor/send-counseling-summons/'),
      headers: _headers,
      body: jsonEncode({
        'report_id': reportId,
        'report_type': reportType,
        'message': message ?? 'You have been summoned for counseling.',
        'scheduled_date': scheduledDate ?? DateTime.now().toIso8601String(),
      }),
    );

    debugPrint('📢 Send summons response: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        debugPrint('✅ Counseling summons sent successfully');
        
        // ✅ Update local report status to 'summoned'
        final index = _counselorStudentReports.indexWhere((r) => r['id'] == reportId);
        if (index != -1) {
          _counselorStudentReports[index]['status'] = 'summoned';
        }
        
        final studentReportIndex = _studentReports.indexWhere((r) => r['id'] == reportId);
        if (studentReportIndex != -1) {
          _studentReports[studentReportIndex]['status'] = 'summoned';
        }
        
        if (reportType == 'teacher_report') {
          final teacherReportIndex = _teacherReports.indexWhere((r) => r['id'] == reportId);
          if (teacherReportIndex != -1) {
            _teacherReports[teacherReportIndex]['status'] = 'summoned';
          }
        }
        
        notifyListeners();
        return true;
      } else {
        _error = data['error'] ?? 'Failed to send counseling summons';
        debugPrint('❌ Failed: $_error');
        notifyListeners();
        return false;
      }
    } else {
      final errorData = jsonDecode(response.body);
      _error = errorData['error'] ?? 'Failed to send summons: ${response.statusCode}';
      debugPrint('❌ HTTP ${response.statusCode}: $_error');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error sending counseling summons: $e';
    debugPrint('❌ Exception: $_error');
    notifyListeners();
    return false;
  }
}

// Record violation
Future<bool> recordViolation(Map<String, dynamic> violationData) async {
  if (_token == null) {
    _error = 'Authentication token not found';
    return false;
  }

  try {
    debugPrint('⚠️ Recording violation for student #${violationData['student_id']}');
    
    // ✅ FIX: Use the correct URL that matches your urls.py
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/record-violation/'), // ✅ Changed from /api/violations/record/
      headers: _headers,
      body: jsonEncode(violationData),
    );

    debugPrint('⚠️ Record violation response: ${response.statusCode}');
    debugPrint('⚠️ Response body: ${response.body}');

    final contentType = response.headers['content-type'] ?? '';
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      // ✅ Only try to decode JSON if response is actually JSON
      if (contentType.contains('application/json') && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Violation recorded successfully');
          
          // If there's a related report, update its status
          if (violationData['related_report_id'] != null) {
            final reportId = violationData['related_report_id'];
            final reportType = violationData['report_type'] ?? 'student_report';
            
            // Update report status to 'resolved'
            await updateReportStatus(
              reportId,
              'resolved',
              reportType: reportType,
            );
          }
          
          // Refresh all relevant data
          await Future.wait([
            fetchStudentViolations(forceRefresh: true),
            fetchCounselorStudentReports(forceRefresh: true),
            if (violationData['report_type'] == 'teacher_report')
              fetchTeacherReports(),
            fetchStudentsList(schoolYear: _selectedSchoolYear),
          ]);
          
          _error = null;
          notifyListeners();
          return true;
        } else {
          _error = data['error'] ?? 'Failed to record violation';
          debugPrint('❌ Backend error: $_error');
          notifyListeners();
          return false;
        }
      } else {
        // Assume success if non-JSON 200/201 response
        debugPrint('✅ Violation recorded successfully (non-JSON response)');
        _error = null;
        notifyListeners();
        return true;
      }
    } else if (response.statusCode == 404) {
      _error = 'Endpoint not found. Check if /api/record-violation/ exists in backend';
      debugPrint('❌ 404 Error: $_error');
      notifyListeners();
      return false;
    } else {
      // ✅ Handle non-JSON error responses (like HTML error pages)
      if (contentType.contains('application/json')) {
        try {
          final data = jsonDecode(response.body);
          _error = data['error'] ?? 'HTTP ${response.statusCode}: ${response.reasonPhrase}';
        } catch (e) {
          _error = 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Error'}';
        }
      } else {
        _error = 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Error'} (Non-JSON response)';
      }
      debugPrint('❌ Error: $_error');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error recording violation: $e';
    debugPrint('❌ Exception: $_error');
    notifyListeners();
    return false;
  }
}

  // Clear all data
  void clearData() {
    _token = null;
    _counselorProfile = null;
    _studentReports.clear();
    _teacherReports.clear();
    _notifications.clear();
    _counselorStudentReports.clear();
    _studentsList.clear();
    _studentViolations.clear();
    _violationTypes.clear();
    _counselingSessions.clear();
    _isLoading = false;
    _isLoadingStudentsList = false;
    _isLoadingStudentViolations = false;
    _isLoadingCounselorStudentReports = false;
    _isLoadingCounselingSessions = false;
    _error = null;
    _systemSchoolYear = null;
    _isSystemActive = true;
    _systemMessage = null;
    _lastFetchTime = null;
    notifyListeners();
  }

  // Dispose HTTP client
  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
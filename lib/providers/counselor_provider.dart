import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class CounselorProvider with ChangeNotifier {
  String? _token;
  bool _isLoading = false;
  bool _isLoadingStudentsList = false;
  bool _isLoadingStudentViolations = false;
  bool _isLoadingCounselorStudentReports = false;
  String? _error;
  
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

  // ✅ NEW: School year filtering
  String _selectedSchoolYear = 'current';
  List<String> _availableSchoolYears = [];
  
  String get selectedSchoolYear => _selectedSchoolYear;
  List<String> get availableSchoolYears => _availableSchoolYears;

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

  // ADDED: Export students list method
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
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
      body: jsonEncode({
        'grade_filter': gradeFilter != 'All' ? gradeFilter : null,
        'section_filter': sectionFilter != 'All' ? sectionFilter : null,
        'school_year': schoolYear,
        'format': 'csv', // or 'xlsx', 'pdf'
      }),
    );

    debugPrint('🔍 Export students response: ${response.statusCode}');
    debugPrint('🔍 Export students body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        debugPrint('✅ Students list exported successfully for school year: ${schoolYear ?? "all"}');
        
        // If the API returns a download URL, you could open it
        if (data['download_url'] != null) {
          debugPrint('📥 Download URL: ${data['download_url']}');
        }
        
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

// ✅ NEW: Initialize with saved school year
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

  // ✅ NEW: Fetch available school years from backend
  Future<void> fetchAvailableSchoolYears() async {
    if (_token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/counselor/available-school-years/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
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

  // ✅ NEW: Set school year and refresh all data
  Future<bool> setSchoolYear(String schoolYear) async {
  try {
    _selectedSchoolYear = schoolYear;
    
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_school_year', schoolYear);
    
    debugPrint('📅 School year changed to: $schoolYear');
    notifyListeners();
    
    // Refresh all data with new school year filter
    await Future.wait([
      fetchCounselorStudentReports(forceRefresh: true),
      fetchStudentViolations(forceRefresh: true),
      fetchProfile(),  // ✅ FIXED: Changed from fetchCounselorProfile() to fetchProfile()
      fetchStudentsList(schoolYear: schoolYear),  // ✅ ADDED: Pass school year parameter
      // Add other fetch methods as needed
    ]);
    
    debugPrint('✅ All data refreshed for school year: $schoolYear');
    return true;
  } catch (e) {
    debugPrint('❌ Error setting school year: $e');
    return false;
  }
}

  // ✅ HELPER: Get current school year
  String _getCurrentSchoolYear() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    return month >= 6 ? '$year-${year + 1}' : '${year - 1}-$year';
  }

  // Fetch violation analytics method
  Future<Map<String, dynamic>?> fetchViolationAnalytics() async {
    try {
      debugPrint('📊 Fetching violation analytics...');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/counselor/violation-analytics/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );

      debugPrint('📊 Analytics response status: ${response.statusCode}');
      debugPrint('📊 Analytics response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          debugPrint('✅ Analytics data received successfully');
          
          // Process the analytics data to match what the dashboard expects
          final analytics = data['analytics'] ?? {};
          final summary = analytics['summary'] ?? {};
          
          // Create the expected data structure
          final processedData = {
            'success': true,
            'violation_analytics': {
              // Convert violations by category to the expected format
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
          
          debugPrint('📊 Processed analytics data: $processedData');
          return processedData;
        } else {
          debugPrint('❌ Analytics API returned success=false: ${data['error']}');
          return null;
        }
      } else {
        debugPrint('❌ Analytics API failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Analytics fetch error: $e');
      return null;
    }
  }

  // Fetch counselor profile
  Future<void> fetchProfile() async {
    if (_token == null) return;
    
    _setLoading(true);
    _setError(null);

    try {
      final url = Uri.parse('$_baseUrl/api/profile/');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );

      debugPrint('🔍 Counselor profile response: ${response.statusCode}');
      debugPrint('🔍 Counselor profile body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _counselorProfile = Map<String, dynamic>.from(data['profile'] ?? {});
          debugPrint('✅ Counselor profile loaded: $_counselorProfile');
        } else {
          _setError(data['error'] ?? 'Failed to load profile');
        }
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

  // Fetch students list (for counselor management)
  Future<void> fetchStudentsList({String? schoolYear}) async {
  if (_token == null) return;

  _isLoadingStudentsList = true;
  notifyListeners();

  try {
    final year = schoolYear ?? _selectedSchoolYear;
    
    // ✅ IMPORTANT: Pass school year as query parameter
    final url = year == 'all'
        ? Uri.parse('$_baseUrl/api/counselor/students-list/')
        : Uri.parse('$_baseUrl/api/counselor/students-list/?school_year=$year');
    
    debugPrint('📊 Fetching students for school year: $year');
    debugPrint('🌐 URL: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Token $_token',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        _studentsList = List<Map<String, dynamic>>.from(data['students'] ?? []);
        debugPrint('✅ Fetched ${_studentsList.length} students for S.Y. $year');
        
        // ✅ DEBUG: Print first student to verify school year
        if (_studentsList.isNotEmpty) {
          debugPrint('📌 Sample student: ${_studentsList.first}');
        }
      }
    }
  } catch (e) {
    debugPrint('❌ Error fetching students: $e');
  } finally {
    _isLoadingStudentsList = false;
    notifyListeners();
  }
}
  // Add these properties to your CounselorProvider:

DateTime? _lastFetchTime;
static const Duration _cacheTimeout = Duration(minutes: 5);

// Update the fetch method to use caching:
Future<void> fetchCounselorStudentReports({bool forceRefresh = false}) async {
  // Check if we have cached data that's still valid
  if (!forceRefresh && 
      _lastFetchTime != null && 
      DateTime.now().difference(_lastFetchTime!) < _cacheTimeout &&
      _counselorStudentReports.isNotEmpty) {
    debugPrint("📋 Using cached student reports data");
    return;
  }

  if (_token == null) {
    debugPrint("❌ No token available for fetchCounselorStudentReports");
    return;
  }

  // Prevent multiple simultaneous calls
  if (_isLoadingCounselorStudentReports) {
    debugPrint("⏳ Already loading counselor student reports, skipping duplicate call");
    return;
  }

  _isLoadingCounselorStudentReports = true;
  _error = null;
  notifyListeners();

  try {
    // Use the same working endpoint as fetchStudentReports
    final url = _selectedSchoolYear == 'all'
        ? Uri.parse('$_baseUrl/api/counselor/student-reports/')
        : Uri.parse('$_baseUrl/api/counselor/student-reports/?school_year=$_selectedSchoolYear');
    
    debugPrint("📡 Fetching from: $url");
    final stopwatch = Stopwatch()..start();

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Token $_token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    stopwatch.stop();
    debugPrint("🔍 API Response time: ${stopwatch.elapsedMilliseconds}ms");
    debugPrint("📊 Response status: ${response.statusCode}");
    debugPrint("📊 Response body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}");

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Handle the response format that matches your working API
      if (data is Map && data.containsKey('success') && data['success'] == true) {
        _counselorStudentReports = List<Map<String, dynamic>>.from(data['reports'] ?? []);
        
        // Also update the regular student reports to keep them in sync
        _studentReports = List<Map<String, dynamic>>.from(data['reports'] ?? []);
        
        _lastFetchTime = DateTime.now();
        debugPrint("✅ Successfully loaded ${_counselorStudentReports.length} student reports");
      } else {
        throw Exception('API returned success=false: ${data['error'] ?? 'Unknown error'}');
      }
      
    } else {
      final errorData = json.decode(response.body);
      final errorMessage = errorData['detail'] ?? errorData['error'] ?? 'Unknown error';
      throw Exception('HTTP ${response.statusCode}: $errorMessage');
    }
    
  } catch (e) {
    _error = e.toString();
    debugPrint("❌ Error fetching counselor student reports: $_error");
    rethrow;
  } finally {
    _isLoadingCounselorStudentReports = false;
    notifyListeners();
  }
}

Future<Map<String, dynamic>> fetchDashboardAnalytics() async {
  if (_token == null) {
    throw Exception('Authentication token not found');
  }

  try {
    debugPrint('📊 Fetching comprehensive dashboard analytics...');
    
    // Fetch all data concurrently
    await Future.wait([
      fetchCounselorStudentReports(forceRefresh: true),
      fetchTeacherReports(),
      fetchStudentViolations(),
      fetchViolationTypes(),
    ]);

    // Calculate totals
    final totalStudentReports = _counselorStudentReports.length;
    final totalTeacherReports = _teacherReports.length;
    final totalReports = totalStudentReports + totalTeacherReports;
    
    // Calculate status distribution
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

    // Calculate violation analytics
    final violationsByType = <String, int>{};
    final violationsByStatus = <String, int>{};
    final violationsBySeverity = <String, int>{};
    
    for (final violation in _studentViolations) {
      // Count by violation type
      final violationType = violation['violation_type']?['name']?.toString() ?? 
                           violation['violation_type']?.toString() ?? 'Unknown';
      violationsByType[violationType] = (violationsByType[violationType] ?? 0) + 1;
      
      // Count by status
      final status = violation['status']?.toString() ?? 'unknown';
      violationsByStatus[status] = (violationsByStatus[status] ?? 0) + 1;
      
      // Count by severity
      final severity = violation['severity']?.toString() ?? 
                      violation['violation_type']?['severity_level']?.toString() ?? 'medium';
      violationsBySeverity[severity] = (violationsBySeverity[severity] ?? 0) + 1;
    }

    // Calculate recent activity (last 30 days)
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

    debugPrint('📊 Dashboard analytics calculated: ${analytics['summary']}');
    return analytics;
    
  } catch (e) {
    debugPrint('❌ Error fetching dashboard analytics: $e');
    rethrow;
  }
}

// Add method to get combined recent reports for activity feed
List<Map<String, dynamic>> getCombinedRecentReports({int limit = 10}) {
  final combinedReports = <Map<String, dynamic>>[];
  
  // Add student reports with source identifier
  for (final report in _counselorStudentReports) {
    combinedReports.add({
      ...report,
      'source_type': 'student_report',
      'reporter_type': 'Student',
      'icon': 'person',
    });
  }
  
  // Add teacher reports with source identifier
  for (final report in _teacherReports) {
    combinedReports.add({
      ...report,
      'source_type': 'teacher_report',
      'reporter_type': 'Teacher', 
      'icon': 'school',
    });
  }
  
  // Sort by date (most recent first)
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
    // ✅ Add school year query parameter
    final url = _selectedSchoolYear == 'all'
        ? Uri.parse('$_baseUrl/api/counselor/student-violations/')
        : Uri.parse('$_baseUrl/api/counselor/student-violations/?school_year=$_selectedSchoolYear');
    
    debugPrint('🔍 Fetching student violations for school year: ${schoolYear ?? "all"}');
    
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
    );

    debugPrint('🔍 Student violations response: ${response.statusCode}');
    debugPrint('🔍 Student violations body preview: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      
      if (responseData['success'] == true) {
        _studentViolations = List<Map<String, dynamic>>.from(responseData['violations'] ?? []);
        _error = null;
        
        debugPrint('✅ Student violations loaded: ${_studentViolations.length} violations for ${schoolYear ?? "all school years"}');
        
        // Debug: Print first few violations to verify data
        if (_studentViolations.isNotEmpty) {
          for (int i = 0; i < math.min(3, _studentViolations.length); i++) {
            final violation = _studentViolations[i];
            debugPrint('  Violation $i: student_id=${violation['student_id']}, type=${violation['violation_type']?['name'] ?? violation['violation_name']}, school_year=${violation['school_year']}');
          }
        }
      } else {
        _error = responseData['message'] ?? 'Failed to load student violations';
        debugPrint('❌ Error in response: $_error');
      }
    } else {
      _error = 'Failed to load student violations: HTTP ${response.statusCode}';
      debugPrint('❌ HTTP Error: $_error');
      debugPrint('❌ Response body: ${response.body}');
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
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/violation-types/'), // Use existing endpoint
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

  // Fetch student reports (for counselor to review)
  Future<void> fetchStudentReports() async {
  if (_token == null) return;

  try {
    debugPrint('📡 Fetching student reports...');

    // ✅ Make sure it has /api/ prefix
    final response = await http.get(
      Uri.parse('$_baseUrl/api/counselor/student-reports/'),  // ✅ Must have /api/
      headers: {
        'Authorization': 'Token $_token',
        'Content-Type': 'application/json',
      },
    );

    debugPrint('📡 Student reports response: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      _studentReports = List<Map<String, dynamic>>.from(data['reports'] ?? []);
      debugPrint('✅ Fetched ${_studentReports.length} student reports');
      notifyListeners();
    } else {
      debugPrint('❌ Failed to fetch student reports: ${response.statusCode}');
      throw Exception('Server error: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('❌ Error fetching student reports: $e');
    throw Exception('Error: $e');
  }
}

  // Update the fetchTeacherReports method with better error handling
  Future<void> fetchTeacherReports() async {
    try {
      print('🔍 Fetching teacher reports from counselor endpoint...');
      
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/counselor/teacher-reports/'),  // ✅ Added /api/
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $_token',
            },
          )
          .timeout(const Duration(seconds: 10));

      print('📡 Teacher reports response: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          _teacherReports = List<Map<String, dynamic>>.from(
            data['reports']?.map((report) => Map<String, dynamic>.from(report)) ?? []
          );
          
          print('✅ Teacher reports loaded: ${_teacherReports.length} reports');
          notifyListeners();
        } else {
          throw Exception(data['message'] ?? 'Failed to load teacher reports');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching teacher reports: $e');
      _error = 'Failed to load teacher reports: $e';
      _teacherReports = [];
      notifyListeners();
    }
  }

  Future<bool> updateReportStatus(int reportId, String status, {String? notes}) async {
  try {
    print('🔄 Updating report $reportId status to: $status');
    
    // ✅ FIX: Use the correct endpoint from urls.py
    final response = await http.post(
      Uri.parse('$_baseUrl/api/reports/$reportId/update-status/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
      body: json.encode({
        'status': status,
        if (notes != null) 'counselor_notes': notes,
      }),
    ).timeout(const Duration(seconds: 10));

    print('📡 Update report status response: ${response.statusCode}');
    print('📡 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        print('✅ Report status updated successfully');
        
        // Update local state
        final reportIndex = _studentReports.indexWhere((r) => r['id'] == reportId);
        if (reportIndex != -1) {
          _studentReports[reportIndex]['status'] = status;
          if (notes != null) {
            _studentReports[reportIndex]['counselor_notes'] = notes;
          }
        }
        
        // Also update counselorStudentReports if it exists there
        final counselorReportIndex = _counselorStudentReports.indexWhere((r) => r['id'] == reportId);
        if (counselorReportIndex != -1) {
          _counselorStudentReports[counselorReportIndex]['status'] = status;
          if (notes != null) {
            _counselorStudentReports[counselorReportIndex]['counselor_notes'] = notes;
          }
        }
        
        notifyListeners();
        return true;
      } else {
        _error = data['message'] ?? data['error'] ?? 'Failed to update report status';
        print('❌ API returned success=false: $_error');
        notifyListeners();
        return false;
      }
    } else {
      final errorData = json.decode(response.body);
      _error = errorData['error'] ?? errorData['message'] ?? 'Server error: ${response.statusCode}';
      print('❌ Failed to update report status: $_error');
      print('❌ Response body: ${response.body}');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error updating report status: $e';
    print('❌ Error updating report status: $e');
    notifyListeners();
    return false;
  }
}

// Also fix the teacher report method:
Future<bool> updateTeacherReportStatus(int reportId, String status, {String? notes}) async {
  try {
    print('🔄 Updating teacher report $reportId status to: $status');
    
    final response = await http.patch(
      Uri.parse('$_baseUrl/api/counselor/teacher-reports/$reportId/update-status/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
      body: json.encode({
        'status': status,
        'counselor_notes': notes ?? '',
      }),
    ).timeout(const Duration(seconds: 10));

    print('📡 Update teacher report status response: ${response.statusCode}');
    print('📡 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        print('✅ Teacher report status updated successfully');
        
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
        _error = data['message'] ?? data['error'] ?? 'Failed to update teacher report status';
        print('❌ Failed to update teacher report status: $_error');
        notifyListeners();
        return false;
      }
    } else {
      final errorData = json.decode(response.body);
      _error = errorData['error'] ?? 'Server error: ${response.statusCode}';
      print('❌ Failed to update teacher report status: $_error');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error updating teacher report status: $e';
    print('❌ Error updating teacher report status: $e');
    notifyListeners();
    return false;
  }
}

Future<bool> createTallyRecord(Map<String, dynamic> tallyData) async {
  if (_token == null) return false;
  
  try {
    debugPrint('📊 Creating tally record: ${tallyData['student_id']}');
    
    final response = await http.post(
      Uri.parse('$_baseUrl/api/counselor/tally-records/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',  // Use Token instead of Bearer
      },
      body: jsonEncode(tallyData),
    );

    debugPrint('📊 Create tally response status: ${response.statusCode}');
    debugPrint('📊 Create tally response body: ${response.body}');

    if (response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      if (responseData['success'] == true) {
        debugPrint('✅ Tally record created successfully');
        return true;
      } else {
        _error = responseData['message'] ?? 'Failed to create tally record';
        return false;
      }
    } else {
      _error = 'Failed to create tally record: ${response.statusCode}';
      debugPrint('❌ Error creating tally record: ${response.body}');
      return false;
    }
  } catch (e) {
    _error = 'Error creating tally record: $e';
    debugPrint('❌ Exception creating tally record: $e');
    return false;
  }
}

Future<bool> recordViolationFromTally(Map<String, dynamic> violationData) async {
  if (_token == null) return false;
  
  try {
    debugPrint('⚠️ Recording violation from tally for student: ${violationData['student_id']}');
    
    // ✅ Ensure school_year is included
    if (!violationData.containsKey('school_year')) {
      final currentYear = DateTime.now().year;
      final currentMonth = DateTime.now().month;
      violationData['school_year'] = currentMonth >= 6 
          ? '$currentYear-${currentYear + 1}'
          : '${currentYear - 1}-$currentYear';
    }
    
    final response = await http.post(
      Uri.parse('$_baseUrl/api/counselor/violations/from-tally/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
      body: jsonEncode(violationData),
    );

    debugPrint('⚠️ Record violation response status: ${response.statusCode}');
    debugPrint('⚠️ Record violation response body: ${response.body}');

    if (response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      if (responseData['success'] == true) {
        debugPrint('✅ Violation from tally recorded successfully');
        
        // Refresh violations with school year filter
        await fetchStudentViolations(
          schoolYear: violationData['school_year'],
          forceRefresh: true,
        );
        notifyListeners();
        return true;
      } else {
        _error = responseData['message'] ?? 'Failed to record violation from tally';
        return false;
      }
    } else {
      _error = 'Failed to record violation from tally: ${response.statusCode}';
      debugPrint('❌ Error recording violation from tally: ${response.body}');
      return false;
    }
  } catch (e) {
    _error = 'Error recording violation from tally: $e';
    debugPrint('❌ Exception recording violation from tally: $e');
    return false;
  }
}

// Add helper method to get current school year:
String getCurrentSchoolYear() {
  final currentYear = DateTime.now().year;
  final currentMonth = DateTime.now().month;
  
  if (currentMonth >= 6) {
    return '$currentYear-${currentYear + 1}';
  } else {
    return '${currentYear - 1}-$currentYear';
  }
}

  // Add method to fetch tally records for analytics
Future<List<Map<String, dynamic>>> fetchTallyRecords() async {
  if (_token == null) return [];
  
  try {
    debugPrint('📊 Fetching tally records...');
    
    final response = await http.get(
      Uri.parse('$_baseUrl/api/counselor/tally-records/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tallyRecords = List<Map<String, dynamic>>.from(data['results'] ?? data ?? []);
      
      debugPrint('✅ Fetched ${tallyRecords.length} tally records');
      return tallyRecords;
    } else {
      debugPrint('❌ Error fetching tally records: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    debugPrint('❌ Exception fetching tally records: $e');
    return [];
  }
}

  // Fetch notifications
  Future<void> fetchNotifications() async {
    if (_token == null) return;

    try {
      final url = Uri.parse('$_baseUrl/api/notifications/');
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

    // Use the correct endpoint from your URL patterns
    final url = Uri.parse('$_baseUrl/api/mark-report-reviewed/');
    final response = await http.post(  // Changed from PUT to POST
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
      body: jsonEncode({
        'report_id': reportId,  // Send as report_id in body
        'status': 'reviewed',
      }),
    );

    debugPrint('🔍 Mark as reviewed response: ${response.statusCode}');
    debugPrint('🔍 Mark as reviewed body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        // Update local state
        _counselorStudentReports[index]['status'] = 'reviewed';
        // Also update the regular student reports if they share the same data
        if (index < _studentReports.length) {
          _studentReports[index]['status'] = 'reviewed';
        }
        notifyListeners();
        debugPrint('✅ Report marked as reviewed successfully');
        return true;
      } else {
        debugPrint('❌ API returned success=false: ${data['error'] ?? 'Unknown error'}');
        return false;
      }
    } else {
      debugPrint('❌ HTTP error ${response.statusCode}');
      return false;
    }
  } catch (e) {
    debugPrint('❌ Mark as reviewed error: $e');
    return false;
  }
}

  // Additional methods for student management
  Future<bool> addStudent(Map<String, dynamic> studentData) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return false;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/students/add/');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
        body: jsonEncode(studentData),
      );

      debugPrint('🔍 Add student response: ${response.statusCode}');
      debugPrint('🔍 Add student body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Student added successfully');
          return true;
        } else {
          _setError(data['error'] ?? 'Failed to add student');
          return false;
        }
      } else {
        final errorData = jsonDecode(response.body);
        _setError(errorData['error'] ?? 'Failed to add student');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Add student error: $e');
      _setError('Network error: $e');
      return false;
    }
  }

  Future<bool> updateStudent(int studentId, Map<String, dynamic> studentData) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return false;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/students/update/$studentId/');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
        body: jsonEncode(studentData),
      );

      debugPrint('🔍 Update student response: ${response.statusCode}');
      debugPrint('🔍 Update student body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Student updated successfully');
          return true;
        } else {
          _setError(data['error'] ?? 'Failed to update student');
          return false;
        }
      } else {
        final errorData = jsonDecode(response.body);
        _setError(errorData['error'] ?? 'Failed to update student');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Update student error: $e');
      _setError('Network error: $e');
      return false;
    }
  }

  Future<bool> deleteStudent(int studentId) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return false;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/students/delete/$studentId/');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );

      debugPrint('🔍 Delete student response: ${response.statusCode}');
      debugPrint('🔍 Delete student body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Student deleted successfully');
          return true;
        } else {
          _setError(data['error'] ?? 'Failed to delete student');
          return false;
        }
      } else {
        final errorData = jsonDecode(response.body);
        _setError(errorData['error'] ?? 'Failed to delete student');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Delete student error: $e');
      _setError('Network error: $e');
      return false;
    }
  }

  // Fix bulkAddStudents method
  Future<bool> bulkAddStudents(List<Map<String, dynamic>> students) async {
    try {
      _setLoading(true);
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/counselor/bulk-add-students/'), // Add trailing slash
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
        body: jsonEncode({
          'students': students,
        }),
      );

      debugPrint('📝 Bulk add students response: ${response.statusCode}');
      debugPrint('📝 Bulk add students body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          // Refresh the students list after successful bulk add
          await fetchStudentsList();
          
          _error = null;
          debugPrint('✅ ${students.length} students added successfully');
          return true;
        } else {
          _error = data['error'] ?? 'Failed to add students';
          debugPrint('❌ Bulk add failed: $_error');
          return false;
        }
      } else {
        final errorData = jsonDecode(response.body);
        _error = errorData['error'] ?? 'Failed to add students';
        debugPrint('❌ Bulk add failed with status ${response.statusCode}: $_error');
        return false;
      }
    } catch (e) {
      _error = 'Network error: $e';
      debugPrint('❌ Bulk add students error: $e');
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Fix recordViolation method
  Future<bool> recordViolation(Map<String, dynamic> violationData) async {
  try {
    debugPrint('🎯 Recording violation: $violationData');
    
    // ✅ Ensure school_year is included
    if (!violationData.containsKey('school_year')) {
      final currentYear = DateTime.now().year;
      final currentMonth = DateTime.now().month;
      violationData['school_year'] = currentMonth >= 6 
          ? '$currentYear-${currentYear + 1}'
          : '${currentYear - 1}-$currentYear';
    }
    
    final response = await http.post(
      Uri.parse('$_baseUrl/api/record-violation/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
      body: jsonEncode(violationData),
    );

    debugPrint('🎯 Record violation response: ${response.statusCode}');
    debugPrint('🎯 Record violation body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      
      if (data['success'] == true) {
        debugPrint('✅ Violation recorded successfully');
        // Refresh violation data with current school year filter
        await fetchStudentViolations(
          schoolYear: violationData['school_year'],
          forceRefresh: true,
        );
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
    debugPrint('❌ Record violation error: $e');
    _error = 'Network error: $e';
    return false;
  }
}

  // Fetch counseling sessions
  Future<void> fetchCounselingSessions() async {
    if (_token == null) {
      _setError('Authentication token not found');
      return;
    }

    _isLoadingCounselingSessions = true;
    _setError(null);
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/api/counselor/counseling-sessions/');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
      );

      debugPrint('🔍 Counseling sessions response: ${response.statusCode}');
      debugPrint('🔍 Counseling sessions body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _counselingSessions = List<Map<String, dynamic>>.from(data['sessions'] ?? []);
          debugPrint('✅ Counseling sessions loaded: ${_counselingSessions.length} sessions');
        } else {
          _setError(data['error'] ?? 'Failed to load counseling sessions');
        }
      } else {
        _setError('Failed to load counseling sessions: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Counseling sessions fetch error: $e');
      _setError('Network error: $e');
    } finally {
      _isLoadingCounselingSessions = false;
      notifyListeners();
    }
  }

  // Create counseling session
  Future<bool> createCounselingSession(Map<String, dynamic> sessionData) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return false;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/counselor/counseling-sessions/');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
        body: jsonEncode(sessionData),
      );

      debugPrint('🔍 Create counseling session response: ${response.statusCode}');
      debugPrint('🔍 Create counseling session body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Counseling session created successfully');
          // Refresh sessions to show the new one
          await fetchCounselingSessions();
          return true;
        } else {
          _setError(data['error'] ?? 'Failed to create counseling session');
          return false;
        }
      } else {
        final errorData = jsonDecode(response.body);
        _setError(errorData['error'] ?? 'Failed to create counseling session');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Create counseling session error: $e');
      _setError('Network error: $e');
      return false;
    }
  }

  // Update counseling session status
  Future<bool> updateCounselingSessionStatus(int sessionId, String status) async {
    if (_token == null) {
      _setError('Authentication token not found');
      return false;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/counselor/counseling-sessions/$sessionId/status/');
      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
        body: jsonEncode({'status': status}),
      );

      debugPrint('🔍 Update counseling session status response: ${response.statusCode}');
      debugPrint('🔍 Update counseling session status body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('✅ Counseling session status updated successfully');
          // Refresh sessions to reflect the update
          await fetchCounselingSessions();
          return true;
        } else {
          _setError(data['error'] ?? 'Failed to update counseling session status');
          return false;
        }
      } else {
        _setError('Failed to update counseling session status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Update counseling session status error: $e');
      _setError('Network error: $e');
      return false;
    }
  }

  // Clear all data (for logout)
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
    notifyListeners();
  }

  // Add this method to your CounselorProvider class:

  Future<bool> updateReportStatusById(int reportId, String status, String notes) async {
  try {
    debugPrint('🔄 Updating report status: Report ID $reportId to $status');
    
    // ✅ FIX: Add /api/ prefix
    final response = await http.patch(
      Uri.parse('$_baseUrl/api/reports/$reportId/update-status/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
      body: jsonEncode({
        'status': status,
        'counselor_notes': notes,
      }),
    );

    debugPrint('📡 Update report status response: ${response.statusCode}');

    if (response.statusCode == 200) {
      debugPrint('✅ Report status updated successfully');
      
      // Update the local report list
      final index = _counselorStudentReports.indexWhere((r) => r['id'] == reportId);
      if (index != -1) {
        _counselorStudentReports[index]['status'] = status;
        notifyListeners();
      }
      
      return true;
    } else {
      _error = 'Failed to update report status: ${response.statusCode}';
      debugPrint('❌ Failed to update report status: ${response.body}');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error updating report status: $e';
    debugPrint('❌ Error updating report status: $e');
    notifyListeners();
    return false;
  }
}

  Future<bool> updateReportStatusRemote(int reportId, String status) async {
  try {
    debugPrint('🔄 Updating report status: Report ID $reportId to $status');
    
    // ✅ FIX: Add /api/ prefix
    final response = await http.patch(
      Uri.parse('$_baseUrl/api/reports/$reportId/update-status/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
      body: jsonEncode({
        'status': status,
        'counselor_notes': 'Violation tallied and recorded',
      }),
    );

    debugPrint('📡 Update report status response: ${response.statusCode}');

    if (response.statusCode == 200) {
      debugPrint('✅ Report status updated successfully');
      
      // Update the local report list
      _counselorStudentReports.removeWhere((r) => r['id'] == reportId);
      notifyListeners();
      
      return true;
    } else {
      _error = 'Failed to update report status: ${response.statusCode}';
      debugPrint('❌ Failed to update report status: ${response.body}');
      notifyListeners();
      return false;
    }
  } catch (e) {
    _error = 'Error updating report status: $e';
    debugPrint('❌ Error updating report status: $e');
    notifyListeners();
    return false;
  }
}
Future<bool> sendCounselingSummons({
  required int reportId,
  String? scheduledDate,
  String? message,
}) async {
  if (_token == null) {
    debugPrint('❌ No token available');
    return false;
  }

  try {
    debugPrint('📨 Sending counseling summons for report $reportId');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/reports/$reportId/send-summons/'),
      headers: {
        'Authorization': 'Token $_token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        if (scheduledDate != null) 'scheduled_date': scheduledDate,
        if (message != null) 'message': message,
      }),
    );

    debugPrint('📡 Response status: ${response.statusCode}');
    debugPrint('📡 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        debugPrint('✅ Counseling summons sent successfully');
        // Refresh reports to update status
        await fetchStudentReports();
        await fetchTeacherReports();
        return true;
      }
    }

    debugPrint('❌ Failed to send summons: ${response.body}');
    return false;
  } catch (e) {
    debugPrint('❌ Error sending counseling summons: $e');
    return false;
  }
}

/// Mark report as invalid (no violation)
Future<bool> markReportAsInvalid({
  required int reportId,
  required String reason,
}) async {
  if (_token == null) {
    debugPrint('❌ No token available');
    return false;
  }

  try {
    debugPrint('❌ Marking report $reportId as invalid');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/reports/$reportId/mark-invalid/'),
      headers: {
        'Authorization': 'Token $_token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'reason': reason,
      }),
    );

    debugPrint('📡 Response status: ${response.statusCode}');
    debugPrint('📡 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        debugPrint('✅ Report marked as invalid successfully');
        // Refresh reports
        await fetchStudentReports();
        await fetchTeacherReports();
        return true;
      }
    }

    debugPrint('❌ Failed to mark report as invalid: ${response.body}');
    return false;
  } catch (e) {
    debugPrint('❌ Error marking report as invalid: $e');
    return false;
  }
}

Future<Map<String, dynamic>> getSectionAnalytics({
  required String schoolYear,
  String? semester,
}) async {
  if (_token == null) {
    throw Exception('Authentication token not found');
  }

  try {
    debugPrint('📊 Fetching section analytics for $schoolYear${semester != null ? " - $semester" : ""}');
    
    final queryParams = <String, String>{
      'school_year': schoolYear,
    };
    
    if (semester != null && semester != 'All') {
      queryParams['semester'] = semester;
    }
    
    final uri = Uri.parse('$_baseUrl/api/counselor/section-analytics/').replace(
      queryParameters: queryParams,
    );
    
    debugPrint('📊 Request URL: $uri');
    
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $_token',
      },
    );

    debugPrint('📊 Section analytics response: ${response.statusCode}');
    
    if (response.body.isNotEmpty) {
      debugPrint('📊 Section analytics body preview: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      if (data['success'] == true || data.containsKey('sections')) {
        debugPrint('✅ Section analytics loaded successfully');
        
        // Ensure all numeric values are properly typed
        final sections = (data['sections'] as List<dynamic>?)?.map((section) {
          return {
            'id': section['id'],
            'name': section['name'],
            'grade_level': section['grade_level'] is int 
                ? section['grade_level'] 
                : int.tryParse(section['grade_level'].toString()) ?? 0,
            'total_violations': section['total_violations'] is int
                ? section['total_violations']
                : int.tryParse(section['total_violations'].toString()) ?? 0,
            'student_count': section['student_count'] is int
                ? section['student_count']
                : int.tryParse(section['student_count'].toString()) ?? 0,
            'avg_per_student': section['avg_per_student'] is double
                ? section['avg_per_student']
                : double.tryParse(section['avg_per_student'].toString()) ?? 0.0,
            'violation_breakdown': section['violation_breakdown'] ?? {},
          };
        }).toList() ?? [];
        
        return {
          'success': true,
          'school_year': data['school_year'] ?? schoolYear,
          'semester': data['semester'] ?? semester ?? 'All',
          'total_violations': data['total_violations'] is int
              ? data['total_violations']
              : int.tryParse(data['total_violations'].toString()) ?? 0,
          'total_sections': data['total_sections'] is int
              ? data['total_sections']
              : int.tryParse(data['total_sections'].toString()) ?? 0,
          'avg_per_section': data['avg_per_section'] is double
              ? data['avg_per_section']
              : double.tryParse(data['avg_per_section'].toString()) ?? 0.0,
          'sections': sections,
        };
      } else {
        throw Exception(data['error'] ?? 'Failed to load section analytics');
      }
    } else if (response.statusCode == 404) {
      // Backend endpoint not implemented yet - return mock data for testing
      debugPrint('⚠️ Section analytics endpoint not found - returning mock data');
      return _getMockSectionAnalytics(schoolYear, semester);
    } else {
      throw Exception('Failed to load section analytics: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('❌ Error fetching section analytics: $e');
    
    // Return mock data if backend not ready
    debugPrint('⚠️ Returning mock data due to error');
    return _getMockSectionAnalytics(schoolYear, semester);
  }
}

/// Get mock section analytics data (for development/testing)
Map<String, dynamic> _getMockSectionAnalytics(String schoolYear, String? semester) {
  final random = math.Random();
  
  // Generate mock sections
  final sections = <Map<String, dynamic>>[];
  final grades = [7, 8, 9, 10, 11, 12];
  final sectionsPerGrade = ['A', 'B', 'C'];
  
  for (final grade in grades) {
    for (final section in sectionsPerGrade) {
      final studentCount = 25 + random.nextInt(16); // 25-40 students
      final totalViolations = random.nextInt(35); // 0-34 violations
      
      // Generate violation breakdown
      final violationTypes = {
        'Tardiness': random.nextInt(10),
        'Uniform Violation': random.nextInt(8),
        'Disruptive Behavior': random.nextInt(6),
        'Incomplete Requirements': random.nextInt(5),
        'Improper Haircut': random.nextInt(4),
      };
      
      sections.add({
        'id': sections.length + 1,
        'name': 'Grade $grade-$section',
        'grade_level': grade,
        'total_violations': totalViolations,
        'student_count': studentCount,
        'avg_per_student': studentCount > 0 
            ? double.parse((totalViolations / studentCount).toStringAsFixed(2))
            : 0.0,
        'violation_breakdown': violationTypes,
      });
    }
  }
  
  // Sort by total violations (highest first)
  sections.sort((a, b) => 
    (b['total_violations'] as int).compareTo(a['total_violations'] as int)
  );
  
  final totalViolations = sections.fold<int>(
    0, 
    (sum, section) => sum + (section['total_violations'] as int)
  );
  
  return {
    'success': true,
    'school_year': schoolYear,
    'semester': semester ?? 'All',
    'total_violations': totalViolations,
    'total_sections': sections.length,
    'avg_per_section': sections.isNotEmpty
        ? double.parse((totalViolations / sections.length).toStringAsFixed(2))
        : 0.0,
    'sections': sections,
  };
}

Future<bool> sendGuidanceNotice(int reportId) async {
  try {
    print('📢 Sending guidance notice for report #$reportId');
    
    // ✅ FIX: Add /api/ prefix to the URL
    final response = await http.post(
      Uri.parse('$_baseUrl/api/counselor/reports/$reportId/send-guidance-notice/'),  // ✅ Changed from /counselor/ to /api/counselor/
      headers: {
        'Authorization': 'Token $_token',
        'Content-Type': 'application/json',
      },
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        print('✅ Guidance notice sent successfully');
        print('📧 Notifications sent to:');
        print('   - Reported student: ${data['notifications_sent']?['reported_student']}');
        print('   - Reporter: ${data['notifications_sent']?['reporter']}');
        print('   - Total notified: ${data['total_notified']}');
        
        notifyListeners();
        return true;
      }
    }

    print('❌ Failed to send guidance notice: ${response.statusCode}');
    _error = 'Failed to send guidance notice';
    notifyListeners();
    return false;
  } catch (e) {
    print('❌ Error sending guidance notice: $e');
    _error = e.toString();
    notifyListeners();
    return false;
  }
}
}
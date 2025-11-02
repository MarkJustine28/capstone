import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StudentProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;
  String? _token; // Add token storage

  List<Map<String, dynamic>> get reports => _reports;
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get isLoadingReports => _isLoading; // Added this getter
  String? get error => _error;
  String? get token => _token; // Added this getter

  final String? serverIp = dotenv.env['SERVER_IP'];

  // Add setToken method
  void setToken(String token) {
    _token = token;
    notifyListeners();
  }

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
    // Remove the duplicate :8000 port - serverIp already includes it
    final url = Uri.parse("http://$serverIp/api/student/reports/");
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
        } else {
          debugPrint("❌ Reports field is not a List: ${decoded['reports']}");
          _reports = [];
        }
      } else {
        _error = decoded['error'] ?? 'Failed to fetch reports';
        _reports = [];
      }
    } else {
      try {
        final errorBody = jsonDecode(response.body);
        _error = errorBody['error'] ?? errorBody['detail'] ?? "HTTP ${response.statusCode}";
      } catch (e) {
        _error = "HTTP ${response.statusCode}: ${response.body}";
      }
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
    // Fixed URL - remove duplicate port
    final url = Uri.parse("http://$serverIp/api/student/notifications/");
    debugPrint("🌐 Fetching notifications from: $url");
    
    final response = await http.get(
      url,
      headers: {
        "Authorization": "Token $token",
        "Content-Type": "application/json",
        "Accept": "application/json", // Added for consistency
      },
    ).timeout(const Duration(seconds: 10)); // Added timeout

    debugPrint("📩 Notifications Status Code: ${response.statusCode}");
    debugPrint("📩 Notifications Response: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      
      if (decoded is Map<String, dynamic> && decoded['success'] == true) {
        if (decoded['notifications'] is List) {
          _notifications = List<Map<String, dynamic>>.from(decoded['notifications']);
          debugPrint("✅ Successfully loaded ${_notifications.length} notifications");
        } else {
          debugPrint("❌ Notifications field is not a List: ${decoded['notifications']}");
          _notifications = [];
        }
      } else {
        _error = decoded['error'] ?? 'Failed to fetch notifications';
        _notifications = [];
      }
    } else {
      try {
        final errorBody = jsonDecode(response.body);
        _error = errorBody['error'] ?? errorBody['detail'] ?? "HTTP ${response.statusCode}";
      } catch (e) {
        _error = "HTTP ${response.statusCode}: ${response.body}";
      }
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

// Update the submitReport method:
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
    // Remove the duplicate :8000 port - serverIp already includes it
    final url = Uri.parse("http://$serverIp/api/student/reports/");
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
        
        // Add the new report to the local list if available in response
        if (decoded.containsKey('report')) {
          final newReport = decoded['report'];
          _reports.insert(0, newReport);
        }
        
        // Optionally refresh all reports to get the latest data
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
      } catch (e) {
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

  Future<void> markNotificationAsRead(String token, int notificationId) async {
  if (serverIp == null) return;

  try {
    // Fixed URL - remove duplicate port
    final url = Uri.parse("http://$serverIp/api/notifications/$notificationId/read/");
    
    final response = await http.post(
      url,
      headers: {
        "Authorization": "Token $token",
        "Content-Type": "application/json",
        "Accept": "application/json", // Added for consistency
      },
    ).timeout(const Duration(seconds: 10)); // Added timeout

    if (response.statusCode == 200) {
      // Update the notification locally
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

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearData() {
    _reports = [];
    _notifications = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

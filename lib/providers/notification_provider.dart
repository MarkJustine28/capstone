import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class NotificationProvider with ChangeNotifier {
  // Use the SERVER_IP from .env file
  String get baseUrl => 'http://${dotenv.env['SERVER_IP']}/api';
  
  String? _token;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  // Getters
  List<Map<String, dynamic>> get notifications => _notifications;
  List<Map<String, dynamic>> get unreadNotifications => 
      _notifications.where((n) => !(n['is_read'] ?? false)).toList();
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void setToken(String? token) {
    _token = token;
    if (token != null) {
      fetchNotifications();
    }
  }

  /// Fetch all notifications for current user
  Future<void> fetchNotifications() async {
    if (_token == null) {
      debugPrint('❌ No token available for fetching notifications');
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('🔄 Fetching notifications from: $baseUrl/notifications/');
      debugPrint('🔄 Using token: ${_token?.substring(0, 10)}...');

      final response = await http.get(
        Uri.parse('$baseUrl/notifications/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout - Please check if Django server is running');
        },
      );

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // Handle the Django response structure
        if (responseData['success'] == true) {
          final List<dynamic> notificationsData = responseData['notifications'] ?? [];
          _notifications = notificationsData.map((n) => n as Map<String, dynamic>).toList();
          _unreadCount = responseData['unread_count'] ?? 0;
          
          debugPrint('✅ Notifications fetched: ${_notifications.length}');
          debugPrint('📬 Unread: $_unreadCount');
        } else {
          debugPrint('❌ Response indicates failure: ${responseData['error']}');
        }
      } else {
        debugPrint('❌ Failed to fetch notifications: ${response.statusCode}');
        debugPrint('❌ Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching notifications: $e');
      debugPrint('❌ Base URL: $baseUrl');
      debugPrint('❌ Please ensure Django server is running');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(int notificationId) async {
    if (_token == null) return false;

    try {
      debugPrint('🔄 Marking notification $notificationId as read...');

      final response = await http.patch(
        Uri.parse('$baseUrl/notifications/$notificationId/mark-read/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('📡 Mark as read response: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true) {
          // Update local state
          final index = _notifications.indexWhere((n) => n['id'] == notificationId);
          if (index != -1) {
            _notifications[index]['is_read'] = true;
            _updateUnreadCount();
            notifyListeners();
          }
          
          debugPrint('✅ Notification $notificationId marked as read');
          return true;
        }
      }
      
      debugPrint('❌ Failed to mark notification as read: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    if (_token == null) return false;

    try {
      debugPrint('🔄 Marking all notifications as read...');

      final response = await http.post(
        Uri.parse('$baseUrl/notifications/mark-all-read/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('📡 Mark all as read response: ${response.statusCode}');
      debugPrint('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['success'] == true) {
          // Update all local notifications to read
          for (var notification in _notifications) {
            notification['is_read'] = true;
          }
          _updateUnreadCount();
          notifyListeners();
          
          debugPrint('✅ All notifications marked as read');
          return true;
        }
      }
      
      debugPrint('❌ Failed to mark all as read: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(int notificationId) async {
    if (_token == null) return false;

    try {
      debugPrint('🔄 Deleting notification $notificationId...');

      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('📡 Delete response: ${response.statusCode}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        _notifications.removeWhere((n) => n['id'] == notificationId);
        _updateUnreadCount();
        notifyListeners();
        
        debugPrint('✅ Notification $notificationId deleted');
        return true;
      } else {
        debugPrint('❌ Failed to delete notification: ${response.statusCode}');
        debugPrint('❌ Response: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      return false;
    }
  }

  /// Get notification icon based on type
  IconData getNotificationIcon(String? type) {
    switch (type) {
      case 'report_submitted':
        return Icons.report;
      case 'violation_recorded':
        return Icons.warning;
      case 'session_scheduled':
        return Icons.event;
      case 'report_reviewed':
        return Icons.check_circle;
      case 'message':
        return Icons.message;
      case 'reminder':
        return Icons.alarm;
      default:
        return Icons.notifications;
    }
  }

  /// Get notification color based on type
  Color getNotificationColor(String? type) {
    switch (type) {
      case 'report_submitted':
        return Colors.blue;
      case 'violation_recorded':
        return Colors.red;
      case 'session_scheduled':
        return Colors.purple;
      case 'report_reviewed':
        return Colors.green;
      case 'message':
        return Colors.orange;
      case 'reminder':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  /// Update unread count
  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !(n['is_read'] ?? false)).length;
  }

  /// Format notification time
  String formatNotificationTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown';
    
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateStr;
    }
  }

  /// Clear all notifications
  void clearNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
  }
}
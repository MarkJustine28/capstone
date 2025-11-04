import 'package:flutter/material.dart';
import '../services/api_services.dart';

class NotificationProvider with ChangeNotifier {
  String? _token;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Map<String, dynamic>> get notifications => _notifications;
  List<Map<String, dynamic>> get unreadNotifications => 
      _notifications.where((n) => !(n['is_read'] ?? false)).toList();
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setToken(String? token) {
    _token = token;
    debugPrint('🔐 NotificationProvider token set: ${token != null ? "✅" : "❌"}');
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
      _error = null;
      notifyListeners();

      debugPrint('🔄 Fetching notifications from: ${ApiService.baseUrl}/notifications/');
      debugPrint('🔄 Using token: ${_token!.substring(0, 10)}...');

      // ✅ Use ApiService
      final result = await ApiService.instance.getStudentNotifications(token: _token!);

      if (result['success']) {
        final data = result['data'];
        _notifications = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
        _unreadCount = data['unread_count'] ?? 0;
        _error = null;
        
        debugPrint('✅ Notifications fetched: ${_notifications.length}');
        debugPrint('📬 Unread: $_unreadCount');
      } else {
        _error = result['error'] ?? 'Failed to fetch notifications';
        debugPrint('❌ Error: $_error');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Exception fetching notifications: $e');
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

      // ✅ Use ApiService
      final result = await ApiService.instance.markNotificationAsRead(
        token: _token!,
        notificationId: notificationId,
      );

      if (result['success']) {
        // Update local state
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
          _updateUnreadCount();
          notifyListeners();
        }
        
        debugPrint('✅ Notification $notificationId marked as read');
        return true;
      } else {
        debugPrint('❌ Failed to mark notification as read: ${result['error']}');
        return false;
      }
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

      // ✅ Use ApiService for bulk mark as read
      final result = await ApiService.instance.post(
        endpoint: '/notifications/mark-all-read/',
        token: _token,
        data: {},
      );

      if (result['success']) {
        // Update all local notifications to read
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
        _updateUnreadCount();
        notifyListeners();
        
        debugPrint('✅ All notifications marked as read');
        return true;
      } else {
        debugPrint('❌ Failed to mark all as read: ${result['error']}');
        return false;
      }
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

      // ✅ Use ApiService
      final result = await ApiService.instance.delete(
        endpoint: '/notifications/$notificationId/',
        token: _token,
      );

      if (result['success']) {
        _notifications.removeWhere((n) => n['id'] == notificationId);
        _updateUnreadCount();
        notifyListeners();
        
        debugPrint('✅ Notification $notificationId deleted');
        return true;
      } else {
        debugPrint('❌ Failed to delete notification: ${result['error']}');
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
      case 'report_updated':
        return Icons.update;
      case 'report_verified':
        return Icons.verified;
      case 'report_dismissed':
        return Icons.cancel;
      case 'counseling_summons':
        return Icons.event_available;
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
      case 'teacher_reg':
        return Icons.person_add;
      case 'account_approved':
        return Icons.check_circle_outline;
      case 'account_rejected':
        return Icons.highlight_off;
      case 'announcement':
        return Icons.campaign;
      case 'grade_promotion':
        return Icons.school;
      case 'strand_change':
        return Icons.swap_horiz;
      case 'system_alert':
        return Icons.notification_important;
      default:
        return Icons.notifications;
    }
  }

  /// Get notification color based on type
  Color getNotificationColor(String? type) {
    switch (type) {
      case 'report_submitted':
        return Colors.blue;
      case 'report_verified':
        return Colors.green;
      case 'report_dismissed':
        return Colors.grey;
      case 'counseling_summons':
        return Colors.deepPurple;
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
      case 'teacher_reg':
        return Colors.teal;
      case 'account_approved':
        return Colors.green;
      case 'account_rejected':
        return Colors.red;
      case 'announcement':
        return Colors.indigo;
      case 'grade_promotion':
        return Colors.lightBlue;
      case 'strand_change':
        return Colors.cyan;
      case 'system_alert':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  /// Get notification priority badge
  String? getPriorityBadge(String? type) {
    switch (type) {
      case 'counseling_summons':
        return 'URGENT';
      case 'system_alert':
        return 'IMPORTANT';
      case 'violation_recorded':
        return 'HIGH';
      case 'account_rejected':
        return 'IMPORTANT';
      default:
        return null;
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

  /// Get formatted date with time
  String getFormattedDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown';
    
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[date.month - 1];
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? 'PM' : 'AM';
      
      return '$month ${date.day}, ${date.year} at $hour:${date.minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return dateStr;
    }
  }

  /// Filter notifications by type
  List<Map<String, dynamic>> getNotificationsByType(String type) {
    return _notifications.where((n) => n['type'] == type).toList();
  }

  /// Get notifications by date range
  List<Map<String, dynamic>> getNotificationsByDateRange(DateTime start, DateTime end) {
    return _notifications.where((n) {
      try {
        final date = DateTime.parse(n['created_at']);
        return date.isAfter(start) && date.isBefore(end);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  /// Get today's notifications
  List<Map<String, dynamic>> getTodayNotifications() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    return getNotificationsByDateRange(today, tomorrow);
  }

  /// Get notification by ID
  Map<String, dynamic>? getNotificationById(int id) {
    try {
      return _notifications.firstWhere((n) => n['id'] == id);
    } catch (e) {
      return null;
    }
  }

  /// Check if notification is recent (less than 24 hours old)
  bool isRecentNotification(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;
    
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      return now.difference(date).inHours < 24;
    } catch (e) {
      return false;
    }
  }

  /// Clear all notifications locally
  void clearNotifications() {
    _notifications.clear();
    _unreadCount = 0;
    _error = null;
    notifyListeners();
  }

  /// Refresh notifications (force fetch)
  Future<void> refresh() async {
    await fetchNotifications();
  }
}
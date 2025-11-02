import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';

class StudentNotificationsPage extends StatefulWidget {
  const StudentNotificationsPage({super.key});

  @override
  State<StudentNotificationsPage> createState() => _StudentNotificationsPageState();
}

class _StudentNotificationsPageState extends State<StudentNotificationsPage> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    
    try {
      if (authProvider.token != null) {
        await studentProvider.fetchNotifications(authProvider.token!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load notifications: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications();
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return timestamp;
    }
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: (notification['is_read'] as bool? ?? false) ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: (notification['is_read'] as bool? ?? false) ? null : Colors.blue.shade50,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(notification['notification_type'] as String? ?? ''),
          child: Icon(
            _getNotificationIcon(notification['notification_type'] as String? ?? ''),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          notification['title'] as String? ?? 'No Title',
          style: TextStyle(
            fontWeight: (notification['is_read'] as bool? ?? false) 
                ? FontWeight.normal 
                : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['message'] as String? ?? 'No Message',
              style: TextStyle(
                fontWeight: (notification['is_read'] as bool? ?? false) 
                    ? FontWeight.normal 
                    : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(notification['created_at'] as String? ?? ''),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if ((notification['notification_type'] as String? ?? '').isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification['notification_type'] as String? ?? ''),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  (notification['notification_type'] as String? ?? '').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: (notification['related_report_id'] != null)
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
        onTap: (notification['related_report_id'] != null)
            ? () {
                // Navigate to report details
                print("Navigate to report: ${notification['related_report_id']}");
              }
            : null,
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'system_alert':
        return Colors.blue;
      case 'report_submitted':
        return Colors.green;
      case 'report_updated':
        return Colors.orange;
      case 'reminder':
        return Colors.purple;
      case 'announcement':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'system_alert':
        return Icons.info;
      case 'report_submitted':
        return Icons.check_circle;
      case 'report_updated':
        return Icons.update;
      case 'reminder':
        return Icons.alarm;
      case 'announcement':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshNotifications,
          ),
        ],
      ),
      body: Consumer<StudentProvider>(
        builder: (context, studentProvider, child) {
          final notifications = studentProvider.notifications;

          if (_isLoading && notifications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "No notifications yet",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshNotifications,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = notifications[index];

                return _buildNotificationCard(notification);
              },
            ),
          );
        },
      ),
    );
  }
}
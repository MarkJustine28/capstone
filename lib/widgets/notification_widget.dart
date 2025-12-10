import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        final unreadCount = notificationProvider.unreadCount;
        
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.yellow),
              onPressed: () {
                _showNotificationsBottomSheet(context);
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const NotificationBottomSheet(),
    );
  }
}

class NotificationBottomSheet extends StatelessWidget {
  const NotificationBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (notificationProvider.unreadCount > 0)
                        TextButton(
                          onPressed: () async {
                            await notificationProvider.markAllAsRead();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('All notifications marked as read'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('Mark all read'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Notification List
                Expanded(
                  child: notificationProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : notificationProvider.notifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_off,
                                    size: 80,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No notifications yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: notificationProvider.fetchNotifications,
                              child: ListView.builder(
                                controller: scrollController,
                                itemCount: notificationProvider.notifications.length,
                                itemBuilder: (context, index) {
                                  final notification =
                                      notificationProvider.notifications[index];
                                  return NotificationItem(
                                    notification: notification,
                                  );
                                },
                              ),
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class NotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;

  const NotificationItem({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    final isRead = notification['is_read'] ?? false;
    final type = notification['type']?.toString();
    final priorityBadge = notificationProvider.getPriorityBadge(type);
    
    return Dismissible(
      key: Key('notification_${notification['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        notificationProvider.deleteNotification(notification['id']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: InkWell(
        onTap: () {
          // Show floating details dialog
          _showNotificationDetails(context, notificationProvider);
        },
        child: Container(
          color: isRead ? Colors.white : Colors.blue.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: notificationProvider.getNotificationColor(type).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notificationProvider.getNotificationIcon(type),
                  color: notificationProvider.getNotificationColor(type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with priority badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (priorityBadge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: notificationProvider.getNotificationColor(type),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              priorityBadge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Message preview
                    Text(
                      notification['message'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Time
                    Text(
                      notificationProvider.formatNotificationTime(
                        notification['created_at'],
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Unread indicator & arrow
              Column(
                children: [
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationDetails(BuildContext context, NotificationProvider provider) {
    final type = notification['type']?.toString();
    final metadata = notification['metadata'] as Map<String, dynamic>?;
    final createdAt = notification['created_at'];
    final isRead = notification['is_read'] ?? false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: provider.getNotificationColor(type),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      provider.getNotificationIcon(type),
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notification['title'] ?? 'Notification',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatNotificationType(type ?? ''),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Message
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          notification['message'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Details Section
                      const Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Full timestamp
                      _buildDetailRow(
                        icon: Icons.access_time,
                        label: 'Received',
                        value: provider.getFormattedDateTime(createdAt),
                        color: Colors.blue.shade700,
                      ),
                      
                      // Related report ID
                      if (metadata?['report_id'] != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.tag,
                          label: 'Report ID',
                          value: '#${metadata!['report_id']}',
                          color: Colors.purple.shade700,
                        ),
                      ],
                      
                      // Violation type
                      if (metadata?['violation_type'] != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.warning,
                          label: 'Violation',
                          value: metadata!['violation_type'].toString(),
                          color: Colors.red.shade700,
                        ),
                      ],
                      
                      // Student name
                      if (metadata?['student_name'] != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.person,
                          label: 'Student',
                          value: metadata!['student_name'].toString(),
                          color: Colors.green.shade700,
                        ),
                      ],
                      
                      // Reporter name
                      if (metadata?['reporter_name'] != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.person_outline,
                          label: 'Reported by',
                          value: metadata!['reporter_name'].toString(),
                          color: Colors.orange.shade700,
                        ),
                      ],
                      
                      // Session date (for counseling summons)
                      if (metadata?['session_date'] != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.event,
                          label: 'Scheduled',
                          value: provider.getFormattedDateTime(metadata!['session_date']),
                          color: Colors.deepPurple.shade700,
                        ),
                      ],
                      
                      // Status
                      if (metadata?['status'] != null) ...[
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.info_outline,
                          label: 'Status',
                          value: _formatStatus(metadata!['status'].toString()),
                          color: _getStatusColor(metadata['status'].toString()),
                        ),
                      ],
                      
                      // Action required indicator
                      if (_requiresAction(type)) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.priority_high, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Action required - Please respond promptly',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () {
                        provider.deleteNotification(notification['id']);
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notification deleted'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Close'),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // ✅ Mark as read when dialog is closed
      if (!isRead) {
        provider.markAsRead(notification['id']);
      }
    });
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNotificationType(String type) {
    return type.replaceAll('_', ' ').split(' ').map((word) {
      return word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  String _formatStatus(String status) {
    return status.toUpperCase().replaceAll('_', ' ');
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'verified':
      case 'resolved':
      case 'approved':
        return Colors.green;
      case 'dismissed':
      case 'invalid':
      case 'rejected':
        return Colors.grey;
      case 'summoned':
        return Colors.deepPurple;
      default:
        return Colors.blue;
    }
  }

  bool _requiresAction(String? type) {
    return type == 'counseling_summons' || 
           type == 'report_submitted' || 
           type == 'system_alert';
  }
}
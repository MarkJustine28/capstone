/// lib/models/notification_item.dart

/// Model representing a notification
class NotificationItem {
  /// Unique identifier for the notification
  final int id;

  /// The content of the notification
  final String message;

  /// Timestamp of when the notification was created
  final String timestamp;

  /// Type of notification: 'report', 'counseling', etc.
  final String type;

  /// Whether the notification has been read
  final bool isRead;

  /// ID of related report (if applicable)
  final int? reportId;

  /// Constructor
  NotificationItem({
    required this.id,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.reportId,
  });

  /// Create a NotificationItem from JSON
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? 0,
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? '',
      type: json['type'] ?? 'report',
      isRead: json['is_read'] ?? false,
      reportId: json['report_id'],
    );
  }

  /// Convert NotificationItem to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'timestamp': timestamp,
      'type': type,
      'is_read': isRead,
      'report_id': reportId,
    };
  }

  /// Create a copy of this notification with updated fields
  NotificationItem copyWith({
    int? id,
    String? message,
    String? timestamp,
    String? type,
    bool? isRead,
    int? reportId,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      reportId: reportId ?? this.reportId,
    );
  }

  @override
  String toString() {
    return 'NotificationItem{id: $id, message: $message, type: $type, isRead: $isRead, timestamp: $timestamp}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}


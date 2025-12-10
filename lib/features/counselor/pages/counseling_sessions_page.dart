import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/counselor_provider.dart';
import 'package:intl/intl.dart';

class CounselingSessionsPage extends StatefulWidget {
  const CounselingSessionsPage({Key? key}) : super(key: key);

  @override
  State<CounselingSessionsPage> createState() => _CounselingSessionsPageState();
}

class _CounselingSessionsPageState extends State<CounselingSessionsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    
    // ✅ FIXED: Initialize TabController in initState
    _tabController = TabController(
      length: 3, // scheduled, completed, cancelled
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSessions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
  if (!mounted) return;
  
  debugPrint('🔄 Auto-refreshing sessions and provider data...');
  
  // Refresh provider data first
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  await counselorProvider.fetchCounselingSessions();
  
  // Then refresh local sessions (this will preserve virtual completed/cancelled sessions)
  await _fetchSessions();
  
  debugPrint('✅ Auto-refresh completed');
}

  Future<void> _fetchSessions() async {
  if (!mounted) return;
  
  setState(() => _isLoading = true);
  
  try {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    // Get existing counseling sessions first
    await counselorProvider.fetchCounselingSessions();
    final existingSessions = counselorProvider.counselingSessions;
    
    // Get high-risk students separately
    final highRiskStudents = await counselorProvider.getHighRiskStudentsForCounseling();
    
    debugPrint('📊 Found ${existingSessions.length} existing sessions');
    debugPrint('🚨 Found ${highRiskStudents.length} high-risk students');
    
    // ✅ SIMPLIFIED: Start with existing real sessions only
    final allSessions = <Map<String, dynamic>>[];
    allSessions.addAll(existingSessions);
    
    // ✅ Track which students already have sessions
    final studentsWithSessions = <int>{};
    for (final session in existingSessions) {
      final studentId = session['student_id'];
      if (studentId != null) {
        studentsWithSessions.add(studentId);
      }
    }
    
    debugPrint('📋 Students with existing sessions: $studentsWithSessions');
    
    // ✅ AUTO-CREATE real counseling sessions for high-risk students without existing sessions
    for (final student in highRiskStudents) {
      final studentId = student['id'];
      
      if (!studentsWithSessions.contains(studentId)) {
        debugPrint('🚨 Creating real counseling session for ${student['name']} (${student['violation_count']} violations)');
        
        // ✅ Create a real counseling session in the database
        final sessionData = {
          'student_id': student['id'],
          'action_type': 'Mandatory Counseling - High Risk',
          'description': 'Student has ${student['violation_count']} tallied violations requiring mandatory counseling.\n\nViolation Types: ${(student['violation_types'] as List).join(', ')}\n\nThis session is required due to the high number of violations.',
          'notes': 'Auto-generated session for high-risk student',
          'status': 'scheduled',
          'priority': student['priority'],
          'scheduled_date': DateTime.now().add(const Duration(days: 1)).toIso8601String(), // Schedule for tomorrow
          'school_year': counselorProvider.selectedSchoolYear,
          'violation_count': student['violation_count'],
          'is_auto_generated': true,
        };
        
        final success = await counselorProvider.createCounselingSession(sessionData);
        
        if (success) {
          debugPrint('✅ Successfully created real session for ${student['name']}');
          studentsWithSessions.add(studentId);
        } else {
          debugPrint('❌ Failed to create session for ${student['name']}: ${counselorProvider.error}');
        }
      } else {
        debugPrint('⏭️ Skipping ${student['name']} - already has a session');
      }
    }
    
    // ✅ Refresh to get all sessions including newly created ones
    await counselorProvider.fetchCounselingSessions();
    final finalSessions = counselorProvider.counselingSessions;
    
    debugPrint('✅ Total sessions after auto-creation: ${finalSessions.length}');
    
    if (mounted) {
      setState(() {
        _sessions = finalSessions;
        _isLoading = false;
      });
      
      // ✅ Debug: Show tab counts after refresh
      debugPrint('📊 After refresh - Scheduled: ${_getFilteredSessions('scheduled').length}');
      debugPrint('✅ After refresh - Completed: ${_getFilteredSessions('completed').length}');
      debugPrint('❌ After refresh - Cancelled: ${_getFilteredSessions('cancelled').length}');
    }
  } catch (e) {
    debugPrint('❌ Error fetching sessions: $e');
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

// ✅ Get filtered sessions including urgent ones
List<Map<String, dynamic>> _getFilteredSessions(String status) {
  debugPrint('🔍 Filtering sessions for status: $status');
  
  final filtered = _sessions.where((session) => session['status'] == status).toList();
  
  debugPrint('✅ ${status.toUpperCase()} sessions found: ${filtered.length}');
  for (final session in filtered) {
    debugPrint('  - ${session['student_name']} (${session['status']}) - ID: ${session['id']}');
  }
  
  return filtered;
}

// ✅ Handle emergency scheduling
void _scheduleEmergencyCounseling(Map<String, dynamic> student) async {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  
  final success = await counselorProvider.scheduleEmergencyCounseling(
    studentId: student['id'],
    studentName: student['name'],
    violationCount: student['violation_count'],
    violationTypes: List<String>.from(student['violation_types']),
    notes: 'Emergency counseling scheduled due to ${student['violation_count']} violations',
  );
  
  if (success && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚨 Emergency counseling scheduled for ${student['name']}'),
        backgroundColor: Colors.orange,
      ),
    );

    // ✅ AUTO-REFRESH: Refresh data after emergency scheduling
    await _refreshData();
  }
}

  @override
  Widget build(BuildContext context) {
    final scheduledSessions = _getFilteredSessions('scheduled');
    final completedSessions = _getFilteredSessions('completed');
    final cancelledSessions = _getFilteredSessions('cancelled');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Counseling/Conference Sessions'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // ✅ Add manual refresh button
          IconButton(
            onPressed: _isLoading ? null : _refreshData,
            icon: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
            tooltip: 'Refresh Sessions',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Scheduled (${scheduledSessions.length})'),
            Tab(text: 'Completed (${completedSessions.length})'),
            Tab(text: 'Cancelled (${cancelledSessions.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSessionsList(scheduledSessions, 'scheduled'),
                _buildSessionsList(completedSessions, 'completed'),
                _buildSessionsList(cancelledSessions, 'cancelled'),
              ],
            ),
    );
  }

  Widget _buildSessionsList(List<Map<String, dynamic>> sessions, String status) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'scheduled' ? Icons.event_available : Icons.check_circle,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              status == 'scheduled' 
                  ? 'No scheduled sessions'
                  : status == 'completed'
                      ? 'No completed sessions'
                      : 'No cancelled sessions',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index];
          return _buildSessionCard(session, status);
        },
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, String status) {
  DateTime scheduledDate;
  try {
    scheduledDate = DateTime.parse(session['scheduled_date']);
  } catch (e) {
    scheduledDate = DateTime.now();
  }
  
  final formattedDate = DateFormat('MMM dd, yyyy').format(scheduledDate);
  final formattedTime = DateFormat('h:mm a').format(scheduledDate);
  
  // ✅ Check if this is an auto-generated session for high-risk student
  final isAutoGenerated = session['is_auto_generated'] == true;
  final violationCount = session['violation_count'];
  
  // ✅ Check notification status
  final notificationSent = session['notification_sent'] ?? false;
  
  Color statusColor;
  IconData statusIcon;
  
  switch (status) {
    case 'scheduled':
      statusColor = isAutoGenerated ? Colors.orange : Colors.blue;
      statusIcon = isAutoGenerated ? Icons.warning : Icons.schedule;
      break;
    case 'completed':
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      break;
    case 'cancelled':
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      break;
    default:
      statusColor = Colors.grey;
      statusIcon = Icons.info;
  }

  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: isAutoGenerated ? 3 : 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: isAutoGenerated ? BorderSide(color: Colors.orange, width: 1) : BorderSide.none,
    ),
    child: InkWell(
      onTap: () => _showSessionDetails(session),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isAutoGenerated ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange.shade50, Colors.orange.shade100],
          ) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with notification status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                session['student_name'] ?? 'Unknown Student',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // ✅ Notification status indicator
                            if (notificationSent) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.notifications_active, color: Colors.white, size: 12),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'NOTIFIED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            // ✅ Violation count for auto-generated sessions
                            if (isAutoGenerated && violationCount != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${violationCount} VIOLATIONS',
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
                        Text(
                          session['action_type'] ?? 'Counseling Session',
                          style: TextStyle(
                            fontSize: 13,
                            color: isAutoGenerated ? Colors.orange.shade700 : Colors.grey.shade600,
                            fontWeight: isAutoGenerated ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        // ✅ Show notification status text
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              notificationSent ? Icons.check_circle : Icons.warning_amber,
                              size: 14,
                              color: notificationSent ? Colors.green.shade600 : Colors.orange.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              notificationSent ? 'Student notified' : 'Student not notified',
                              style: TextStyle(
                                fontSize: 11,
                                color: notificationSent ? Colors.green.shade600 : Colors.orange.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAutoGenerated && status == 'scheduled' ? 'HIGH RISK' : status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Date & Time
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isAutoGenerated ? Colors.orange.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAutoGenerated ? Colors.orange.shade200 : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today, 
                      size: 16, 
                      color: isAutoGenerated ? Colors.orange.shade600 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate, 
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.w500,
                        color: isAutoGenerated ? Colors.orange.shade800 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time, 
                      size: 16, 
                      color: isAutoGenerated ? Colors.orange.shade600 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedTime, 
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.w500,
                        color: isAutoGenerated ? Colors.orange.shade800 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Description preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAutoGenerated ? Colors.orange.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAutoGenerated ? Colors.orange.shade200 : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  session['description'] ?? 'No description available',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13, 
                    color: isAutoGenerated ? Colors.orange.shade800 : Colors.grey.shade700,
                    fontWeight: isAutoGenerated ? FontWeight.w500 : FontWeight.normal,
                    height: 1.3,
                  ),
                ),
              ),
              
              // Action buttons for scheduled sessions
if (status == 'scheduled') ...[
  const SizedBox(height: 16),
  const Divider(height: 1),
  const SizedBox(height: 12),
  
  // ✅ FIXED: Use Column for better layout on small screens
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // ✅ Notification controls (full width)
      if (!notificationSent) ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _sendNotificationToStudent(session),
            icon: const Icon(Icons.notifications, size: 16),
            label: const Text('Notify Student'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ] else ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 6),
              Text(
                'Student Notified',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
      
      // ✅ Action buttons in a Row with proper spacing
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _cancelSession(session),
              icon: const Icon(Icons.cancel, size: 16),
              label: const Text('Cancel', overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _markAsCompleted(session),
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('Complete', overflow: TextOverflow.ellipsis),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
],
              
              // ✅ Show session completion info for completed sessions
              if (status == 'completed' && session['completion_date'] != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20, color: Colors.green.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Session Completed',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            Text(
                              DateFormat('MMM dd, yyyy - h:mm a').format(
                                DateTime.parse(session['completion_date'])
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade600,
                              ),
                            ),
                            if (session['notes'] != null && session['notes'].toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Notes: ${session['notes']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // ✅ Show cancellation info for cancelled sessions  
              if (status == 'cancelled') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cancel, size: 20, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Session Cancelled',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            if (session['updated_at'] != null)
                              Text(
                                'Cancelled on: ${DateFormat('MMM dd, yyyy - h:mm a').format(DateTime.parse(session['updated_at']))}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade600,
                                ),
                              ),
                          ],
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
    ),
  );
}

// ✅ NEW: Method to send notification to student
Future<void> _sendNotificationToStudent(Map<String, dynamic> session) async {
  try {
    // Show loading state
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('📨 Sending notification to ${session['student_name']}...'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );

    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    final sessionId = session['id'];
    final isVirtualSession = sessionId is String && sessionId.toString().startsWith('virtual_');
    
    bool success = false;
    
    if (isVirtualSession) {
      // ✅ For virtual sessions, create a notification and session record
      final sessionMessage = '''
${session['action_type'] ?? 'Counseling Session'}

${session['description'] ?? 'You have been scheduled for a counseling session.'}

📅 Please report to the Guidance Office at your earliest convenience.
⚠️ This is regarding your recent violations and requires immediate attention.
📍 Location: Guidance Office (Main Building)

Thank you for your cooperation.''';
      
      success = await counselorProvider.sendCounselingNotification(
        studentId: session['student_id'],
        message: sessionMessage,
        scheduledDate: session['scheduled_date'],
      );
      
      if (success) {
        // ✅ Update the virtual session to show it's been notified
        setState(() {
          final sessionIndex = _sessions.indexWhere((s) => s['id'] == sessionId);
          if (sessionIndex != -1) {
            _sessions[sessionIndex]['notification_sent'] = true;
            _sessions[sessionIndex]['status'] = 'scheduled'; // Change from urgent to scheduled
          }
        });
      }
    } else {
      // ✅ For existing sessions, just send a notification
      final sessionMessage = '''
Counseling Session Reminder

${session['description'] ?? 'You have a scheduled counseling session.'}

📅 Scheduled Date: ${_formatDateTime(session['scheduled_date'])}
📍 Location: Guidance Office (Main Building)

Please ensure you arrive on time. Thank you.''';
      
      success = await counselorProvider.sendCounselingNotification(
        studentId: session['student_id'],
        message: sessionMessage,
        scheduledDate: session['scheduled_date'],
      );
      
      if (success) {
        // ✅ Just update the notification status locally
        setState(() {
          final sessionIndex = _sessions.indexWhere((s) => s['id'] == sessionId);
          if (sessionIndex != -1) {
            _sessions[sessionIndex]['notification_sent'] = true;
          }
        });
      }
    }
    
    if (success) {
      // ✅ AUTO-REFRESH: Refresh data after notification
      await _refreshData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('✅ Notification sent to ${session['student_name']}'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to send notification: ${counselorProvider.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Error sending notification: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// ✅ Helper method to format date and time
String _formatDateTime(String? dateTimeString) {
  if (dateTimeString == null) return 'TBD';
  
  try {
    final dateTime = DateTime.parse(dateTimeString);
    return DateFormat('MMM dd, yyyy - h:mm a').format(dateTime);
  } catch (e) {
    return 'TBD';
  }
}

// ✅ ADD: Handle proper scheduling of urgent sessions
void _scheduleProperSession(Map<String, dynamic> session) {
  // Show dialog to schedule a proper session
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Schedule Counseling Session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Schedule a proper counseling session for ${session['student_name']}?'),
          const SizedBox(height: 8),
          Text(
            'This student has ${session['violation_count']} violations and needs immediate intervention.',
            style: TextStyle(color: Colors.red.shade600, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            // You can implement a proper scheduling dialog here
            _scheduleEmergencyCounseling(session['student']);
          },
          icon: const Icon(Icons.schedule, size: 16),
          label: const Text('Schedule Session'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

  void _showSessionDetails(Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(session['student_name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Type', session['action_type']),
              _buildDetailRow('Status', session['status'].toUpperCase()),
              _buildDetailRow('Scheduled', DateFormat('MMM dd, yyyy - h:mm a').format(DateTime.parse(session['scheduled_date']))),
              if (session['completion_date'] != null)
                _buildDetailRow('Completed', DateFormat('MMM dd, yyyy - h:mm a').format(DateTime.parse(session['completion_date']))),
              const SizedBox(height: 12),
              const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(session['description']),
              if (session['notes'] != null && session['notes'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(session['notes']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _markAsCompleted(Map<String, dynamic> session) async {
  final notesController = TextEditingController();
  
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mark Session as Completed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Mark counseling session with ${session['student_name']} as completed?'),
          const SizedBox(height: 16),
          TextField(
            controller: notesController,
            decoration: const InputDecoration(
              labelText: 'Session Notes',
              hintText: 'What was discussed? Any outcomes?',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Mark Completed'),
        ),
      ],
    ),
  );

  if (result != true) {
    notesController.dispose();
    return;
  }

  // Show processing state
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('⏳ Completing session for ${session['student_name']}...'),
        ],
      ),
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 3),
    ),
  );

  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final sessionId = session['id'];

  try {
    // ✅ SIMPLIFIED: Always update existing session (no virtual logic)
    final updateData = {
      'status': 'completed',
      'completion_date': DateTime.now().toIso8601String(),
      'notes': notesController.text.trim(),
    };
    
    final success = await counselorProvider.updateCounselingSession(sessionId, updateData);
    
    if (success) {
      debugPrint('✅ Session ${sessionId} marked as completed');
      
      // ✅ Refresh to get updated data
      await counselorProvider.fetchCounselingSessions();
      
      // ✅ Update local sessions
      setState(() {
        _sessions = counselorProvider.counselingSessions;
      });
      
      // ✅ Send completion notification
      try {
        final sessionMessage = '''
Counseling Session Completed

Session with: ${session['student_name']}
Date: ${DateTime.now().toLocal().toString().split('.')[0]}
Reason: High violation count (${session['violation_count']} violations)

Session Notes: ${notesController.text.trim().isEmpty ? 'No additional notes provided.' : notesController.text.trim()}

This counseling session has been completed. Continue following school policies and guidelines.

Thank you for your cooperation.''';
        
        await counselorProvider.sendCounselingNotification(
          studentId: session['student_id'],
          message: sessionMessage,
        );
        debugPrint('✅ Sent completion notification');
      } catch (e) {
        debugPrint('⚠️ Could not send completion notification: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('✅ Session completed - ${session['student_name']}'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      throw Exception(counselorProvider.error ?? 'Unknown error');
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to complete session: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    notesController.dispose();
  }
}

  Future<void> _cancelSession(Map<String, dynamic> session) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Cancel Session'),
      content: Text('Cancel counseling session with ${session['student_name']}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('No'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Yes, Cancel'),
        ),
      ],
    ),
  );
  
  if (result == true) {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    try {
      final success = await counselorProvider.updateCounselingSession(
        session['id'],
        {'status': 'cancelled'},
      );
      
      if (success) {
        // ✅ Refresh to get updated data
        await counselorProvider.fetchCounselingSessions();
        
        setState(() {
          _sessions = counselorProvider.counselingSessions;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('✅ Session cancelled - ${session['student_name']}'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(counselorProvider.error ?? 'Unknown error');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to cancel session: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
}
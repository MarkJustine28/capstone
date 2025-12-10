import '../../../widgets/school_year_banner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/routes.dart';
import '../../../providers/counselor_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/notification_widget.dart';
import 'student_violations_page.dart';
import 'student_report_page.dart';
import 'teacher_reports_page.dart';
import 'counseling_sessions_page.dart';
import '../../../core/constants/app_breakpoints.dart';
import 'dart:math';

class CounselorDashboardPage extends StatefulWidget {
  final String username;
  final String role;

  const CounselorDashboardPage({
    super.key,
    required this.username,
    required this.role,
  });

  @override
  State<CounselorDashboardPage> createState() => _CounselorDashboardPageState();
}

class _CounselorDashboardPageState extends State<CounselorDashboardPage> {
  int _currentTabIndex = 0;
  String? _lastProcessedSchoolYear;
  bool _isLoading = true;
  bool _hasShownFrozenDialog = false; // ✅ Track if frozen dialog shown
  int _studentReportsCount = 0;
  int _teacherReportsCount = 0;
  List<Map<String, dynamic>> _studentReports = [];
  List<Map<String, dynamic>> _teacherReports = [];
  List<Map<String, dynamic>> recentlyHandledStudents = [];
  
  // Analytics data
  Map<String, int> _reportStatusCounts = {};
  Map<String, int> _monthlyReportTrends = {};
  Map<String, int> _violationTypeCounts = {};
  List<Map<String, dynamic>> _riskAnalysis = [];
  List<String> _recommendations = [];
  Map<String, Map<String, int>> _behavioralPatterns = {}; // month -> {violationType: count}
  List<String> _selectedViolationTypes = [];
  String? _selectedFilterYear;
  int? _selectedFilterMonth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  // ✅ NEW: Initialize dashboard with system check
  Future<void> _initializeDashboard() async {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    if (counselorProvider.token != null) {
      notificationProvider.setToken(counselorProvider.token!);
      
      try {
        // ✅ Check system status first
        await counselorProvider.fetchSystemSettings();
        
        if (!counselorProvider.isSystemActive && !_hasShownFrozenDialog) {
          _hasShownFrozenDialog = true;
          // Show system frozen dialog
          Future.delayed(Duration.zero, () => _showSystemFrozenDialog());
          setState(() => _isLoading = false);
          return;
        }
        
        await counselorProvider.fetchProfile();

        // Continue with normal initialization
        await _fetchDashboardData();
        
      } catch (e) {
        debugPrint('❌ Error initializing dashboard: $e');
        if (e is SystemFrozenException && !_hasShownFrozenDialog) {
          _hasShownFrozenDialog = true;
          Future.delayed(Duration.zero, () => _showSystemFrozenDialog());
        }
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeNotifications() {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    if (counselorProvider.token != null) {
      notificationProvider.setToken(counselorProvider.token);
    }
  }

  // ✅ NEW: Show system frozen dialog
  void _showSystemFrozenDialog() {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock_clock, color: Colors.orange.shade700, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'System Temporarily Frozen',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.school_outlined,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                Text(
                  counselorProvider.systemMessage ?? 
                  'The Guidance Tracking System is currently frozen for maintenance or school year transition.\n\n'
                  'The system will be reactivated when the new school year begins or maintenance is complete.\n\n'
                  'As a counselor, you may need to access admin settings to reactivate the system.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Current School Year:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        counselorProvider.systemSchoolYear ?? 'N/A',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Contact the system administrator if you need assistance.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              onPressed: () async {
                Navigator.of(context).pop();
                // Logout user
                await counselorProvider.logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, AppRoutes.login);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchDashboardData() async {
  if (!mounted) return;
  
  try {
    setState(() => _isLoading = true);
    
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);

    if (counselorProvider.token == null) {
      debugPrint("❌ No token found in CounselorProvider");
      return;
    }

    debugPrint("📊 Starting dashboard data fetch...");

    // ✅ FIX: Use fetchCounselorStudentReports and include counseling sessions
    await Future.wait([
      counselorProvider.fetchCounselorStudentReports(forceRefresh: true),
      counselorProvider.fetchTeacherReports(),
      counselorProvider.fetchStudentViolations(forceRefresh: true),
      counselorProvider.fetchViolationTypes(),
      counselorProvider.fetchDashboardAnalytics(),
      counselorProvider.fetchCounselingSessions(), // ✅ ADD: Fetch counseling sessions
    ]);

    // ✅ ADD: Fetch recently handled students after we have counseling sessions
    await _fetchRecentlyHandledStudents();

    debugPrint("✅ All data fetched successfully");

    if (mounted) {
      setState(() {
        _studentReports = counselorProvider.counselorStudentReports;
        _teacherReports = counselorProvider.teacherReports;
        
        _studentReportsCount = _studentReports.length;
        _teacherReportsCount = _teacherReports.length;
        
        debugPrint("📊 Dashboard data loaded:");
        debugPrint("   - Student Reports: $_studentReportsCount");
        debugPrint("   - Teacher Reports: $_teacherReportsCount");
        debugPrint("   - Total Violations: ${counselorProvider.studentViolations.length}");
        debugPrint("   - Recently Handled Students: ${recentlyHandledStudents.length}"); // ✅ ADD
        
        // Count tallied violations for verification
        final talliedCount = counselorProvider.studentViolations.where((v) {
          return v['related_report_id'] != null || 
                 v['related_report'] != null ||
                 v['related_student_report_id'] != null ||
                 v['related_student_report'] != null;
        }).length;
        debugPrint("   - Tallied Violations (with report link): $talliedCount");
        
        _processAllAnalytics();
        
        _isLoading = false;
      });
    }
  } on SystemFrozenException {
    if (!_hasShownFrozenDialog) {
      _hasShownFrozenDialog = true;
      _showSystemFrozenDialog();
    }
  } catch (e) {
    debugPrint("❌ Error fetching dashboard data: $e");
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error loading dashboard: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  void _processPrescriptiveAnalytics() {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final allViolations = counselorProvider.studentViolations;
  
  _riskAnalysis = [];
  _recommendations = [];

  final pendingCount = _reportStatusCounts['pending'] ?? 0;
  final totalReports = _studentReportsCount + _teacherReportsCount;
  
  // ✅ UPDATED: Get high-risk students with more sophisticated filtering
  final Map<int, Map<String, dynamic>> studentViolationCounts = {};
  
  for (final violation in allViolations) {
    final studentId = violation['student_id'] ?? violation['student']?['id'];
    
    if (studentId != null) {
      if (!studentViolationCounts.containsKey(studentId)) {
        studentViolationCounts[studentId] = {
          'id': studentId,
          'name': violation['student_name'] ?? 
                 violation['student']?['name'] ?? 
                 'Unknown Student',
          'student_id': violation['student']?['student_id'] ?? '',
          'grade_level': violation['student']?['grade_level'] ?? '',
          'section': violation['student']?['section'] ?? '',
          'count': 0,
          'types': <String>[],
          'dates': <DateTime>[],
        };
      }
      
      studentViolationCounts[studentId]!['count'] = 
          (studentViolationCounts[studentId]!['count'] as int) + 1;
      
      final violationType = _violationNameFromRecord(violation);
      (studentViolationCounts[studentId]!['types'] as List<String>).add(violationType);
      
      // ✅ NEW: Track violation dates
      try {
        final dateStr = violation['created_at']?.toString() ?? 
                       violation['date']?.toString() ?? '';
        if (dateStr.isNotEmpty) {
          final date = DateTime.parse(dateStr);
          (studentViolationCounts[studentId]!['dates'] as List<DateTime>).add(date);
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing date: $e');
      }
    }
  }
  
  // ✅ NEW: Enhanced counseling check - track both completion AND recent violations
  final recentlyHandledStudentIds = <int, DateTime>{};  // Map student ID to last counseling date
  final counselingSessions = counselorProvider.counselingSessions;
  
  for (final session in counselingSessions) {
    try {
      // Check for completed sessions
      final completionDate = session['completion_date'] ?? session['actual_date'];
      if (completionDate != null && session['status'] == 'completed') {
        final sessionDate = DateTime.parse(completionDate);
        final studentId = session['student_id'] ?? 
                         session['reported_student_id'] ?? 
                         session['reported_student']?['id'];
        
        if (studentId != null) {
          // Keep track of the most recent counseling date
          if (!recentlyHandledStudentIds.containsKey(studentId) ||
              sessionDate.isAfter(recentlyHandledStudentIds[studentId]!)) {
            recentlyHandledStudentIds[studentId] = sessionDate;
            debugPrint('✅ Student $studentId last counseled on ${sessionDate.toLocal()}');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error parsing completion date: $e');
    }
  }
  
  // ✅ NEW: Intelligent filtering - show if violations AFTER last counseling
  final highRiskStudents = studentViolationCounts.values
      .where((student) {
        final studentId = student['id'] as int;
        final violationCount = student['count'] as int;
        final violationDates = student['dates'] as List<DateTime>;
        
        // Must have 3+ violations
        if (violationCount < 3) return false;
        
        // Check if student was counseled
        final lastCounselingDate = recentlyHandledStudentIds[studentId];
        
        if (lastCounselingDate == null) {
          // Never been counseled - definitely show
          debugPrint('🚨 ${student['name']} - $violationCount violations, NEVER counseled');
          return true;
        }
        
        // ✅ NEW: Check if there are violations AFTER the last counseling
        final violationsAfterCounseling = violationDates
            .where((date) => date.isAfter(lastCounselingDate))
            .length;
        
        if (violationsAfterCounseling >= 3) {
          // Has 3+ violations after counseling - show again!
          debugPrint('🚨 ${student['name']} - $violationsAfterCounseling NEW violations after counseling on ${lastCounselingDate.toLocal()}');
          return true;
        }
        
        // ✅ NEW: Also check if total violations are now 4+ (even if some are old)
        // This catches students who had 3, got counseled, now have 4
        if (violationCount >= 4 && violationsAfterCounseling >= 1) {
          debugPrint('🚨 ${student['name']} - $violationCount total violations (${violationsAfterCounseling} new), counseled on ${lastCounselingDate.toLocal()}');
          return true;
        }
        
        // Was counseled and hasn't violated 3+ times since - don't show
        debugPrint('⏭️ Skipping ${student['name']} - counseled on ${lastCounselingDate.toLocal()}, only ${violationsAfterCounseling} new violations');
        return false;
      })
      .toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  
  debugPrint('📊 High-risk students needing counseling: ${highRiskStudents.length}');
  debugPrint('📊 Recently counseled students: ${recentlyHandledStudentIds.length}');
  
  // ✅ UPDATED: Risk analysis for high-risk students
  if (highRiskStudents.isNotEmpty) {
    // Separate students into categories
    final neverCounseled = <Map<String, dynamic>>[];
    final repeatedOffenders = <Map<String, dynamic>>[];
    
    for (final student in highRiskStudents) {
      final studentId = student['id'] as int;
      final lastCounselingDate = recentlyHandledStudentIds[studentId];
      
      if (lastCounselingDate == null) {
        neverCounseled.add(student);
      } else {
        repeatedOffenders.add({
          ...student,
          'last_counseling': lastCounselingDate,
        });
      }
    }
    
    // ✅ Critical: Students who were never counseled
    if (neverCounseled.isNotEmpty) {
      _riskAnalysis.add({
        'level': 'Critical',
        'issue': 'High-Risk Students (Never Counseled)',
        'count': neverCounseled.length,
        'description': '${neverCounseled.length} student(s) with 3+ violations have NEVER been counseled',
        'color': Colors.red,
        'students': neverCounseled,
      });
      
      for (final student in neverCounseled.take(3)) {
        _recommendations.add(
          "🚨 CRITICAL: Schedule FIRST counseling session for ${student['name']} "
          "(${student['grade_level']}-${student['section']}) - ${student['count']} violations, NEVER counseled"
        );
      }
    }
    
    // ✅ High: Repeated offenders (counseled but violated again)
    if (repeatedOffenders.isNotEmpty) {
      _riskAnalysis.add({
        'level': 'High',
        'issue': 'Repeated Offenders (Post-Counseling)',
        'count': repeatedOffenders.length,
        'description': '${repeatedOffenders.length} student(s) violated again after counseling - escalation needed',
        'color': Colors.deepOrange,
        'students': repeatedOffenders,
      });
      
      for (final student in repeatedOffenders.take(3)) {
        final lastCounseling = student['last_counseling'] as DateTime;
        final daysSince = DateTime.now().difference(lastCounseling).inDays;
        
        _recommendations.add(
          "🔴 HIGH PRIORITY: FOLLOW-UP counseling for ${student['name']} "
          "(${student['grade_level']}-${student['section']}) - ${student['count']} total violations, "
          "last counseled $daysSince days ago. Consider escalation or parent conference."
        );
      }
    }
    
    // Summary recommendations
    if (highRiskStudents.length > 3) {
      final remaining = highRiskStudents.length - 3;
      _recommendations.add(
        "⚠️ ATTENTION: $remaining additional student(s) require counseling or follow-up"
      );
    }
  } else if (recentlyHandledStudentIds.isNotEmpty) {
    // ✅ Positive: All high-risk students have been addressed
    _riskAnalysis.add({
      'level': 'Info',
      'issue': 'Recent Counseling Interventions Completed',
      'count': recentlyHandledStudentIds.length,
      'description': 'All high-risk students have been counseled. Continue monitoring for re-offenses.',
      'color': Colors.green,
    });
    
    _recommendations.add(
      "✅ GOOD WORK: All high-risk students have received counseling. Monitor for re-offenses and provide follow-up support as needed."
    );
  }
  
  // ✅ Rest of your existing risk analysis (pending reports, bullying, violence, etc.)
  if (pendingCount > 5) {
    _riskAnalysis.add({
      'level': 'High',
      'issue': 'High Pending Reports',
      'count': pendingCount,
      'description': '$pendingCount reports are pending review',
      'color': Colors.red,
    });
    
    _recommendations.add(
      "🔴 ACTION REQUIRED: Review and process $pendingCount pending reports to prevent backlog buildup"
    );
  }

  final bullyingCount = _violationTypeCounts.entries
      .where((entry) => entry.key.toLowerCase().contains('bullying'))
      .fold(0, (sum, entry) => sum + entry.value);
  
  if (bullyingCount >= 3) {
    _riskAnalysis.add({
      'level': 'High',
      'issue': 'Bullying Trend Detected',
      'count': bullyingCount,
      'description': 'Multiple bullying incidents require immediate attention',
      'color': Colors.red,
    });
    
    _recommendations.add(
      "🚨 ACTION REQUIRED: Implement anti-bullying campaign and conduct group counseling sessions ($bullyingCount cases)"
    );
  }

  final violenceCount = (_violationTypeCounts['Fighting'] ?? 0) + 
                       (_violationTypeCounts['Violence'] ?? 0) + 
                       (_violationTypeCounts['Physical Altercation'] ?? 0);
  
  if (violenceCount >= 2) {
    _riskAnalysis.add({
      'level': 'High',
      'issue': 'Violence Concerns',
      'count': violenceCount,
      'description': 'Fighting/violence incidents need intervention',
      'color': Colors.red,
    });
    
    _recommendations.add(
      "⚠️ ACTION REQUIRED: Coordinate with school security and conduct anger management workshops ($violenceCount cases)"
    );
  }

  final attendanceCount = (_violationTypeCounts['Tardiness'] ?? 0) + 
                         (_violationTypeCounts['Absenteeism'] ?? 0) + 
                         (_violationTypeCounts['Cutting Classes'] ?? 0) +
                         (_violationTypeCounts['Skipping Class'] ?? 0);

  if (attendanceCount >= 5) {
    _riskAnalysis.add({
      'level': 'Medium',
      'issue': 'Attendance Issues',
      'count': attendanceCount,
      'description': 'High number of attendance-related violations',
      'color': Colors.orange,
    });
    
    _recommendations.add(
      "📚 ACTION REQUIRED: Contact parents/guardians of students with chronic absenteeism ($attendanceCount cases)"
    );
  }

  if (totalReports > 20) {
    _riskAnalysis.add({
      'level': 'Medium',
      'issue': 'High Report Volume',
      'count': totalReports,
      'description': 'Increased reporting activity detected',
      'color': Colors.orange,
    });
    
    _recommendations.add(
      "📊 ACTION SUGGESTED: Analyze patterns in high report volume and consider preventive measures"
    );
  }

  final substanceCount = (_violationTypeCounts['Using Vape/Cigarette'] ?? 0) + 
                        (_violationTypeCounts['Substance Use'] ?? 0) +
                        (_violationTypeCounts['Smoking'] ?? 0);
  if (substanceCount >= 3) {
    _recommendations.add(
      "🚭 ACTION REQUIRED: Conduct substance abuse awareness program and individual counseling sessions ($substanceCount cases)"
    );
  }

  final academicCount = (_violationTypeCounts['Cheating'] ?? 0) + 
                       (_violationTypeCounts['Academic Dishonesty'] ?? 0);
  if (academicCount >= 2) {
    _recommendations.add(
      "📖 ACTION REQUIRED: Organize academic integrity workshops and meet with involved students ($academicCount cases)"
    );
  }

  if (_recommendations.isEmpty) {
    _recommendations.add(
      "✅ EXCELLENT STATUS: All identified issues have been addressed. Continue regular monitoring and maintain proactive student engagement."
    );
  }
}

  Future<bool> _confirmLogout(BuildContext context) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Logout"),
            content: const Text("Are you sure you want to log out?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Logout"),
              ),
            ],
          ),
        ) ?? false;
  }

  // Update this method to use the correct tab names:
  Widget _getCurrentTabContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildManageStudentsTab();
      case 2:
        return _buildStudentReportsContent();
      case 3:
        return _buildTeacherReportsContent();
      case 4:
        return _buildAnalyticsContent();
      default:
        return _buildOverviewTab();
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

@override
Widget build(BuildContext context) {
  return Consumer<CounselorProvider>(
    builder: (context, provider, child) {
      // ✅ Show frozen screen if system is inactive
      if (!provider.isSystemActive && !_isLoading) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Guidance Tracker'),
              backgroundColor: Colors.grey.shade700,
              automaticallyImplyLeading: false,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_clock,
                      size: 100,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'System Frozen',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      provider.systemMessage ?? 
                      'The system is currently unavailable.\nPlease contact the administrator.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      onPressed: () async {
                        await provider.logout();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, AppRoutes.login);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isDesktop = AppBreakpoints.isDesktop(screenWidth);
          final isTablet = AppBreakpoints.isTablet(screenWidth);

          return WillPopScope(
            onWillPop: () => _confirmLogout(context),
            child: Scaffold(
              key: _scaffoldKey,
              appBar: (_currentTabIndex == 1 || _currentTabIndex == 2 || _currentTabIndex == 3) 
                  ? null 
                  : AppBar(
                      automaticallyImplyLeading: false,
                      centerTitle: false,
                      title: Text(
                        isDesktop ? "Counselor Dashboard" : "Dashboard",
                        style: TextStyle(
                          fontSize: isDesktop ? 20 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      toolbarHeight: isDesktop ? 72 : 56,
                      actions: [
                        // Notifications
                        const NotificationBell(),
                        
                        // Counseling Sessions
                        IconButton(
                          icon: const Icon(Icons.event_note),
                          iconSize: isDesktop ? 24 : 20,
                          tooltip: 'Counseling Sessions',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CounselingSessionsPage(),
                              ),
                            );
                          },
                        ),

                        // Settings
                        IconButton(
                          icon: const Icon(Icons.settings),
                          iconSize: isDesktop ? 24 : 20,
                          tooltip: 'Settings',
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.counselorSettings);
                          },
                        ),
                        
                        // Refresh
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          iconSize: isDesktop ? 24 : 20,
                          tooltip: 'Refresh',
                          onPressed: () {
                            setState(() => _isLoading = true);
                            _fetchDashboardData();
                          },
                        ),
                        
                        // User menu for desktop
                        if (isDesktop)
                          PopupMenuButton<String>(
                            offset: const Offset(0, 56),
                            icon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_drop_down),
                              ],
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'profile',
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, size: 20),
                                    const SizedBox(width: 12),
                                    Text(widget.username),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'profile') {
                                // Handle profile view if needed
                              }
                            },
                          ),
                        
                        SizedBox(width: isDesktop ? 8 : 4),
                      ],
                    ),
              body: _getCurrentTabContent(),
              bottomNavigationBar: _buildBottomNavigationBar(),
            ),
          );
        },
      );
    },
  );
}

Widget? _buildDesktopDrawer() {
  return Drawer(
    child: Column(
      children: [
        DrawerHeader(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 32, color: Colors.blue.shade700),
              ),
              SizedBox(height: 12),
              Text(
                widget.username,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Counselor',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        ListTile(
          leading: Icon(Icons.dashboard, color: _currentTabIndex == 0 ? Colors.blue : null),
          title: Text('Overview'),
          selected: _currentTabIndex == 0,
          onTap: () {
            setState(() => _currentTabIndex = 0);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.people, color: _currentTabIndex == 1 ? Colors.blue : null),
          title: Text('Manage Students'),
          selected: _currentTabIndex == 1,
          onTap: () {
            setState(() => _currentTabIndex = 1);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.report, color: _currentTabIndex == 2 ? Colors.blue : null),
          title: Text('Student Reports'),
          selected: _currentTabIndex == 2,
          onTap: () {
            setState(() => _currentTabIndex = 2);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.school, color: _currentTabIndex == 3 ? Colors.blue : null),
          title: Text('Teacher Reports'),
          selected: _currentTabIndex == 3,
          onTap: () {
            setState(() => _currentTabIndex = 3);
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: Icon(Icons.analytics, color: _currentTabIndex == 4 ? Colors.blue : null),
          title: Text('Analytics'),
          selected: _currentTabIndex == 4,
          onTap: () {
            setState(() => _currentTabIndex = 4);
            Navigator.pop(context);
          },
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.event_note),
          title: Text('Counseling Sessions'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CounselingSessionsPage(),
              ),
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.settings),
          title: Text('Settings'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.counselorSettings);
          },
        ),
      ],
    ),
  );
}

  // Update the _buildBottomNavigationBar method:
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentTabIndex,
      onTap: (index) {
        setState(() {
          _currentTabIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Overview',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Manage Students', // Links to StudentsManagementPage
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.report),
          label: 'Student Reports', // Links to StudentReportPage
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.school),
          label: 'Teacher Reports',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Analytics',
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
  return Consumer<CounselorProvider>(
    builder: (context, counselorProvider, child) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isDesktop = AppBreakpoints.isDesktop(screenWidth);
          final isTablet = AppBreakpoints.isTablet(screenWidth);
          final padding = AppBreakpoints.getPadding(screenWidth);

          return SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // School Year Banner
                const SchoolYearBanner(),
                
                // Main content with responsive padding
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: AppBreakpoints.getMaxContentWidth(screenWidth),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Greeting Card
                          _buildGreetingCard(),
                          SizedBox(height: isDesktop ? 32 : 20),

                          // Quick Stats Cards
                          _buildQuickStatsGrid(),
                          SizedBox(height: isDesktop ? 32 : 20),

                          // Desktop/Tablet: Two column layout
                          if (isDesktop || isTablet)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      _buildTopViolationsOverview(),
                                      SizedBox(height: isDesktop ? 24 : 20),
                                      _buildRecentActivitySection(),
                                    ],
                                  ),
                                ),
                                SizedBox(width: isDesktop ? 24 : 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildQuickActionsCard(isDesktop: isDesktop),
                                ),
                              ],
                            )
                          else ...[
                            // Mobile: Stacked layout
                            _buildTopViolationsOverview(),
                            const SizedBox(height: 20),
                            _buildRecentActivitySection(),
                            const SizedBox(height: 20),
                            _buildQuickActionsCard(isDesktop: false),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildHighRiskStudentsSection({required bool isDesktop}) {
  return FutureBuilder<List<Map<String, dynamic>>>(
    future: Provider.of<CounselorProvider>(context, listen: false).getHighRiskStudentsForCounseling(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Card(
          child: Container(
            height: 60,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Checking for high-risk students...'),
              ],
            ),
          ),
        );
      }
      
      if (snapshot.hasError) {
        debugPrint('❌ Error loading high-risk students: ${snapshot.error}');
        return const SizedBox.shrink();
      }
      
      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
        return Column(
          children: [
            _buildHighRiskStudentsAlert(snapshot.data!, isDesktop: isDesktop),
            SizedBox(height: isDesktop ? 24 : 20),
          ],
        );
      }
      
      return const SizedBox.shrink();
    },
  );
}

Widget _buildHighRiskStudentsAlert(List<Map<String, dynamic>> highRiskStudents, {required bool isDesktop}) {
  if (highRiskStudents.isEmpty) return const SizedBox.shrink();
  
  return Card(
    elevation: isDesktop ? 6 : 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
      side: BorderSide(color: Colors.red.shade300, width: 2),
    ),
    child: Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.red.shade50, Colors.red.shade100],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                ),
                child: Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: isDesktop ? 28 : 24,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🚨 Immediate Counseling Required',
                      style: TextStyle(
                        fontSize: isDesktop ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    Text(
                      '${highRiskStudents.length} student${highRiskStudents.length > 1 ? 's' : ''} with 3+ violations need${highRiskStudents.length == 1 ? 's' : ''} counseling',
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CounselingSessionsPage(),
                    ),
                  );
                },
                icon: Icon(Icons.event_note, size: isDesktop ? 20 : 18),
                label: Text(
                  'View Sessions',
                  style: TextStyle(fontSize: isDesktop ? 14 : 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 20 : 16,
                    vertical: isDesktop ? 12 : 10,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: isDesktop ? 20 : 16),
          
          // Students list (show top 3)
          ...highRiskStudents.take(3).map((student) => Container(
            margin: EdgeInsets.only(bottom: isDesktop ? 12 : 10),
            padding: EdgeInsets.all(isDesktop ? 16 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: (student['priority'] == 'high' ? Colors.red : Colors.orange),
                  radius: isDesktop ? 24 : 20,
                  child: Text(
                    '${student['violation_count'] ?? 0}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 16 : 14,
                    ),
                  ),
                ),
                SizedBox(width: isDesktop ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? 'Unknown Student',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isDesktop ? 16 : 14,
                        ),
                      ),
                      Text(
                        'Grade ${student['grade_level'] ?? 'Unknown'}-${student['section'] ?? 'Unknown'} • ID: ${student['student_id'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: isDesktop ? 13 : 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Violations: ${_formatViolationTypes(student['violation_types'])}',
                        style: TextStyle(
                          fontSize: isDesktop ? 12 : 11,
                          color: Colors.red.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _scheduleEmergencyCounseling(student),
                  icon: Icon(Icons.schedule, size: isDesktop ? 16 : 14),
                  label: Text(
                    'Schedule',
                    style: TextStyle(fontSize: isDesktop ? 12 : 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 12 : 10,
                      vertical: isDesktop ? 8 : 6,
                    ),
                  ),
                ),
              ],
            ),
          )),
          
          // Show more button if there are more students
          if (highRiskStudents.length > 3)
            Padding(
              padding: EdgeInsets.only(top: isDesktop ? 12 : 10),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CounselingSessionsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.group, size: 16),
                  label: Text('View all ${highRiskStudents.length} students'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

// ✅ ADD: Helper method to format violation types safely
String _formatViolationTypes(dynamic violationTypes) {
  if (violationTypes == null) return 'Unknown';
  
  if (violationTypes is List) {
    final types = violationTypes.cast<String>();
    final displayTypes = types.take(2).join(', ');
    return types.length > 2 ? '$displayTypes...' : displayTypes;
  }
  
  return violationTypes.toString();
}

// ✅ ADD: Emergency counseling scheduling method
void _scheduleEmergencyCounseling(Map<String, dynamic> student) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.emergency, color: Colors.red.shade700),
          const SizedBox(width: 8),
          const Expanded(child: Text('Emergency Counseling')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Schedule immediate counseling session for:'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Text(
                    '${student['violation_count'] ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Grade ${student['grade_level'] ?? 'Unknown'}-${student['section'] ?? 'Unknown'}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      Text(
                        '${student['violation_count'] ?? 0} active violations',
                        style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            
            // Navigate to counseling sessions
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CounselingSessionsPage(),
              ),
            );
          },
          icon: const Icon(Icons.emergency, size: 16),
          label: const Text('Schedule Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

// NEW: Quick Actions Card for desktop sidebar
Widget _buildQuickActionsCard({required bool isDesktop}) {
  return Card(
    elevation: 2,
    child: Padding(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, color: Colors.orange, size: isDesktop ? 24 : 20),
              SizedBox(width: isDesktop ? 12 : 8),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          
          _buildQuickActionButton(
            icon: Icons.add_circle,
            label: 'New Counseling Session',
            color: Colors.blue,
            isDesktop: isDesktop,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CounselingSessionsPage(),
                ),
              );
            },
          ),
          SizedBox(height: isDesktop ? 12 : 10),
          
          _buildQuickActionButton(
            icon: Icons.person_search,
            label: 'Manage Students',
            color: Colors.green,
            isDesktop: isDesktop,
            onTap: () => setState(() => _currentTabIndex = 1),
          ),
          SizedBox(height: isDesktop ? 12 : 10),
          
          _buildQuickActionButton(
            icon: Icons.report,
            label: 'View Reports',
            color: Colors.orange,
            isDesktop: isDesktop,
            onTap: () => setState(() => _currentTabIndex = 2),
          ),
          SizedBox(height: isDesktop ? 12 : 10),
          
          _buildQuickActionButton(
            icon: Icons.analytics,
            label: 'Analytics',
            color: Colors.purple,
            isDesktop: isDesktop,
            onTap: () => setState(() => _currentTabIndex = 4),
          ),
        ],
      ),
    ),
  );
}

Widget _buildQuickActionButton({
  required IconData icon,
  required String label,
  required Color color,
  required bool isDesktop,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isDesktop ? 24 : 20),
          SizedBox(width: isDesktop ? 12 : 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isDesktop ? 15 : 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: isDesktop ? 16 : 14,
            color: color.withOpacity(0.5),
          ),
        ],
      ),
    ),
  );
}

  // Add this method to your _CounselorDashboardPageState class:

  Widget _buildRecentActivitySection() {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final recentReports = counselorProvider.getCombinedRecentReports(limit: 5);

  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isDesktop = AppBreakpoints.isDesktop(screenWidth);
      final isTablet = AppBreakpoints.isTablet(screenWidth);

      return Card(
        elevation: isDesktop ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        ),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 24 : (isTablet ? 20 : 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        color: Colors.blue.shade700,
                        size: isDesktop ? 28 : 24,
                      ),
                      SizedBox(width: isDesktop ? 12 : 8),
                      Text(
                        "Recent Activity",
                        style: TextStyle(
                          fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (recentReports.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _currentTabIndex = 2),
                      child: Text(
                        "View All",
                        style: TextStyle(
                          fontSize: isDesktop ? 14 : 13,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: isDesktop ? 20 : 16),
              
              if (recentReports.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 32 : 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: isDesktop ? 64 : 48,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(height: isDesktop ? 16 : 12),
                        Text(
                          "No recent activity found",
                          style: TextStyle(
                            fontSize: isDesktop ? 16 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...recentReports.take(isDesktop ? 5 : 3).map((report) => Container(
                  margin: EdgeInsets.only(bottom: isDesktop ? 12 : 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 20 : (isTablet ? 16 : 12),
                      vertical: isDesktop ? 12 : (isTablet ? 10 : 8),
                    ),
                    leading: Container(
                      width: isDesktop ? 48 : 40,
                      height: isDesktop ? 48 : 40,
                      decoration: BoxDecoration(
                        color: _getStatusColor(report['status']?.toString()).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                      ),
                      child: Icon(
                        report['reporter_type'] == 'Student' 
                            ? Icons.person_outline 
                            : Icons.school_outlined,
                        color: _getStatusColor(report['status']?.toString()),
                        size: isDesktop ? 24 : 20,
                      ),
                    ),
                    title: Text(
                      report['title']?.toString() ?? 'Untitled Report',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isDesktop ? 15 : 14,
                      ),
                      maxLines: isDesktop ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: isDesktop ? 14 : 12,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'From: ${report['reporter_type']} • ${_formatDate(report['created_at'] ?? report['date'])}',
                                style: TextStyle(
                                  fontSize: isDesktop ? 13 : (isTablet ? 12 : 11),
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (report['reported_student_name'] != null) ...[
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.account_circle_outlined,
                                size: isDesktop ? 14 : 12,
                                color: Colors.grey.shade600,
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Student: ${report['reported_student_name']}',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 13 : (isTablet ? 12 : 11),
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 12 : 8,
                        vertical: isDesktop ? 6 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(report['status']?.toString()).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(isDesktop ? 8 : 6),
                      ),
                      child: Text(
                        (report['status']?.toString() ?? 'pending').toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(report['status']?.toString()),
                          fontSize: isDesktop ? 11 : 10,
                        ),
                      ),
                    ),
                    onTap: () {
                      if (report['source_type'] == 'student_report') {
                        setState(() => _currentTabIndex = 2);
                      } else {
                        setState(() => _currentTabIndex = 3);
                      }
                    },
                  ),
                )),
            ],
          ),
        ),
      );
    },
  );
}

// Add helper method to format dates
String _formatDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return 'Unknown';
  try {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  } catch (e) {
    return dateStr;
  }
}

  Widget _buildGreetingCard() {
  return Consumer<CounselorProvider>(
    builder: (context, provider, child) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isDesktop = AppBreakpoints.isDesktop(screenWidth);
          final isTablet = AppBreakpoints.isTablet(screenWidth);

          // ✅ SIMPLIFIED: Get full_name directly from profile
          final profile = provider.counselorProfile;
          final displayName = profile?['full_name']?.toString() ?? widget.username;
          
          debugPrint('👤 Profile Data: $profile');
          debugPrint('✅ Display Name: $displayName');

          return Card(
            elevation: isDesktop ? 4 : 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
            ),
            child: Container(
              padding: EdgeInsets.all(isDesktop ? 32 : (isTablet ? 24 : 20)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isDesktop ? 6 : 4),
                        Text(
                          displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isDesktop ? 12 : 8),
                        Text(
                          'Ready to make a positive impact today!',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isTablet || isDesktop) ...[
                    SizedBox(width: isDesktop ? 32 : 24),
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 24 : 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                      ),
                      child: Icon(
                        Icons.dashboard,
                        color: Colors.white,
                        size: isDesktop ? 64 : 48,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    } else if (hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
    }
  }

  String _violationNameFromRecord(Map<String, dynamic> v) {
    try {
      if (v['violation_type'] != null) {
        if (v['violation_type'] is Map) {
          return v['violation_type']['name']?.toString() ?? 'Unknown';
        } else {
          return v['violation_type'].toString();
        }
      }
      if (v['custom_violation'] != null && v['custom_violation'].toString().trim().isNotEmpty) {
        return v['custom_violation'].toString();
      }
      if (v['violation_name'] != null) return v['violation_name'].toString();
      if (v['type'] != null) return v['type'].toString();
      return 'Other';
    } catch (e) {
      return 'Other';
    }
  }

  // NEW: Top Tallied Reports Overview for Overview Tab
  Widget _buildTopViolationsOverview() {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final talliedViolations = counselorProvider.studentViolations;

  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isDesktop = AppBreakpoints.isDesktop(screenWidth);
      final isTablet = AppBreakpoints.isTablet(screenWidth);

      // Count violations by type
      final talliedViolationCounts = <String, int>{};
      int totalTallied = 0;

      for (final violation in talliedViolations) {
        final hasRelatedReport = violation['related_report_id'] != null || 
                                 violation['related_report'] != null;
        if (hasRelatedReport) totalTallied += 1;

        final violationType = _violationNameFromRecord(violation as Map<String, dynamic>);
        talliedViolationCounts[violationType] = (talliedViolationCounts[violationType] ?? 0) + 1;
      }

      final topTalliedViolations = talliedViolationCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return InkWell(
        onTap: () => setState(() => _currentTabIndex = 1),
        child: Card(
          elevation: isDesktop ? 4 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
          ),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : (isTablet ? 20 : 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bar_chart_rounded,
                                color: Colors.orange.shade700,
                                size: isDesktop ? 28 : 24,
                              ),
                              SizedBox(width: isDesktop ? 12 : 8),
                              Expanded(
                                child: Text(
                                  "Top Tallied Reports",
                                  style: TextStyle(
                                    fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isDesktop ? 8 : 4),
                          Text(
                            "${talliedViolations.length} total violations • $totalTallied from reports",
                            style: TextStyle(
                              fontSize: isDesktop ? 14 : (isTablet ? 13 : 12),
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDesktop || isTablet)
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 12 : 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          size: isDesktop ? 20 : 16,
                          color: Colors.orange.shade700,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: isDesktop ? 24 : 16),

                if (topTalliedViolations.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(isDesktop ? 32 : 20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: isDesktop ? 64 : 48,
                            color: Colors.grey.shade300,
                          ),
                          SizedBox(height: isDesktop ? 16 : 12),
                          Text(
                            "No tallied reports found",
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...topTalliedViolations.take(isDesktop ? 5 : 3).map((entry) => Padding(
                    padding: EdgeInsets.only(bottom: isDesktop ? 16 : 12),
                    child: Container(
                      padding: EdgeInsets.all(isDesktop ? 16 : 12),
                      decoration: BoxDecoration(
                        color: _getViolationColor(entry.key).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                        border: Border.all(
                          color: _getViolationColor(entry.key).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: isDesktop ? 48 : (isTablet ? 44 : 40),
                            height: isDesktop ? 48 : (isTablet ? 44 : 40),
                            decoration: BoxDecoration(
                              color: _getViolationColor(entry.key),
                              borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: isDesktop ? 24 : 20,
                            ),
                          ),
                          SizedBox(width: isDesktop ? 16 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "${entry.value} tallied ${entry.value == 1 ? 'report' : 'reports'}",
                                  style: TextStyle(
                                    fontSize: isDesktop ? 13 : (isTablet ? 12 : 11),
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 16 : 12,
                              vertical: isDesktop ? 8 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getViolationColor(entry.key),
                              borderRadius: BorderRadius.circular(isDesktop ? 20 : 15),
                            ),
                            child: Text(
                              "${entry.value}",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),

                // Show more button on mobile
                if (!isDesktop && !isTablet && topTalliedViolations.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _currentTabIndex = 1),
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View All'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

  // NEW: Get color for actual violation types
  Color _getViolationColor(String violationType) {
    final type = violationType.toLowerCase();
    if (type.contains('bullying')) return Colors.red;
    if (type.contains('tardiness') || type.contains('absent') || type.contains('cutting')) return Colors.orange;
    if (type.contains('vape') || type.contains('cigarette') || type.contains('substance')) return Colors.brown;
    if (type.contains('cheat')) return Colors.blue;
    if (type.contains('fight') || type.contains('violence')) return Colors.deepOrange;
    if (type.contains('misbehavior') || type.contains('behavioral')) return Colors.purple;
    if (type.contains('uniform') || type.contains('hair') || type.contains('dress')) return Colors.teal;
    if (type.contains('gambling')) return Colors.amber;
    return Colors.grey;
  }

  // Add this method to your _CounselorDashboardPageState class:
  Widget _buildQuickStatsGrid() {
  return Consumer<CounselorProvider>(
    builder: (context, provider, child) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isDesktop = AppBreakpoints.isDesktop(screenWidth);
          final isTablet = AppBreakpoints.isTablet(screenWidth);
          final isMobile = AppBreakpoints.isMobile(screenWidth);
          final gridColumns = isMobile ? 2 : (isTablet ? 3 : 4);
          
          final selectedSchoolYear = provider.selectedSchoolYear;
          final isFiltered = selectedSchoolYear != 'all';
          
          // Get filtered data
          final allViolations = provider.studentViolations;
          
          List<Map<String, dynamic>> filteredStudentReports;
          List<Map<String, dynamic>> filteredTeacherReports;
          
          if (selectedSchoolYear == 'all') {
            filteredStudentReports = _studentReports;
            filteredTeacherReports = _teacherReports;
          } else {
            filteredStudentReports = _studentReports.where((report) {
              final reportSchoolYear = report['school_year']?.toString() ?? 
                                      report['reported_student']?['school_year']?.toString() ?? '';
              return reportSchoolYear == selectedSchoolYear;
            }).toList();
            
            filteredTeacherReports = _teacherReports.where((report) {
              final reportSchoolYear = report['school_year']?.toString() ?? 
                                      report['student']?['school_year']?.toString() ?? '';
              return reportSchoolYear == selectedSchoolYear;
            }).toList();
          }
          
          final counselorRecordedCount = allViolations.where((v) {
            final hasNoReport = v['related_report_id'] == null && 
                               v['related_report'] == null &&
                               v['related_student_report_id'] == null &&
                               v['related_student_report'] == null &&
                               v['related_teacher_report_id'] == null &&
                               v['related_teacher_report'] == null;
            
            final isCounselorRecorded = v['counselor'] != null || 
                                       v['recorded_by'] == 'counselor';
            
            return hasNoReport && isCounselorRecorded;
          }).length;
          
          final pendingStudentReports = filteredStudentReports.where((r) => 
            r['status']?.toString() == 'pending'
          ).length;
          
          final totalTalliedReports = allViolations.where((v) {
            final hasRelatedReport = v['related_report_id'] != null || 
                                     v['related_report'] != null ||
                                     v['related_student_report_id'] != null ||
                                     v['related_student_report'] != null ||
                                     v['related_teacher_report_id'] != null ||
                                     v['related_teacher_report'] != null;
            
            final isCounselorRecorded = v['counselor'] != null;
            
            return hasRelatedReport || isCounselorRecorded;
          }).length;
          
          final totalReports = filteredStudentReports.length + 
                              filteredTeacherReports.length + 
                              counselorRecordedCount;
          
          return Column(
            children: [
              // Filter indicator
              if (isFiltered)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 16 : 12,
                    vertical: isDesktop ? 10 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list,
                        size: isDesktop ? 20 : 16,
                        color: Colors.blue.shade700,
                      ),
                      SizedBox(width: isDesktop ? 8 : 6),
                      Flexible(
                        child: Text(
                          'Showing data for S.Y. $selectedSchoolYear only',
                          style: TextStyle(
                            fontSize: isDesktop ? 14 : 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Responsive Stats Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: gridColumns,
                crossAxisSpacing: isDesktop ? 20 : (isTablet ? 16 : 12),
                mainAxisSpacing: isDesktop ? 20 : (isTablet ? 16 : 12),
                childAspectRatio: isMobile ? 1 : (isTablet ? 1.4 : 1.8),
                children: [
                  _buildResponsiveStatCard(
                    "📊 Total Reports",
                    "$totalReports",
                    "Student + Teacher + Counselor",
                    Colors.blue,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    onTap: () {},
                  ),
                  _buildResponsiveStatCard(
                    "👥 Student Reports", 
                    "${filteredStudentReports.length}",
                    "$pendingStudentReports pending review",
                    Colors.green,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    onTap: () => setState(() => _currentTabIndex = 2),
                  ),
                  _buildResponsiveStatCard(
                    "🏫 Teacher Reports",
                    "${filteredTeacherReports.length}",
                    "From educators",
                    Colors.orange,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    onTap: () => setState(() => _currentTabIndex = 3),
                  ),
                  _buildResponsiveStatCard(
                    "📝 Counselor Reports",
                    "$counselorRecordedCount",
                    "Directly recorded",
                    Colors.purple,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    onTap: () => setState(() => _currentTabIndex = 1), // Navigate to Manage Students tab
                  ),
                  _buildResponsiveStatCard(
                    "📊 Total Tallied Reports",
                    "$totalTalliedReports",
                    "From reports + direct entries",
                    Colors.red,
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    onTap: () => setState(() => _currentTabIndex = 1),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

// NEW: Responsive stat card
Widget _buildResponsiveStatCard(
  String title,
  String value,
  String subtitle,
  Color color, {
  required bool isDesktop,
  required bool isTablet,
  VoidCallback? onTap,
}) {
  // Determine mobile from the provided desktop/tablet flags
  final isMobile = !(isDesktop || isTablet);

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: EdgeInsets.all(isMobile ? 10 : (isTablet ? 16 : 20)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: isDesktop ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title
          Flexible(
            flex: 2,
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: isDesktop ? 16 : (isTablet ? 14 : 12),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Value
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: isDesktop ? 32 : (isTablet ? 28 : 24),
                ),
              ),
            ),
          ),
          
          // Subtitle
          Flexible(
            flex: 2,
            child: Text(
              subtitle,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: isDesktop ? 13 : (isTablet ? 11 : 10),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildEmptyState(String schoolYear) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Activity Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            schoolYear == 'all'
                ? 'No reports or violations recorded yet'
                : 'No data for S.Y. $schoolYear',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.counselorSettings);
            },
            icon: const Icon(Icons.settings),
            label: const Text('Change School Year'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'resolved':
      case 'closed':
        return Colors.green;
      case 'active':
        return Colors.red;
      case 'dismissed':
        return Colors.grey;
      case 'reviewed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }



  // Replace the _buildManageStudentsTab method with this to link to your existing page:

  Widget _buildManageStudentsTab() {
  return Column(
    children: [
      
      // Existing content
      const Expanded(
        child: StudentViolationsPage(),
      ),
    ],
  );
}

  // (Removed unused _showStudentViolations method)

  // Add this method to your _CounselorDashboardPageState class:
  Widget _buildStudentReportsContent() {
  return Column(
    children: [
      
      // Existing content
      const Expanded(
        child: StudentReportPage(),
      ),
    ],
  );
}

  // Add this method to your _CounselorDashboardPageState class:

  Widget _buildTeacherReportsContent() {
  return Column(
    children: [
      
      // Existing content
      const Expanded(
        child: TeacherReportsPage(),
      ),
    ],
  );
}

  // Add this method to your _CounselorDashboardPageState class:

  Widget _buildAnalyticsContent() {
  return Consumer<CounselorProvider>(
    builder: (context, provider, child) {
      // ✅ Only reprocess if school year actually changed
      if (_lastProcessedSchoolYear != provider.selectedSchoolYear) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            debugPrint("🔄 School year changed from $_lastProcessedSchoolYear to ${provider.selectedSchoolYear}");
            setState(() {
              _processAllAnalytics(schoolYear: provider.selectedSchoolYear);
              _lastProcessedSchoolYear = provider.selectedSchoolYear;
            });
          }
        });
      }
      
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Analytics Header
            Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                      Text(
                        'School Year: ${provider.selectedSchoolYear}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Status Distribution Chart
            _buildStatusDistributionCard(),
            const SizedBox(height: 20),

            // Violation Types Analysis
            _buildViolationTypesCard(),
            const SizedBox(height: 20),

            _buildBehavioralPatternCard(),
            const SizedBox(height: 20),

            // Monthly Trends
            _buildMonthlyTrendsCard(),
            const SizedBox(height: 20),

            // Risk Analysis Section
            _buildRiskAnalysisCard(),
            const SizedBox(height: 20),

            // Recommendations Section
            _buildRecommendationsCard(),
          ],
        ),
      );
    },
  );
}

// ✅ NEW: Show detailed violation breakdown for a student
void _showStudentViolationDetails(BuildContext context, Map<String, dynamic> student) {
  final violations = student['violations'] as List<Map<String, dynamic>>;
  
  // Count violations by type
  final Map<String, int> violationTypeCounts = {};
  for (final violation in violations) {
    final type = violation['type'] as String;
    violationTypeCounts[type] = (violationTypeCounts[type] ?? 0) + 1;
  }
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  student['name'] ?? 'Unknown',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${student['grade_level']} - ${student['section']} • ID: ${student['student_id']}'.trim(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Total: ${student['count']} violations',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Violation Breakdown:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: violationTypeCounts.length,
                itemBuilder: (context, index) {
                  final entry = violationTypeCounts.entries.elementAt(index);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getViolationColor(entry.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getViolationColor(entry.key).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getViolationColor(entry.key),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            // Navigate to student management page
            setState(() => _currentTabIndex = 1);
          },
          icon: const Icon(Icons.manage_accounts, size: 16),
          label: const Text('View Student'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );
}

 Widget _buildStatusDistributionCard() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isDesktop = AppBreakpoints.isDesktop(screenWidth);
      final isTablet = AppBreakpoints.isTablet(screenWidth);

      return Card(
        elevation: isDesktop ? 4 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        ),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 24 : (isTablet ? 20 : 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.pie_chart_rounded,
                    color: Colors.blue.shade700,
                    size: isDesktop ? 28 : 24,
                  ),
                  SizedBox(width: isDesktop ? 12 : 8),
                  Expanded(
                    child: Text(
                      'Report Status Distribution',
                      style: TextStyle(
                        fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isDesktop ? 24 : 16),
              
              if (_reportStatusCounts.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 32 : 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.pie_chart_outline,
                          size: isDesktop ? 64 : 48,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(height: isDesktop ? 16 : 12),
                        Text(
                          'No status data available',
                          style: TextStyle(
                            fontSize: isDesktop ? 16 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Pending Reports
                if (_reportStatusCounts['pending'] != null && _reportStatusCounts['pending']! > 0)
                  _buildStatusRow(
                    'PENDING',
                    _reportStatusCounts['pending']!,
                    Colors.orange,
                    isDesktop: isDesktop,
                  ),
                
                // Reviewed Reports
                if (_reportStatusCounts['reviewed'] != null && _reportStatusCounts['reviewed']! > 0)
                  _buildStatusRow(
                    'REVIEWED',
                    _reportStatusCounts['reviewed']!,
                    Colors.blue,
                    isDesktop: isDesktop,
                  ),
                
                // Resolved Reports
                if (_reportStatusCounts['resolved'] != null && _reportStatusCounts['resolved']! > 0)
                  _buildStatusRow(
                    'RESOLVED',
                    _reportStatusCounts['resolved']!,
                    Colors.green,
                    isDesktop: isDesktop,
                  ),
                
                // ✅ NEW: Invalid/Dismissed Reports
                if (_reportStatusCounts['invalid'] != null && _reportStatusCounts['invalid']! > 0)
                  _buildStatusRow(
                    'INVALID / DISMISSED',
                    _reportStatusCounts['invalid']!,
                    Colors.grey,
                    isDesktop: isDesktop,
                  ),
                
                // Counselor-Recorded Violations
                if (_reportStatusCounts['counselor_recorded'] != null && _reportStatusCounts['counselor_recorded']! > 0)
                  _buildStatusRow(
                    'COUNSELOR RECORDED',
                    _reportStatusCounts['counselor_recorded']!,
                    Colors.purple,
                    isDesktop: isDesktop,
                  ),
                
                // Divider
                Padding(
                  padding: EdgeInsets.symmetric(vertical: isDesktop ? 12 : 10),
                  child: const Divider(),
                ),
                
                // Total
                _buildStatusRow(
                  'TOTAL',
                  _reportStatusCounts['total'] ?? 0,
                  Colors.grey.shade700,
                  isDesktop: isDesktop,
                  isBold: true,
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

// ✅ NEW: Helper method for status rows
Widget _buildStatusRow(
  String label,
  int count,
  Color color, {
  required bool isDesktop,
  bool isBold = false,
}) {
  return Padding(
    padding: EdgeInsets.only(bottom: isDesktop ? 12 : 10),
    child: Row(
      children: [
        Container(
          width: isDesktop ? 20 : 16,
          height: isDesktop ? 20 : 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(isDesktop ? 6 : 4),
          ),
        ),
        SizedBox(width: isDesktop ? 16 : 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isDesktop ? 15 : 14,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 12 : 10,
            vertical: isDesktop ? 6 : 5,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: isDesktop ? 16 : 14,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildViolationTypesCard() {
  final topViolations = _violationTypeCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isDesktop = AppBreakpoints.isDesktop(screenWidth);
      final isTablet = AppBreakpoints.isTablet(screenWidth);

      return Card(
        elevation: isDesktop ? 4 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        ),
        child: Padding(
          padding: EdgeInsets.all(isDesktop ? 24 : (isTablet ? 20 : 16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.red.shade700,
                    size: isDesktop ? 28 : 24,
                  ),
                  SizedBox(width: isDesktop ? 12 : 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Violation Types Analysis',
                          style: TextStyle(
                            fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_violationTypeCounts.values.fold(0, (sum, count) => sum + count)} total violations',
                          style: TextStyle(
                            fontSize: isDesktop ? 13 : 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isDesktop ? 24 : 16),
              
              if (topViolations.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 32 : 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.bar_chart_outlined,
                          size: isDesktop ? 64 : 48,
                          color: Colors.grey.shade300,
                        ),
                        SizedBox(height: isDesktop ? 16 : 12),
                        Text(
                          'No violation data found',
                          style: TextStyle(
                            fontSize: isDesktop ? 16 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...topViolations.take(isDesktop ? 8 : 5).map((entry) {
                  final maxValue = topViolations.first.value;
                  final widthFactor = (entry.value / maxValue).clamp(0.0, 1.0);
                  
                  return Padding(
                    padding: EdgeInsets.only(bottom: isDesktop ? 14 : 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: isDesktop ? 2 : 3,
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isDesktop ? 15 : 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: isDesktop ? 16 : 12),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 12 : 10,
                                vertical: isDesktop ? 6 : 5,
                              ),
                              decoration: BoxDecoration(
                                color: _getViolationColor(entry.key).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                              ),
                              child: Text(
                                '${entry.value}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getViolationColor(entry.key),
                                  fontSize: isDesktop ? 16 : 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isDesktop ? 8 : 6),
                        Container(
                          height: isDesktop ? 12 : 10,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(isDesktop ? 6 : 5),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: widthFactor,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _getViolationColor(entry.key),
                                borderRadius: BorderRadius.circular(isDesktop ? 6 : 5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildMonthlyTrendsCard() {
  // Calculate trends
  final trendInsight = _calculateTrendInsight();
  
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Text(
                'Monthly Report Trends',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_monthlyReportTrends.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No trend data available'),
              ),
            )
          else ...[
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _monthlyReportTrends.length,
                itemBuilder: (context, index) {
                  final entry = _monthlyReportTrends.entries.elementAt(index);
                  final maxValue = _monthlyReportTrends.values.isNotEmpty 
                      ? _monthlyReportTrends.values.reduce((a, b) => a > b ? a : b)
                      : 1;
                  final height = maxValue > 0 
                      ? (entry.value / maxValue) * 120
                      : 0.0;
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 20,
                          alignment: Alignment.center,
                          child: Text(
                            '${entry.value}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        Container(
                          width: 30,
                          height: height,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade400,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Container(
                          height: 24,
                          alignment: Alignment.center,
                          child: RotatedBox(
                            quarterTurns: 1,
                            child: Text(
                              _formatMonthLabel(entry.key),
                              style: const TextStyle(fontSize: 9),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // ✅ NEW: Trend Description/Insight
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: trendInsight['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: trendInsight['color'].withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    trendInsight['icon'],
                    color: trendInsight['color'],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trendInsight['title'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: trendInsight['color'],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trendInsight['description'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
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
  );
}

// ✅ NEW: Calculate trend insights
Map<String, dynamic> _calculateTrendInsight() {
  if (_monthlyReportTrends.isEmpty) {
    return {
      'icon': Icons.info,
      'color': Colors.grey,
      'title': 'No Data Available',
      'description': 'Start tracking reports to see monthly trends.',
    };
  }

  final sortedMonths = _monthlyReportTrends.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  if (sortedMonths.length < 2) {
    return {
      'icon': Icons.pending,
      'color': Colors.blue,
      'title': 'Insufficient Data',
      'description': 'Need at least 2 months of data to analyze trends.',
    };
  }

  // Get last 2 months
  final lastMonth = sortedMonths.last;
  final previousMonth = sortedMonths[sortedMonths.length - 2];
  
  final lastMonthCount = lastMonth.value;
  final previousMonthCount = previousMonth.value;
  final change = lastMonthCount - previousMonthCount;
  final percentChange = previousMonthCount > 0 
      ? ((change / previousMonthCount) * 100).abs().toStringAsFixed(1)
      : '0';

  // Calculate average
  final average = (_monthlyReportTrends.values.reduce((a, b) => a + b) / 
                   _monthlyReportTrends.length).round();

  // Determine trend
  if (change > 0) {
    // Increasing trend
    if (lastMonthCount > average * 1.5) {
      return {
        'icon': Icons.trending_up,
        'color': Colors.red,
        'title': '⚠️ Sharp Increase Detected',
        'description': 'Reports increased by $percentChange% from ${_formatMonthLabel(previousMonth.key)} to ${_formatMonthLabel(lastMonth.key)}. '
                      'Current month ($lastMonthCount) is significantly above average ($average). Immediate attention recommended.',
      };
    } else {
      return {
        'icon': Icons.arrow_upward,
        'color': Colors.orange,
        'title': '📈 Increasing Trend',
        'description': 'Reports rose by $percentChange% from ${_formatMonthLabel(previousMonth.key)} ($previousMonthCount) to ${_formatMonthLabel(lastMonth.key)} ($lastMonthCount). '
                      'Monitor this trend closely.',
      };
    }
  } else if (change < 0) {
    // Decreasing trend
    return {
      'icon': Icons.trending_down,
      'color': Colors.green,
      'title': '✅ Decreasing Trend',
      'description': 'Reports decreased by $percentChange% from ${_formatMonthLabel(previousMonth.key)} ($previousMonthCount) to ${_formatMonthLabel(lastMonth.key)} ($lastMonthCount). '
                    'Positive improvement observed.',
    };
  } else {
    // Stable trend
    return {
      'icon': Icons.horizontal_rule,
      'color': Colors.blue,
      'title': '➡️ Stable Trend',
      'description': 'Reports remained consistent at $lastMonthCount for the past 2 months. '
                    'System running at steady state (average: $average reports/month).',
    };
  }
}

  // Add this helper method to format month labels better:
  String _formatMonthLabel(String monthKey) {
  try {
    // ✅ FIX: Handle both YYYY-MM and YYYY-MM-DD formats
    final parts = monthKey.split('-');
    if (parts.length >= 2) {
      final year = parts[0];
      final month = int.parse(parts[1]);
      final monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      if (month >= 1 && month <= 12) {
        return '${monthNames[month - 1]}\n\'${year.substring(2)}';
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error formatting month label: $e');
  }
  return monthKey;
}

  Widget _buildRiskAnalysisCard() {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                'Risk Analysis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_riskAnalysis.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No significant risks detected. System running smoothly.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._riskAnalysis.map((risk) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (risk['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (risk['color'] as Color).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: risk['color'] as Color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          risk['level'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              risk['issue'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              risk['description'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: risk['color'] as Color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${risk['count']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // ✅ NEW: Show high-risk students if available
                  if (risk['students'] != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'High-Risk Students:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(risk['students'] as List).take(3).map((student) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 16, color: risk['color'] as Color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${student['name']} (${student['grade_level']}-${student['section']})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: risk['color'] as Color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${student['count']} violations',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if ((risk['students'] as List).length > 3)
                      TextButton(
                        onPressed: () {
                          _showAllHighRiskStudents(context, risk['students'] as List);
                        },
                        child: Text('View all ${(risk['students'] as List).length} students'),
                      ),
                  ],
                ],
              ),
            )),
        ],
      ),
    ),
  );
}

// ✅ NEW: Show all high-risk students dialog
void _showAllHighRiskStudents(BuildContext context, List students) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('High-Risk Students (3+ Violations)'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red,
                child: Text(
                  '${student['count']}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(student['name']),
              subtitle: Text('${student['grade_level']}-${student['section']} • ID: ${student['student_id']}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _showStudentViolationDetails(context, student);
              },
            );
          },
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

  Widget _buildRecommendationsCard() {
  return Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              const Text(
                'Action Items & Recommendations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Suggested actions for the guidance counselor',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          
          ..._recommendations.asMap().entries.map((entry) {
            final index = entry.key;
            final recommendation = entry.value;
            
            // Determine icon and color based on priority
            IconData icon;
            Color color;
            
            if (recommendation.startsWith('🚨 CRITICAL') || recommendation.startsWith('🚨 ACTION REQUIRED')) {
              icon = Icons.emergency;
              color = Colors.red;
            } else if (recommendation.startsWith('🔴 ACTION REQUIRED') || recommendation.startsWith('⚠️ ACTION REQUIRED')) {
              icon = Icons.priority_high;
              color = Colors.red.shade700;
            } else if (recommendation.startsWith('📚 ACTION REQUIRED') || recommendation.startsWith('🚭 ACTION REQUIRED') || recommendation.startsWith('📖 ACTION REQUIRED')) {
              icon = Icons.assignment_turned_in;
              color = Colors.orange;
            } else if (recommendation.startsWith('📊 ACTION SUGGESTED')) {
              icon = Icons.info;
              color = Colors.blue;
            } else {
              icon = Icons.check_circle;
              color = Colors.green;
            }
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Action ${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recommendation,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
}

void _processBehavioralPatterns() {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final selectedSchoolYear = counselorProvider.selectedSchoolYear ?? 'all';
  
  // ✅ ONLY use tallied violations (those linked to reports)
  final allViolations = counselorProvider.studentViolations.where((violation) {
    // Must have a related report
    final hasTalliedReport = violation['related_report_id'] != null || 
                             violation['related_report'] != null ||
                             violation['related_student_report_id'] != null ||
                             violation['related_student_report'] != null ||
                             violation['related_teacher_report_id'] != null ||
                             violation['related_teacher_report'] != null;
    
    if (!hasTalliedReport) return false;
    
    // Filter by school year
    if (selectedSchoolYear == 'all') return true;
    
    final violationSchoolYear = violation['school_year']?.toString() ?? 
                                violation['student']?['school_year']?.toString() ?? '';
    return violationSchoolYear == selectedSchoolYear;
  }).toList();
  
  _behavioralPatterns = {};
  final Map<String, int> violationTypeTotals = {};
  
  debugPrint('📊 Processing behavioral patterns for S.Y. $selectedSchoolYear...');
  debugPrint('📊 Total violations: ${counselorProvider.studentViolations.length}');
  debugPrint('📊 Tallied violations (with reports): ${allViolations.length}');
  
  // Process each tallied violation by month and type
  for (final violation in allViolations) {
    try {
      final createdAt = violation['created_at']?.toString() ?? 
                       violation['date']?.toString() ?? '';
      
      if (createdAt.isEmpty) continue;
      
      // Get month key (YYYY-MM format)
      final monthKey = createdAt.substring(0, 7);
      
      // Get violation type
      final violationType = _violationNameFromRecord(violation as Map<String, dynamic>);
      
      // Initialize month if not exists
      if (!_behavioralPatterns.containsKey(monthKey)) {
        _behavioralPatterns[monthKey] = {};
      }
      
      // Count this violation
      _behavioralPatterns[monthKey]![violationType] = 
          (_behavioralPatterns[monthKey]![violationType] ?? 0) + 1;
      
      // Track totals for finding top types
      violationTypeTotals[violationType] = 
          (violationTypeTotals[violationType] ?? 0) + 1;
      
    } catch (e) {
      debugPrint('⚠️ Error processing violation for behavioral pattern: $e');
    }
  }
  
  // Select top 5 violation types to display
  final topTypes = violationTypeTotals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  
  _selectedViolationTypes = topTypes
      .take(5)
      .map((e) => e.key)
      .toList();
  
  debugPrint('✅ Processed ${_behavioralPatterns.length} months of tallied violation data for S.Y. $selectedSchoolYear');
  debugPrint('📈 Top tallied violation types: $_selectedViolationTypes');
  debugPrint('📊 Total tallied violations by type: $violationTypeTotals');
}

void _processAllAnalytics({String? schoolYear}) {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final selectedSchoolYear = schoolYear ?? counselorProvider.selectedSchoolYear ?? 'all';
  
  debugPrint("🔄 Processing analytics for school year: $selectedSchoolYear");
  
  // Filter reports by school year
  List<Map<String, dynamic>> filteredStudentReports;
  List<Map<String, dynamic>> filteredTeacherReports;
  List<Map<String, dynamic>> filteredViolations;
  
  if (selectedSchoolYear == 'all') {
    filteredStudentReports = _studentReports;
    filteredTeacherReports = _teacherReports;
    filteredViolations = counselorProvider.studentViolations;
  } else {
    // Filter student reports
    filteredStudentReports = _studentReports.where((report) {
      final reportSchoolYear = report['school_year']?.toString() ?? 
                              report['reported_student']?['school_year']?.toString() ?? '';
      return reportSchoolYear == selectedSchoolYear;
    }).toList();
    
    // Filter teacher reports
    filteredTeacherReports = _teacherReports.where((report) {
      final reportSchoolYear = report['school_year']?.toString() ?? 
                              report['student']?['school_year']?.toString() ?? '';
      return reportSchoolYear == selectedSchoolYear;
    }).toList();
    
    // Filter violations
    filteredViolations = counselorProvider.studentViolations.where((violation) {
      final violationSchoolYear = violation['school_year']?.toString() ?? 
                                  violation['student']?['school_year']?.toString() ?? '';
      return violationSchoolYear == selectedSchoolYear;
    }).toList();
  }
  
  debugPrint("📊 Filtered data counts:");
  debugPrint("   Student Reports: ${filteredStudentReports.length}");
  debugPrint("   Teacher Reports: ${filteredTeacherReports.length}");
  debugPrint("   Violations: ${filteredViolations.length}");
  
  // Count counselor-recorded violations (no linked report)
  final counselorRecordedCount = filteredViolations.where((v) {
    final hasNoReport = v['related_report_id'] == null && 
                       v['related_report'] == null &&
                       v['related_student_report_id'] == null &&
                       v['related_student_report'] == null &&
                       v['related_teacher_report_id'] == null &&
                       v['related_teacher_report'] == null;
    
    final isCounselorRecorded = v['counselor'] != null || 
                               v['recorded_by'] == 'counselor';
    
    return hasNoReport && isCounselorRecorded;
  }).length;
  
  debugPrint("   Counselor-Recorded Violations: $counselorRecordedCount");
  
  // ✅ UPDATED: Process report status counts INCLUDING invalid reports
  final pendingStudentReports = filteredStudentReports.where((r) => 
    r['status']?.toString() == 'pending'
  ).length;
  
  final pendingTeacherReports = filteredTeacherReports.where((r) => 
    r['status']?.toString() == 'pending'
  ).length;
  
  final reviewedStudentReports = filteredStudentReports.where((r) => 
    r['status']?.toString() == 'reviewed' || r['status']?.toString() == 'under_review'
  ).length;
  
  final reviewedTeacherReports = filteredTeacherReports.where((r) => 
    r['status']?.toString() == 'reviewed' || r['status']?.toString() == 'under_review'
  ).length;
  
  final resolvedStudentReports = filteredStudentReports.where((r) => 
    r['status']?.toString() == 'resolved'
  ).length;
  
  final resolvedTeacherReports = filteredTeacherReports.where((r) => 
    r['status']?.toString() == 'resolved'
  ).length;
  
  // ✅ NEW: Count invalid reports
  final invalidStudentReports = filteredStudentReports.where((r) => 
    r['status']?.toString() == 'invalid' || r['status']?.toString() == 'dismissed'
  ).length;
  
  final invalidTeacherReports = filteredTeacherReports.where((r) => 
    r['status']?.toString() == 'invalid' || r['status']?.toString() == 'dismissed'
  ).length;
  
  // ✅ UPDATED: Include counselor-recorded and invalid in total
  _reportStatusCounts = {
    'pending': pendingStudentReports + pendingTeacherReports,
    'reviewed': reviewedStudentReports + reviewedTeacherReports,
    'resolved': resolvedStudentReports + resolvedTeacherReports,
    'invalid': invalidStudentReports + invalidTeacherReports,  // ✅ NEW
    'counselor_recorded': counselorRecordedCount,
    'total': filteredStudentReports.length + filteredTeacherReports.length + counselorRecordedCount,
  };
  
  debugPrint("📊 Status counts: $_reportStatusCounts");
  
  // Process violation types from FILTERED violations (normalize names)
  _violationTypeCounts = {};
  
  debugPrint("📋 Processing ${filteredViolations.length} violations...");
  
  for (final violation in filteredViolations) {
    final v = violation as Map<String, dynamic>;
    final name = _violationNameFromRecord(v);
    _violationTypeCounts[name] = (_violationTypeCounts[name] ?? 0) + 1;
  }
  
  debugPrint("📊 Violation types: $_violationTypeCounts");
  
  // Process monthly trends from FILTERED reports
_monthlyReportTrends = {};

final allFilteredReports = [...filteredStudentReports, ...filteredTeacherReports];

// ✅ ADD: Include counselor-recorded violations in monthly trends
for (final violation in filteredViolations) {
  final hasNoReport = violation['related_report_id'] == null && 
                     violation['related_report'] == null &&
                     violation['related_student_report_id'] == null &&
                     violation['related_student_report'] == null &&
                     violation['related_teacher_report_id'] == null &&
                     violation['related_teacher_report'] == null;
  
  final isCounselorRecorded = violation['counselor'] != null || 
                             violation['recorded_by'] == 'counselor';
  
  if (hasNoReport && isCounselorRecorded) {
    try {
      final createdAt = violation['created_at']?.toString() ?? 
                       violation['date']?.toString() ?? '';
      if (createdAt.isNotEmpty) {
        final monthKey = createdAt.substring(0, 7);
        _monthlyReportTrends[monthKey] = (_monthlyReportTrends[monthKey] ?? 0) + 1;
      }
    } catch (e) {
      debugPrint("⚠️ Error parsing date for counselor-recorded violation: $e");
    }
  }
}

// Add student and teacher reports
for (final report in allFilteredReports) {
  try {
    final createdAt = report['created_at']?.toString() ?? '';
    if (createdAt.isNotEmpty) {
      final monthKey = createdAt.substring(0, 7);
      _monthlyReportTrends[monthKey] = (_monthlyReportTrends[monthKey] ?? 0) + 1;
    }
  } catch (e) {
    debugPrint("⚠️ Error parsing date for report: $e");
  }
}

debugPrint("📊 Monthly trends (including counselor reports): $_monthlyReportTrends");
  
  // Process risk analysis with filtered data
  _processPrescriptiveAnalytics();
  _processBehavioralPatterns();

  debugPrint("✅ Analytics processing complete for S.Y. $selectedSchoolYear");
}

// Replace the _buildBehavioralPatternCard method with this:

Widget _buildBehavioralPatternCard() {
  return Consumer<CounselorProvider>(
    builder: (context, provider, child) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isDesktop = AppBreakpoints.isDesktop(screenWidth);
          final isTablet = AppBreakpoints.isTablet(screenWidth);
          final selectedSchoolYear = provider.selectedSchoolYear ?? 'all';

          final monthlyTotals = _calculateMonthlyTalliedReports();

          return Card(
            elevation: isDesktop ? 4 : 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
            ),
            child: Padding(
              padding: EdgeInsets.all(isDesktop ? 24 : (isTablet ? 20 : 16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.show_chart,
                        color: Colors.purple.shade700,
                        size: isDesktop ? 28 : 24,
                      ),
                      SizedBox(width: isDesktop ? 12 : 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student Behavior Over Time',
                              style: TextStyle(
                                fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              selectedSchoolYear == 'all'
                                  ? 'Total tallied violations trend (All Years)'
                                  : 'Total tallied violations trend - S.Y. $selectedSchoolYear',
                              style: TextStyle(
                                fontSize: isDesktop ? 13 : 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isDesktop ? 20 : 16),

                  // Filter Controls
                  _buildSimpleGraphFilters(isDesktop: isDesktop, isTablet: isTablet),
                  SizedBox(height: isDesktop ? 20 : 16),
                  
                  if (monthlyTotals.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(isDesktop ? 32 : 20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.filter_alt_off,
                              size: isDesktop ? 64 : 48,
                              color: Colors.grey.shade300,
                            ),
                            SizedBox(height: isDesktop ? 16 : 12),
                            Text(
                              _selectedFilterYear != null || _selectedFilterMonth != null
                                  ? 'No tallied violation data for selected filters'
                                  : selectedSchoolYear == 'all'
                                      ? 'No tallied violation data available'
                                      : 'No tallied violation data for S.Y. $selectedSchoolYear',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isDesktop ? 16 : 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (_selectedFilterYear != null || _selectedFilterMonth != null) ...[
                              SizedBox(height: 16),
                              TextButton.icon(
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear Filters'),
                                onPressed: () {
                                  setState(() {
                                    _selectedFilterYear = null;
                                    _selectedFilterMonth = null;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // Summary statistics
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 16 : 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade50, Colors.purple.shade100],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            'Total Tallied',
                            '${monthlyTotals.values.fold(0, (sum, count) => sum + count)}',
                            Icons.warning_amber,
                            Colors.purple.shade700,
                            isDesktop: isDesktop,
                          ),
                          Container(
                            width: 1,
                            height: isDesktop ? 40 : 30,
                            color: Colors.purple.shade300,
                          ),
                          _buildSummaryItem(
                            'Months Tracked',
                            '${monthlyTotals.length}',
                            Icons.calendar_today,
                            Colors.purple.shade700,
                            isDesktop: isDesktop,
                          ),
                          Container(
                            width: 1,
                            height: isDesktop ? 40 : 30,
                            color: Colors.purple.shade300,
                          ),
                          _buildSummaryItem(
                            'Average/Month',
                            '${(monthlyTotals.values.fold(0, (sum, count) => sum + count) / monthlyTotals.length).round()}',
                            Icons.trending_up,
                            Colors.purple.shade700,
                            isDesktop: isDesktop,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isDesktop ? 20 : 16),
                    
                    // ✅ LINE GRAPH instead of bar chart
                    SizedBox(
                      height: isDesktop ? 300 : 250,
                      child: _buildTalliedViolationsLineGraph(monthlyTotals, isDesktop: isDesktop),
                    ),
                    
                    // ✅ DESCRIPTIVE ANALYTICS
                    SizedBox(height: isDesktop ? 20 : 16),
                    _buildDescriptiveAnalytics(monthlyTotals, isDesktop: isDesktop),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ✅ NEW: Line graph for tallied violations
Widget _buildTalliedViolationsLineGraph(Map<String, int> monthlyTotals, {required bool isDesktop}) {
  if (monthlyTotals.isEmpty) return const SizedBox();
  
  return CustomPaint(
    painter: TalliedViolationsLineGraphPainter(
      monthlyTotals: monthlyTotals,
      isDesktop: isDesktop,
    ),
    child: Container(),
  );
}

// ✅ NEW: Descriptive Analytics Section
Widget _buildDescriptiveAnalytics(Map<String, int> monthlyTotals, {required bool isDesktop}) {
  if (monthlyTotals.isEmpty || monthlyTotals.length < 2) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 12 : 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue.shade700, size: isDesktop ? 20 : 18),
          SizedBox(width: isDesktop ? 12 : 8),
          const Expanded(
            child: Text(
              'Need at least 2 months of data for descriptive analysis',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  final sortedMonths = monthlyTotals.keys.toList()..sort();
  final values = sortedMonths.map((month) => monthlyTotals[month]!).toList();
  
  // Calculate statistics
  final total = values.fold(0, (sum, count) => sum + count);
  final average = (total / values.length).toStringAsFixed(1);
  final maxValue = values.reduce((a, b) => a > b ? a : b);
  final minValue = values.reduce((a, b) => a < b ? a : b);
  final maxMonth = sortedMonths[values.indexOf(maxValue)];
  final minMonth = sortedMonths[values.indexOf(minValue)];
  
  // Calculate standard deviation
  final mean = total / values.length;
  final variance = values.fold(0.0, (sum, value) => sum + ((value - mean) * (value - mean))) / values.length;
  final stdDev = sqrt(variance).toStringAsFixed(1);
  
  // Calculate trend (linear regression slope)
  double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
  for (int i = 0; i < values.length; i++) {
    sumX += i;
    sumY += values[i];
    sumXY += i * values[i];
    sumX2 += i * i;
  }
  final n = values.length;
  final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  
  // Determine trend direction
  String trendDescription;
  Color trendColor;
  IconData trendIcon;
  
  if (slope > 0.5) {
    trendDescription = 'Increasing Trend';
    trendColor = Colors.red;
    trendIcon = Icons.trending_up;
  } else if (slope < -0.5) {
    trendDescription = 'Decreasing Trend';
    trendColor = Colors.green;
    trendIcon = Icons.trending_down;
  } else {
    trendDescription = 'Stable Pattern';
    trendColor = Colors.blue;
    trendIcon = Icons.horizontal_rule;
  }
  
  // Calculate recent trend
  String recentTrendText = '';
  if (values.length >= 6) {
    final recentAvg = values.sublist(values.length - 3).fold(0, (sum, v) => sum + v) / 3;
    final previousAvg = values.sublist(values.length - 6, values.length - 3).fold(0, (sum, v) => sum + v) / 3;
    final change = ((recentAvg - previousAvg) / previousAvg * 100).toStringAsFixed(1);
    
    if (recentAvg > previousAvg) {
      recentTrendText = 'Recent 3-month average increased by $change% compared to previous 3 months.';
    } else if (recentAvg < previousAvg) {
      recentTrendText = 'Recent 3-month average decreased by ${change.replaceAll('-', '')}% compared to previous 3 months.';
    } else {
      recentTrendText = 'Recent 3-month average remained stable.';
    }
  }
  
  return Column(
    children: [
      // Trend Summary Card
      Container(
        padding: EdgeInsets.all(isDesktop ? 16 : 12),
        decoration: BoxDecoration(
          color: trendColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: trendColor.withOpacity(0.3), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isDesktop ? 10 : 8),
                  decoration: BoxDecoration(
                    color: trendColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(trendIcon, color: Colors.white, size: isDesktop ? 24 : 20),
                ),
                SizedBox(width: isDesktop ? 16 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trendDescription,
                        style: TextStyle(
                          fontSize: isDesktop ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: trendColor,
                        ),
                      ),
                      if (recentTrendText.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          recentTrendText,
                          style: TextStyle(
                            fontSize: isDesktop ? 13 : 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      
      SizedBox(height: isDesktop ? 16 : 12),
      
      // Statistical Summary Cards
      Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Average',
              average,
              'per month',
              Colors.blue,
              Icons.show_chart,
              isDesktop: isDesktop,
            ),
          ),
          SizedBox(width: isDesktop ? 12 : 10),
          Expanded(
            child: _buildStatCard(
              'Peak Month',
              '$maxValue',
              _formatMonthLabel(maxMonth),
              Colors.red,
              Icons.arrow_upward,
              isDesktop: isDesktop,
            ),
          ),
          SizedBox(width: isDesktop ? 12 : 10),
          Expanded(
            child: _buildStatCard(
              'Lowest Month',
              '$minValue',
              _formatMonthLabel(minMonth),
              Colors.green,
              Icons.arrow_downward,
              isDesktop: isDesktop,
            ),
          ),
        ],
      ),
      
      SizedBox(height: isDesktop ? 16 : 12),
      
      // Detailed Analysis
      Container(
        padding: EdgeInsets.all(isDesktop ? 16 : 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple.shade700, size: isDesktop ? 20 : 18),
                SizedBox(width: isDesktop ? 8 : 6),
                Text(
                  'Descriptive Analytics',
                  style: TextStyle(
                    fontSize: isDesktop ? 15 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? 12 : 10),
            
            _buildAnalyticsRow(
              'Data Range',
              '${_formatMonthLabel(sortedMonths.first)} to ${_formatMonthLabel(sortedMonths.last)}',
              Icons.date_range,
              isDesktop: isDesktop,
            ),
            _buildAnalyticsRow(
              'Total Violations',
              '$total violations recorded',
              Icons.warning_amber,
              isDesktop: isDesktop,
            ),
            _buildAnalyticsRow(
              'Variability',
              'Standard Deviation: $stdDev violations',
              Icons.scatter_plot,
              isDesktop: isDesktop,
            ),
            _buildAnalyticsRow(
              'Range',
              'Min: $minValue, Max: $maxValue (Difference: ${maxValue - minValue})',
              Icons.straighten,
              isDesktop: isDesktop,
            ),
            
            // Interpretation
            SizedBox(height: isDesktop ? 12 : 10),
            Container(
              padding: EdgeInsets.all(isDesktop ? 12 : 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb, color: Colors.blue.shade700, size: isDesktop ? 18 : 16),
                  SizedBox(width: isDesktop ? 10 : 8),
                  Expanded(
                    child: Text(
                      _getInterpretation(slope, double.parse(stdDev), average, maxValue, minValue),
                      style: TextStyle(
                        fontSize: isDesktop ? 12 : 11,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Map<String, int> _calculateMonthlyTalliedReports() {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final selectedSchoolYear = counselorProvider.selectedSchoolYear ?? 'all';
  
  // ✅ FIX: Get ALL tallied violations (matching overview card logic)
  final allViolations = counselorProvider.studentViolations;
  
  final talliedViolations = allViolations.where((violation) {
    // Must have a related report OR be counselor-recorded
    final hasRelatedReport = violation['related_report_id'] != null || 
                             violation['related_report'] != null ||
                             violation['related_student_report_id'] != null ||
                             violation['related_student_report'] != null ||
                             violation['related_teacher_report_id'] != null ||
                             violation['related_teacher_report'] != null;
    
    final isCounselorRecorded = violation['counselor'] != null || 
                               violation['recorded_by'] == 'counselor';
    
    // ✅ Include both tallied reports AND counselor-recorded violations
    if (!hasRelatedReport && !isCounselorRecorded) return false;
    
    // Filter by school year ONLY (not by month/year filters)
    if (selectedSchoolYear == 'all') return true;
    
    final violationSchoolYear = violation['school_year']?.toString() ?? 
                                violation['student']?['school_year']?.toString() ?? '';
    return violationSchoolYear == selectedSchoolYear;
  }).toList();
  
  debugPrint('📊 Total tallied violations (matching overview): ${talliedViolations.length}');
  
  final monthlyTotals = <String, int>{};
  
  for (final violation in talliedViolations) {
    try {
      final createdAt = violation['created_at']?.toString() ?? 
                       violation['date']?.toString() ?? '';
      
      if (createdAt.isEmpty) continue;
      
      // Parse the date and normalize to the 1st day of the month
      final date = DateTime.parse(createdAt);
      final normalizedDate = DateTime(date.year, date.month, 1);
      final monthKey = '${normalizedDate.year}-${normalizedDate.month.toString().padLeft(2, '0')}-01';
      
      monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0) + 1;
    } catch (e) {
      debugPrint('⚠️ Error processing violation date: $e');
    }
  }
  
  debugPrint('📊 Monthly breakdown before filters: $monthlyTotals');
  
  // ✅ Apply year/month filters ONLY for display (not for total count)
  if (_selectedFilterYear != null || _selectedFilterMonth != null) {
    final filteredTotals = <String, int>{};
    
    for (final entry in monthlyTotals.entries) {
      try {
        final date = DateTime.parse(entry.key);
        
        bool matchesYear = _selectedFilterYear == null || date.year.toString() == _selectedFilterYear;
        bool matchesMonth = _selectedFilterMonth == null || date.month == _selectedFilterMonth;
        
        if (matchesYear && matchesMonth) {
          filteredTotals[entry.key] = entry.value;
        }
      } catch (e) {
        debugPrint('⚠️ Error filtering month: $e');
      }
    }
    
    debugPrint('📊 Filtered display: ${filteredTotals.values.fold(0, (sum, count) => sum + count)} violations');
    debugPrint('📊 Total (unfiltered): ${monthlyTotals.values.fold(0, (sum, count) => sum + count)} violations');
    
    return filteredTotals;
  }
  
  debugPrint('📊 All monthly totals (no filters): ${monthlyTotals.values.fold(0, (sum, count) => sum + count)} violations');
  return monthlyTotals;
}

// ✅ ADD: Build simple graph filters
Widget _buildSimpleGraphFilters({required bool isDesktop, required bool isTablet}) {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final selectedSchoolYear = counselorProvider.selectedSchoolYear ?? 'all';
  
  final monthlyTotals = _calculateMonthlyTalliedReports();
  final availableYears = monthlyTotals.keys
      .map((monthKey) => monthKey.substring(0, 4))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a));

  return Container(
    padding: EdgeInsets.all(isDesktop ? 16 : 12),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.filter_alt, size: isDesktop ? 20 : 18, color: Colors.purple.shade700),
            SizedBox(width: isDesktop ? 8 : 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter Graph',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 15 : 14,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  if (selectedSchoolYear != 'all') ...[
                    SizedBox(height: 2),
                    Text(
                      'Data filtered for S.Y. $selectedSchoolYear',
                      style: TextStyle(
                        fontSize: isDesktop ? 11 : 10,
                        color: Colors.purple.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_selectedFilterYear != null || _selectedFilterMonth != null)
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 12 : 8,
                    vertical: isDesktop ? 8 : 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  setState(() {
                    _selectedFilterYear = null;
                    _selectedFilterMonth = null;
                  });
                },
              ),
          ],
        ),
        SizedBox(height: isDesktop ? 12 : 10),
        
        if (isDesktop || isTablet)
          Row(
            children: [
              Expanded(child: _buildYearFilter(availableYears, isDesktop)),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(child: _buildMonthFilter(isDesktop)),
            ],
          )
        else
          Column(
            children: [
              _buildYearFilter(availableYears, isDesktop),
              const SizedBox(height: 12),
              _buildMonthFilter(isDesktop),
            ],
          ),
      ],
    ),
  );
}

// ✅ ADD: Build summary item
Widget _buildSummaryItem(
  String label,
  String value,
  IconData icon,
  Color color, {
  required bool isDesktop,
}) {
  return Column(
    children: [
      Icon(icon, color: color, size: isDesktop ? 28 : 24),
      SizedBox(height: isDesktop ? 8 : 6),
      Text(
        value,
        style: TextStyle(
          fontSize: isDesktop ? 24 : 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          fontSize: isDesktop ? 12 : 11,
          color: Colors.grey.shade600,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

// ✅ Helper: Build stat card for analytics
Widget _buildStatCard(
  String label,
  String value,
  String subtitle,
  Color color,
  IconData icon, {
  required bool isDesktop,
}) {
  return Container(
    padding: EdgeInsets.all(isDesktop ? 12 : 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: isDesktop ? 24 : 20),
        SizedBox(height: isDesktop ? 8 : 6),
        Text(
          value,
          style: TextStyle(
            fontSize: isDesktop ? 20 : 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isDesktop ? 11 : 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: isDesktop ? 10 : 9,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// ✅ Helper: Build analytics row
Widget _buildAnalyticsRow(String label, String value, IconData icon, {required bool isDesktop}) {
  return Padding(
    padding: EdgeInsets.only(bottom: isDesktop ? 8 : 6),
    child: Row(
      children: [
        Icon(icon, size: isDesktop ? 16 : 14, color: Colors.grey.shade600),
        SizedBox(width: isDesktop ? 8 : 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: isDesktop ? 13 : 12, color: Colors.grey.shade800),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ✅ Helper: Get interpretation text
String _getInterpretation(double slope, double stdDev, String average, int maxValue, int minValue) {
  final avgNum = double.parse(average);
  final variability = (stdDev / avgNum * 100).toStringAsFixed(1);
  
  String interpretation = 'Interpretation: ';
  
  if (slope > 0.5) {
    interpretation += 'There is a concerning upward trend in violations, suggesting increasing behavioral issues. ';
  } else if (slope < -0.5) {
    interpretation += 'There is a positive downward trend in violations, indicating improvement in student behavior. ';
  } else {
    interpretation += 'Violations remain relatively stable over time with no significant increasing or decreasing pattern. ';
  }
  
  if (double.parse(variability) > 30) {
    interpretation += 'High variability ($variability%) indicates inconsistent patterns, possibly due to external factors or seasonal effects.';
  } else if (double.parse(variability) > 15) {
    interpretation += 'Moderate variability ($variability%) shows some fluctuation in behavior patterns.';
  } else {
    interpretation += 'Low variability ($variability%) indicates consistent behavior patterns across months.';
  }
  
  return interpretation;
}                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 

// ✅ NEW: Build filter controls                                                                                                                                                                                                                                                                                                                                                                    
Widget _buildGraphFilters({required bool isDesktop, required bool isTablet}) {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final selectedSchoolYear = counselorProvider.selectedSchoolYear ?? 'all';
  
  // Get available years from data
  final availableYears = _behavioralPatterns.keys
      .map((monthKey) => monthKey.substring(0, 4))
      .toSet()
      .toList()
    ..sort((a, b) => b.compareTo(a)); // Sort descending

  return Container(
    padding: EdgeInsets.all(isDesktop ? 16 : 12),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.filter_alt, size: isDesktop ? 20 : 18, color: Colors.purple.shade700),
            SizedBox(width: isDesktop ? 8 : 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter Graph',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 15 : 14,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  if (selectedSchoolYear != 'all') ...[
                    SizedBox(height: 2),
                    Text(
                      'Data filtered for S.Y. $selectedSchoolYear',
                      style: TextStyle(
                        fontSize: isDesktop ? 11 : 10,
                        color: Colors.purple.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_selectedFilterYear != null || _selectedFilterMonth != null)
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 12 : 8,
                    vertical: isDesktop ? 8 : 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  setState(() {
                    _selectedFilterYear = null;
                    _selectedFilterMonth = null;
                  });
                },
              ),
          ],
        ),
        SizedBox(height: isDesktop ? 12 : 10),
        
        // Responsive layout for filters
        if (isDesktop || isTablet)
          Row(
            children: [
              Expanded(child: _buildYearFilter(availableYears, isDesktop)),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(child: _buildMonthFilter(isDesktop)),
            ],
          )
        else
          Column(
            children: [
              _buildYearFilter(availableYears, isDesktop),
              const SizedBox(height: 12),
              _buildMonthFilter(isDesktop),
            ],
          ),
      ],
    ),
  );
}

// ✅ NEW: Year filter dropdown
Widget _buildYearFilter(List<String> availableYears, bool isDesktop) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Year',
        style: TextStyle(
          fontSize: isDesktop ? 13 : 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonFormField<String>(
          value: _selectedFilterYear,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 12 : 10,
              vertical: isDesktop ? 12 : 10,
            ),
            border: InputBorder.none,
            hintText: 'All Years',
            hintStyle: TextStyle(fontSize: isDesktop ? 14 : 13),
          ),
          style: TextStyle(
            fontSize: isDesktop ? 14 : 13,
            color: Colors.black87,
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('All Years'),
            ),
            ...availableYears.map((year) => DropdownMenuItem(
              value: year,
              child: Text(year),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedFilterYear = value;
            });
          },
        ),
      ),
    ],
  );
}

// ✅ NEW: Month filter dropdown
Widget _buildMonthFilter(bool isDesktop) {
  final months = [
    {'value': null, 'label': 'All Months'},
    {'value': 1, 'label': 'January'},
    {'value': 2, 'label': 'February'},
    {'value': 3, 'label': 'March'},
    {'value': 4, 'label': 'April'},
    {'value': 5, 'label': 'May'},
    {'value': 6, 'label': 'June'},
    {'value': 7, 'label': 'July'},
    {'value': 8, 'label': 'August'},
    {'value': 9, 'label': 'September'},
    {'value': 10, 'label': 'October'},
    {'value': 11, 'label': 'November'},
    {'value': 12, 'label': 'December'},
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Month',
        style: TextStyle(
          fontSize: isDesktop ? 13 : 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonFormField<int>(
          value: _selectedFilterMonth,
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 12 : 10,
              vertical: isDesktop ? 12 : 10,
            ),
            border: InputBorder.none,
            hintText: 'All Months',
            hintStyle: TextStyle(fontSize: isDesktop ? 14 : 13),
          ),
          style: TextStyle(
            fontSize: isDesktop ? 14 : 13,
            color: Colors.black87,
          ),
          items: months.map((month) => DropdownMenuItem<int>(
            value: month['value'] as int?,
            child: Text(month['label'] as String),
          )).toList(),
          onChanged: (value) {
            setState(() {
              _selectedFilterMonth = value;
            });
          },
        ),
      ),
    ],
  );
}

// ✅ NEW: Get filtered behavioral patterns
Map<String, Map<String, int>> _getFilteredBehavioralPatterns() {
  if (_selectedFilterYear == null && _selectedFilterMonth == null) {
    return _behavioralPatterns;
  }

  final filtered = <String, Map<String, int>>{};

  for (final entry in _behavioralPatterns.entries) {
    final monthKey = entry.key; // Format: YYYY-MM
    final parts = monthKey.split('-');
    
    if (parts.length != 2) continue;
    
    final year = parts[0];
    final month = int.tryParse(parts[1]);
    
    if (month == null) continue;

    // Apply filters
    bool matchesYear = _selectedFilterYear == null || year == _selectedFilterYear;
    bool matchesMonth = _selectedFilterMonth == null || month == _selectedFilterMonth;

    if (matchesYear && matchesMonth) {
      filtered[monthKey] = entry.value;
    }
  }

  return filtered;
}

Widget _buildLineGraph({required bool isDesktop}) {
  // ✅ Use filtered data instead of raw data
  final filteredData = _getFilteredBehavioralPatterns();
  
  // Sort months chronologically
  final sortedMonths = filteredData.keys.toList()
    ..sort();
  
  // ✅ Need at least 2 months for a meaningful line graph
  if (sortedMonths.isEmpty || sortedMonths.length < 2) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 32 : 20),
        child: Column(
          children: [
            Icon(
              Icons.show_chart,
              size: isDesktop ? 64 : 48,
              color: Colors.grey.shade300,
            ),
            SizedBox(height: isDesktop ? 16 : 12),
            Text(
              sortedMonths.isEmpty 
                  ? 'No data available for selected filters'
                  : 'Need at least 2 months of data to show trends',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Find max value for scaling
  int maxValue = 0;
  for (final month in sortedMonths) {
    for (final type in _selectedViolationTypes) {
      final count = filteredData[month]?[type] ?? 0;
      if (count > maxValue) maxValue = count;
    }
  }
  
  // ✅ Ensure maxValue is never 0 to avoid division by zero
  if (maxValue == 0) maxValue = 1;
  
  return CustomPaint(
    painter: LineGraphPainter(
      months: sortedMonths,
      violationTypes: _selectedViolationTypes,
      data: filteredData, // ✅ Pass filtered data
      maxValue: maxValue,
      isDesktop: isDesktop,
    ),
    child: Container(),
  );
}

Color _getViolationColorForIndex(int index) {
  final colors = [
    Colors.red,
    Colors.orange,
    Colors.blue,
    Colors.green,
    Colors.purple,
  ];
  return colors[index % colors.length];
}

Widget _buildBehavioralInsights({required bool isDesktop}) {
  // ✅ Use filtered data
  final filteredData = _getFilteredBehavioralPatterns();
  
  if (filteredData.isEmpty || _selectedViolationTypes.isEmpty) {
    return const SizedBox();
  }
  
  // Calculate insights
  final sortedMonths = filteredData.keys.toList()..sort();
  if (sortedMonths.length < 2) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 12 : 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: Colors.blue.shade700, size: isDesktop ? 20 : 18),
          SizedBox(width: isDesktop ? 12 : 8),
          const Expanded(
            child: Text(
              'Need more data to analyze behavioral trends',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  // Get latest and previous month
  final latestMonth = sortedMonths.last;
  final previousMonth = sortedMonths[sortedMonths.length - 2];
  
  // Find most increasing violation type
  String? mostIncreasingType;
  int maxIncrease = 0;
  
  for (final type in _selectedViolationTypes) {
    final latest = filteredData[latestMonth]?[type] ?? 0;
    final previous = filteredData[previousMonth]?[type] ?? 0;
    final increase = latest - previous;
    
    if (increase > maxIncrease) {
      maxIncrease = increase;
      mostIncreasingType = type;
    }
  }
  
  if (mostIncreasingType != null && maxIncrease > 0) {
    final previousCount = filteredData[previousMonth]?[mostIncreasingType] ?? 0;
    final percentIncrease = previousCount > 0 
        ? ((maxIncrease / previousCount) * 100).toStringAsFixed(1)
        : '100';
    
    return Container(
      padding: EdgeInsets.all(isDesktop ? 12 : 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.trending_up, color: Colors.orange.shade700, size: isDesktop ? 20 : 18),
          SizedBox(width: isDesktop ? 12 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ Rising Trend Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 13 : 12,
                    color: Colors.orange.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '$mostIncreasingType violations increased by $percentIncrease% '
                  'from ${_formatMonthLabel(previousMonth)} to ${_formatMonthLabel(latestMonth)}. '
                  'Consider implementing targeted interventions.',
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 11,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  return Container(
    padding: EdgeInsets.all(isDesktop ? 12 : 10),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.green.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.check_circle, color: Colors.green.shade700, size: isDesktop ? 20 : 18),
        SizedBox(width: isDesktop ? 12 : 8),
        const Expanded(
          child: Text(
            '✅ Behavioral patterns are stable or improving',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

Future<void> _fetchRecentlyHandledStudents() async {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  
  try {
    // Get counseling sessions from the last 7 days
    final counselingSessions = counselorProvider.counselingSessions;
    
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    
    // Find students who had counseling sessions in the last 7 days
    final recentStudentIds = <int>{};
    
    for (final session in counselingSessions) {
      try {
        final sessionDate = DateTime.parse(session['created_at'] ?? session['scheduled_date'] ?? '');
        
        if (sessionDate.isAfter(sevenDaysAgo) && 
            (session['status'] == 'completed' || session['status'] == 'scheduled')) {
          final studentId = session['student_id'];
          if (studentId != null) {
            recentStudentIds.add(studentId);
          }
        }
      } catch (e) {
        // Skip invalid dates
        continue;
      }
    }
    
    debugPrint('📊 Found ${recentStudentIds.length} students with recent counseling');
    debugPrint('📊 Recently handled students (last 7 days): ${recentStudentIds.length}');
    debugPrint('   Student IDs: $recentStudentIds');
    
    // Get student details for recently counseled students
    final allViolations = counselorProvider.studentViolations;
    final studentViolationCounts = <int, Map<String, dynamic>>{};
    
    for (final violation in allViolations) {
      final studentId = violation['student_id'] ?? violation['student']?['id'];
      
      if (studentId != null && recentStudentIds.contains(studentId)) {
        if (!studentViolationCounts.containsKey(studentId)) {
          studentViolationCounts[studentId] = {
            'id': studentId,
            'name': violation['student_name'] ?? 
                   violation['student']?['name'] ?? 
                   'Unknown Student',
            'student_id': violation['student']?['student_id'] ?? '',
            'grade_level': violation['student']?['grade_level'] ?? '',
            'section': violation['student']?['section'] ?? '',
            'count': 0,
            'types': <String>[],
          };
        }
        
        studentViolationCounts[studentId]!['count'] = 
            (studentViolationCounts[studentId]!['count'] as int) + 1;
        
        final violationType = _violationNameFromRecord(violation);
        (studentViolationCounts[studentId]!['types'] as List<String>).add(violationType);
      }
    }
    
    // Only include students who have 3+ violations (were high-risk)
    recentlyHandledStudents = studentViolationCounts.values
        .where((student) => (student['count'] as int) >= 3)
        .toList();
    
    debugPrint('📊 High-risk students after filtering: ${recentlyHandledStudents.length}');
    
    // Log which students were skipped
    for (final studentId in recentStudentIds) {
      final student = studentViolationCounts[studentId];
      if (student != null) {
        final violationCount = student['count'] as int;
        if (violationCount >= 3) {
          debugPrint('✅ Including ${student['name']} - $violationCount violations (recently counseled)');
        } else {
          debugPrint('⏭️ Skipping ${student['name']} - only $violationCount violations');
        }
      } else {
        // Try to find student name from sessions
        final session = counselingSessions.firstWhere(
          (s) => s['student_id'] == studentId,
          orElse: () => {'student_name': 'Unknown Student'},
        );
        debugPrint('⏭️ Skipping ${session['student_name']} - recently counseled');
      }
    }
    
  } catch (e) {
    debugPrint('❌ Error fetching recently handled students: $e');
    recentlyHandledStudents = [];
  }
}

/// Fetch student reports from the server
Future<void> _fetchStudentReports() async {
  try {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    debugPrint('🔍 Fetching student reports...');
    
    // Use the existing method from counselor provider
    await counselorProvider.fetchStudentReports();
    
    if (mounted) {
      setState(() {
        _studentReports = counselorProvider.studentReports;
        _studentReportsCount = _studentReports.length;
      });
      
      debugPrint('✅ Student reports fetched: ${_studentReports.length} reports');
    }
  } catch (e) {
    debugPrint('❌ Error fetching student reports: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching student reports: $e'),
          backgroundColor: Colors.red,
        ),                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        
      );
    }
  }
}

/// Fetch teacher reports from the server
Future<void> _fetchTeacherReports() async {
  try {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    debugPrint('🔍 Fetching teacher reports...');
    
    // Use the existing method from counselor provider
    await counselorProvider.fetchTeacherReports();
    
    if (mounted) {
      setState(() {
        _teacherReports = counselorProvider.teacherReports;
        _teacherReportsCount = _teacherReports.length;
      });
      
      debugPrint('✅ Teacher reports fetched: ${_teacherReports.length} reports');
    }
  } catch (e) {
    debugPrint('❌ Error fetching teacher reports: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching teacher reports: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Show report filtering dialog
Future<void> _showReportFilterDialog() async {
  String? selectedStatus = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Filter Reports'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('All Reports'),
            onTap: () => Navigator.of(context).pop('all'),
          ),
          ListTile(
            title: const Text('Pending Only'),
            onTap: () => Navigator.of(context).pop('pending'),
          ),
          ListTile(
            title: const Text('Resolved Only'),
            onTap: () => Navigator.of(context).pop('resolved'),
          ),
          ListTile(
            title: const Text('Reviewed Only'),
            onTap: () => Navigator.of(context).pop('reviewed'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  
  if (selectedStatus != null) {
    // Apply filter logic here
    debugPrint('🔍 Filtering reports by status: $selectedStatus');
    // You can implement filtering logic based on selectedStatus
  }
}
}

class TalliedViolationsLineGraphPainter extends CustomPainter {
  final Map<String, int> monthlyTotals;
  final bool isDesktop;
  
  TalliedViolationsLineGraphPainter({
    required this.monthlyTotals,
    required this.isDesktop,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (monthlyTotals.isEmpty) return;
    
    final sortedMonths = monthlyTotals.keys.toList()..sort();
    final values = sortedMonths.map((month) => monthlyTotals[month]!).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    
    if (maxValue <= 0) return;
    
    // Margins
    final leftMargin = isDesktop ? 50.0 : 40.0;
    final rightMargin = isDesktop ? 20.0 : 15.0;
    final topMargin = isDesktop ? 20.0 : 15.0;
    final bottomMargin = isDesktop ? 50.0 : 40.0;
    
    final graphWidth = size.width - leftMargin - rightMargin;
    final graphHeight = size.height - topMargin - bottomMargin;
    
    if (graphWidth <= 0 || graphHeight <= 0) return;
    
    // Draw grid and axes
    _drawGridAndAxes(canvas, size, graphWidth, graphHeight, leftMargin, rightMargin, topMargin, bottomMargin, maxValue);
    
    // Draw the line
    _drawLine(canvas, sortedMonths, values, maxValue, graphWidth, graphHeight, leftMargin, topMargin);
    
    // Draw X-axis labels
    _drawXAxisLabels(canvas, size, sortedMonths, graphWidth, leftMargin, bottomMargin);
  }
  
  void _drawGridAndAxes(Canvas canvas, Size size, double graphWidth, double graphHeight, 
      double leftMargin, double rightMargin, double topMargin, double bottomMargin, int maxValue) {
    
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    // Y-axis grid lines and labels
    for (int i = 0; i <= 4; i++) {
      final y = topMargin + (graphHeight * i / 4);
      
      // Grid line
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width - rightMargin, y),
        gridPaint,
      );
      
      // Y-axis label
      final value = (maxValue * (4 - i) / 4).round();
      textPainter.text = TextSpan(
        text: '$value',
        style: TextStyle(
          fontSize: isDesktop ? 12 : 10,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 8, y - textPainter.height / 2),
      );
    }
    
    // Axes
    final axisPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 2;
    
    // Y-axis
    canvas.drawLine(
      Offset(leftMargin, topMargin),
      Offset(leftMargin, topMargin + graphHeight),
      axisPaint,
    );
    
    // X-axis
    canvas.drawLine(
      Offset(leftMargin, topMargin + graphHeight),
      Offset(size.width - rightMargin, topMargin + graphHeight),
      axisPaint,
    );
  }
  
  void _drawLine(Canvas canvas, List<String> sortedMonths, List<int> values, int maxValue,
      double graphWidth, double graphHeight, double leftMargin, double topMargin) {
    
    final linePaint = Paint()
      ..color = Colors.purple.shade700
      ..strokeWidth = isDesktop ? 3 : 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.purple.shade400.withOpacity(0.3),
          Colors.purple.shade100.withOpacity(0.1),
        ],
      ).createShader(Rect.fromLTWH(leftMargin, topMargin, graphWidth, graphHeight));
    
    final dotPaint = Paint()
      ..color = Colors.purple.shade700
      ..style = PaintingStyle.fill;
    
    final points = <Offset>[];
    
    for (int i = 0; i < sortedMonths.length; i++) {
      final divisor = sortedMonths.length > 1 ? (sortedMonths.length - 1) : 1;
      final x = leftMargin + (graphWidth * i / divisor);
      final normalizedValue = values[i] / maxValue;
      final y = topMargin + graphHeight - (graphHeight * normalizedValue);
      
      if (!x.isNaN && !y.isNaN && x.isFinite && y.isFinite) {
        points.add(Offset(x, y));
      }
    }
    
    if (points.isEmpty) return;
    
    // Draw filled area under line
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, topMargin + graphHeight);
    fillPath.lineTo(points.first.dx, points.first.dy);
    
    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    
    fillPath.lineTo(points.last.dx, topMargin + graphHeight);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw the line
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    
    canvas.drawPath(linePath, linePaint);
    
    // Draw dots and value labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      
      // Outer glow
      canvas.drawCircle(
        point,
        isDesktop ? 8 : 6,
        Paint()
          ..color = Colors.purple.shade200.withOpacity(0.5)
          ..style = PaintingStyle.fill,
      );
      
      // Main dot
      canvas.drawCircle(point, isDesktop ? 5 : 4, dotPaint);
      
      // White border
      canvas.drawCircle(
        point,
        isDesktop ? 5 : 4,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      
      // Value label above dot
      textPainter.text = TextSpan(
        text: '${values[i]}',
        style: TextStyle(
          fontSize: isDesktop ? 13 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.purple.shade900,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(point.dx - textPainter.width / 2, point.dy - textPainter.height - 8),
      );
    }
  }
  
  void _drawXAxisLabels(Canvas canvas, Size size, List<String> sortedMonths,
      double graphWidth, double leftMargin, double bottomMargin) {
    
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    for (int i = 0; i < sortedMonths.length; i++) {
      final divisor = sortedMonths.length > 1 ? (sortedMonths.length - 1) : 1;
      final x = leftMargin + (graphWidth * i / divisor);
      
      final monthLabel = _formatMonthLabel(sortedMonths[i]);
      final lines = monthLabel.split('\n');
      double yOffset = size.height - bottomMargin + 10;
      
      for (final line in lines) {
        textPainter.text = TextSpan(
          text: line,
          style: TextStyle(
            fontSize: isDesktop ? 11 : 9,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x - textPainter.width / 2, yOffset));
        yOffset += textPainter.height + 2;
      }
    }
  }
  
  String _formatMonthLabel(String monthKey) {
  try {
    // ✅ Handle both YYYY-MM-DD (from line graph) and YYYY-MM (from monthly trends)
    final parts = monthKey.split('-');
    if (parts.length >= 2) {
      final month = int.parse(parts[1]);
      final monthNames = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      if (month >= 1 && month <= 12) {
        return monthNames[month - 1]; // ✅ Only month name (Nov, Dec)
      }
    }
  } catch (e) {
    debugPrint('⚠️ Error formatting month label: $e');
  }
  return monthKey;
}
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LineGraphPainter extends CustomPainter {
  final List<String> months;
  final List<String> violationTypes;
  final Map<String, Map<String, int>> data;
  final int maxValue;
  final bool isDesktop;
  
  LineGraphPainter({
    required this.months,
    required this.violationTypes,
    required this.data,
    required this.maxValue,
    required this.isDesktop,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // ✅ Validate size
    if (size.width <= 0 || size.height <= 0) return;
    if (months.isEmpty || months.length < 2) return;
    if (maxValue <= 0) return;
    
    final paint = Paint()
      ..strokeWidth = isDesktop ? 2.5 : 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    final dotPaint = Paint()
      ..style = PaintingStyle.fill;
    
    // Calculate dimensions
    final leftMargin = isDesktop ? 50.0 : 40.0;
    final rightMargin = isDesktop ? 20.0 : 15.0;
    final topMargin = isDesktop ? 20.0 : 15.0;
    final bottomMargin = isDesktop ? 50.0 : 40.0; // ✅ Increased for rotated labels
    
    final graphWidth = size.width - leftMargin - rightMargin;
    final graphHeight = size.height - topMargin - bottomMargin;
    
    // ✅ Validate graph dimensions
    if (graphWidth <= 0 || graphHeight <= 0) return;
    
    // Draw grid lines and Y-axis labels
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    // Y-axis (4 grid lines + bottom line = 5 lines total)
    for (int i = 0; i <= 4; i++) {
      final y = topMargin + (graphHeight * i / 4);
      
      // Draw grid line
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width - rightMargin, y),
        gridPaint,
      );
      
      // Draw Y-axis label
      final value = (maxValue * (4 - i) / 4).round();
      textPainter.text = TextSpan(
        text: '$value',
        style: TextStyle(
          fontSize: isDesktop ? 12 : 10,
          color: Colors.grey.shade700,
        ),
      );
      textPainter.layout();
      
      final textY = y - textPainter.height / 2;
      if (textY >= 0 && textY + textPainter.height <= size.height) {
        textPainter.paint(
          canvas,
          Offset(leftMargin - textPainter.width - 8, textY),
        );
      }
    }
    
    // X-axis labels
    for (int i = 0; i < months.length; i++) {
      // ✅ Prevent division by zero
      final divisor = months.length > 1 ? (months.length - 1) : 1;
      final x = leftMargin + (graphWidth * i / divisor);
      
      final monthLabel = _formatMonthLabel(months[i]);
      
      // Draw month label (not rotated for better readability)
      final lines = monthLabel.split('\n');
      double yOffset = size.height - bottomMargin + 10;
      
      for (final line in lines) {
        textPainter.text = TextSpan(
          text: line,
          style: TextStyle(
            fontSize: isDesktop ? 11 : 9,
            color: Colors.grey.shade700,
          ),
        );
        textPainter.layout();
        
        final textX = x - textPainter.width / 2;
        if (textX >= 0 && textX + textPainter.width <= size.width) {
          textPainter.paint(canvas, Offset(textX, yOffset));
        }
        yOffset += textPainter.height + 2;
      }
    }
    
    // Draw lines for each violation type
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.blue,
      Colors.green,
      Colors.purple,
    ];
    
    for (int typeIndex = 0; typeIndex < violationTypes.length; typeIndex++) {
      final type = violationTypes[typeIndex];
      final color = colors[typeIndex % colors.length];
      
      paint.color = color;
      dotPaint.color = color;
      
      final points = <Offset>[];
      
      for (int i = 0; i < months.length; i++) {
        final month = months[i];
        final count = data[month]?[type] ?? 0;
        
        // ✅ Prevent division by zero
        final divisor = months.length > 1 ? (months.length - 1) : 1;
        final x = leftMargin + (graphWidth * i / divisor);
        
        // ✅ Safe division - maxValue is already validated to be > 0
        final normalizedValue = count / maxValue;
        final y = topMargin + graphHeight - (graphHeight * normalizedValue);
        
        // ✅ Validate point coordinates
        if (!x.isNaN && !y.isNaN && x.isFinite && y.isFinite) {
          points.add(Offset(x, y));
        }
      }
      
      // Draw line only if we have valid points
      if (points.length > 1) {
        final path = Path();
        path.moveTo(points[0].dx, points[0].dy);
        
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].dx, points[i].dy);
        }
        
        canvas.drawPath(path, paint);
      }
      
      // Draw dots
      for (final point in points) {
        // Draw filled dot
        canvas.drawCircle(point, isDesktop ? 4 : 3, dotPaint);
        
        // Draw white border
        canvas.drawCircle(
          point,
          isDesktop ? 4 : 3,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }
  
  String _formatMonthLabel(String monthKey) {
    try {
      final parts = monthKey.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final month = int.parse(parts[1]);
        final monthNames = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        if (month >= 1 && month <= 12) {
          return '${monthNames[month - 1]}\n\'${year.substring(2)}';
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error formatting month label: $e');
    }
    return monthKey;
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
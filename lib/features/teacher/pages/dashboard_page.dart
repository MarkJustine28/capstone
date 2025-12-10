import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/teacher_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/notification_widget.dart';
import '../../../config/routes.dart';
import '../pages/student_list_page.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({Key? key}) : super(key: key);

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  int _currentIndex = 0;
  bool _hasShownFrozenDialog = false; // ✅ Track if frozen dialog shown

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  // ✅ NEW: Initialize dashboard with system check
  Future<void> _initializeDashboard() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    if (authProvider.token != null) {
      teacherProvider.setToken(authProvider.token!);
      notificationProvider.setToken(authProvider.token!);
      
      try {
        // ✅ Check system status first
        await teacherProvider.fetchSystemSettings();
        
        if (!teacherProvider.isSystemActive && !_hasShownFrozenDialog) {
          _hasShownFrozenDialog = true;
          // Show system frozen dialog
          Future.delayed(Duration.zero, () => _showSystemFrozenDialog());
          return;
        }
        
        // Continue with normal initialization
        await _refreshData();
        
      } catch (e) {
        debugPrint('❌ Error initializing dashboard: $e');
        if (e is SystemFrozenException && !_hasShownFrozenDialog) {
          _hasShownFrozenDialog = true;
          Future.delayed(Duration.zero, () => _showSystemFrozenDialog());
        }
      }
    }
  }

  Future<void> _refreshData() async {
    final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
    
    try {
      await Future.wait([
        teacherProvider.fetchProfile(),
        teacherProvider.fetchAdvisingStudents(),
        teacherProvider.fetchReports(),
        teacherProvider.fetchNotifications(),
        teacherProvider.fetchViolationTypes(),
      ]);
    } on SystemFrozenException {
      if (!_hasShownFrozenDialog) {
        _hasShownFrozenDialog = true;
        _showSystemFrozenDialog();
      }
    } catch (e) {
      debugPrint('❌ Error refreshing data: $e');
    }
  }

  // ✅ NEW: Show system frozen dialog
  void _showSystemFrozenDialog() {
    final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
    
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
                  teacherProvider.systemMessage ?? 
                  'The Guidance Tracking System is currently frozen for maintenance or school break.\n\n'
                  'The system will be reactivated when the new school year begins or maintenance is complete.\n\n'
                  'Please contact the administrator if you need immediate access.',
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
                        teacherProvider.systemSchoolYear ?? 'N/A',
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
                  'Thank you for your patience!',
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
                await teacherProvider.logout();
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

  Future<void> _logout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 12),
            Text('Confirm Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    // If user confirmed, proceed with logout
    if (confirmed == true) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TeacherProvider>(
      builder: (context, provider, child) {
        // ✅ Show frozen screen if system is inactive
        if (!provider.isSystemActive) {
          return Scaffold(
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
          );
        }

        // Normal dashboard UI
        final List<Widget> pages = [
          _buildHomePage(),
          _buildStudentsPage(),
          _buildReportsPage(),
          _buildProfilePage(),
        ];

        return WillPopScope(
          onWillPop: () async => false,
          child: Scaffold(
            body: pages[_currentIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.blue.shade700,
              unselectedItemColor: Colors.grey,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'Students',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.report),
                  label: 'Reports',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
            floatingActionButton: _currentIndex == 0 || _currentIndex == 1
                ? FloatingActionButton.extended(
                    onPressed: () async {
                      final result = await Navigator.pushNamed(
                        context,
                        AppRoutes.teacherSubmitReport,
                      );
                      
                      if (result == true && mounted) {
                        _refreshData();
                      }
                    },
                    icon: const Icon(Icons.add_alert),
                    label: const Text('Report Violation'),
                    backgroundColor: Colors.red.shade600,
                  )
                : null,
          ),
        );
      },
    );
  }

  // ========== HOME PAGE ==========
  Widget _buildHomePage() {
    return Consumer<TeacherProvider>(
      builder: (context, teacherProvider, child) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: const Text('Teacher Dashboard'),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            actions: [
              const NotificationBell(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshData,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeCard(teacherProvider.teacherProfile),
                  const SizedBox(height: 20),
                  _buildAdvisingClassCard(teacherProvider),
                  const SizedBox(height: 20),
                  _buildQuickStats(teacherProvider),
                  const SizedBox(height: 20),
                  _buildRecentReports(teacherProvider),
                  const SizedBox(height: 20),
                  _buildNotificationsSection(teacherProvider),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeCard(Map<String, dynamic>? profile) {
    String displayName = 'Teacher';
    
    if (profile != null) {
      displayName = profile['full_name']?.toString() ?? '';
      
      if (displayName.isEmpty) {
        final firstName = profile['first_name']?.toString() ?? '';
        final lastName = profile['last_name']?.toString() ?? '';
        displayName = '$firstName $lastName'.trim();
      }
      
      if (displayName.isEmpty) {
        displayName = profile['username']?.toString() ?? 'Teacher';
      }
    }
    
    String initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';
    if (displayName.split(' ').length > 1) {
      final parts = displayName.split(' ');
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profile?['employee_id'] != null)
                    Text(
                      'ID: ${profile!['employee_id']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvisingClassCard(TeacherProvider teacherProvider) {
    final profile = teacherProvider.teacherProfile;
    final grade = profile?['advising_grade']?.toString() ?? '';
    final strand = profile?['advising_strand']?.toString() ?? '';
    final section = profile?['advising_section']?.toString() ?? '';
    
    String classInfo = '';
    if (grade.isNotEmpty && section.isNotEmpty) {
      if (['11', '12'].contains(grade) && strand.isNotEmpty) {
        classInfo = 'Grade $grade $strand - $section';
      } else {
        classInfo = 'Grade $grade - $section';
      }
    }
    
    final studentCount = teacherProvider.advisingStudents.length;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => setState(() => _currentIndex = 1),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: classInfo.isEmpty ? Colors.orange.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  classInfo.isEmpty ? Icons.info_outline : Icons.class_,
                  color: classInfo.isEmpty ? Colors.orange.shade700 : Colors.green.shade700,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classInfo.isEmpty ? 'No Advising Class' : 'My Advising Class',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      classInfo.isEmpty ? 'Not assigned yet' : classInfo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (classInfo.isNotEmpty)
                      Text(
                        '$studentCount ${studentCount == 1 ? 'student' : 'students'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(TeacherProvider teacherProvider) {
    final totalReports = teacherProvider.reports.length;
    final pendingReports = teacherProvider.reports
        .where((r) => r['status'] == 'pending')
        .length;
    final unreadNotifications = teacherProvider.notifications
        .where((n) => !(n['is_read'] ?? false))
        .length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Statistics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Reports',
                '$totalReports',
                Icons.assignment,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Pending',
                '$pendingReports',
                Icons.pending_actions,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'My Students',
                '${teacherProvider.advisingStudents.length}',
                Icons.people,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Notifications',
                '$unreadNotifications',
                Icons.notifications,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentReports(TeacherProvider teacherProvider) {
    final recentReports = teacherProvider.reports.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _currentIndex = 2),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (recentReports.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No reports submitted yet',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...recentReports.map((report) => Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(report['status']),
                child: Icon(
                  _getStatusIcon(report['status']),
                  color: Colors.white,
                  size: 18,
                ),
              ),
              title: Text(
                report['title'] ?? 'Untitled Report',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Status: ${_getStatusText(report['status'])} • ${_formatDate(report['created_at'])}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
              onTap: () => _showReportDetailsDialog(report),
            ),
          )),
      ],
    );
  }

  Widget _buildNotificationsSection(TeacherProvider teacherProvider) {
    final unreadNotifications = teacherProvider.notifications
        .where((n) => !(n['is_read'] ?? false))
        .take(3)
        .toList();
    
    if (unreadNotifications.isEmpty) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...unreadNotifications.map((notification) => Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.blue.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: const Icon(Icons.notifications_active, color: Colors.white, size: 18),
            ),
            title: Text(
              notification['title'] ?? 'Notification',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              notification['message'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        )),
      ],
    );
  }

  // ========== STUDENTS PAGE ==========
  Widget _buildStudentsPage() {
  return const StudentListPage();
}

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final firstName = student['first_name'] ?? '';
    final lastName = student['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showStudentDetailsDialog(student),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isNotEmpty ? fullName : 'Unknown Student',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${student['student_id'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      _getStudentGradeInfo(student),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.pushNamed(
                    context,
                    AppRoutes.teacherSubmitReport,
                    arguments: {'selected_student': student},
                  );
                  
                  if (result == true && mounted) {
                    _refreshData();
                  }
                },
                icon: const Icon(Icons.report, size: 16),
                label: const Text('Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== REPORTS PAGE ==========
  Widget _buildReportsPage() {
  return Consumer<TeacherProvider>(
    builder: (context, teacherProvider, child) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Reports'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false, // ✅ Remove back button
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => teacherProvider.fetchReports(),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => teacherProvider.fetchReports(),
          child: teacherProvider.reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No reports submitted yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            AppRoutes.teacherSubmitReport,
                          );
                          
                          if (result == true && mounted) {
                            _refreshData();
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Submit First Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: teacherProvider.reports.length,
                  itemBuilder: (context, index) {
                    final report = teacherProvider.reports[index];
                    return _buildReportCard(report);
                  },
                ),
        ),
      );
    },
  );
}

  Widget _buildReportCard(Map<String, dynamic> report) {
  final status = report['status']?.toString() ?? 'pending';
  final statusColor = _getStatusColor(status);
  final title = report['title'] ?? 'No Title';
  final content = report['content'] ?? 
               report['description'] ?? 
               report['details'] ?? 
               '';
  final date = report['created_at'] ?? report['date'] ?? '';

  // ✅ FIXED: Extract student name properly
  String studentName = 'Unknown Student';

  debugPrint('🔍 DASHBOARD: reported_student type: ${report['reported_student'].runtimeType}');
  debugPrint('🔍 DASHBOARD: reported_student data: ${report['reported_student']}');

  if (report['reported_student'] != null) {
    if (report['reported_student'] is Map) {
      final reportedStudent = report['reported_student'] as Map<String, dynamic>;
      
      // Try different possible field names
      studentName = reportedStudent['name']?.toString() ?? 
                    reportedStudent['full_name']?.toString() ?? 
                    reportedStudent['student_name']?.toString() ?? 
                    'Unknown Student';
      
      // If still empty, try combining first_name and last_name
      if (studentName == 'Unknown Student') {
        final firstName = reportedStudent['first_name']?.toString() ?? '';
        final lastName = reportedStudent['last_name']?.toString() ?? '';
        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          studentName = '$firstName $lastName'.trim();
        }
      }
      
      debugPrint('✅ DASHBOARD: Extracted student name: "$studentName"');
    } else if (report['reported_student'] is String) {
      studentName = report['reported_student'].toString();
      debugPrint('✅ DASHBOARD: Student name from string: "$studentName"');
    }
  } else if (report['student_name'] != null) {
    studentName = report['student_name'].toString();
    debugPrint('✅ DASHBOARD: Student name from student_name field: "$studentName"');
  }

  debugPrint('📝 DASHBOARD: Final student name: "$studentName"');
  
  return Card(
    elevation: 2,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      onTap: () => _showReportDetailsDialog(report),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ✅ Student name row
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    studentName,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Description preview
            if (content.isNotEmpty)
              Text(
                content,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            const SizedBox(height: 12),

            // Footer with date
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  // ========== PROFILE PAGE ==========
  Widget _buildProfilePage() {
    return Consumer<TeacherProvider>(
      builder: (context, teacherProvider, child) {
        final profile = teacherProvider.teacherProfile;
        
        String displayName = 'Teacher';
        if (profile != null) {
          displayName = profile['full_name']?.toString() ?? '';
          if (displayName.isEmpty) {
            final firstName = profile['first_name']?.toString() ?? '';
            final lastName = profile['last_name']?.toString() ?? '';
            displayName = '$firstName $lastName'.trim();
          }
          if (displayName.isEmpty) {
            displayName = profile['username']?.toString() ?? 'Teacher';
          }
        }
        
        String initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';
        if (displayName.split(' ').length > 1) {
          final parts = displayName.split(' ');
          initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
        }
        
        // ✅ Use system school year from provider
        final currentSchoolYear = teacherProvider.systemSchoolYear ?? _calculateCurrentSchoolYear();
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('My Profile'),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: _logout,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [           
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue.shade700,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  profile?['email'] ?? 'No email',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                _buildProfileInfoCard('Personal Information', [
                  {'label': 'Employee ID', 'value': profile?['employee_id'] ?? 'N/A'},
                  {'label': 'Username', 'value': profile?['username'] ?? 'N/A'},
                  {'label': 'Department', 'value': profile?['department'] ?? 'N/A'},
                  {'label': 'Current School Year', 'value': currentSchoolYear}, // ✅ Show system school year
                ]),
                
                const SizedBox(height: 16),
                
                _buildProfileInfoCard('Teaching Assignment', [
                  {'label': 'Advising Class', 'value': _getAdvisingClassDisplay(profile)},
                  {'label': 'Number of Students', 'value': '${teacherProvider.advisingStudents.length}'},
                  {'label': 'Reports Submitted', 'value': '${teacherProvider.reports.length}'},
                ]),
                
                const SizedBox(height: 24),
                
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ Helper to calculate current school year
  String _calculateCurrentSchoolYear() {
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;
    return currentMonth >= 6 
        ? '$currentYear-${currentYear + 1}' 
        : '${currentYear - 1}-$currentYear';
  }

  Widget _buildProfileInfoCard(String title, List<Map<String, String>> items) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      item['label']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item['value']!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _getAdvisingClassDisplay(Map<String, dynamic>? profile) {
    if (profile == null) return 'Not assigned';
    
    final grade = profile['advising_grade']?.toString() ?? '';
    final strand = profile['advising_strand']?.toString() ?? '';
    final section = profile['advising_section']?.toString() ?? '';
    
    if (grade.isEmpty || section.isEmpty) return 'Not assigned';
    
    if (['11', '12'].contains(grade) && strand.isNotEmpty) {
      return 'Grade $grade $strand - Section $section';
    }
    return 'Grade $grade - Section $section';
  }

  // ========== HELPER METHODS ==========
  
  String _getStudentGradeInfo(Map<String, dynamic> student) {
    final grade = student['grade_level']?.toString() ?? '';
    final strand = student['strand']?.toString() ?? '';
    final section = student['section']?.toString() ?? '';
    
    if (['11', '12'].contains(grade) && strand.isNotEmpty) {
      return 'Grade $grade $strand - Section $section';
    } else if (grade.isNotEmpty && section.isNotEmpty) {
      return 'Grade $grade - Section $section';
    }
    return grade.isNotEmpty ? 'Grade $grade' : 'N/A';
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'reviewed': return Colors.blue;
      case 'resolved': return Colors.green;
      case 'dismissed': return Colors.grey;
      case 'invalid': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending': return Icons.schedule;
      case 'reviewed': return Icons.visibility;
      case 'resolved': return Icons.check_circle;
      case 'dismissed': return Icons.cancel;
      case 'invalid': return Icons.error;
      default: return Icons.help;
    }
  }

  String _getStatusText(String? status) {
    if (status == null) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  // ========== DIALOGS ==========
  
  void _showStudentDetailsDialog(Map<String, dynamic> student) {
    final firstName = student['first_name'] ?? '';
    final lastName = student['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fullName.isNotEmpty ? fullName : 'Student Details',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Student ID', student['student_id'] ?? 'N/A'),
              _buildDetailRow('Name', fullName.isNotEmpty ? fullName : 'N/A'),
              _buildDetailRow('Email', student['email'] ?? 'N/A'),
              _buildDetailRow('Grade Level', _getStudentGradeInfo(student)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              
              final result = await Navigator.pushNamed(
                context,
                AppRoutes.teacherSubmitReport,
                arguments: {'selected_student': student},
              );
              
              if (result == true && mounted) {
                _refreshData();
              }
            },
            icon: const Icon(Icons.report, size: 16),
            label: const Text('Report Violation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDetailsDialog(Map<String, dynamic> report) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.description, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Report Details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ✅ FIXED: Proper student name extraction
            _buildDetailRow(
              'Student',
              report['reported_student'] is Map
                  ? (report['reported_student']['name']?.toString() ?? 
                     report['reported_student']['full_name']?.toString() ??
                     '${report['reported_student']['first_name'] ?? ''} ${report['reported_student']['last_name'] ?? ''}'.trim() ??
                     'Unknown Student')
                  : (report['student_name']?.toString() ?? 
                     report['reported_student']?.toString() ?? 
                     'Unknown Student'),
            ),
            
            _buildDetailRow(
              'Status',
              _getStatusText(report['status']?.toString() ?? 'pending'),
            ),
            
            _buildDetailRow(
              'Date Submitted',
              _formatDate(report['created_at']?.toString() ?? 
                         report['date']?.toString() ?? ''),
            ),
            
            if (report['incident_date'] != null)
              _buildDetailRow(
                'Incident Date',
                _formatDate(report['incident_date'].toString()),
              ),
            
            const SizedBox(height: 16),
            const Text(
              'Description:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                report['content']?.toString() ?? 
                report['description']?.toString() ?? 
                report['details']?.toString() ?? 
                'No description provided',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            
            // ✅ Additional fields if available
            if (report['violation_type'] != null) ...[
              const SizedBox(height: 12),
              _buildDetailRow(
                'Violation Type',
                report['violation_type'] is Map
                    ? (report['violation_type']['name']?.toString() ?? 'Unknown')
                    : report['violation_type'].toString(),
              ),
            ],
            
            if (report['severity'] != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                'Severity',
                report['severity'].toString().toUpperCase(),
              ),
            ],
            
            if (report['counselor_notes'] != null && 
                report['counselor_notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Counselor Notes:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  report['counselor_notes'].toString(),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
}
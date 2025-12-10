import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../config/routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/notification_widget.dart';
import '../../../core/constants/app_breakpoints.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> with TickerProviderStateMixin {
  bool isLoading = true;
  bool _hasShownFrozenDialog = false; // ✅ Track if frozen dialog shown
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDashboard();
    });
  }

  // ✅ NEW: Initialize dashboard with system check
  Future<void> _initializeDashboard() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    if (authProvider.token != null) {
      studentProvider.setToken(authProvider.token!);
      notificationProvider.setToken(authProvider.token!);
      
      try {
        // ✅ Check system status first
        await studentProvider.fetchSystemSettings();
        
        if (!studentProvider.isSystemActive && !_hasShownFrozenDialog) {
          _hasShownFrozenDialog = true;
          // Show system frozen dialog
          Future.delayed(Duration.zero, () => _showSystemFrozenDialog());
          setState(() => isLoading = false);
          _animationController.forward();
          return;
        }
        
        // Continue with normal initialization
        await _loadStudentData();
        
      } catch (e) {
        debugPrint('❌ Error initializing dashboard: $e');
        if (e is SystemFrozenException && !_hasShownFrozenDialog) {
          _hasShownFrozenDialog = true;
          Future.delayed(Duration.zero, () => _showSystemFrozenDialog());
        }
        setState(() => isLoading = false);
        _animationController.forward();
      }
    } else {
      setState(() => isLoading = false);
      _animationController.forward();
    }
  }

  void _initializeNotifications() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
    
    if (authProvider.token != null) {
      notificationProvider.setToken(authProvider.token);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);

    try {
      if (authProvider.token != null) {
        await Future.wait([
          studentProvider.fetchStudentInfo(authProvider.token!),
          studentProvider.fetchReports(authProvider.token!),
          studentProvider.fetchNotifications(authProvider.token!),
        ]);
      }
    } on SystemFrozenException {
      if (!_hasShownFrozenDialog) {
        _hasShownFrozenDialog = true;
        _showSystemFrozenDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading data: $e"),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        _animationController.forward();
      }
    }
  }

  // ✅ NEW: Show system frozen dialog
  void _showSystemFrozenDialog() {
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    
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
                  studentProvider.systemMessage ?? 
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
                        studentProvider.systemSchoolYear ?? 'N/A',
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
                await studentProvider.logout();
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

  Future<bool> _confirmLogout(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange),
            SizedBox(width: 8),
            Text("Confirm Logout"),
          ],
        ),
        content: const Text("Are you sure you want to log out of your account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    ) ?? false;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  int _getUnreadNotifications(StudentProvider provider) {
    return provider.notifications.where((notification) => 
      !(notification['is_read'] as bool? ?? false)
    ).length;
  }

  int _getPendingReports(StudentProvider provider) {
    return provider.reports.where((report) => 
      (report['status'] as String? ?? '').toLowerCase() == 'pending'
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final studentProvider = Provider.of<StudentProvider>(context);

    // ✅ Show frozen screen if system is inactive
    if (!studentProvider.isSystemActive && !isLoading) {
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
                    studentProvider.systemMessage ?? 
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
                      await studentProvider.logout();
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

    return WillPopScope(
      onWillPop: () => _confirmLogout(context),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: const Text(
            "Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 24,
            ),
          ),
          actions: [
            const NotificationBell(),
            IconButton(
              icon: const Icon(Icons.logout_outlined, color: Colors.white, size: 28),
              onPressed: () async {
                final shouldLogout = await _confirmLogout(context);
                if (shouldLogout) {
                  authProvider.logout();
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    AppRoutes.login, 
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Loading your dashboard...",
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                color: const Color(0xFF4CAF50),
                onRefresh: _loadStudentData,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Hero Section with gradient background
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const CircleAvatar(
                                        radius: 35,
                                        backgroundColor: Colors.white,
                                        child: Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Color(0xFF4CAF50),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${_getGreeting()}!",
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (() {
                                              final fullName = [
                                                authProvider.firstName,
                                                authProvider.lastName,
                                              ]
                                                  .where((name) => name != null && name.isNotEmpty)
                                                  .join(' ')
                                                  .trim();

                                              return fullName.isNotEmpty
                                                  ? fullName
                                                  : (authProvider.username ?? 'Student');
                                            })(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ✅ School Year Card (using system school year if available)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: _buildSchoolYearCard(studentProvider),
                        ),

                        // Stats Cards
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatsCard(
                                  title: "Total Reports",
                                  value: "${studentProvider.reports.length}",
                                  icon: Icons.assignment_outlined,
                                  color: Colors.blue,
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.myReports),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _StatsCard(
                                  title: "Pending",
                                  value: "${_getPendingReports(studentProvider)}",
                                  icon: Icons.pending_actions_outlined,
                                  color: Colors.orange,
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.myReports),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Quick Actions Section
                        Padding(
  padding: const EdgeInsets.all(20),
  child: LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isDesktop = AppBreakpoints.isDesktop(screenWidth);
      final isTablet = AppBreakpoints.isTablet(screenWidth);
      
      // Calculate responsive grid columns
      int gridColumns = 2;
      if (isDesktop) {
        gridColumns = 4;
      } else if (isTablet) {
        gridColumns = constraints.maxWidth > 800 ? 3 : 2;
      }

      // Calculate responsive aspect ratio
      double aspectRatio = 1.1;
      if (isDesktop) {
        aspectRatio = 1.3;
      } else if (isTablet) {
        aspectRatio = 1.2;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2E7D32),
            ),
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: gridColumns,
            crossAxisSpacing: isDesktop ? 20 : 16,
            mainAxisSpacing: isDesktop ? 20 : 16,
            childAspectRatio: aspectRatio,
            children: [
              _ActionCard(
                icon: Icons.add_box_outlined,
                title: "Submit Report",
                subtitle: "Report an incident",
                gradient: const LinearGradient(
                  colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.submitReport),
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
              _ActionCard(
                icon: Icons.history_outlined,
                title: "My Reports",
                subtitle: "${studentProvider.reports.length} reports",
                gradient: const LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.myReports),
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
              _ActionCard(
                icon: Icons.notifications_outlined,
                title: "Notifications",
                subtitle: "${_getUnreadNotifications(studentProvider)} unread",
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF9800), Color(0xFFE65100)],
                ),
                showBadge: _getUnreadNotifications(studentProvider) > 0,
                onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
              _ActionCard(
                icon: Icons.settings_outlined,
                title: "Settings",
                subtitle: "Preferences",
                gradient: const LinearGradient(
                  colors: [Color(0xFF607D8B), Color(0xFF455A64)],
                ),
                onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                isDesktop: isDesktop,
                isTablet: isTablet,
              ),
            ],
          ),
        ],
      );
    },
  ),
),

                        // Recent Activity Section
                        if (studentProvider.reports.isNotEmpty || studentProvider.notifications.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Recent Activity",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      if (studentProvider.reports.isNotEmpty) ...[
                                        _buildRecentReports(studentProvider),
                                        if (studentProvider.notifications.isNotEmpty)
                                          const Divider(height: 1),
                                      ],
                                      if (studentProvider.notifications.isNotEmpty)
                                        _buildRecentNotifications(studentProvider),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRecentReports(StudentProvider provider) {
    final recentReports = provider.reports.take(3).toList();
    
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.assignment, color: Color(0xFF4CAF50)),
          title: const Text(
            "Recent Reports",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.myReports),
            child: const Text("View All"),
          ),
        ),
        ...recentReports.map((report) => ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: _getStatusColor(report['status'] ?? '').withOpacity(0.2),
            child: Icon(
              _getStatusIcon(report['status'] ?? ''),
              size: 16,
              color: _getStatusColor(report['status'] ?? ''),
            ),
          ),
          title: Text(
            report['title'] ?? 'Untitled',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Text(
            (report['status'] ?? 'Unknown').toString().toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              color: _getStatusColor(report['status'] ?? ''),
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: () => Navigator.pushNamed(context, AppRoutes.myReports),
        )),
      ],
    );
  }

  Widget _buildRecentNotifications(StudentProvider provider) {
    final recentNotifications = provider.notifications.take(3).toList();
    
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.notifications, color: Color(0xFF4CAF50)),
          title: const Text(
            "Recent Notifications",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.notifications),
            child: const Text("View All"),
          ),
        ),
        ...recentNotifications.map((notification) => ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: (notification['is_read'] as bool? ?? false) 
                ? Colors.grey.withOpacity(0.2)
                : Colors.blue.withOpacity(0.2),
            child: Icon(
              Icons.notifications,
              size: 16,
              color: (notification['is_read'] as bool? ?? false) 
                  ? Colors.grey
                  : Colors.blue,
            ),
          ),
          title: Text(
            notification['title'] ?? 'Notification',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: (notification['is_read'] as bool? ?? false) 
                  ? FontWeight.normal 
                  : FontWeight.w500,
            ),
          ),
          subtitle: Text(
            notification['message'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
        )),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'under_review':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      case 'dismissed':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Icons.check_circle;
      case 'under_review':
        return Icons.search;
      case 'pending':
        return Icons.schedule;
      case 'dismissed':
        return Icons.cancel;
      default:
        return Icons.report;
    }
  }

  Widget _buildSchoolYearCard(StudentProvider provider) {
    // ✅ Prioritize system school year over student's school year
    final schoolYear = provider.systemSchoolYear ?? provider.currentSchoolYear;
    final grade = provider.gradeLevel;
    final section = provider.section;
    final isCurrentYear = _isCurrentSchoolYear(schoolYear);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isCurrentYear
                ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                : [Colors.orange.shade600, Colors.orange.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.school,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'School Year $schoolYear',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Grade $grade - $section',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrentYear)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'CURRENT',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isCurrentSchoolYear(String schoolYear) {
    if (schoolYear == 'N/A') return false;
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final currentSY = month >= 6 ? '$year-${year + 1}' : '${year - 1}-$year';
    return schoolYear == currentSY;
  }
}

// Stats Card Widget
class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktop = AppBreakpoints.isDesktop(screenWidth);
        final isTablet = AppBreakpoints.isTablet(screenWidth);
        
        final iconSize = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);
        final valueSize = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);
        final titleSize = isDesktop ? 16.0 : (isTablet ? 15.0 : 14.0);
        final padding = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);
        final spacing = isDesktop ? 12.0 : (isTablet ? 10.0 : 8.0);
        final borderRadius = isDesktop ? 16.0 : (isTablet ? 14.0 : 12.0);
        final elevation = isDesktop ? 4.0 : (isTablet ? 3.5 : 3.0);

        return GestureDetector(
          onTap: onTap,
          child: Card(
            elevation: elevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(icon, color: color, size: iconSize),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: valueSize,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: spacing),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: titleSize,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
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
}

// Action Card Widget
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool showBadge;
  final bool isDesktop;
  final bool isTablet;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.showBadge = false,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive sizing
    final iconSize = isDesktop ? 48.0 : (isTablet ? 44.0 : 40.0);
    final titleSize = isDesktop ? 18.0 : (isTablet ? 17.0 : 16.0);
    final subtitleSize = isDesktop ? 14.0 : (isTablet ? 13.0 : 12.0);
    final padding = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);
    final spacing = isDesktop ? 16.0 : (isTablet ? 14.0 : 12.0);
    final borderRadius = isDesktop ? 20.0 : (isTablet ? 18.0 : 16.0);
    final elevation = isDesktop ? 6.0 : (isTablet ? 5.0 : 4.0);
    final badgeSize = isDesktop ? 14.0 : (isTablet ? 13.0 : 12.0);
    final badgePosition = isDesktop ? 12.0 : (isTablet ? 10.0 : 8.0);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: gradient,
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: iconSize,
                      color: Colors.white,
                    ),
                    SizedBox(height: spacing),
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: spacing * 0.3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: subtitleSize,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (showBadge)
                Positioned(
                  top: badgePosition,
                  right: badgePosition,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildSchoolYearCard(StudentProvider provider) {
  final schoolYear = provider.currentSchoolYear;
  final grade = provider.gradeLevel;
  final section = provider.section;
  final isCurrentYear = _isCurrentSchoolYear(schoolYear);

  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: isCurrentYear
              ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
              : [Colors.orange.shade600, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'School Year $schoolYear',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Grade $grade - $section',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentYear)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'CURRENT',
                style: TextStyle(
                  color: Color(0xFF2E7D32),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

bool _isCurrentSchoolYear(String schoolYear) {
  if (schoolYear == 'N/A') return false;
  final now = DateTime.now();
  final year = now.year;
  final month = now.month;
  final currentSY = month >= 6 ? '$year-${year + 1}' : '${year - 1}-$year';
  return schoolYear == currentSY;
}
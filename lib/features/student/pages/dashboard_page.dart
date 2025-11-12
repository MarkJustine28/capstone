import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../config/routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/notification_widget.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> with TickerProviderStateMixin {
  bool isLoading = true;
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
      _loadStudentData();
      _initializeNotifications();
    });
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
        studentProvider.fetchStudentInfo(authProvider.token!), // ✅ ADD THIS
        studentProvider.fetchReports(authProvider.token!),
        studentProvider.fetchNotifications(authProvider.token!),
      ]);
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

  return WillPopScope(
    onWillPop: () => _confirmLogout(context),
    child: Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false, // ✅ Align title to the left
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
                                              // Combine first and last name
                                              final fullName = [
                                                authProvider.firstName,
                                                authProvider.lastName,
                                              ]
                                                  .where((name) => name != null && name.isNotEmpty)
                                                  .join(' ')
                                                  .trim();

                                              // If full name is empty, fallback to username or 'Student'
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
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Quick Actions",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            const SizedBox(height: 16),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.1,
                              children: [
                                _ActionCard(
                                  icon: Icons.add_box_outlined,
                                  title: "Submit Report",
                                  subtitle: "Report an incident",
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                                  ),
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.submitReport),
                                ),
                                _ActionCard(
                                  icon: Icons.history_outlined,
                                  title: "My Reports",
                                  subtitle: "${studentProvider.reports.length} reports",
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                                  ),
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.myReports),
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
                                ),
                                _ActionCard(
                                  icon: Icons.settings_outlined,
                                  title: "Settings",
                                  subtitle: "Preferences",
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF607D8B), Color(0xFF455A64)],
                                  ),
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                                ),
                              ],
                            ),
                          ],
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
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
                  Icon(icon, color: color, size: 24),
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
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
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

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: gradient,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 40, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (showBadge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 12,
                    height: 12,
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
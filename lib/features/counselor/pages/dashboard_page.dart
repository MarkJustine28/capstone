import '../../../widgets/school_year_banner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/routes.dart';
import '../../../providers/counselor_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../widgets/notification_widget.dart';
import 'student_violations_page.dart'; // This should import StudentsManagementPage
import 'student_report_page.dart';
import 'teacher_reports_page.dart';

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
  bool _isLoading = true;
  int _studentReportsCount = 0;
  int _teacherReportsCount = 0;
  List<Map<String, dynamic>> _studentReports = [];
  List<Map<String, dynamic>> _teacherReports = [];
  
  // Analytics data - NEW: Use API data instead of local processing
  Map<String, int> _reportStatusCounts = {};
  Map<String, int> _monthlyReportTrends = {};
  Map<String, int> _violationTypeCounts = {};
  List<Map<String, dynamic>> _riskAnalysis = [];
  List<String> _recommendations = [];

  // Removed duplicate build method to resolve "The name 'build' is already defined" error.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDashboardData();
      _initializeNotifications();
    });
  }

void _initializeNotifications() {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
  
  if (counselorProvider.token != null) {
    notificationProvider.setToken(counselorProvider.token);
  }
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

    // ✅ FIX 1: Fetch ALL data first (not just analytics)
    await Future.wait([
      counselorProvider.fetchStudentReports(),      // Fetch student reports
      counselorProvider.fetchTeacherReports(),      // Fetch teacher reports
      counselorProvider.fetchStudentViolations(),   // Fetch violations
      counselorProvider.fetchDashboardAnalytics(),  // Fetch analytics
    ]);

    debugPrint("✅ All data fetched successfully");
    debugPrint("   - Student Reports: ${counselorProvider.counselorStudentReports.length}");
    debugPrint("   - Teacher Reports: ${counselorProvider.teacherReports.length}");
    debugPrint("   - Violations: ${counselorProvider.studentViolations.length}");

    if (mounted) {
      setState(() {
        // ✅ FIX 2: Update local state with fetched data
        _studentReports = counselorProvider.counselorStudentReports;
        _teacherReports = counselorProvider.teacherReports;
        
        _studentReportsCount = _studentReports.length;
        _teacherReportsCount = _teacherReports.length;
        
        // ✅ FIX 3: Process analytics from ACTUAL data (not API analytics)
        _processAllAnalytics();
        
        _isLoading = false;
      });
      
      debugPrint("📊 Dashboard state updated:");
      debugPrint("  - Total Reports: ${_studentReportsCount + _teacherReportsCount}");
      debugPrint("  - Student Reports: $_studentReportsCount");
      debugPrint("  - Teacher Reports: $_teacherReportsCount");
      debugPrint("  - Pending: ${_reportStatusCounts['pending'] ?? 0}");
      debugPrint("  - Violations: ${counselorProvider.studentViolations.length}");
      debugPrint("  - Violation Types: ${_violationTypeCounts.length}");
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

// (Removed duplicate code block; this logic already exists inside _fetchDashboardData)

  void _processPrescriptiveAnalytics() {
    _riskAnalysis = [];
    _recommendations = [];

    // Risk Analysis with null safety
    final pendingCount = _reportStatusCounts['pending'] ?? 0;
    final totalReports = _studentReportsCount + _teacherReportsCount;
    
    if (pendingCount > 5) {
      _riskAnalysis.add({
        'level': 'High',
        'issue': 'High Pending Reports',
        'count': pendingCount,
        'description': '$pendingCount reports are pending review',
        'color': Colors.red,
      });
    }

    // Violation-specific risk analysis with null safety
    final bullyingCount = _violationTypeCounts.entries
        .where((entry) => entry.key.toLowerCase().contains('bullying'))
        .fold(0, (sum, entry) => sum + entry.value);
    
    // Safe arithmetic with explicit null checks
    final violenceCount = (_violationTypeCounts['Fighting'] ?? 0) + 
                         (_violationTypeCounts['Violence'] ?? 0) + 
                         (_violationTypeCounts['Physical Altercation'] ?? 0);
    
    final attendanceCount = (_violationTypeCounts['Tardiness'] ?? 0) + 
                           (_violationTypeCounts['Absenteeism'] ?? 0) + 
                           (_violationTypeCounts['Cutting Classes'] ?? 0) +
                           (_violationTypeCounts['Skipping Class'] ?? 0);

    if (bullyingCount >= 3) {
      _riskAnalysis.add({
        'level': 'High',
        'issue': 'Bullying Trend',
        'count': bullyingCount,
        'description': 'Multiple bullying incidents require immediate attention',
        'color': Colors.red,
      });
    }

    if (violenceCount >= 2) {
      _riskAnalysis.add({
        'level': 'High',
        'issue': 'Violence Concerns',
        'count': violenceCount,
        'description': 'Fighting/violence incidents need intervention',
        'color': Colors.red,
      });
    }

    if (attendanceCount >= 5) {
      _riskAnalysis.add({
        'level': 'Medium',
        'issue': 'Attendance Issues',
        'count': attendanceCount,
        'description': 'High number of attendance-related violations',
        'color': Colors.orange,
      });
    }

    if (totalReports > 20) {
      _riskAnalysis.add({
        'level': 'Medium',
        'issue': 'High Report Volume',
        'count': totalReports,
        'description': 'Increased reporting activity detected',
        'color': Colors.orange,
      });
    }

    // Generate Recommendations with null safety
    if (pendingCount > 3) {
      _recommendations.add("🔴 Priority: Review $pendingCount pending reports to prevent backlog");
    }

    if (bullyingCount >= 3) {
      _recommendations.add("🚨 Urgent: Implement school-wide anti-bullying measures ($bullyingCount cases)");
    }

    if (violenceCount >= 2) {
      _recommendations.add("⚠️ Safety Alert: Review security measures due to violence reports ($violenceCount cases)");
    }

    if (attendanceCount >= 5) {
      _recommendations.add("📚 Attendance: Investigate truancy patterns ($attendanceCount cases)");
    }

    final substanceCount = (_violationTypeCounts['Using Vape/Cigarette'] ?? 0) + 
                          (_violationTypeCounts['Substance Use'] ?? 0) +
                          (_violationTypeCounts['Smoking'] ?? 0);
    if (substanceCount >= 3) {
      _recommendations.add("🚭 Substance Alert: Address vaping/smoking issues ($substanceCount cases)");
    }

    final academicCount = (_violationTypeCounts['Cheating'] ?? 0) + 
                         (_violationTypeCounts['Academic Dishonesty'] ?? 0);
    if (academicCount >= 2) {
      _recommendations.add("📖 Academic Integrity: Review cheating prevention measures ($academicCount cases)");
    }

    if (_recommendations.isEmpty) {
      _recommendations.add("✨ System running smoothly. Continue monitoring trends");
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
        return _buildOverviewTab(); // Changed from _buildDashboardContent
      case 1:
        return _buildManageStudentsTab(); // This exists
      case 2:
        return _buildStudentReportsContent(); // Add this method
      case 3:
        return _buildTeacherReportsContent(); // Add this method
      case 4:
        return _buildAnalyticsContent(); // Add this method
      default:
        return _buildOverviewTab();
    }
  }

  @override
Widget build(BuildContext context) {
  return WillPopScope(
    onWillPop: () => _confirmLogout(context),
    child: Scaffold(
      // Hide AppBar for Manage Students (1), Student Reports (2), and Teacher Reports (3) tabs
      appBar: (_currentTabIndex == 1 || _currentTabIndex == 2 || _currentTabIndex == 3) 
          ? null 
          : AppBar(
              automaticallyImplyLeading: false,
              centerTitle: false, // ✅ Align title to the left
              title: const Text("Counselor Dashboard"),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              actions: [
                const NotificationBell(), // ✅ Notification bell
                
                // ✅ NEW: Settings Button
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.counselorSettings); // ✅ CORRECT
                  },
                ),
                
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh',
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _fetchDashboardData();
                  },
                ),
                
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  tooltip: 'Logout',
                  onPressed: () async {
                    final shouldLogout = await _confirmLogout(context);
                    if (shouldLogout) {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  },
                ),
              ],
            ),
      body: _getCurrentTabContent(),
      bottomNavigationBar: _buildBottomNavigationBar(),
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
      return SingleChildScrollView(
        padding: EdgeInsets.zero, // Remove padding from ScrollView
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ NEW: School Year Banner at the very top
            const SchoolYearBanner(),
            
            // Main content with padding
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting Card
                  _buildGreetingCard(),
                  const SizedBox(height: 20),

                  // Quick Stats Cards
                  _buildQuickStatsGrid(),
                  const SizedBox(height: 20),

                  // Top Violations Overview
                  _buildTopViolationsOverview(),
                  const SizedBox(height: 20),

                  // Recent Activity
                  _buildRecentActivitySection(),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

  // Add this method to your _CounselorDashboardPageState class:

  Widget _buildRecentActivitySection() {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final recentReports = counselorProvider.getCombinedRecentReports(limit: 5);

  return Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "🕒 Recent Activity",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to a detailed activity page or switch tabs
                },
                child: const Text("View All"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentReports.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("No recent activity found"),
              ),
            )
          else
            ...recentReports.map((report) => ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(report['status']?.toString()).withOpacity(0.1),
                child: Icon(
                  report['reporter_type'] == 'Student' ? Icons.person : Icons.school,
                  color: _getStatusColor(report['status']?.toString()),
                ),
              ),
              title: Text(
                report['title']?.toString() ?? 'Untitled Report',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('From: ${report['reporter_type']} • ${_formatDate(report['created_at'] ?? report['date'])}'),
                  if (report['reported_student_name'] != null)
                    Text('Student: ${report['reported_student_name']}'),
                ],
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(report['status']?.toString()).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (report['status']?.toString() ?? 'pending').toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(report['status']?.toString()),
                    fontSize: 10,
                  ),
                ),
              ),
              onTap: () {
                // Navigate to appropriate report details based on source_type
                if (report['source_type'] == 'student_report') {
                  // Navigate to student reports tab
                  setState(() => _currentTabIndex = 2);
                } else {
                  // Navigate to teacher reports tab  
                  setState(() => _currentTabIndex = 3);
                }
              },
            )),
        ],
      ),
    ),
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
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ready to make a positive impact today!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
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

  // NEW: Top Tallied Reports Overview for Overview Tab
  Widget _buildTopViolationsOverview() {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);

    // Get all manually tallied violations by guidance counselor
    final talliedViolations = counselorProvider.studentViolations;

    // Count violations by type for all tallied ones
    final talliedViolationCounts = <String, int>{};
    for (final violation in talliedViolations) {
      String violationType = 'Other'; // Default fallback

      // Extract violation type from different possible fields
      if (violation['violation_type'] != null) {
        if (violation['violation_type'] is Map) {
          violationType = violation['violation_type']['name']?.toString() ?? 'Other';
        } else {
          violationType = violation['violation_type'].toString();
        }
      } else if (violation['custom_violation'] != null) {
        violationType = violation['custom_violation'].toString();
      } else if (violation['violation_name'] != null) {
        violationType = violation['violation_name'].toString();
      } else if (violation['type'] != null) {
        violationType = violation['type'].toString();
      }

      talliedViolationCounts[violationType] = (talliedViolationCounts[violationType] ?? 0) + 1;
    }

    final topTalliedViolations = talliedViolationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return InkWell(
      onTap: () => setState(() => _currentTabIndex = 1), // Navigate to Manage Students tab (violations page)
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                        Text(
                          "📊 Top Tallied Reports (${talliedViolations.length} total)",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Manually tallied by guidance counselor • Tap to manage",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),

              if (topTalliedViolations.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("No tallied reports found"),
                  ),
                )
              else
                ...topTalliedViolations.take(3).map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _getViolationColor(entry.key),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.warning, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              "${entry.value} tallied reports",
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getViolationColor(entry.key),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          "${entry.value}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
      ),
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
      final selectedSchoolYear = provider.selectedSchoolYear;
      final isFiltered = selectedSchoolYear != 'all';
      
      // ✅ Add debug logging
      debugPrint("📊 Building Quick Stats Grid:");
      debugPrint("   - Selected SY: $selectedSchoolYear");
      debugPrint("   - Student Reports Count: $_studentReportsCount");
      debugPrint("   - Teacher Reports Count: $_teacherReportsCount");
      debugPrint("   - Provider Student Reports: ${provider.counselorStudentReports.length}");
      debugPrint("   - Provider Teacher Reports: ${provider.teacherReports.length}");
      debugPrint("   - Provider Violations: ${provider.studentViolations.length}");
      
      // Filter data by school year
      List<Map<String, dynamic>> filteredStudentReports;
      List<Map<String, dynamic>> filteredTeacherReports;
      List<Map<String, dynamic>> filteredViolations;
      
      if (selectedSchoolYear == 'all') {
        filteredStudentReports = _studentReports;
        filteredTeacherReports = _teacherReports;
        filteredViolations = provider.studentViolations;
      } else {
        // Filter by school year
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
        
        filteredViolations = provider.studentViolations.where((violation) {
          final violationSchoolYear = violation['school_year']?.toString() ?? 
                                      violation['student']?['school_year']?.toString() ?? '';
          return violationSchoolYear == selectedSchoolYear;
        }).toList();
      }
      
      final pendingStudentReports = filteredStudentReports.where((r) => 
        r['status']?.toString() == 'pending'
      ).length;
      
      debugPrint("📊 Filtered Results:");
      debugPrint("   - Filtered Student Reports: ${filteredStudentReports.length}");
      debugPrint("   - Filtered Teacher Reports: ${filteredTeacherReports.length}");
      debugPrint("   - Filtered Violations: ${filteredViolations.length}");
      debugPrint("   - Pending Student Reports: $pendingStudentReports");
      
      return Column(
        children: [
          // Show filter indicator if not viewing all years
          if (isFiltered)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_list, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Showing data for S.Y. $selectedSchoolYear only',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          
          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                "📊 Total Reports",
                "${filteredStudentReports.length + filteredTeacherReports.length}",
                "All submitted reports",
                Colors.blue,
                onTap: () {},
              ),
              _buildStatCard(
                "👥 Student Reports", 
                "${filteredStudentReports.length}",
                "$pendingStudentReports pending review",
                Colors.green,
                onTap: () => setState(() => _currentTabIndex = 2),
              ),
              _buildStatCard(
                "🏫 Teacher Reports",
                "${filteredTeacherReports.length}",
                "From educators",
                Colors.orange,
                onTap: () => setState(() => _currentTabIndex = 3),
              ),
              _buildStatCard(
                "📊 Total Tallied Reports",
                "${filteredViolations.length}",
                "Manually tallied by counselor",
                Colors.red,
                onTap: () => setState(() => _currentTabIndex = 1),
              ),
            ],
          ),
        ],
      );
    },
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

Widget _buildStatCard(String title, String value, String subtitle, Color color, {VoidCallback? onTap}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12), // Reduced from 16 to 12
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title with flexible sizing
          Flexible(
            flex: 2,
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12, // Reduced from 14 to 12
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Value with flexible sizing
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 20, // Reduced from 24 to 20
                ),
              ),
            ),
          ),
          
          // Subtitle with flexible sizing
          Flexible(
            flex: 2,
            child: Text(
              subtitle,
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 10, // Reduced from 12 to 10
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
  return Column(
    children: [
      // ✅ NEW: School Year Banner
      
      // Existing analytics content
      Expanded(
        child: SingleChildScrollView(
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
                        Consumer<CounselorProvider>(
                          builder: (context, provider, child) {
                            return Text(
                              'School Year: ${provider.selectedSchoolYear}',
                              style: TextStyle(color: Colors.grey.shade600),
                            );
                          },
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

              // Top Students with Most Violations
              _buildTopViolatorsCard(),
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
        ),
      ),
    ],
  );
}

// ✅ NEW: Add this method to show top students with most violations
Widget _buildTopViolatorsCard() {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  
  // Get all violations
  final violations = counselorProvider.studentViolations;
  
  // Group violations by student
  final Map<int, Map<String, dynamic>> studentViolationCounts = {};
  
  for (final violation in violations) {
    final studentId = violation['student_id'] ?? violation['student']?['id'];
    
    if (studentId != null) {
      if (!studentViolationCounts.containsKey(studentId)) {
        // Initialize student entry
        studentViolationCounts[studentId] = {
          'id': studentId,
          'name': violation['student_name'] ?? 
                 violation['student']?['name'] ?? 
                 'Unknown Student',
          'student_id': violation['student']?['student_id'] ?? '',
          'grade_level': violation['student']?['grade_level'] ?? '',
          'section': violation['student']?['section'] ?? '',
          'count': 0,
          'violations': <Map<String, dynamic>>[],
        };
      }
      
      // Increment count and add violation details
      studentViolationCounts[studentId]!['count'] = 
          (studentViolationCounts[studentId]!['count'] as int) + 1;
      
      (studentViolationCounts[studentId]!['violations'] as List).add({
        'type': violation['violation_type']?['name'] ?? 
                violation['custom_violation'] ?? 
                'Other',
        'date': violation['incident_date'] ?? violation['created_at'],
      });
    }
  }
  
  // Sort students by violation count (descending)
  final sortedStudents = studentViolationCounts.values.toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
  
  // Take top 5
  final topViolators = sortedStudents.take(5).toList();
  
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
              Icon(Icons.person_off, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top Students with Most Violations',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Students requiring immediate attention',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (topViolators.isEmpty)
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
                      'No violations recorded yet. Great work!',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topViolators.length,
              itemBuilder: (context, index) {
                final student = topViolators[index];
                final violationCount = student['count'] as int;
                
                // Get severity color based on count
                Color getSeverityColor() {
                  if (violationCount >= 10) return Colors.red;
                  if (violationCount >= 5) return Colors.orange;
                  return Colors.amber;
                }
                
                return InkWell(
                  onTap: () {
                    // Show detailed violation breakdown
                    _showStudentViolationDetails(context, student);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: getSeverityColor().withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: getSeverityColor().withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // ✅ UPDATED: Simple number rank badge
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: getSeverityColor(),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}', // ✅ Simple numbering: 1, 2, 3, 4, 5
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Student info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${student['grade_level']} - ${student['section']}'.trim(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Student ID: ${student['student_id']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Violation count badge
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: getSeverityColor(),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$violationCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'violations',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
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
                Icon(Icons.pie_chart, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Report Status Distribution',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_reportStatusCounts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No status data available'),
                ),
              )
            else
              ..._reportStatusCounts.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _getStatusColor(entry.key),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(entry.key).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(entry.key),
                        ),
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

  // Update the _buildViolationTypesCard to show debug info
  Widget _buildViolationTypesCard() {
  final topViolations = _violationTypeCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

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
              Icon(Icons.bar_chart, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Text(
                'Violation Types Analysis (${_violationTypeCounts.values.fold(0, (sum, count) => sum + count)} total)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (topViolations.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.info, color: Colors.orange.shade700),
                  const SizedBox(height: 8),
                  const Text(
                    'No violation data found',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Debug: Reports=${_studentReports.length + _teacherReports.length}, '
                    'Violations=${Provider.of<CounselorProvider>(context, listen: false).studentViolations.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else
            ...topViolations.take(5).map((entry) {
              // Calculate width factor safely
              final maxValue = topViolations.isNotEmpty ? topViolations.first.value : 1;
              final widthFactor = maxValue > 0 ? (entry.value / maxValue).clamp(0.0, 1.0) : 0.0;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: widthFactor, // Now guaranteed to be between 0.0 and 1.0
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getViolationColor(entry.key),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getViolationColor(entry.key).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getViolationColor(entry.key),
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
}

  Widget _buildMonthlyTrendsCard() {
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
            else
              SizedBox(
                height: 180, // Reduced from 200 to 180
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _monthlyReportTrends.length,
                  itemBuilder: (context, index) {
                    final entry = _monthlyReportTrends.entries.elementAt(index);
                    final maxValue = _monthlyReportTrends.values.isNotEmpty 
                        ? _monthlyReportTrends.values.reduce((a, b) => a > b ? a : b)
                        : 1;
                    final height = maxValue > 0 
                        ? (entry.value / maxValue) * 120  // Reduced max height from 150 to 120
                        : 0.0;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min, // Add this to prevent overflow
                        children: [
                          // Value label
                          Container(
                            height: 20, // Fixed height for label
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
                          
                          // Bar chart
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
                          
                          // Month label
                          Container(
                            height: 24, // Fixed height for rotated text
                            alignment: Alignment.center,
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: Text(
                                _formatMonthLabel(entry.key),
                                style: const TextStyle(fontSize: 9), // Reduced font size
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
          ],
        ),
      ),
    );
  }

  // Add this helper method to format month labels better:
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
          return '${monthNames[month - 1]} ${year.substring(2)}'; // Short format like "Oct 24"
        }
      }
    } catch (e) {
      // If parsing fails, return the original
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
                child: Row(
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
              )),
          ],
        ),
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
                Icon(Icons.lightbulb, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Recommendations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ..._recommendations.map((recommendation) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    recommendation.startsWith('🔴') ? Icons.priority_high :
                    recommendation.startsWith('🚨') ? Icons.emergency :
                    recommendation.startsWith('⚠️') ? Icons.warning :
                    Icons.info,
                    color: recommendation.startsWith('🔴') ? Colors.red :
                           recommendation.startsWith('🚨') ? Colors.red :
                           recommendation.startsWith('⚠️') ? Colors.orange :
                           Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recommendation,
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

void _processAllAnalytics() {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  
  debugPrint("🔄 Processing analytics from fetched data...");
  
  // ✅ Process report status counts from ACTUAL reports
  final pendingStudentReports = _studentReports.where((r) => 
    r['status']?.toString() == 'pending'
  ).length;
  
  final pendingTeacherReports = _teacherReports.where((r) => 
    r['status']?.toString() == 'pending'
  ).length;
  
  final reviewedStudentReports = _studentReports.where((r) => 
    r['status']?.toString() == 'reviewed' || r['status']?.toString() == 'under_review'
  ).length;
  
  final reviewedTeacherReports = _teacherReports.where((r) => 
    r['status']?.toString() == 'reviewed' || r['status']?.toString() == 'under_review'
  ).length;
  
  final resolvedStudentReports = _studentReports.where((r) => 
    r['status']?.toString() == 'resolved'
  ).length;
  
  final resolvedTeacherReports = _teacherReports.where((r) => 
    r['status']?.toString() == 'resolved'
  ).length;
  
  _reportStatusCounts = {
    'pending': pendingStudentReports + pendingTeacherReports,
    'reviewed': reviewedStudentReports + reviewedTeacherReports,
    'resolved': resolvedStudentReports + resolvedTeacherReports,
    'total': _studentReports.length + _teacherReports.length,
  };
  
  debugPrint("📊 Status counts: $_reportStatusCounts");
  
  // ✅ Process violation types from ACTUAL violations
  _violationTypeCounts = {};
  
  final violations = counselorProvider.studentViolations;
  debugPrint("📋 Processing ${violations.length} violations...");
  
  for (final violation in violations) {
    String violationType = 'Other'; // Default fallback
    
    // Try to extract violation type from different possible fields
    if (violation['violation_type'] != null) {
      if (violation['violation_type'] is Map) {
        violationType = violation['violation_type']['name']?.toString() ?? 'Other';
      } else {
        violationType = violation['violation_type'].toString();
      }
    } else if (violation['custom_violation'] != null) {
      violationType = violation['custom_violation'].toString();
    } else if (violation['violation_name'] != null) {
      violationType = violation['violation_name'].toString();
    } else if (violation['type'] != null) {
      violationType = violation['type'].toString();
    }
    
    // Increment count for this violation type
    _violationTypeCounts[violationType] = (_violationTypeCounts[violationType] ?? 0) + 1;
  }
  
  debugPrint("📊 Violation types: $_violationTypeCounts");
  
  // ✅ Process monthly trends from ACTUAL reports
  _monthlyReportTrends = {};
  
  // Combine all reports for trend analysis
  final allReports = [..._studentReports, ..._teacherReports];
  
  for (final report in allReports) {
    try {
      final createdAt = report['created_at']?.toString() ?? '';
      if (createdAt.isNotEmpty) {
        // Extract YYYY-MM format
        final monthKey = createdAt.substring(0, 7); // "2025-11"
        _monthlyReportTrends[monthKey] = (_monthlyReportTrends[monthKey] ?? 0) + 1;
      }
    } catch (e) {
      debugPrint("⚠️ Error parsing date for report: $e");
    }
  }
  
  debugPrint("📊 Monthly trends: $_monthlyReportTrends");
  
  // ✅ Process risk analysis
  _processPrescriptiveAnalytics();
  
  debugPrint("✅ Analytics processing complete:");
  debugPrint("  - Status counts: $_reportStatusCounts");
  debugPrint("  - Violation types: ${_violationTypeCounts.length} types");
  debugPrint("  - Monthly trends: ${_monthlyReportTrends.length} months");
  debugPrint("  - Risk analysis: ${_riskAnalysis.length} risks");
  debugPrint("  - Recommendations: ${_recommendations.length} items");
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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counselor_provider.dart';
import '../../../widgets/school_year_banner.dart';

class StudentReportPage extends StatefulWidget {
  const StudentReportPage({super.key});

  @override
  State<StudentReportPage> createState() => _StudentReportPageState();
}

class _StudentReportPageState extends State<StudentReportPage> {
  final Set<int> _loadingReports = {}; // Track which reports are being updated

  @override
  void initState() {
    super.initState();
    // ✅ Avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReports();
    });
  }
  
  Future<void> _fetchReports() async {
  if (!mounted) return;
  
  try {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    // Check token first
    if (authProvider.token == null) {
      debugPrint("❌ No authentication token available");
      return;
    }
    
    // Set token only if it's different (avoid unnecessary operations)
    if (counselorProvider.token != authProvider.token) {
      counselorProvider.setToken(authProvider.token!);
    }
    
    // Add timeout and better error handling
    debugPrint("🔍 Starting to fetch student reports...");
    final stopwatch = Stopwatch()..start();
    
    await counselorProvider.fetchCounselorStudentReports().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw Exception('Request timeout - please check your connection');
      },
    );
    
    stopwatch.stop();
    debugPrint("✅ Student reports fetched in ${stopwatch.elapsedMilliseconds}ms");
    
  } catch (e) {
    debugPrint("❌ Exception fetching student reports: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load reports: ${_getErrorMessage(e)}"),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _fetchReports(),
          ),
        ),
      );
    }
  }
}

String _getErrorMessage(dynamic error) {
  if (error.toString().contains('timeout')) {
    return 'Connection timeout. Please check your internet.';
  } else if (error.toString().contains('SocketException')) {
    return 'No internet connection.';
  } else if (error.toString().contains('401')) {
    return 'Authentication failed. Please login again.';
  } else if (error.toString().contains('500')) {
    return 'Server error. Please try again later.';
  }
  return 'Unknown error occurred.';
}

  Future<void> _showReportDetails(BuildContext context, Map<String, dynamic> report) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report["title"] ?? "Report Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow("Student Reported", report["reported_student_name"] ?? report["student_name"] ?? "Unknown"),
              _buildDetailRow("Reported by", report["reported_by"]?["name"] ?? "Unknown"),
              _buildDetailRow("Reporter Email", report["reported_by"]?["username"] ?? "N/A"),
              _buildDetailRow("Date", _formatDate(report["created_at"] ?? report["date"])),
              _buildDetailRow("Status", report["status"] ?? "pending"),
              
              // Add violation type information if available
              if (report["violation_type"] != null)
                _buildDetailRow("Violation Type", report["violation_type"].toString()),
              if (report["custom_violation"] != null && report["custom_violation"].toString().isNotEmpty)
                _buildDetailRow("Custom Violation", report["custom_violation"].toString()),
              
              const SizedBox(height: 12),
              const Text(
                "Report Content:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  report["content"] ?? "No content available",
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              
              // Add guidance note
              if (report["status"] == "pending") ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "After reviewing this report, you can record violations manually in Students Management.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade800,
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
          if (report["status"] == "pending")
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                final index = Provider.of<CounselorProvider>(context, listen: false)
                    .counselorStudentReports
                    .indexWhere((r) => r['id'] == report['id']);
                if (index >= 0) {
                  _verifyAndTallyReport(context, index);
                }
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Mark as Reviewed"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
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
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  return Consumer<CounselorProvider>(
    builder: (context, provider, child) {
      // Use the correct data source
      final reports = provider.counselorStudentReports.isNotEmpty 
          ? provider.counselorStudentReports 
          : provider.studentReports;
      final isLoading = provider.isLoadingCounselorStudentReports || provider.isLoading;

      return Scaffold(
          // Use AppBar instead of custom container for proper system padding
          appBar: AppBar(
            automaticallyImplyLeading: false, // Hide back button since we're in a tab
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            elevation: 4,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Student Reports',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${reports.length} reports • S.Y. ${provider.selectedSchoolYear}', // ✅ Show school year
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              // Filter Button
              IconButton(
                icon: const Icon(Icons.filter_list, color: Colors.white),
                onPressed: () => _showFilterDialog(),
                tooltip: 'Filter Reports',
              ),
              // Refresh Button
              IconButton(
                icon: isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
                onPressed: isLoading ? null : () => _fetchReports(),
                tooltip: 'Refresh',
              ),
              // Export Button
              IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: () => _exportReports(),
                tooltip: 'Export Reports',
              ),
              const SizedBox(width: 8), // Add some padding from the edge
            ],
          ),
          body: Column(
            children: [
              // ✅ NEW: School Year Banner
              const SchoolYearBanner(),
              
              // Main content
              Expanded(
                child: isLoading && reports.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Loading student reports..."),
                          ],
                        ),
                      )
                    : reports.isEmpty
                        ? _buildEmptyState(provider.selectedSchoolYear) // ✅ Pass school year
                        : RefreshIndicator(
                            onRefresh: () => provider.fetchCounselorStudentReports(forceRefresh: true),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: reports.length,
                              itemBuilder: (context, index) {
                                final report = reports[index];
                                final isLoading = _loadingReports.contains(index);
                                
                                return _buildReportCard(report, index, isLoading);
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Reports'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Reports'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              title: const Text('Pending Only'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              title: const Text('Reviewed Only'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _exportReports() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildEmptyState(String schoolYear) { // ✅ Add schoolYear parameter
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "No Student Reports",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            schoolYear == 'all'
                ? 'No reports available across all years'
                : 'No reports found for S.Y. $schoolYear', // ✅ Show school year context
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _fetchReports(),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, int index, bool isLoading) {
  final status = report["status"]?.toString().toLowerCase() ?? 'pending';
  final isInvalid = status == 'invalid' || status == 'dismissed';
  
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      // ✅ Add red border for invalid reports
      side: isInvalid 
          ? BorderSide(color: Colors.red.shade300, width: 2)
          : BorderSide.none,
    ),
    child: ExpansionTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: _getStatusColor(status).withOpacity(0.1),
            child: Icon(
              isInvalid ? Icons.cancel : Icons.report_problem,
              color: _getStatusColor(status),
            ),
          ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        report["title"] ?? "Untitled Report",
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: isInvalid ? TextDecoration.lineThrough : null,
          color: isInvalid ? Colors.grey.shade600 : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Student Reported: ${report["reported_student_name"] ?? report["student_name"] ?? report["student"]?["name"] ?? "Unknown"}",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isInvalid ? Colors.grey.shade500 : null,
            ),
          ),
          if (report["reported_by"] != null)
            Text(
              "Reported by: ${report["reported_by"]["name"] ?? "Unknown"}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Date: ${_formatDate(report["created_at"] ?? report["date"])}",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor(status),
                    width: 1,
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: isInvalid
          ? Icon(Icons.block, color: Colors.red.shade700)
          : (status == "pending"
              ? IconButton(
                  onPressed: isLoading 
                      ? null 
                      : () => _verifyAndTallyReport(context, index),
                  icon: Icon(
                    isLoading ? Icons.hourglass_empty : Icons.check_circle_outline,
                    color: isLoading ? Colors.grey : Colors.blue,
                  ),
                  tooltip: isLoading ? "Processing..." : "Review Report",
                )
              : Icon(
                  Icons.check_circle,
                  color: _getStatusColor(status),
                )),
      children: [
        // ✅ Add banner for invalid reports
        if (isInvalid)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.red.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.block, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '❌ This report has been marked as invalid/dismissed.\n'
                    'No further action is required.',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Report Details:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isInvalid ? Colors.grey.shade100 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isInvalid ? Colors.grey.shade300 : Colors.grey.shade200,
                  ),
                ),
                child: Text(
                  report["content"] ?? "No details available",
                  style: TextStyle(
                    fontSize: 14,
                    color: isInvalid ? Colors.grey.shade600 : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // ✅ Show different buttons based on status
              if (isInvalid)
                // For invalid reports - only show "View Details" button
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_off, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'No action needed - Report dismissed',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // For valid reports - show action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _showReportDetails(context, report),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text(
                          "View Details",
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (status == "pending")
  Flexible(
    flex: 2,
    child: ElevatedButton.icon(
      onPressed: isLoading 
          ? null 
          : () => _verifyAndTallyReport(context, index),
      icon: isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.notifications_active, size: 16), // ✅ Changed icon
      label: Text(
        isLoading ? "Sending..." : "Send Notice", // ✅ Changed text
        style: const TextStyle(fontSize: 12),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isLoading ? Colors.grey : Colors.blue, // ✅ Changed color
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: const Size(0, 36),
      ),
    ),
  ),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "Unknown";
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'reviewed':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  // Update the _verifyAndTallyReport method:
Future<void> _verifyAndTallyReport(BuildContext context, int index) async {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final report = counselorProvider.counselorStudentReports[index];

  // ✅ Show dialog to send guidance notice with both parties notified
  final sendNotice = await _showGuidanceNoticeDialog(context, report);
  if (!sendNotice) {
    return;
  }

  setState(() {
    _loadingReports.add(index);
  });

  try {
    // ✅ FIX: Get report type and pass it to sendGuidanceNotice
    final reportType = report['report_type']?.toString() ?? 'student_report';
    
    debugPrint('📢 Sending guidance notice for report #${report['id']} (type: $reportType)');
    
    // ✅ NEW: Send guidance notice to BOTH reporter and reported student with report type
    final success = await counselorProvider.sendGuidanceNotice(
      reportId: report['id'],
      reportType: reportType, // ✅ Pass the report type
      message: 'You are summoned to the guidance office regarding an incident report. Please report as soon as possible.',
      scheduledDate: DateTime.now(),
    );
    
    if (mounted) {
      if (success) {
        // Refresh the reports list
        await counselorProvider.fetchCounselorStudentReports(forceRefresh: true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "📢 Guidance Notices Sent!",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        "✓ ${report['reported_student_name'] ?? report['student_name'] ?? 'Student'} notified to report to guidance office\n"
                        "✓ ${report['reported_by']?['name'] ?? 'Reporter'} notified that student was summoned",
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to send guidance notices'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('❌ Error sending guidance notice: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending notices: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _loadingReports.remove(index);
      });
    }
  }
}

// ✅ NEW: Dialog to confirm sending guidance notice
Future<bool> _showGuidanceNoticeDialog(BuildContext context, Map<String, dynamic> report) async {
  final reportedStudentName = report['reported_student_name'] ?? report['student_name'] ?? 'Unknown Student';
  final reporterName = report['reported_by']?['name'] ?? 'Unknown Reporter';
  
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.notifications_active, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('📢 Send Guidance Notice')),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Report Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📄 Report Summary',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Divider(),
                    Text('Title: ${report['title'] ?? 'Untitled'}'),
                    const SizedBox(height: 4),
                    Text(
                      'Student Reported: $reportedStudentName',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Reported by: $reporterName'),
                    if (report['violation_type'] != null)
                      Text('Violation: ${report['violation_type']}'),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // ✅ NEW: Show who will be notified
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Both parties will be notified:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Reported Student notification
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.person, color: Colors.orange.shade700, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📢 $reportedStudentName',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Text(
                                'Will receive: "You are summoned to the guidance office regarding an incident report. Please report as soon as possible."',
                                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    
                    // Reporter notification
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.assignment_ind, color: Colors.green.shade700, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📋 $reporterName',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Text(
                                'Will receive: "Your report has been reviewed. The student has been summoned to the guidance office for counseling."',
                                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This report will move to "Send Guidance Notice" tab where you can later mark it as reviewed or invalid after counseling.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close, color: Colors.grey),
          label: const Text('Cancel'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mark as Invalid option
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(false);
                await _showMarkAsInvalidDialog(context, report);
              },
              icon: const Icon(Icons.block, color: Colors.red),
              label: const Text('Mark Invalid'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
            const SizedBox(width: 8),
            // Send Notice to Both button
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text('Send Notice to Both'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    ),
  ) ?? false;
}

// ✅ NEW: Dialog to mark report as invalid
Future<void> _showMarkAsInvalidDialog(BuildContext context, Map<String, dynamic> report) async {
  final reasonController = TextEditingController();
  
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.block, color: Colors.red),
          SizedBox(width: 8),
          Text('Mark Report as Invalid'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why is this report invalid?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: 'e.g., Report is unsubstantiated, false accusation, etc.',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This report will be marked as invalid and will not count towards violations.',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            reasonController.dispose();
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (reasonController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please provide a reason'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            if (reasonController.text.trim().length < 20) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please provide more details (at least 20 characters)'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Confirm Invalid', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  
  if (confirmed == true && mounted) {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    // ✅ FIX: Get and pass report type
    final reportType = report['report_type']?.toString() ?? 'student_report';
    
    final success = await counselorProvider.markReportAsInvalid(
      reportId: report['id'],
      reason: reasonController.text.trim(),
      reportType: reportType, // ✅ Pass the report type
    );
    
    if (success && mounted) {
      await counselorProvider.fetchCounselorStudentReports(forceRefresh: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '✅ Report Marked as Invalid',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${report['reported_student_name'] ?? report['student_name'] ?? 'Student'} has been cleared',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to mark report as invalid'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  reasonController.dispose();
}

  Future<bool> _showVerificationDialog(BuildContext context, Map<String, dynamic> report) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_user, color: Colors.blue),
            const SizedBox(width: 8),
            const Expanded(child: Text('📋 Review Report')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📄 Report Details', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Title: ${report['title'] ?? 'Untitled'}'),
                    Text('Student Reported: ${report['reported_student_name'] ?? report['student_name'] ?? 'Unknown'}'),
                    Text('Reported by: ${report['reported_by']?['name'] ?? 'Unknown'}'),
                    Text('Date: ${_formatDate(report['created_at'] ?? report['date'])}'),
                    if (report['violation_type'] != null)
                      Text('Violation Type: ${report['violation_type']}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📝 Report Content:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(report['content'] ?? 'No content available'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Is this report valid and accurate?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If valid, you can record violations manually in Students Management.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close, color: Colors.red),
            label: const Text('❌ Invalid/Dismiss'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('✅ Valid Report'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _markReportAsDismissed(BuildContext context, int index) async {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  final report = counselorProvider.counselorStudentReports[index];
  
  setState(() {
    _loadingReports.add(index);
  });

  try {
    // ✅ FIX: Get and pass report type
    final reportType = report['report_type']?.toString() ?? 'student_report';
    
    // ✅ Update report status to 'invalid' instead of just marking as reviewed
    final success = await counselorProvider.updateReportStatus(
      report['id'],
      'invalid', // Mark as invalid/dismissed
      reportType: reportType, // ✅ Pass the report type
    );
    
    if (mounted) {
      if (success) {
        await counselorProvider.fetchCounselorStudentReports(forceRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.block, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Report marked as invalid/dismissed.\n"
                    "It will not appear in the tally list.",
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Failed to dismiss report"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error dismissing report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _loadingReports.remove(index);
      });
    }
  }
}
}
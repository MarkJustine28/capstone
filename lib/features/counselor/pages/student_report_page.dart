import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counselor_provider.dart';
import '../../../widgets/school_year_banner.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

class StudentReportPage extends StatefulWidget {
  const StudentReportPage({super.key});

  @override
  State<StudentReportPage> createState() => _StudentReportPageState();
}

class _StudentReportPageState extends State<StudentReportPage> {
  final Set<int> _loadingReports = {};
  String _selectedStatus = 'all'; // ✅ ADD: Status filter
  String _searchQuery = ''; // ✅ ADD: Search query

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReports();
    });
  }

  // ✅ NEW: Get filtered reports (like teacher reports)
  List<Map<String, dynamic>> _getFilteredReports() {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    var reports = counselorProvider.counselorStudentReports.isNotEmpty 
        ? counselorProvider.counselorStudentReports 
        : counselorProvider.studentReports;

    // Filter by status
    if (_selectedStatus != 'all') {
      reports = reports.where((r) => (r['status'] ?? '').toLowerCase() == _selectedStatus).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      reports = reports.where((r) {
        final title = (r['title'] ?? '').toLowerCase();
        final studentName = (r['reported_student_name'] ?? r['student_name'] ?? '').toLowerCase();
        final content = (r['content'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return title.contains(query) || studentName.contains(query) || content.contains(query);
      }).toList();
    }

    return reports;
  }
  
  Future<void> _fetchReports({int retryCount = 0}) async {
    if (!mounted) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      
      if (authProvider.token == null) {
        debugPrint("❌ No authentication token available");
        return;
      }
      
      if (counselorProvider.token != authProvider.token) {
        counselorProvider.setToken(authProvider.token!);
      }
      
      if (retryCount == 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    retryCount > 0 
                        ? 'Retrying... (attempt ${retryCount + 1}/3)'
                        : 'Loading student reports...',
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }
      
      debugPrint("🔍 Fetching student reports (attempt ${retryCount + 1})...");
      final stopwatch = Stopwatch()..start();
      
      await counselorProvider.fetchCounselorStudentReports().timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception('Server timeout - Render.com free tier may be starting up (this can take 50+ seconds)');
        },
      );
      
      stopwatch.stop();
      debugPrint("✅ Student reports fetched in ${stopwatch.elapsedMilliseconds}ms");
      
      if (mounted && retryCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ Reports loaded successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } on TimeoutException catch (e) {
      debugPrint("⏱️ Timeout fetching student reports: $e");
      
      if (retryCount < 2 && mounted) {
        final waitSeconds = (retryCount + 1) * 5;
        
        debugPrint("⏳ Waiting ${waitSeconds}s before retry...");
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⏱️ Server is starting up...\n'
              'Retrying in $waitSeconds seconds (attempt ${retryCount + 2}/3)',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: waitSeconds),
          ),
        );
        
        await Future.delayed(Duration(seconds: waitSeconds));
        
        if (mounted) {
          await _fetchReports(retryCount: retryCount + 1);
        }
      } else if (mounted) {
        _showTimeoutErrorDialog();
      }
      
    } on http.ClientException catch (e) {
      debugPrint("🌐 Network error fetching student reports: $e");
      
      if (retryCount < 2 && mounted) {
        final waitSeconds = (retryCount + 1) * 3;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🌐 Network error. Retrying in $waitSeconds seconds...',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: waitSeconds),
            action: SnackBarAction(
              label: 'Retry Now',
              textColor: Colors.white,
              onPressed: () => _fetchReports(retryCount: retryCount + 1),
            ),
          ),
        );
        
        await Future.delayed(Duration(seconds: waitSeconds));
        
        if (mounted) {
          await _fetchReports(retryCount: retryCount + 1);
        }
      } else if (mounted) {
        _showNetworkErrorDialog();
      }
      
    } catch (e) {
      debugPrint("❌ Exception fetching student reports: $e");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to load reports: ${_getErrorMessage(e)}",
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _fetchReports(),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showTimeoutErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Server Timeout'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The server is taking longer than expected to respond.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
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
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Common Causes:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• Render.com free tier "cold start" (can take 50+ seconds)'),
                    const Text('• Server is processing large amounts of data'),
                    const Text('• Network connection is slow'),
                    const Text('• Server may be temporarily unavailable'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 What to try:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('1. Wait a moment and try again'),
                    Text('2. Check your internet connection'),
                    Text('3. Try refreshing the page'),
                    Text('4. If problem persists, contact admin'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _fetchReports();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Network Error'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unable to connect to the server.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔍 Please check:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('✓ Your internet connection is active'),
                    const Text('✓ You can access other websites'),
                    const Text('✓ Your firewall isn\'t blocking the connection'),
                    const Text('✓ The server URL is correct'),
                    const SizedBox(height: 12),
                    Text(
                      'Server: ${const String.fromEnvironment('SERVER_IP', defaultValue: 'Not configured')}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _fetchReports();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('timeout')) {
      return 'Server timeout - this can happen with Render.com free tier';
    } else if (errorStr.contains('socketexception') || errorStr.contains('failed to fetch')) {
      return 'Network error - check your connection';
    } else if (errorStr.contains('401')) {
      return 'Session expired - please login again';
    } else if (errorStr.contains('500')) {
      return 'Server error - please try again';
    } else if (errorStr.contains('502') || errorStr.contains('503')) {
      return 'Server temporarily unavailable';
    }
    return 'Connection error';
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
        // ✅ Use filtered reports instead
        final filteredReports = _getFilteredReports();
        final isLoading = provider.isLoadingCounselorStudentReports || provider.isLoading;
        final schoolYear = provider.selectedSchoolYear;

        debugPrint('📊 Student Reports Page:');
        debugPrint('   - Filtered reports: ${filteredReports.length}');
        debugPrint('   - Selected S.Y.: $schoolYear');

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
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
                  '${filteredReports.length} reports • S.Y. $schoolYear',
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
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // School Year Banner
              const SchoolYearBanner(),
              
              // ✅ NEW: Search Bar and Status Filter (like teacher reports)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade100,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search reports...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Status Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', 'all', Colors.grey),
                          _buildFilterChip('Pending', 'pending', Colors.orange),
                          _buildFilterChip('Reviewed', 'reviewed', Colors.green),
                          _buildFilterChip('Resolved', 'resolved', Colors.green),
                          _buildFilterChip('Dismissed', 'dismissed', Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main content
              Expanded(
                child: isLoading && filteredReports.isEmpty
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
                    : filteredReports.isEmpty
                        ? _buildEmptyState(schoolYear)
                        : RefreshIndicator(
                            onRefresh: () => provider.fetchCounselorStudentReports(forceRefresh: true),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: filteredReports.length,
                              itemBuilder: (context, index) {
                                final report = filteredReports[index];
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

  // ✅ NEW: Filter dialog (like teacher reports)
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
              onTap: () {
                setState(() => _selectedStatus = 'all');
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Pending Only'),
              onTap: () {
                setState(() => _selectedStatus = 'pending');
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Reviewed Only'),
              onTap: () {
                setState(() => _selectedStatus = 'reviewed');
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: const Text('Dismissed Only'),
              onTap: () {
                setState(() => _selectedStatus = 'dismissed');
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Filter chip widget (like teacher reports)
  Widget _buildFilterChip(String label, String value, Color color) {
    final isSelected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedStatus = value);
        },
        backgroundColor: Colors.white,
        selectedColor: color.withOpacity(0.2),
        checkmarkColor: color,
        labelStyle: TextStyle(
          color: isSelected ? color : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
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

  Widget _buildEmptyState(String schoolYear) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No reports match your search'
                : "No Student Reports",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              schoolYear == 'all'
                  ? 'No reports available across all years'
                  : 'No reports found for S.Y. $schoolYear',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _fetchReports(),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
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

  // Show dialog to send guidance notice
  final sendNotice = await _showGuidanceNoticeDialog(context, report);
  if (!sendNotice) {
    return;
  }

  setState(() {
    _loadingReports.add(index);
  });

  try {
    final reportType = report['report_type']?.toString() ?? 'student_report';
    
    debugPrint('📢 Sending guidance notice for report #${report['id']} (type: $reportType)');
    
    // ✅ Show progress
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Sending guidance notices...'),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );
    
    // Send guidance notice with timeout
    final success = await counselorProvider.sendGuidanceNotice(
      reportId: report['id'],
      reportType: reportType,
      message: 'You are summoned to the guidance office regarding an incident report. Please report as soon as possible.',
      scheduledDate: DateTime.now(),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Request timeout'),
    );
    
    if (mounted) {
      if (success) {
        // ✅ Success feedback
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
                        "✓ ${report['reported_student_name'] ?? report['student_name'] ?? 'Student'} notified\n"
                        "✓ ${report['reported_by']?['name'] ?? 'Reporter'} notified",
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Refresh with retry logic
        await _refreshReportsWithRetry(counselorProvider, report['id']);
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to send guidance notices'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  } on TimeoutException catch (e) {
    debugPrint('⏱️ Timeout sending guidance notice: $e');
    if (mounted) {
      _showTimeoutErrorDialog();
    }
  } on http.ClientException catch (e) {
    debugPrint('🌐 Network error sending guidance notice: $e');
    if (mounted) {
      _showNetworkErrorDialog();
    }
  } catch (e) {
    debugPrint('❌ Error sending guidance notice: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${_getErrorMessage(e)}'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _verifyAndTallyReport(context, index),
          ),
          duration: const Duration(seconds: 4),
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

// ✅ NEW: Retry logic for fetching reports
Future<void> _refreshReportsWithRetry(CounselorProvider provider, int reportId, {int retries = 3}) async {
  for (int attempt = 1; attempt <= retries; attempt++) {
    try {
      debugPrint('🔄 Attempt $attempt/$retries: Refreshing reports...');
      
      // Wait before retry (exponential backoff)
      if (attempt > 1) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }
      
      // Try to fetch reports
      await Future.wait([
        provider.fetchCounselorStudentReports(forceRefresh: true),
        provider.fetchStudentReports(),
      ], eagerError: false); // ✅ Don't stop on first error
      
      // ✅ Verify the report was updated
      final updatedReport = provider.studentReports
          .firstWhere((r) => r['id'] == reportId, orElse: () => {});
      
      if (updatedReport.isNotEmpty) {
        debugPrint('✅ Report #$reportId successfully updated: status=${updatedReport['status']}');
        return; // Success!
      } else {
        debugPrint('⚠️ Report #$reportId not found in updated list');
      }
      
    } catch (e) {
      debugPrint('⚠️ Attempt $attempt failed: $e');
      
      if (attempt == retries) {
        debugPrint('❌ All retry attempts failed. Data may be stale.');
        
        // ✅ Show warning but don't fail
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notice sent successfully!\n'
                      'List may not be updated yet. Pull to refresh.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Refresh Now',
                textColor: Colors.white,
                onPressed: () => _fetchReports(),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
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
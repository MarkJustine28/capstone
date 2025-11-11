import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/counselor_provider.dart';
import '../../../widgets/school_year_banner.dart'; // ✅ ADD THIS IMPORT
import '../../../config/routes.dart';

class TeacherReportsPage extends StatefulWidget {
  const TeacherReportsPage({Key? key}) : super(key: key);

  @override
  State<TeacherReportsPage> createState() => _TeacherReportsPageState();
}

class _TeacherReportsPageState extends State<TeacherReportsPage> {
  String _selectedStatus = 'all';
  String _searchQuery = '';
  final Set<int> _loadingReports = {}; // Track which reports are being updated

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchReports();
    });
  }

  Future<void> _fetchReports() async {
    if (!mounted) return;

    try {
      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      
      debugPrint("🔍 Starting to fetch teacher reports...");
      final stopwatch = Stopwatch()..start();
      
      await counselorProvider.fetchTeacherReports().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout - please check your connection');
        },
      );
      
      stopwatch.stop();
      debugPrint("✅ Teacher reports fetched in ${stopwatch.elapsedMilliseconds}ms");
      
    } catch (e) {
      debugPrint("❌ Exception fetching teacher reports: $e");
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

  List<Map<String, dynamic>> _getFilteredReports() {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    var reports = counselorProvider.teacherReports;

    // Filter by status
    if (_selectedStatus != 'all') {
      reports = reports.where((r) => (r['status'] ?? '').toLowerCase() == _selectedStatus).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      reports = reports.where((r) {
        final title = (r['title'] ?? '').toLowerCase();
        final studentName = (r['student_name'] ?? '').toLowerCase();
        final content = (r['content'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return title.contains(query) || studentName.contains(query) || content.contains(query);
      }).toList();
    }

    return reports;
  }

  Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange;
    case 'under_review':  // ✅ Added this
      return Colors.blue;
    case 'reviewed':  // Keep for backward compatibility
      return Colors.blue;
    case 'investigating':
      return Colors.purple;
    case 'resolved':
      return Colors.green;
    case 'dismissed':
    case 'invalid':
      return Colors.red;
    case 'escalated':
      return Colors.red.shade700;
    default:
      return Colors.grey;
  }
}

IconData _getStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Icons.pending;
    case 'under_review':  // ✅ Added this
    case 'reviewed':  // Keep for backward compatibility
      return Icons.rate_review;
    case 'investigating':
      return Icons.search;
    case 'resolved':
      return Icons.check_circle;
    case 'dismissed':
    case 'invalid':
      return Icons.cancel;
    case 'escalated':
      return Icons.warning;
    default:
      return Icons.info;
  }
}

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _verifyAndTallyReport(BuildContext context, Map<String, dynamic> report) async {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);

  // Show verification dialog
  final verified = await _showVerificationDialog(context, report);
  if (!verified) {
    // If not verified, mark as dismissed
    await _markReportAsDismissed(context, report);
    return;
  }

  // Mark as under_review (valid) - ✅ Changed from 'reviewed' to 'under_review'
  setState(() {
    _loadingReports.add(report['id']);
  });

  try {
    final success = await counselorProvider.updateTeacherReportStatus(
      report['id'],
      'under_review',  // ✅ Changed from 'reviewed' to 'under_review'
    );

    if (mounted) {
      if (success) {
        // Refresh the reports list
        await counselorProvider.fetchTeacherReports();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "✅ Report marked as valid and under review!\n"
                    "You can now manually record violations in Students Management.",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to mark report as reviewed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reviewing report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _loadingReports.remove(report['id']);
      });
    }
  }
}

  Future<bool> _showVerificationDialog(BuildContext context, Map<String, dynamic> report) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.verified_user, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Expanded(child: Text('📋 Review Report')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Report Summary Card
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
                        Icon(Icons.report, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text('📄 Report Details', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 16),
                    _buildInfoRow('Title', report['title'] ?? 'Untitled'),
                    _buildInfoRow('Student', report['student_name'] ?? 'Unknown'),
                    _buildInfoRow('Reported by', report['reported_by']?['username'] ?? 'Unknown'),
                    _buildInfoRow('Date', _formatDate(report['created_at'])),
                    if (report['violation_type'] != null)
                      _buildInfoRow('Violation', report['violation_type']),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Report Content
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, color: Colors.grey.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text('📝 Report Content', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      report['content'] ?? 'No content available',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Verification Question
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
                              fontSize: 13,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _markReportAsDismissed(BuildContext context, Map<String, dynamic> report) async {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    setState(() {
      _loadingReports.add(report['id']);
    });

    try {
      final success = await counselorProvider.updateTeacherReportStatus(
        report['id'],
        'dismissed',
      );
      
      if (mounted) {
        if (success) {
          await counselorProvider.fetchTeacherReports();
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
          _loadingReports.remove(report['id']);
        });
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDetails(BuildContext context, Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            const Expanded(child: Text('Report Details')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Report Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['title'] ?? 'Untitled Report',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getStatusIcon(report['status'] ?? 'pending'),
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (report['status'] ?? 'pending').replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
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
              
              // Report Information
              _buildDetailCard(
                icon: Icons.person,
                title: 'Student Information',
                color: Colors.green,
                children: [
                  _buildDetailRow('Name', report['student_name'] ?? 'Unknown'),
                  if (report['student_id'] != null)
                    _buildDetailRow('Student ID', report['student_id'].toString()),
                ],
              ),
              const SizedBox(height: 12),
              
              _buildDetailCard(
                icon: Icons.person_outline,
                title: 'Reporter Information',
                color: Colors.orange,
                children: [
                  _buildDetailRow('Reported by', report['reported_by']?['username'] ?? 'Unknown'),
                  _buildDetailRow('Report Date', _formatDate(report['created_at'])),
                ],
              ),
              const SizedBox(height: 12),
              
              if (report['violation_type'] != null || report['incident_date'] != null)
                _buildDetailCard(
                  icon: Icons.warning,
                  title: 'Violation Information',
                  color: Colors.red,
                  children: [
                    if (report['violation_type'] != null)
                      _buildDetailRow('Type', report['violation_type']),
                    if (report['incident_date'] != null)
                      _buildDetailRow('Incident Date', _formatDate(report['incident_date'])),
                  ],
                ),
              
              const SizedBox(height: 12),
              
              // Report Content
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, color: Colors.grey.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Report Content',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      report['content'] ?? 'No content available',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                    ),
                  ],
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
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CounselorProvider>(
      builder: (context, provider, child) {
        final filteredReports = _getFilteredReports();
        final isLoading = provider.isLoading;
        final schoolYear = provider.selectedSchoolYear;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Teacher Reports",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${filteredReports.length} reports • S.Y. $schoolYear', // ✅ Added school year
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
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
                onPressed: isLoading ? null : _fetchReports,
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // ✅ NEW: School Year Banner
              const SchoolYearBanner(),
              
              // Search Bar
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
                          _buildFilterChip('Under Review', 'under_review', Colors.blue),
                          _buildFilterChip('Resolved', 'resolved', Colors.green),
                          _buildFilterChip('Dismissed', 'dismissed', Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Reports List
              Expanded(
                child: isLoading && filteredReports.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Loading teacher reports..."),
                          ],
                        ),
                      )
                    : filteredReports.isEmpty
                        ? _buildEmptyState(schoolYear) // ✅ Pass school year
                        : RefreshIndicator(
                            onRefresh: _fetchReports,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: filteredReports.length,
                              itemBuilder: (context, index) {
                                final report = filteredReports[index];
                                final isLoadingReport = _loadingReports.contains(report['id']);
                                
                                return _buildReportCard(report, isLoadingReport);
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
                : 'No Teacher Reports',
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
                : 'No reports for S.Y. $schoolYear',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Reports will appear here when teachers submit them",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _fetchReports,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              if (schoolYear != 'all')
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.counselorSettings);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Change Year'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isLoading) {
    final status = report["status"]?.toString().toLowerCase() ?? 'pending';
    final isInvalid = status == 'invalid' || status == 'dismissed';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
      "Student: ${report["student_name"] ?? "Unknown"}",
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: isInvalid ? Colors.grey.shade500 : null,
      ),
    ),
    if (report["reported_by"] != null)
      Text(
        "Reported by: ${report["reported_by"]["username"] ?? "Unknown"}",
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
    
    if (report["violation_type"] != null)
      Text(
        "Type: ${report["violation_type"]}",
        style: TextStyle(
          fontSize: 12,
          color: isInvalid ? Colors.grey.shade500 : Colors.blue.shade700,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    
    const SizedBox(height: 4),
    
    // ✅ FIXED: Wrapped in Flexible to prevent overflow
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            _formatDate(report["created_at"]),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
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
              fontSize: 9,
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
                        : () => _verifyAndTallyReport(context, report),
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
                
                if (isInvalid)
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
                                : () => _verifyAndTallyReport(context, report),
                            icon: isLoading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline, size: 16),
                            label: Text(
                              isLoading ? "Processing..." : "Mark Reviewed",
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLoading ? Colors.grey : Colors.green,
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
}
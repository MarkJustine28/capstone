import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/student_provider.dart';
import '../../../providers/auth_provider.dart';

class ViewRecordsPage extends StatefulWidget {
  const ViewRecordsPage({super.key});

  @override
  State<ViewRecordsPage> createState() => _ViewRecordsPageState();
}

class _ViewRecordsPageState extends State<ViewRecordsPage> {
  String _selectedFilter = 'all';
  String _selectedSortBy = 'newest';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshReports();
    });
  }

  Future<void> _refreshReports() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    
    if (authProvider.token != null) {
      await studentProvider.fetchReports(authProvider.token!);
    }
  }

  List<Map<String, dynamic>> _getFilteredAndSortedReports(List<Map<String, dynamic>> reports) {
    // Filter reports
    List<Map<String, dynamic>> filteredReports = reports;
    
    if (_selectedFilter != 'all') {
      filteredReports = reports.where((report) {
        final status = (report['status'] ?? '').toString().toLowerCase();
        return status == _selectedFilter;
      }).toList();
    }

    // Sort reports
    filteredReports.sort((a, b) {
      switch (_selectedSortBy) {
        case 'newest':
          final dateA = _parseDate(a['created_at'] ?? a['date']);
          final dateB = _parseDate(b['created_at'] ?? b['date']);
          return dateB.compareTo(dateA);
        case 'oldest':
          final dateA = _parseDate(a['created_at'] ?? a['date']);
          final dateB = _parseDate(b['created_at'] ?? b['date']);
          return dateA.compareTo(dateB);
        case 'title':
          return (a['title'] ?? '').toString().compareTo((b['title'] ?? '').toString());
        case 'status':
          return (a['status'] ?? '').toString().compareTo((b['status'] ?? '').toString());
        default:
          return 0;
      }
    });

    return filteredReports;
  }

  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    try {
      return DateTime.parse(dateValue.toString());
    } catch (e) {
      return DateTime.now();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'completed':
        return Colors.green;
      case 'under_review':
      case 'investigating':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      case 'dismissed':
        return Colors.red;
      case 'escalated':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'completed':
        return Icons.check_circle;
      case 'under_review':
      case 'investigating':
        return Icons.search;
      case 'pending':
        return Icons.schedule;
      case 'dismissed':
        return Icons.cancel;
      case 'escalated':
        return Icons.priority_high;
      default:
        return Icons.report;
    }
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) {
          final createdAt = _parseDate(report['created_at'] ?? report['date']);
          final formattedDate = DateFormat('MMMM d, yyyy • h:mm a').format(createdAt);

          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title and Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        report['title'] ?? 'Untitled Report',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(report['status'] ?? ''),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(report['status'] ?? ''),
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (report['status'] ?? 'Unknown').toString().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Date and additional info - FIX: Wrap text in Expanded/Flexible
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, // FIX: Align to start
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded( // FIX: Wrap text in Expanded
                            child: Text(
                              'Submitted: $formattedDate',
                              style: const TextStyle(color: Colors.grey),
                              overflow: TextOverflow.ellipsis, // FIX: Handle overflow
                            ),
                          ),
                        ],
                      ),
                      if (report['violation_type'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start, // FIX: Align to start
                          children: [
                            const Icon(Icons.category, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded( // FIX: Wrap text in Expanded to prevent overflow
                              child: Text(
                                'Type: ${report['violation_type']}',
                                style: const TextStyle(color: Colors.grey),
                                softWrap: true, // FIX: Allow text wrapping
                                overflow: TextOverflow.visible, // FIX: Allow text to wrap instead of ellipsis
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (report['custom_violation'] != null && report['custom_violation'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.edit_note, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Custom: ${report['custom_violation']}',
                                style: const TextStyle(color: Colors.grey),
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (report['location'] != null && report['location'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded( // FIX: Wrap text in Expanded
                              child: Text(
                                'Location: ${report['location']}',
                                style: const TextStyle(color: Colors.grey),
                                softWrap: true, // FIX: Allow text wrapping
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (report['category'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.label, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Category: ${report['category']}',
                                style: const TextStyle(color: Colors.grey),
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (report['severity'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.priority_high, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Severity: ${report['severity']}',
                                style: const TextStyle(color: Colors.grey),
                                softWrap: true,
                                overflow: TextOverflow.visible,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Content
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        report['content'] ?? 'No description provided.',
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Close button
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentProvider>(
      builder: (context, studentProvider, child) {
        final reports = _getFilteredAndSortedReports(studentProvider.reports);

        return Scaffold(
          appBar: AppBar(
            title: const Text("My Reports"),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                onSelected: (value) {
                  setState(() {
                    if (value.startsWith('filter_')) {
                      _selectedFilter = value.replaceFirst('filter_', '');
                    } else if (value.startsWith('sort_')) {
                      _selectedSortBy = value.replaceFirst('sort_', '');
                    }
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    enabled: false,
                    child: Text('Filter by Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  PopupMenuItem(
                    value: 'filter_all',
                    child: Row(
                      children: [
                        Icon(_selectedFilter == 'all' ? Icons.check : Icons.filter_list),
                        const SizedBox(width: 8),
                        const Text('All Reports'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'filter_pending',
                    child: Row(
                      children: [
                        Icon(_selectedFilter == 'pending' ? Icons.check : Icons.schedule),
                        const SizedBox(width: 8),
                        const Text('Pending'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'filter_under_review',
                    child: Row(
                      children: [
                        Icon(_selectedFilter == 'under_review' ? Icons.check : Icons.search),
                        const SizedBox(width: 8),
                        const Text('Under Review'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'filter_resolved',
                    child: Row(
                      children: [
                        Icon(_selectedFilter == 'resolved' ? Icons.check : Icons.check_circle),
                        const SizedBox(width: 8),
                        const Text('Resolved'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    enabled: false,
                    child: Text('Sort by', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  PopupMenuItem(
                    value: 'sort_newest',
                    child: Row(
                      children: [
                        Icon(_selectedSortBy == 'newest' ? Icons.check : Icons.arrow_downward),
                        const SizedBox(width: 8),
                        const Text('Newest First'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sort_oldest',
                    child: Row(
                      children: [
                        Icon(_selectedSortBy == 'oldest' ? Icons.check : Icons.arrow_upward),
                        const SizedBox(width: 8),
                        const Text('Oldest First'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sort_title',
                    child: Row(
                      children: [
                        Icon(_selectedSortBy == 'title' ? Icons.check : Icons.sort_by_alpha),
                        const SizedBox(width: 8),
                        const Text('Title A-Z'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sort_status',
                    child: Row(
                      children: [
                        Icon(_selectedSortBy == 'status' ? Icons.check : Icons.label),
                        const SizedBox(width: 8),
                        const Text('Status'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: studentProvider.isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading your reports...'),
                    ],
                  ),
                )
              : reports.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _refreshReports,
                      child: ListView(
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFilter == 'all' 
                                    ? "No reports submitted yet."
                                    : "No reports with status '$_selectedFilter'.",
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Pull to refresh",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshReports,
                      child: Column(
                        children: [
                          // Summary bar
                          Container(
                            padding: const EdgeInsets.all(16),
                            color: Colors.green.shade50,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded( // FIX: Wrap in Expanded to prevent overflow
                                  child: Text(
                                    '${reports.length} of ${studentProvider.reports.length} reports',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green.shade800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_selectedFilter != 'all' || _selectedSortBy != 'newest')
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _selectedFilter = 'all';
                                        _selectedSortBy = 'newest';
                                      });
                                    },
                                    icon: const Icon(Icons.clear, size: 16),
                                    label: const Text('Clear'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.green.shade800,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Reports list
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: reports.length,
                              itemBuilder: (context, index) {
                                final report = reports[index];
                                final createdAt = _parseDate(report['created_at'] ?? report['date']);
                                final formattedDate = DateFormat('MMM d, yyyy').format(createdAt);

                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: CircleAvatar(
                                      backgroundColor: _getStatusColor(report['status'] ?? ''),
                                      child: Icon(
                                        _getStatusIcon(report['status'] ?? ''),
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      report['title'] ?? 'Untitled Report',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2, // FIX: Limit title lines
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(report['status'] ?? '').withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _getStatusColor(report['status'] ?? '').withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            (report['status'] ?? 'Unknown').toString().toUpperCase(),
                                            style: TextStyle(
                                              color: _getStatusColor(report['status'] ?? ''),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Expanded( // FIX: Wrap in Expanded
                                              child: Text(
                                                formattedDate,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _showReportDetails(report),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/counselor_provider.dart';

class SectionAnalyticsPage extends StatefulWidget {
  const SectionAnalyticsPage({super.key});

  @override
  State<SectionAnalyticsPage> createState() => _SectionAnalyticsPageState();
}

class _SectionAnalyticsPageState extends State<SectionAnalyticsPage> {
  String? selectedSchoolYear;
  String selectedSemester = 'All';
  bool _isLoading = false;
  Map<String, dynamic>? analyticsData;
  List<String> availableSchoolYears = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    
    try {
      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      
      // Get available school years from backend
      availableSchoolYears = await _fetchAvailableSchoolYears();
      
      // Set default to current school year
      if (availableSchoolYears.isNotEmpty) {
        selectedSchoolYear = availableSchoolYears.first;
      } else {
        // Fallback to current year
        final currentYear = DateTime.now().year;
        final month = DateTime.now().month;
        if (month >= 6) {
          selectedSchoolYear = '$currentYear-${currentYear + 1}';
        } else {
          selectedSchoolYear = '${currentYear - 1}-$currentYear';
        }
      }
      
      await _loadAnalytics();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<String>> _fetchAvailableSchoolYears() async {
    try {
      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      // Fetch available school years from backend
      // For now, generate based on current date and past years
      final currentYear = DateTime.now().year;
      final month = DateTime.now().month;
      
      List<String> years = [];
      int startYear = month >= 6 ? currentYear : currentYear - 1;
      
      for (int i = 0; i < 5; i++) {
        final year = startYear - i;
        years.add('$year-${year + 1}');
      }
      
      return years;
    } catch (e) {
      debugPrint('❌ Error fetching school years: $e');
      return [];
    }
  }

  Future<void> _loadAnalytics() async {
    if (selectedSchoolYear == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      final data = await counselorProvider.getSectionAnalytics(
        schoolYear: selectedSchoolYear!,
        semester: selectedSemester != 'All' ? selectedSemester : null,
      );
      
      if (mounted) {
        setState(() {
          analyticsData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading analytics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Section Violations Analytics'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCSV,
            tooltip: 'Export Report',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : analyticsData == null
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  child: Column(
                    children: [
                      // Filters
                      _buildFilterSection(),
                      
                      // Summary Cards
                      _buildSummaryCards(),
                      
                      // Section Breakdown
                      Expanded(
                        child: _buildSectionsList(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No analytics data available',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try refreshing or check your connection',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Filter Analytics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedSchoolYear,
                  decoration: InputDecoration(
                    labelText: 'School Year',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.calendar_today, color: Colors.blue.shade700),
                  ),
                  items: availableSchoolYears.isEmpty
                      ? [
                          DropdownMenuItem(
                            value: selectedSchoolYear,
                            child: Text(selectedSchoolYear ?? 'Loading...'),
                          ),
                        ]
                      : availableSchoolYears
                          .map((year) => DropdownMenuItem(
                                value: year,
                                child: Text(year),
                              ))
                          .toList(),
                  onChanged: availableSchoolYears.isEmpty
                      ? null
                      : (value) {
                          setState(() => selectedSchoolYear = value!);
                          _loadAnalytics();
                        },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedSemester,
                  decoration: InputDecoration(
                    labelText: 'Semester',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.school, color: Colors.blue.shade700),
                  ),
                  items: ['All', '1st Semester', '2nd Semester']
                      .map((sem) => DropdownMenuItem(
                            value: sem,
                            child: Text(sem),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => selectedSemester = value!);
                    _loadAnalytics();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalViolations = analyticsData?['total_violations'] ?? 0;
    final totalSections = analyticsData?['total_sections'] ?? 0;
    final avgPerSection = analyticsData?['avg_per_section'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Violations',
              totalViolations.toString(),
              Icons.warning_amber,
              Colors.red,
              'Across all sections',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Total Sections',
              totalSections.toString(),
              Icons.class_,
              Colors.blue,
              'Active sections',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Avg per Section',
              avgPerSection is double 
                  ? avgPerSection.toStringAsFixed(1)
                  : avgPerSection.toString(),
              Icons.analytics,
              Colors.orange,
              'Mean violations',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionsList() {
    final sections = analyticsData?['sections'] as List<dynamic>? ?? [];

    if (sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No sections found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'No violations recorded for $selectedSchoolYear',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index] as Map<String, dynamic>;
        return _buildSectionCard(section, index);
      },
    );
  }

  Widget _buildSectionCard(Map<String, dynamic> section, int index) {
    final sectionName = section['name'] ?? 'Unknown Section';
    final gradeLevel = section['grade_level'] ?? 0;
    final totalViolations = section['total_violations'] is int 
        ? section['total_violations'] 
        : int.tryParse(section['total_violations'].toString()) ?? 0;
    final studentCount = section['student_count'] is int
        ? section['student_count']
        : int.tryParse(section['student_count'].toString()) ?? 0;
    final avgPerStudent = section['avg_per_student'] is double
        ? section['avg_per_student']
        : double.tryParse(section['avg_per_student'].toString()) ?? 0.0;
    final violationBreakdown = section['violation_breakdown'] as Map<String, dynamic>? ?? {};

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getSectionColor(totalViolations).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getSectionColor(totalViolations),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _getSectionColor(totalViolations).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              totalViolations.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                sectionName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Grade $gradeLevel',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(Icons.people, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '$studentCount students',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 12),
              Icon(Icons.analytics, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '${avgPerStudent.toStringAsFixed(1)} avg/student',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pie_chart, color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Violation Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (violationBreakdown.isEmpty)
                  const Text(
                    'No violations recorded',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  )
                else
                  ...violationBreakdown.entries.map((entry) {
                    final violationCount = entry.value is int
                        ? entry.value
                        : int.tryParse(entry.value.toString()) ?? 0;
                    final percentage = totalViolations > 0
                        ? (violationCount / totalViolations * 100)
                        : 0.0;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '$violationCount (${percentage.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalViolations > 0 ? violationCount / totalViolations : 0,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              color: _getViolationTypeColor(entry.key),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _viewSectionDetails(section),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('View Details'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
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

  Color _getSectionColor(int violations) {
    if (violations >= 30) return Colors.red.shade600;
    if (violations >= 20) return Colors.orange.shade600;
    if (violations >= 10) return Colors.yellow.shade700;
    return Colors.green.shade600;
  }

  Color _getViolationTypeColor(String violationType) {
    final colors = [
      Colors.red.shade400,
      Colors.orange.shade400,
      Colors.blue.shade400,
      Colors.purple.shade400,
      Colors.pink.shade400,
      Colors.teal.shade400,
      Colors.indigo.shade400,
    ];
    
    return colors[violationType.hashCode.abs() % colors.length];
  }

  void _exportToCSV() {
    if (analyticsData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // TODO: Implement actual CSV export
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download, color: Colors.white),
            const SizedBox(width: 12),
            Text('Exporting ${analyticsData!['total_sections']} sections...'),
          ],
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _viewSectionDetails(Map<String, dynamic> section) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.class_, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                section['name'] ?? 'Section Details',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Grade Level', 'Grade ${section['grade_level']}'),
                _buildDetailRow('Total Violations', '${section['total_violations']}'),
                _buildDetailRow('Student Count', '${section['student_count']}'),
                _buildDetailRow(
                  'Average per Student',
                  section['avg_per_student'] != null
                      ? (section['avg_per_student'] is double
                          ? section['avg_per_student'].toStringAsFixed(2)
                          : section['avg_per_student'].toString())
                      : 'N/A',
                ),
                const Divider(height: 24),
                const Text(
                  'Violation Breakdown:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                if ((section['violation_breakdown'] as Map<String, dynamic>?)?.isEmpty ?? true)
                  const Text(
                    'No violations recorded',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  )
                else
                  ...(section['violation_breakdown'] as Map<String, dynamic>)
                      .entries
                      .map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(entry.key)),
                                Text(
                                  '${entry.value}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),
              ],
            ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
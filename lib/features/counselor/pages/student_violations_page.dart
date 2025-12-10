import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counselor_provider.dart';
import '../widgets/tally_violation_dialog.dart';
import '../../../widgets/school_year_banner.dart';
import '../../../core/constants/app_breakpoints.dart';
import '../../../config/routes.dart';
import '../pages/counseling_sessions_page.dart';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;

class StudentViolationsPage extends StatefulWidget {
  const StudentViolationsPage({super.key});

  @override
  State<StudentViolationsPage> createState() => _StudentViolationsPageState();
}

class _StudentViolationsPageState extends State<StudentViolationsPage> {
  String _searchQuery = '';
  String _selectedGrade = 'All';
  String _selectedSection = 'All';
  String _selectedSchoolYear = ''; // ✅ Add this
  List<String> availableSchoolYears = [];
  bool _showOnlyWithViolations = false;
  bool _showFolderView = true; // New toggle for folder view
  bool _isLoadingSchoolYears = false;

  final List<String> grades = ['All', '7', '8', '9', '10', '11', '12'];

  // Updated sections map with complete sections for all grades, sorted alphabetically
  final Map<String, List<String>> gradeSections = {
    '7': [
      'Newton',
      'Armstrong',
      'Moseley',
      'Boyle',
      'Edison',
      'Marconi',
      'Locke',
      'Morse',
      'Kepler',
      'Roentgen',
      'Einstein',
      'Ford',
      'Faraday'
    ],
    '8': [
      'Pasteur',
      'Aristotle',
      'Cooper',
      'Mendel',
      'Darwin',
      'Harvey',
      'Davis',
      'Linnaeus',
      'Brown',
      'Fleming',
      'Hooke'
    ],
    '9': [
      'Dalton',
      'Calvin',
      'Lewis',
      'Bunsen',
      'Maxwell',
      'Curie',
      'Garnett',
      'Perkins',
      'Bosch',
      'Meyer'
    ],
    '10': ['Galileo', 'Rutherford', 'Thompson', 'Ampere', 'Volta', 'Siemens', 'Archimedes', 'Chadwick', 'Pascal', 'Hamilton', 'Franklin', 'Anderson'],
  };

  // Strands for Grade 11 and 12
  final Map<String, List<String>> gradeStrands = {
    '11': [
      'STEM',
      'PBM',
      'ABM',
      'HUMSS',
      'HOME ECONOMICS',
      'HOME ECONOMICS/ICT',
      'ICT',
      'EIM-SMAW',
      'SMAW'
    ],
    '12': [
      'SMAW',
      'EIM',
      'ICT',
      'HE',
      'HUMSS',
      'ABM',
      'PBM',
      'STEM'
    ],
  };

  // Sections for each strand by grade
  final Map<String, Map<String, List<String>>> strandSections = {
    '11': {
      'STEM': ['Engineering'],
      'PBM': ['Marine Transportation', 'Marine Engineering'],
      'ABM': ['Financial and Accounting', 'Business and Management', 'Tourism and Hospitality'],
      'HUMSS': ['Socios Hominis', 'Consilium et Communis', 'Scientia Dicsiplina', 'Politicos et Gubernare'],
      'HOME ECONOMICS': ['Culinary Alchemist'],
      'HOME ECONOMICS/ICT': ['Food Innovator'],
      'ICT': ['Computer Networking Technology', 'Computer Hardware Technology'],
      'EIM-SMAW': ['Electrical Technology'],
      'SMAW': ['Welding Fabrication'],
    },
    '12': {
      'SMAW': ['Beryl', 'Gold'],
      'EIM': ['Zircon'],
      'ICT': ['Onyx', 'Amber'],
      'HE': ['Alexandrite'],
      'HUMSS': ['Diamond', 'Pearl', 'Amethyst'],
      'ABM': ['Aquamarine', 'Emerald'],
      'PBM': ['Jade', 'Ruby'],
      'STEM': ['Tanzanite', 'Sapphire'],
    },
  };

  // Helper method to get all sections dynamically
  List<String> get allSections {
    Set<String> sections = {'All'};
    for (String grade in grades.where((g) => g != 'All')) {
      sections.addAll(gradeSections[grade] ?? []);
    }
    return sections.toList()..sort();
  }

  // Helper method to get sections for selected grade
  List<String> get availableSections {
  if (_selectedGrade == 'All') {
    // Show all sections from all grades and strands
    Set<String> sections = {'All'};
    for (String grade in grades.where((g) => g != 'All')) {
      sections.addAll(gradeSections[grade] ?? []);
      if (strandSections.containsKey(grade)) {
        for (var strand in strandSections[grade]!.values) {
          sections.addAll(strand);
        }
      }
    }
    return sections.toList()..sort();
  }
  // For grades 7-10
  if (gradeSections.containsKey(_selectedGrade)) {
    return ['All', ...gradeSections[_selectedGrade]!];
  }
  // For grades 11-12, flatten all strand sections
  if (strandSections.containsKey(_selectedGrade)) {
    Set<String> sections = {'All'};
    for (var strand in strandSections[_selectedGrade]!.values) {
      sections.addAll(strand);
    }
    return sections.toList()..sort();
  }
  return ['All'];
}

  List<String> _generateSchoolYears() {
  final currentYear = DateTime.now().year;
  final month = DateTime.now().month;
  
  // School year starts in June (month 6)
  int startYear = month >= 6 ? currentYear : currentYear - 1;
  
  // Generate current and past 5 school years
  List<String> years = [];
  for (int i = 0; i < 6; i++) {
    final year = startYear - i;
    years.add('$year-${year + 1}');
  }
  
  return years;
}

  @override
void initState() {
  super.initState();
  
  // ✅ Generate available school years
  availableSchoolYears = _generateSchoolYears();
  
  // ✅ Set default to current school year
  final currentYear = DateTime.now().year;
  final currentMonth = DateTime.now().month;
  _selectedSchoolYear = currentMonth >= 6 
      ? '$currentYear-${currentYear + 1}'
      : '${currentYear - 1}-$currentYear';
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _fetchData();
  });
}

  Future<void> _fetchData() async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
  
  if (authProvider.token != null) {
    counselorProvider.setToken(authProvider.token!);
    
    // ✅ Pass school year to fetch methods
    await counselorProvider.fetchStudentsList(schoolYear: _selectedSchoolYear);
    
    // ✅ DEBUG: Check what data we received
    print('📊 Fetched students count: ${counselorProvider.studentsList.length}');
    print('🔍 Selected school year: $_selectedSchoolYear');
    if (counselorProvider.studentsList.isNotEmpty) {
      final firstStudent = counselorProvider.studentsList.first;
      print('📝 First student data: $firstStudent');
      print('📅 First student school_year: ${firstStudent['school_year']}');
    }
    
    await counselorProvider.fetchStudentViolations(schoolYear: _selectedSchoolYear);
    await counselorProvider.fetchViolationTypes();
    await counselorProvider.fetchStudentReports();
    await counselorProvider.fetchTeacherReports();
  }
}

final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
Widget build(BuildContext context) {
  return Consumer<CounselorProvider>(
    builder: (context, provider, child) {
      // ✅ FIX: Get selected school year from provider
      final selectedSchoolYear = provider.selectedSchoolYear;
      
      // ✅ FIX: Filter students based on selected school year FIRST
      List<Map<String, dynamic>> yearFilteredStudents;
      
      if (selectedSchoolYear == 'all') {
        // Show all students from all years
        yearFilteredStudents = provider.studentsList;
      } else {
        // Show only students from selected year
        yearFilteredStudents = provider.studentsList.where((student) {
          final studentSchoolYear = student['school_year']?.toString() ?? '';
          return studentSchoolYear == selectedSchoolYear;
        }).toList();
      }
      
      // ✅ THEN apply other filters (search, grade, section)
      final filteredStudents = yearFilteredStudents.where((student) {
  final matchesGrade = _selectedGrade == 'All' || student['grade_level']?.toString() == _selectedGrade;
  final matchesSection = _selectedSection == 'All' || student['section']?.toString() == _selectedSection;
  final matchesSearch = _searchQuery.isEmpty ||
      (student['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
      (student['student_id']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
      (student['first_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
      (student['last_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

  // Filter by violation status if needed
  if (_showOnlyWithViolations) {
    final studentViolations = provider.studentViolations.where((v) {
      final violationStudentId = v['student_id']?.toString() ?? v['student']?['id']?.toString();
      final currentStudentId = student['id']?.toString();
      final violationSchoolYear = v['school_year']?.toString() ?? '';
      final matchesYear = selectedSchoolYear == 'all' || violationSchoolYear == selectedSchoolYear;
      return violationStudentId == currentStudentId && matchesYear;
    }).toList();
    return matchesSearch && matchesGrade && matchesSection && studentViolations.isNotEmpty;
  }

  return matchesSearch && matchesGrade && matchesSection;
}).toList();

      // Sort students by grade and section
      filteredStudents.sort((a, b) {
        final gradeCompare = (a['grade_level'] ?? '').toString().compareTo((b['grade_level'] ?? '').toString());
        if (gradeCompare != 0) return gradeCompare;
        return (a['section'] ?? '').toString().compareTo((b['section'] ?? '').toString());
      });

      return Scaffold(
          key: _scaffoldKey, // ✅ ADD: Assign key
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.of(context).size.width;
                final isDesktop = AppBreakpoints.isDesktop(screenWidth);
                final isTablet = AppBreakpoints.isTablet(screenWidth);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Students Management",
                      style: TextStyle(fontSize: isDesktop ? 20 : 18),
                    ),
                    Text(
                      '${filteredStudents.length} students • S.Y. $selectedSchoolYear',
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                );
              },
            ),
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            actions: [
      LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isDesktop = AppBreakpoints.isDesktop(screenWidth);
          final iconSize = isDesktop ? 24.0 : 20.0;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Summoned Students Button
              IconButton(
                icon: Icon(Icons.notifications_active, size: iconSize),
                tooltip: 'Summoned Students',
                onPressed: () => _showSendGuidanceNoticeDialog(),
              ),
              
              // Tally Report Button  
              IconButton(
                icon: Icon(Icons.assignment, size: iconSize),
                tooltip: 'Tally Report',
                onPressed: () => _showTallyReportDialog(context),
              ),
              
              // Menu with more options
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: iconSize),
                offset: const Offset(0, 50),
                onSelected: (value) {
                  switch (value) {
                    case 'add_student':
                      _showAddStudentDialog(context);
                      break;
                    case 'bulk_add':
                      _showBulkAddDialog();
                      break;
                    case 'export':
                      _exportStudentsList();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'add_student',
                    child: Row(
                      children: [
                        Icon(Icons.person_add, size: 20),
                        SizedBox(width: 12),
                        Text('Add Student'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'bulk_add',
                    child: Row(
                      children: [
                        Icon(Icons.group_add, size: 20),
                        SizedBox(width: 12),
                        Text('Bulk Add Students'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 12),
                        Text('Export List'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ],
  ),

  drawer: _buildNavigationDrawer(),

        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    // School Year Banner
                    const SchoolYearBanner(),

                    // Search and Filter Section - RESPONSIVE
                    LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final screenWidth = innerConstraints.maxWidth;
                        final isDesktop = AppBreakpoints.isDesktop(screenWidth);
                        final isTablet = AppBreakpoints.isTablet(screenWidth);
                        final padding = AppBreakpoints.getPadding(screenWidth);

                        return Container(
                          padding: EdgeInsets.all(padding),
                          color: Colors.grey.shade50,
                          child: Column(
                            children: [
                              // School year filter info banner
                              if (selectedSchoolYear != 'all')
                                Container(
                                  margin: EdgeInsets.only(bottom: isDesktop ? 16 : 12),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 16 : 12,
                                    vertical: isDesktop ? 10 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.filter_list,
                                        size: isDesktop ? 20 : 16,
                                        color: Colors.blue.shade700,
                                      ),
                                      SizedBox(width: isDesktop ? 12 : 8),
                                      Expanded(
                                        child: Text(
                                          'Showing students enrolled in S.Y. $selectedSchoolYear only',
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

                              // Search bar
                              TextField(
                                decoration: InputDecoration(
                                  hintText: "Search by student name or ID...",
                                  hintStyle: TextStyle(fontSize: isDesktop ? 16 : 14),
                                  prefixIcon: Icon(Icons.search, size: isDesktop ? 24 : 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: padding,
                                    vertical: isDesktop ? 16 : 12,
                                  ),
                                ),
                                style: TextStyle(fontSize: isDesktop ? 16 : 14),
                                onChanged: (value) => setState(() => _searchQuery = value),
                              ),
                              SizedBox(height: isDesktop ? 16 : 12),

                              // Filters - RESPONSIVE LAYOUT
                              if (isDesktop || isTablet)
                                // Desktop/Tablet: Single row
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildGradeDropdown(isDesktop: isDesktop),
                                    ),
                                    SizedBox(width: padding),
                                    Expanded(
                                      flex: 2,
                                      child: _buildSectionDropdown(isDesktop: isDesktop),
                                    ),
                                    SizedBox(width: padding),
                                    Expanded(
                                      flex: 3,
                                      child: _buildViolationToggle(isDesktop: isDesktop),
                                    ),
                                  ],
                                )
                              else
                                // Mobile: Stacked layout
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: _buildGradeDropdown(isDesktop: false)),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildSectionDropdown(isDesktop: false)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildViolationToggle(isDesktop: false),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Students List - keep your existing code
                    provider.isLoadingStudentsList
                        ? const Center(child: CircularProgressIndicator())
                        : filteredStudents.isEmpty
                            ? LayoutBuilder(
                                builder: (context, innerConstraints) {
                                  final isDesktop = AppBreakpoints.isDesktop(innerConstraints.maxWidth);
                                  return Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(isDesktop ? 32 : 24),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.person_off,
                                            size: isDesktop ? 80 : 64,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: isDesktop ? 24 : 16),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? "No students found matching your search"
                                                : "No students enrolled in S.Y. $selectedSchoolYear",
                                            style: TextStyle(
                                              fontSize: isDesktop ? 18 : 16,
                                              color: Colors.grey,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          SizedBox(height: isDesktop ? 12 : 8),
                                          Text(
                                            selectedSchoolYear == 'all'
                                                ? 'No students found across all years'
                                                : 'Add students or change school year filter',
                                            style: TextStyle(
                                              fontSize: isDesktop ? 14 : 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          SizedBox(height: isDesktop ? 24 : 16),
                                          ElevatedButton.icon(
                                            onPressed: () => _showAddStudentDialog(context),
                                            icon: Icon(Icons.person_add, size: isDesktop ? 20 : 18),
                                            label: Text(
                                              "Add Student",
                                              style: TextStyle(fontSize: isDesktop ? 16 : 14),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isDesktop ? 24 : 20,
                                                vertical: isDesktop ? 16 : 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : LayoutBuilder(
                                builder: (context, innerConstraints) {
                                  return _showFolderView
                                      ? _buildFolderView(filteredStudents, provider)
                                      : _buildListView(filteredStudents, provider);
                                },
                              ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}


Widget _buildGradeDropdown({required bool isDesktop}) {
  return DropdownButtonFormField<String>(
    value: _selectedGrade,
    decoration: InputDecoration(
      labelText: 'Grade',
      labelStyle: TextStyle(fontSize: isDesktop ? 14 : 12),
      border: const OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16 : 12,
        vertical: isDesktop ? 16 : 12,
      ),
    ),
    style: TextStyle(fontSize: isDesktop ? 14 : 12, color: Colors.black),
    isExpanded: true,
    items: grades.map((grade) => DropdownMenuItem(
      value: grade,
      child: Text(
        grade == 'All' ? 'All Grades' : 'Grade $grade',
        style: TextStyle(fontSize: isDesktop ? 14 : 12),
      ),
    )).toList(),
    onChanged: (value) => setState(() {
      _selectedGrade = value ?? 'All';
      _selectedSection = 'All';
    }),
  );
}

// Helper widget for Section dropdown
Widget _buildSectionDropdown({required bool isDesktop}) {
  return DropdownButtonFormField<String>(
    value: _selectedSection,
    decoration: InputDecoration(
      labelText: 'Section',
      labelStyle: TextStyle(fontSize: isDesktop ? 14 : 12),
      border: const OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16 : 12,
        vertical: isDesktop ? 16 : 12,
      ),
    ),
    style: TextStyle(fontSize: isDesktop ? 14 : 12, color: Colors.black),
    isExpanded: true,
    items: availableSections.map((section) => DropdownMenuItem(
      value: section,
      child: Text(
        section,
        style: TextStyle(fontSize: isDesktop ? 14 : 12),
        overflow: TextOverflow.ellipsis,
      ),
    )).toList(),
    onChanged: (value) => setState(() => _selectedSection = value ?? 'All'),
  );
}

// Helper widget for Violation toggle
Widget _buildViolationToggle({required bool isDesktop}) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: isDesktop ? 16 : 12,
      vertical: isDesktop ? 8 : 6,
    ),
    decoration: BoxDecoration(
      color: _showOnlyWithViolations ? Colors.orange.shade50 : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
      border: Border.all(
        color: _showOnlyWithViolations ? Colors.orange.shade200 : Colors.grey.shade300,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: _showOnlyWithViolations,
          onChanged: (value) => setState(() => _showOnlyWithViolations = value),
          activeColor: Colors.orange,
        ),
        SizedBox(width: isDesktop ? 12 : 8),
        Expanded(
          child: Text(
            'Show only students with violations',
            style: TextStyle(
              fontSize: isDesktop ? 14 : 12,
              fontWeight: _showOnlyWithViolations ? FontWeight.w600 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

  // NEW: List View - Simple table-like structure
  Widget _buildListView(List<Map<String, dynamic>> students, CounselorProvider provider) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isDesktop = AppBreakpoints.isDesktop(screenWidth);
      final isTablet = AppBreakpoints.isTablet(screenWidth);
      final padding = AppBreakpoints.getPadding(screenWidth);

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(padding),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          final primaryStudentId = student['id']?.toString();
          
          // Get ONLY tallied violations (with related_report)
          final studentViolations = provider.studentViolations
              .where((violation) {
                final violationStudentId = violation['student_id']?.toString() ??
                                          violation['student']?['id']?.toString();
                
                if (violationStudentId != primaryStudentId) {
                  return false;
                }
                
                // ONLY count tallied violations
                return violation['related_report_id'] != null || 
                       violation['related_report'] != null;
              })
              .toList();

          final talliedCount = studentViolations.length;
          final activeTallied = studentViolations
              .where((v) => v['status']?.toString().toLowerCase() == 'active' ||
                           v['status']?.toString().toLowerCase() == 'pending')
              .length;

          return Card(
            margin: EdgeInsets.only(bottom: isDesktop ? 12 : 8),
            elevation: isDesktop ? 3 : 2,
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 12,
                vertical: isDesktop ? 12 : 8,
              ),
              leading: CircleAvatar(
                backgroundColor: _getTalliedViolationColor(talliedCount),
                radius: isDesktop ? 28 : 24,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      talliedCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 16 : 14,
                      ),
                    ),
                    if (isDesktop)
                      const Text(
                        'tallied',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
              title: Text(
                student['name']?.toString() ?? 'Unknown Student',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isDesktop ? 16 : 14,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ID: ${student['student_id'] ?? 'N/A'} • Grade ${student['grade_level']} ${student['section']}',
                    style: TextStyle(fontSize: isDesktop ? 14 : 13),
                  ),
                  if (student['email']?.toString().isNotEmpty == true && (isDesktop || isTablet))
                    Text(
                      student['email'].toString(),
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 12,
                        color: Colors.grey,
                      ),
                    ),
                  SizedBox(height: isDesktop ? 6 : 4),
                  Wrap(
                    spacing: isDesktop ? 6 : 4,
                    runSpacing: 4,
                    children: [
                      if (talliedCount > 0) ...[
                        _buildChip(
                          'Tallied: $talliedCount',
                          Colors.blue,
                          fontSize: isDesktop ? 12 : 11,
                        ),
                        if (activeTallied > 0)
                          _buildChip(
                            'Active: $activeTallied',
                            Colors.orange,
                            fontSize: isDesktop ? 12 : 11,
                          ),
                      ] else
                        _buildChip(
                          'No tallied violations',
                          Colors.grey,
                          fontSize: isDesktop ? 12 : 11,
                        ),
                    ],
                  ),
                ],
              ),
              trailing: isDesktop
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_alert),
                          color: Colors.orange,
                          tooltip: 'Add Violation',
                          onPressed: () => _showAddViolationDialog(student),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          color: Colors.blue,
                          tooltip: 'Edit Student',
                          onPressed: () => _showEditStudentDialog(student),
                        ),
                        if (talliedCount > 0)
                          IconButton(
                            icon: const Icon(Icons.history),
                            color: Colors.green,
                            tooltip: 'View History',
                            onPressed: () => _showViolationHistoryDialog(student, studentViolations),
                          ),
                      ],
                    )
                  : PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        switch (value) {
                          case 'add_violation':
                            _showAddViolationDialog(student);
                            break;
                          case 'edit_student':
                            _showEditStudentDialog(student);
                            break;
                          case 'view_history':
                            _showViolationHistoryDialog(student, studentViolations);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'add_violation',
                          child: Row(
                            children: [
                              Icon(Icons.add_alert, color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Text('Add Violation'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit_student',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Text('Edit Student'),
                            ],
                          ),
                        ),
                        if (talliedCount > 0)
                          const PopupMenuItem(
                            value: 'view_history',
                            child: Row(
                              children: [
                                Icon(Icons.history, color: Colors.green, size: 20),
                                SizedBox(width: 8),
                                Text('View History'),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          );
        },
      );
    },
  );
}

  // Helper to get canonical sections for a grade (includes strandSections for 11/12)
  List<String> _sectionsForGrade(String grade) {
    // Use explicit gradeSections first
    if (gradeSections.containsKey(grade)) {
      return List<String>.from(gradeSections[grade]!);
    }

    // For senior grades, flatten strandSections (keep unique, sorted)
    if (strandSections.containsKey(grade)) {
      final Map<String, List<String>> strands = strandSections[grade]!;
      final Set<String> sections = <String>{};
      for (final sList in strands.values) {
        sections.addAll(sList);
      }
      final result = sections.toList()..sort();
      return result;
    }

    // Fallback: empty list
    return <String>[];
  }

  // NEW: Folder View - ensure sections display even when empty
  Widget _buildFolderView(List<Map<String, dynamic>> students, CounselorProvider provider) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isDesktop = AppBreakpoints.isDesktop(screenWidth);
      final isTablet = AppBreakpoints.isTablet(screenWidth);
      final padding = AppBreakpoints.getPadding(screenWidth);

      // Group students by grade and section
      final Map<String, Map<String, List<Map<String, dynamic>>>> gradeGroups = {};

      // Initialize all grades and sections (even if empty)
      for (final grade in ['7', '8', '9', '10', '11', '12']) {
        gradeGroups[grade] = {};
        final sections = _sectionsForGrade(grade);
        for (final section in sections) {
          gradeGroups[grade]![section] = [];
        }
      }

      // Add students to their respective groups
      for (final student in students) {
        final grade = student['grade_level']?.toString() ?? 'Unknown';
        final section = student['section']?.toString() ?? 'Unknown';

        if (!gradeGroups.containsKey(grade)) {
          gradeGroups[grade] = {};
        }
        if (!gradeGroups[grade]!.containsKey(section)) {
          gradeGroups[grade]![section] = [];
        }

        gradeGroups[grade]![section]!.add(student);
      }

      // Filter grades and sections based on selected filters
      List<String> gradesToShow;
      if (_selectedGrade != 'All') {
        gradesToShow = [_selectedGrade];
      } else {
        gradesToShow = gradeGroups.keys.toList()..sort((a, b) {
          if (a == 'Unknown') return 1;
          if (b == 'Unknown') return -1;
          try {
            final gradeA = int.parse(a);
            final gradeB = int.parse(b);
            return gradeA.compareTo(gradeB);
          } catch (e) {
            return a.compareTo(b);
          }
        });
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(padding),
        itemCount: gradesToShow.length,
        itemBuilder: (context, gradeIndex) {
          final grade = gradesToShow[gradeIndex];
          final sections = gradeGroups[grade]!;

          // Filter sections if a specific section is selected
          List<String> sectionsToShow;
          if (_selectedSection != 'All') {
            sectionsToShow = sections.keys.where((s) => s == _selectedSection).toList();
          } else {
            sectionsToShow = sections.keys.toList()..sort();
          }

          // Count students in shown sections
          final totalStudentsInGrade = sectionsToShow.fold<int>(
            0, 
            (sum, section) => sum + sections[section]!.length,
          );

          return Card(
            margin: EdgeInsets.only(bottom: isDesktop ? 12 : 8),
            elevation: isDesktop ? 3 : 2,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Icon(
                  Icons.folder,
                  color: totalStudentsInGrade > 0 
                      ? Colors.blue.shade700 
                      : Colors.grey.shade400,
                  size: isDesktop ? 36 : 32,
                ),
                title: Text(
                  'Grade $grade',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 20 : 18,
                    color: totalStudentsInGrade > 0 
                        ? Colors.black 
                        : Colors.grey.shade600,
                  ),
                ),
                subtitle: Text(
                  totalStudentsInGrade > 0
                      ? '$totalStudentsInGrade students • ${sectionsToShow.length} sections'
                      : 'Empty • ${sectionsToShow.length} sections',
                  style: TextStyle(
                    fontSize: isDesktop ? 14 : 13,
                    color: totalStudentsInGrade > 0 
                        ? Colors.grey 
                        : Colors.grey.shade500,
                  ),
                ),
                children: [
                  Container(
                    padding: EdgeInsets.only(
                      left: isDesktop ? 20 : 16,
                      right: isDesktop ? 20 : 16,
                      bottom: isDesktop ? 20 : 16,
                    ),
                    child: _buildSectionsForGrade(
                      Map.fromEntries(
                        sectionsToShow.map(
                          (section) => MapEntry(section, sections[section]!),
                        ),
                      ),
                      provider,
                      grade,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  // Update _buildSectionsForGrade to use canonical sections list so empty sections show
  Widget _buildSectionsForGrade(Map<String, List<Map<String, dynamic>>> sections, CounselorProvider provider, String grade) {
    // Use canonical sections for this grade so predefined sections appear even when empty
    final allSectionsForGrade = _sectionsForGrade(grade);

    // Create a complete sections map with empty lists for missing sections
    final completeSections = <String, List<Map<String, dynamic>>>{};
    for (final section in allSectionsForGrade) {
      completeSections[section] = sections[section] ?? [];
    }

    // Add any extra sections that have students but aren't in the predefined list
    for (final entry in sections.entries) {
      if (!completeSections.containsKey(entry.key)) {
        completeSections[entry.key] = entry.value;
      }
    }

    // Sort sections alphabetically
    final sortedSections = completeSections.keys.toList()..sort((a, b) {
      if (a == 'Unknown') return 1;
      if (b == 'Unknown') return -1;
      if (a.length == 1 && b.length == 1) {
        return a.compareTo(b);
      }
      return a.compareTo(b);
    });

    return Column(
      children: sortedSections.map((section) {
        final students = completeSections[section]!;
        final hasStudents = students.isNotEmpty;

        // Sort students within each section by name
        if (hasStudents) {
          students.sort((a, b) {
            final nameA = a['name']?.toString() ?? '';
            final nameB = b['name']?.toString() ?? '';
            return nameA.compareTo(nameB);
          });
        }

        int totalSectionViolations = 0;
        if (hasStudents) {
          for (final student in students) {
            final studentId = student['id']?.toString();
            if (studentId != null) {
              final studentViolations = provider.studentViolations.where((violation) {
                final violationStudentId = violation['student_id']?.toString() ??
                                          violation['student']?['id']?.toString();
                return violationStudentId == studentId;
              }).length;
              totalSectionViolations += studentViolations;
            }
          }
        }

        // Create placeholder student for empty sections
        final displayStudents = hasStudents ? students : [_createEmptyStudent(grade, section)];

        return Card(
          margin: const EdgeInsets.only(bottom: 4),
          color: hasStudents ? Colors.grey.shade50 : Colors.grey.shade100,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(
                hasStudents ? Icons.folder_open : Icons.folder_outlined,
                color: hasStudents ? Colors.orange.shade700 : Colors.grey.shade400,
                size: 24,
              ),
              title: Text(
                '$section',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: hasStudents ? Colors.black : Colors.grey.shade600,
                ),
              ),
              subtitle: Row(
                children: [
                  Text(
                    hasStudents ? '${students.length} students' : 'Empty section',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasStudents ? Colors.grey : Colors.grey.shade500,
                    ),
                  ),
                  if (hasStudents && totalSectionViolations > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getTalliedViolationColor(totalSectionViolations).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _getTalliedViolationColor(totalSectionViolations).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_turned_in,
                            size: 12,
                            color: _getTalliedViolationColor(totalSectionViolations),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$totalSectionViolations tallied',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getTalliedViolationColor(totalSectionViolations),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Column(
                    children: displayStudents.map((student) => _buildCompactStudentCard(student, provider, isPlaceholder: !hasStudents)).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // Helper to create a placeholder student for empty sections
  Map<String, dynamic> _createEmptyStudent(String grade, String section) {
    return {
      'id': null,
      'student_id': null,
      'name': 'Empty',
      'full_name': 'Empty',
      'first_name': '',
      'last_name': '',
      'grade_level': grade,
      'section': section,
      'email': '',
      'contact_number': '',
      'guardian_name': '',
      'guardian_contact': '',
      'is_active': false,
    };
  }

  // Compact student card for folder view
  Widget _buildCompactStudentCard(
  Map<String, dynamic> student,
  CounselorProvider provider, {
  bool isPlaceholder = false,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isDesktop = AppBreakpoints.isDesktop(screenWidth);
      final isTablet = AppBreakpoints.isTablet(screenWidth);

      final studentName = student['name']?.toString() ?? 
                         student['full_name']?.toString() ?? 
                         (() {
                           final firstName = student['first_name']?.toString() ?? '';
                           final lastName = student['last_name']?.toString() ?? '';
                           final fullName = '$firstName $lastName'.trim();
                           return fullName.isNotEmpty 
                               ? fullName 
                               : (student['username']?.toString() ?? 'Unknown Student');
                         })();
      
      final primaryStudentId = student['id']?.toString();
      
      if (primaryStudentId == null && !isPlaceholder) {
        print('⚠️ Warning: Student has no ID: $studentName');
      }
      
      final allStudentViolations = provider.studentViolations.where((violation) {
        final violationStudentId = violation['student_id']?.toString() ??
                                  violation['student']?['id']?.toString();
        return violationStudentId == primaryStudentId;
      }).toList();
      
      final studentViolations = allStudentViolations;

      final studentId = student['student_id']?.toString() ?? 
                       student['id']?.toString() ?? 
                       'No ID';
      
      final gradeSection = 'Grade ${student['grade_level'] ?? 'Unknown'} ${student['section'] ?? 'Unknown'}';
      final email = student['email']?.toString() ?? '';
      final isActive = student['is_active'] == true || 
                      student['status']?.toString() == 'active';

      // Calculate violation summary
      final totalViolations = studentViolations.length;
      final activeViolations = studentViolations
          .where((v) => v['status']?.toString().toLowerCase() == 'active' ||
                       v['status']?.toString().toLowerCase() == 'pending')
          .length;
      
      final resolvedViolations = studentViolations
          .where((v) => v['status']?.toString().toLowerCase() == 'resolved' ||
                       v['status']?.toString().toLowerCase() == 'closed')
          .length;

      final highSeverityViolations = studentViolations
          .where((v) {
            final severity = v['severity']?.toString().toLowerCase() ?? 
                            v['severity_level']?.toString().toLowerCase() ?? 
                            v['violation_type']?['severity_level']?.toString().toLowerCase() ?? '';
            return severity == 'high' || severity == 'critical';
          })
          .length;

      final needsAttention = totalViolations >= 3 || highSeverityViolations >= 1;
      final criticalAttention = totalViolations >= 5 || highSeverityViolations >= 2;

      return Card(
        margin: EdgeInsets.symmetric(
          horizontal: isDesktop ? 6 : 4,
          vertical: isDesktop ? 4 : 2,
        ),
        elevation: isDesktop ? 3 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
          side: BorderSide(
            color: criticalAttention 
                ? Colors.red 
                : needsAttention 
                    ? Colors.orange 
                    : Colors.transparent,
            width: criticalAttention ? 3 : 2,
          ),
        ),
        child: ExpansionTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: _getTalliedViolationColor(totalViolations),
                radius: isDesktop ? 28 : 24,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      totalViolations.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 18 : 16,
                      ),
                    ),
                    if (isDesktop || isTablet)
                      const Text(
                        'tallied',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
              ),
              if (criticalAttention)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(isDesktop ? 5 : 4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.priority_high,
                      color: Colors.white,
                      size: isDesktop ? 14 : 12,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  studentName,
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.black : Colors.grey,
                  ),
                  maxLines: isDesktop ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (needsAttention)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 10 : 8,
                    vertical: isDesktop ? 5 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: criticalAttention ? Colors.red : Colors.orange,
                    borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        criticalAttention ? Icons.warning : Icons.info,
                        color: Colors.white,
                        size: isDesktop ? 14 : 12,
                      ),
                      SizedBox(width: isDesktop ? 5 : 4),
                      Text(
                        criticalAttention ? 'URGENT' : 'ATTENTION',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isDesktop ? 11 : 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ID: $studentId • $gradeSection',
                style: TextStyle(fontSize: isDesktop ? 13 : 12),
              ),
              if (email.isNotEmpty && (isDesktop || isTablet))
                Text(
                  email,
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 11,
                    color: Colors.grey,
                  ),
                ),
              SizedBox(height: isDesktop ? 6 : 4),
              
              // Violation summary with responsive sizing
              Container(
                padding: EdgeInsets.all(isDesktop ? 10 : 8),
                decoration: BoxDecoration(
                  color: _getTalliedViolationColor(totalViolations).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                  border: Border.all(
                    color: _getTalliedViolationColor(totalViolations).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assignment_turned_in,
                          size: isDesktop ? 18 : 16,
                          color: _getTalliedViolationColor(totalViolations),
                        ),
                        SizedBox(width: isDesktop ? 8 : 6),
                        Expanded(
                          child: Text(
                            '$totalViolations Tallied Violation${totalViolations != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: isDesktop ? 14 : 13,
                              fontWeight: FontWeight.bold,
                              color: _getTalliedViolationColor(totalViolations),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    if (totalViolations > 0) ...[
                      SizedBox(height: isDesktop ? 6 : 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (activeViolations > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: _buildChip(
                                'Active: $activeViolations',
                                Colors.orange,
                                fontSize: isDesktop ? 12 : 11,
                              ),
                            ),
                          if (resolvedViolations > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: _buildChip(
                                'Resolved: $resolvedViolations',
                                Colors.green,
                                fontSize: isDesktop ? 12 : 11,
                              ),
                            ),
                          if (highSeverityViolations > 0)
                            _buildChip(
                              'High Severity: $highSeverityViolations',
                              Colors.red,
                              fontSize: isDesktop ? 12 : 11,
                            ),
                        ],
                      ),
                    ],
                    
                    // Action recommendation
                    if (needsAttention) ...[
                      SizedBox(height: isDesktop ? 8 : 6),
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 8 : 6),
                        decoration: BoxDecoration(
                          color: criticalAttention 
                              ? Colors.red.withOpacity(0.1) 
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(isDesktop ? 8 : 6),
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: isDesktop ? 8 : 6),
                            Expanded(
                              child: Text(
                                criticalAttention 
                                    ? 'Requires immediate counselor intervention'
                                    : 'Consider calling student for counseling',
                                style: TextStyle(
                                  fontSize: isDesktop ? 12 : 11,
                                  color: criticalAttention ? Colors.red : Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: EdgeInsets.all(isDesktop ? 20 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student Details
                  _buildStudentDetailsSection(student),
                  SizedBox(height: isDesktop ? 20 : 16),
                  
                  // Tallied Violations List
                  _buildStudentViolationsSection(studentViolations),
                  SizedBox(height: isDesktop ? 20 : 16),
                  
                  // Action Buttons
                  _buildStudentActionButtons(student, needsAttention),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

  // Helper method to get color based on tallied violation count
  Color _getStatusColor(int count) {
    if (count == 0) return Colors.green;
    if (count <= 2) return Colors.blue;
    if (count <= 4) return Colors.orange;
    return Colors.red;
  }

  // Compatibility shim: older code used `_getTalliedViolationColor`; delegate to the canonical _getStatusColor
  Color _getTalliedViolationColor(int count) => _getStatusColor(count);

  // Small utility to build a colored chip-like widget used across the UI
  Widget _buildChip(String label, Color color, {double fontSize = 12}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: FontWeight.w600,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    ),
  );
}

  // Helper method to get severity color
  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'low': return Colors.green;
      case 'medium': return Colors.orange;
      case 'high': return Colors.red;
      case 'critical': return Colors.deepPurple;
      default: return Colors.grey;
    }
  }

  // Helper method to get status color by string
  Color _getStatusColorByString(String status) {
    switch (status.toLowerCase()) {
      case 'active': case 'pending': return Colors.orange;
      case 'resolved': case 'closed': return Colors.green;
      default: return Colors.grey;
    }
  }

  // Helper method to format date
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  // Helper method to build student details section
  Widget _buildStudentDetailsSection(Map<String, dynamic> student) {
  // ✅ FIX: Build full name from available fields with proper fallbacks
  String getFullName() {
    // Try different field combinations to get the full name
    
    // Option 1: Direct 'name' field
    if (student['name']?.toString().isNotEmpty == true) {
      return student['name'].toString();
    }
    
    // Option 2: Direct 'full_name' field
    if (student['full_name']?.toString().isNotEmpty == true) {
      return student['full_name'].toString();
    }
    
    // Option 3: Combine first_name and last_name
    final firstName = student['first_name']?.toString() ?? '';
    final lastName = student['last_name']?.toString() ?? '';
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }
    
    // Option 4: Try user nested object (if student data comes from User model)
    if (student['user'] != null) {
      final user = student['user'] as Map<String, dynamic>;
      final userFirstName = user['first_name']?.toString() ?? '';
      final userLastName = user['last_name']?.toString() ?? '';
      if (userFirstName.isNotEmpty || userLastName.isNotEmpty) {
        return '$userFirstName $userLastName'.trim();
      }
      
      // Try user's full_name
      if (user['full_name']?.toString().isNotEmpty == true) {
        return user['full_name'].toString();
      }
    }
    
    // Option 5: Fall back to username
    if (student['username']?.toString().isNotEmpty == true) {
      return student['username'].toString();
    }
    
    // Option 6: Fall back to user's username
    if (student['user']?['username']?.toString().isNotEmpty == true) {
      return student['user']['username'].toString();
    }
    
    // Final fallback
    return 'Unknown Student';
  }

  // ✅ NEW: Get LRN with proper fallbacks
  String getLRN() {
    // Try different LRN field names
    final lrnFields = [
      'lrn', 'LRN', 'learner_reference_number', 'learners_reference_number'
    ];
    
    for (final field in lrnFields) {
      if (student[field]?.toString().isNotEmpty == true) {
        return student[field].toString();
      }
    }
    
    // Try user nested object
    if (student['user'] != null) {
      for (final field in lrnFields) {
        if (student['user'][field]?.toString().isNotEmpty == true) {
          return student['user'][field].toString();
        }
      }
    }
    
    return 'N/A';
  }

  // ✅ FIX: Get email with proper fallbacks
  String getEmail() {
    if (student['email']?.toString().isNotEmpty == true) {
      return student['email'].toString();
    }
    if (student['user']?['email']?.toString().isNotEmpty == true) {
      return student['user']['email'].toString();
    }
    return 'N/A';
  }

  // ✅ FIX: Get contact with proper fallbacks
  String getContact() {
    // Try different contact field names
    final contactFields = [
      'contact_number', 'phone', 'contact', 'phone_number', 
      'mobile', 'mobile_number', 'student_contact'
    ];
    
    for (final field in contactFields) {
      if (student[field]?.toString().isNotEmpty == true) {
        return student[field].toString();
      }
    }
    
    // Try user nested object
    if (student['user'] != null) {
      for (final field in contactFields) {
        if (student['user'][field]?.toString().isNotEmpty == true) {
          return student['user'][field].toString();
        }
      }
    }
    
    return 'N/A';
  }

  // ✅ FIX: Get guardian info with proper fallbacks
  String getGuardianName() {
    final guardianFields = [
      'guardian_name', 'parent_name', 'guardian', 'parent', 
      'emergency_contact_name', 'contact_person'
    ];
    
    for (final field in guardianFields) {
      if (student[field]?.toString().isNotEmpty == true) {
        return student[field].toString();
      }
    }
    
    return 'N/A';
  }

  String getGuardianContact() {
    final guardianContactFields = [
      'guardian_contact', 'parent_contact', 'guardian_phone', 'parent_phone',
      'emergency_contact_number', 'contact_person_phone', 'guardian_contact_number'
    ];
    
    for (final field in guardianContactFields) {
      if (student[field]?.toString().isNotEmpty == true) {
        return student[field].toString();
      }
    }
    
    return 'N/A';
  }

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Student Details',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // ✅ UPDATED: Removed Student ID and Status, Added LRN
        _buildDetailRow(Icons.person, 'Full Name', getFullName()),
        _buildDetailRow(Icons.numbers, 'LRN', getLRN()), // ✅ ADDED LRN
        _buildDetailRow(Icons.school, 'Grade & Section', 'Grade ${student['grade_level'] ?? 'Unknown'} ${student['section'] ?? 'Unknown'}'),
        _buildDetailRow(Icons.email, 'Email', getEmail()),
        _buildDetailRow(Icons.phone, 'Contact', getContact()),
        _buildDetailRow(Icons.family_restroom, 'Guardian', getGuardianName()),
        _buildDetailRow(Icons.contact_phone, 'Guardian Contact', getGuardianContact()),
        
        // ✅ KEEP: School year info (if available)
        if (student['school_year']?.toString().isNotEmpty == true)
          _buildDetailRow(Icons.calendar_today, 'School Year', student['school_year'].toString()),
      ],
    ),
  );
}

// Make sure you have the updated _buildDetailRow method that accepts IconData
Widget _buildDetailRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
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


  // Helper method to build student violations section
  Widget _buildStudentViolationsSection(List<Map<String, dynamic>> violations) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tallied Violations (${violations.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (violations.isEmpty)
            const Text(
              'No tallied violations from reports',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            )
          else
            ...violations.take(3).map((violation) {
              final violationType = violation['violation_type']?['name']?.toString() ?? 
                                   violation['type']?.toString() ?? 
                                   violation['name']?.toString() ?? 
                                   'Unknown';
              
              final status = violation['status']?.toString() ?? 'Unknown';
              
              final date = violation['date']?.toString() ?? 
                          violation['created_at']?.toString() ?? 
                          violation['recorded_at']?.toString() ?? 
                          'Unknown date';
              
              final severity = violation['severity']?.toString() ?? 
                             violation['severity_level']?.toString() ??
                             violation['violation_type']?['severity_level']?.toString() ?? 
                             'Medium';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border(
                    left: BorderSide(
                      width: 3,
                      color: _getSeverityColor(severity),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            violationType,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColorByString(status),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.assignment_turned_in, size: 12, color: Colors.blue),
                        const SizedBox(width: 4),
                        Text(
                          'Tallied from report',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(date),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          if (violations.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${violations.length - 3} more tallied violations',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to build action buttons for student
  Widget _buildStudentActionButtons(Map<String, dynamic> student, bool needsAttention) {
  return Column(
    children: [
      // First row: Add Violation + Edit Student
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showAddViolationDialog(student),
              icon: const Icon(Icons.add_alert, size: 16),
              label: const Text('Add Violation', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showEditStudentDialog(student),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Student', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
      
      // Second row: Schedule Counseling (if needs attention)
      if (needsAttention) ...[
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showScheduleCounselingDialog(student),
            icon: const Icon(Icons.psychology, size: 16),
            label: const Text('Schedule Counseling Session', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ],
    ],
  );
}



  // Dialog Methods
  void _showAddStudentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddStudentDialog(
        onStudentAdded: () => _fetchData(),
        gradeSections: gradeSections,
      ),
    );
  }

  void _showEditStudentDialog(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => _EditStudentDialog(
        student: student,
        onStudentUpdated: () => _fetchData(),
        gradeSections: gradeSections,
      ),
    );
  }

  void _showAddViolationDialog(Map<String, dynamic> student) {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => _RecordViolationDialog(
        preSelectedStudent: student,
        violationTypes: counselorProvider.violationTypes,
        onViolationRecorded: () => _fetchData(),
      ),
    );
  }

  void _showViolationHistoryDialog(Map<String, dynamic> student, List<Map<String, dynamic>> violations) {
    showDialog(
      context: context,
      builder: (context) => _ViolationHistoryDialog(
        student: student,
        violations: violations,
      ),
    );
  }

  void _showBulkAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _BulkAddStudentsDialog(
        onStudentsAdded: () => _fetchData(),
        gradeSections: gradeSections,
      ),
    );
  }

  void _exportStudentsList() async {
  try {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);

    // ✅ Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(
              child: Text('Generating CSV export...'),
            ),
          ],
        ),
      ),
    );

    final selectedSchoolYear = counselorProvider.selectedSchoolYear;
    
    print('🔍 EXPORT DEBUG:');
    print('   - Selected school year: $selectedSchoolYear');
    print('   - Total students in list: ${counselorProvider.studentsList.length}');
    print('   - Total violations in system: ${counselorProvider.studentViolations.length}');
    print('   - Total student reports: ${counselorProvider.studentReports.length}');
    print('   - Total teacher reports: ${counselorProvider.teacherReports.length}');
    
    // Filter students by school year first
    List<Map<String, dynamic>> yearFilteredStudents;
    if (selectedSchoolYear == 'all') {
      yearFilteredStudents = counselorProvider.studentsList;
    } else {
      yearFilteredStudents = counselorProvider.studentsList.where((student) {
        final studentSchoolYear = student['school_year']?.toString() ?? '';
        return studentSchoolYear == selectedSchoolYear;
      }).toList();
    }

    print('   - Students after school year filter: ${yearFilteredStudents.length}');

    // Apply current filters
    final filteredStudents = yearFilteredStudents.where((student) {
      final matchesGrade = _selectedGrade == 'All' || student['grade_level']?.toString() == _selectedGrade;
      final matchesSection = _selectedSection == 'All' || student['section']?.toString() == _selectedSection;
      final matchesSearch = _searchQuery.isEmpty ||
          (student['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (student['student_id']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesSearch && matchesGrade && matchesSection;
    }).toList();

    // ✅ Sort students by grade (7-12), then section, then name
    filteredStudents.sort((a, b) {
      final gradeA = int.tryParse(a['grade_level']?.toString() ?? '0') ?? 0;
      final gradeB = int.tryParse(b['grade_level']?.toString() ?? '0') ?? 0;
      final gradeCompare = gradeA.compareTo(gradeB);
      
      if (gradeCompare != 0) return gradeCompare;
      
      final sectionA = a['section']?.toString() ?? '';
      final sectionB = b['section']?.toString() ?? '';
      final sectionCompare = sectionA.compareTo(sectionB);
      
      if (sectionCompare != 0) return sectionCompare;
      
      final nameA = a['name']?.toString() ?? '';
      final nameB = b['name']?.toString() ?? '';
      return nameA.compareTo(nameB);
    });

    // ✅ Generate CSV content
    final StringBuffer csvContent = StringBuffer();
    
    // CSV Header
    csvContent.writeln('School Year,Grade,Section,LRN,Last Name,First Name,Total Tallied Violations,Violation Types,Source Breakdown');

    // ✅ Track section totals
    final Map<String, int> sectionTotals = {};
    final Map<String, Map<String, int>> sectionViolationTypes = {};

    // ✅ CSV Data Rows - Student violations
    for (final student in filteredStudents) {
      final primaryStudentId = student['id']?.toString();
      
      // ✅ UPDATED: Get ALL tallied violations (matching dashboard overview logic)
      final allViolations = counselorProvider.studentViolations;
      
      final talliedViolations = allViolations.where((violation) {
        final violationStudentId = violation['student_id']?.toString() ??
                                  violation['student']?['id']?.toString();
        
        if (violationStudentId != primaryStudentId) return false;
        
        // ✅ MATCH DASHBOARD: Include both report-linked AND counselor-recorded
        final hasRelatedReport = violation['related_report_id'] != null || 
                                 violation['related_report'] != null ||
                                 violation['related_student_report_id'] != null ||
                                 violation['related_student_report'] != null ||
                                 violation['related_teacher_report_id'] != null ||
                                 violation['related_teacher_report'] != null;
        
        final isCounselorRecorded = violation['counselor'] != null || 
                                   violation['recorded_by'] == 'counselor';
        
        // ✅ Must have EITHER a related report OR be counselor-recorded
        if (!hasRelatedReport && !isCounselorRecorded) return false;
        
        // School year filter
        if (selectedSchoolYear != 'all') {
          final violationSchoolYear = violation['school_year']?.toString() ?? '';
          if (violationSchoolYear.isEmpty) {
            final studentSchoolYear = student['school_year']?.toString() ?? '';
            if (studentSchoolYear.isNotEmpty && studentSchoolYear != selectedSchoolYear) {
              return false;
            }
          } else if (violationSchoolYear != selectedSchoolYear) {
            return false;
          }
        }
        
        return true;
      }).toList();

      print('   📝 Student: ${student['name']} (${student['section']})');
      print('      - Tallied Violations (incl. counselor reports): ${talliedViolations.length}');

      final totalViolations = talliedViolations.length;
      
      // ✅ Get list of violation types with source tracking
      final Map<String, Map<String, int>> violationsByType = {}; // {type: {source: count}}
      final Map<String, int> sourceCount = {
        'student_report': 0,
        'teacher_report': 0,
        'counselor_report': 0,
      };
      
      for (final violation in talliedViolations) {
        // Determine violation type
        String violationType = violation['violation_type']?['name']?.toString() ?? 
                              violation['type']?.toString() ?? 
                              violation['name']?.toString() ??
                              violation['violation_type']?.toString() ??
                              'Unknown';
        
        // ✅ IMPROVED: Determine source with better detection
        String source;
        
        // Check if it's counselor-recorded (no related report)
        final hasNoReport = violation['related_report_id'] == null && 
                           violation['related_report'] == null &&
                           violation['related_student_report_id'] == null &&
                           violation['related_student_report'] == null &&
                           violation['related_teacher_report_id'] == null &&
                           violation['related_teacher_report'] == null;
        
        final isCounselorRecorded = violation['counselor'] != null || 
                                   violation['recorded_by'] == 'counselor';
        
        if (hasNoReport && isCounselorRecorded) {
          // Directly recorded by counselor (no report)
          source = 'counselor_report';
        } else if (violation['source'] == 'counselor' || violation['report_type'] == 'counselor_report') {
          // From counselor report
          source = 'counselor_report';
        } else if (violation['source'] == 'teacher' || 
                  violation['report_type'] == 'teacher_report' ||
                  violation['related_teacher_report_id'] != null ||
                  violation['related_teacher_report'] != null) {
          // From teacher report
          source = 'teacher_report';
        } else {
          // From student report (default)
          source = 'student_report';
        }
        
        // Count by type and source
        if (!violationsByType.containsKey(violationType)) {
          violationsByType[violationType] = {};
        }
        violationsByType[violationType]![source] = (violationsByType[violationType]![source] ?? 0) + 1;
        sourceCount[source] = (sourceCount[source] ?? 0) + 1;
      }

      // Format violation types with counts
      final violationTypesStr = violationsByType.entries
          .map((e) {
            final typeTotal = e.value.values.fold<int>(0, (sum, count) => sum + count);
            return '${e.key} ($typeTotal)';
          })
          .join('; ');

      // Format source breakdown
      final sourceBreakdown = sourceCount.entries
          .where((e) => e.value > 0)
          .map((e) {
            final sourceName = {
              'student_report': 'Student Reports',
              'teacher_report': 'Teacher Reports',
              'counselor_report': 'Counselor Reports',
            }[e.key] ?? e.key;
            return '$sourceName (${e.value})';
          })
          .join('; ');

      // ✅ Update section totals
      final section = student['section']?.toString() ?? 'Unknown';
      final grade = student['grade_level']?.toString() ?? 'Unknown';
      final sectionKey = 'Grade $grade - $section';
      
      sectionTotals[sectionKey] = (sectionTotals[sectionKey] ?? 0) + totalViolations;
      
      // Track violation types per section
      if (!sectionViolationTypes.containsKey(sectionKey)) {
        sectionViolationTypes[sectionKey] = {};
      }
      for (final entry in violationsByType.entries) {
        final type = entry.key;
        final count = entry.value.values.fold<int>(0, (sum, c) => sum + c);
        sectionViolationTypes[sectionKey]![type] = 
            (sectionViolationTypes[sectionKey]![type] ?? 0) + count;
      }

      // Helper to escape CSV values
      String escapeCsv(String? value) {
        if (value == null || value.isEmpty) return '';
        if (value.contains(',') || value.contains('"') || value.contains('\n')) {
          return '"${value.replaceAll('"', '""')}"';
        }
        return value;
      }

      // ✅ Get student data
      final schoolYear = student['school_year']?.toString() ?? selectedSchoolYear;
      final gradeLevel = student['grade_level']?.toString() ?? '';
      final sectionName = student['section']?.toString() ?? '';
      
      // Get LRN
      final lrn = student['lrn']?.toString() ?? 
                 student['LRN']?.toString() ?? 
                 student['learner_reference_number']?.toString() ?? 
                 student['user']?['lrn']?.toString() ?? '';
      
      // Parse name
      String firstName = '';
      String lastName = '';
      
      if (student['first_name']?.toString().isNotEmpty == true) {
        firstName = student['first_name'].toString();
        lastName = student['last_name']?.toString() ?? '';
      }
      else if (student['user']?['first_name']?.toString().isNotEmpty == true) {
        firstName = student['user']['first_name'].toString();
        lastName = student['user']['last_name']?.toString() ?? '';
      }
      else if (student['full_name']?.toString().isNotEmpty == true) {
        final fullName = student['full_name'].toString();
        final nameParts = fullName.split(' ');
        firstName = nameParts.isNotEmpty ? nameParts.first : '';
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      }
      else if (student['user']?['full_name']?.toString().isNotEmpty == true) {
        final fullName = student['user']['full_name'].toString();
        final nameParts = fullName.split(' ');
        firstName = nameParts.isNotEmpty ? nameParts.first : '';
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      }
      else if (student['name']?.toString().isNotEmpty == true) {
        final fullName = student['name'].toString();
        final nameParts = fullName.split(' ');
        firstName = nameParts.isNotEmpty ? nameParts.first : '';
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      }
      else {
        firstName = student['username']?.toString() ?? '';
        lastName = '';
      }

      // ✅ Write row with violation types AND source breakdown
      csvContent.writeln(
        '${escapeCsv(schoolYear)},'
        '${escapeCsv(gradeLevel)},'
        '${escapeCsv(sectionName)},'
        '${escapeCsv(lrn)},'
        '${escapeCsv(lastName)},'
        '${escapeCsv(firstName)},'
        '$totalViolations,'
        '${escapeCsv(violationTypesStr)},'
        '${escapeCsv(sourceBreakdown)}'
      );
    }

    // ✅ PRINT SECTION TOTALS FOR DEBUGGING
    print('\n📊 SECTION TOTALS (including counselor reports):');
    sectionTotals.forEach((section, total) {
      print('   - $section: $total violations');
    });

    // ✅ ADD SECTION TOTALS at the end
    csvContent.writeln('');
    csvContent.writeln('SECTION TOTALS');
    csvContent.writeln('Grade,Section,Total Tallied Violations,Violation Breakdown');
    
    // Sort section keys
    final sortedSections = sectionTotals.keys.toList()..sort((a, b) {
      final gradeA = int.tryParse(a.split(' ')[1].split(' - ')[0]) ?? 0;
      final gradeB = int.tryParse(b.split(' ')[1].split(' - ')[0]) ?? 0;
      if (gradeA != gradeB) return gradeA.compareTo(gradeB);
      return a.compareTo(b);
    });

    for (final sectionKey in sortedSections) {
      final parts = sectionKey.split(' - ');
      final grade = parts[0].replaceAll('Grade ', '');
      final section = parts[1];
      final total = sectionTotals[sectionKey] ?? 0;
      
      // Get violation type breakdown
      final violationBreakdown = sectionViolationTypes[sectionKey]?.entries
          .map((e) => '${e.key} (${e.value})')
          .join('; ') ?? '';
      
      csvContent.writeln('$grade,$section,$total,"$violationBreakdown"');
    }

    // ✅ Generate filename with timestamp
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
                     '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final syLabel = selectedSchoolYear == 'all' ? 'AllYears' : 'SY${selectedSchoolYear.replaceAll('-', '_')}';
    final gradeLabel = _selectedGrade == 'All' ? 'AllGrades' : 'Grade$_selectedGrade';
    final sectionLabel = _selectedSection == 'All' ? 'AllSections' : _selectedSection.replaceAll(' ', '_');
    
    final filename = 'Student_Violations_${syLabel}_${gradeLabel}_${sectionLabel}_$timestamp.csv';

    // ✅ Download the CSV file
    final bytes = utf8.encode(csvContent.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    
    html.Url.revokeObjectUrl(url);

    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '✅ Export Successful',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Exported ${filteredStudents.length} students with ALL tallied violations (including counselor reports)',
                      style: const TextStyle(fontSize: 12),
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
    }
  } catch (e) {
    debugPrint('❌ Export error: $e');
    
    if (mounted) {
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

  void _showTallyReportDialog(BuildContext context) {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);

  // Fetch both student and teacher reports if not already loaded
  if (counselorProvider.counselorStudentReports.isEmpty) {
    counselorProvider.fetchCounselorStudentReports();
  }
  if (counselorProvider.teacherReports.isEmpty) {
    counselorProvider.fetchTeacherReports();
  }

  showDialog(
    context: context,
    builder: (context) => Consumer<CounselorProvider>(
      builder: (context, provider, child) {
        // ✅ FIX: Include both student reports and teacher reports
        final reviewedStudentReports = provider.counselorStudentReports
            .where((report) {
              final status = report['status']?.toString().toLowerCase();
              return status == 'reviewed' || status == 'verified';
            })
            .map((report) => {...report, 'report_source': 'student_report'})
            .toList();

        final reviewedTeacherReports = provider.teacherReports
            .where((report) {
              final status = report['status']?.toString().toLowerCase();
              return status == 'reviewed' || status == 'verified';
            })
            .map((report) => {...report, 'report_source': 'teacher_report'})
            .toList();

        // ✅ Combine both lists
        final allReviewedReports = [...reviewedStudentReports, ...reviewedTeacherReports];

        // Sort by date (newest first)
        allReviewedReports.sort((a, b) {
          final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
          final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment, color: Colors.green.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('📊 Tally Report', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ UPDATED Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '✅ Ready for Tallying:\n'
                          '• Student Reports: After counseling meeting (reviewed/valid)\n'
                          '• Teacher Reports: After validation by counselor\n\n'
                          'Tally them to officially record violations.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reports list
                Expanded(
                  child: provider.isLoadingCounselorStudentReports || provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : allReviewedReports.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No reports ready for tallying',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Reports appear here when marked as:\n'
                                    '✅ "Reviewed" or "Verified" (validated reports)',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: allReviewedReports.length,
                              itemBuilder: (context, index) {
                                final report = allReviewedReports[index];
                                final isTeacherReport = report['report_source'] == 'teacher_report';
                                final studentName = report['reported_student_name'] ?? 
                                                   report['student_name'] ?? 
                                                   'Unknown';
                                final reporterName = isTeacherReport 
                                    ? (report['reported_by']?['username'] ?? 'Unknown Teacher')
                                    : (report['reported_by']?['name'] ?? report['reporter_name'] ?? 'Unknown Reporter');
                                
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isTeacherReport ? Colors.blue.shade100 : Colors.green.shade100,
                                      child: Icon(
                                        isTeacherReport ? Icons.school : Icons.verified, 
                                        color: isTeacherReport ? Colors.blue.shade700 : Colors.green.shade700,
                                      ),
                                    ),
                                    title: Text(
                                      report['title'] ?? 'Untitled Report',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.person_off, size: 14, color: Colors.red),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Violator: $studentName',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            Icon(
                                              isTeacherReport ? Icons.school : Icons.person, 
                                              size: 14, 
                                              color: isTeacherReport ? Colors.blue : Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${isTeacherReport ? "Teacher" : "Reporter"}: $reporterName',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Date: ${_formatDate(report['created_at'] ?? report['date'])}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                        if (report['violation_type'] != null)
                                          Text(
                                            'Type: ${report['violation_type']}',
                                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                                          ),
                                        // ✅ Show source badge
Container(
  margin: const EdgeInsets.only(top: 4),
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // ✅ Reduced padding
  decoration: BoxDecoration(
    color: isTeacherReport ? Colors.blue.shade100 : Colors.green.shade100,
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min, // ✅ Already has this
    children: [
      Icon(
        isTeacherReport ? Icons.school : Icons.fact_check, 
        size: 10, // ✅ Reduced from 12 to 10
        color: isTeacherReport ? Colors.blue.shade700 : Colors.green.shade700,
      ),
      const SizedBox(width: 3), // ✅ Reduced from 4 to 3
      Flexible( // ✅ ADD Flexible wrapper
        child: Text(
          isTeacherReport ? 'TEACHER' : 'STUDENT', // ✅ Shortened text
          style: TextStyle(
            fontSize: 9, // ✅ Reduced from 10 to 9
            color: isTeacherReport ? Colors.blue.shade700 : Colors.green.shade700,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis, // ✅ Add overflow handling
          maxLines: 1,
        ),
      ),
    ],
  ),
),
                                      ],
                                    ),
                                    trailing: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).pop(); // Close selection dialog
                                        _showTallyViolationDialog(report);
                                      },
                                      icon: const Icon(Icons.gavel, size: 16),
                                      label: const Text('Tally'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              label: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
}

  void _showSendGuidanceNoticeDialog() async {
  // ✅ SAVE PARENT CONTEXT IMMEDIATELY
  final parentContext = context;
  
  // ✅ Get provider BEFORE showing dialog
  final counselorProvider = Provider.of<CounselorProvider>(parentContext, listen: false);
  
  // Fetch student reports first
  await counselorProvider.fetchCounselorStudentReports();
  
  if (!parentContext.mounted) return;
  
  showDialog(
    context: parentContext,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        child: Container(
          width: MediaQuery.of(dialogContext).size.width * 0.95,
          height: MediaQuery.of(dialogContext).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.notifications_active, color: Colors.orange.shade700, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summoned Students',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Students awaiting counseling after summons',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const Divider(height: 30),
              
              // Content
              Expanded(
                child: Consumer<CounselorProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoadingCounselorStudentReports) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 20),
                            Text('Loading summoned students...', style: TextStyle(fontSize: 15)),
                            SizedBox(height: 10),
                            Text(
                              'First load may take 30-60 seconds\n(Backend cold starting)',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    // ✅ Filter for SUMMONED reports
                    final summonedReports = provider.counselorStudentReports
                        .where((report) => 
                          report['status']?.toString().toLowerCase() == 'summoned')
                        .toList();

                    print('📢 Summoned reports count: ${summonedReports.length}');

                    // Error state
                    if (provider.error != null && summonedReports.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off, size: 70, color: Colors.grey),
                            const SizedBox(height: 20),
                            Text(
                              provider.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.grey, fontSize: 15),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await provider.fetchCounselorStudentReports(forceRefresh: true);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Empty state
                    if (summonedReports.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 20),
                            Text(
                              'No summoned students',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Students appear here when their reports\nare marked as "summoned" for counseling',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    // List of summoned students
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  'Found ${summonedReports.length} student(s) summoned for counseling. '
                                  'After counseling, mark reports as Reviewed (valid) or Invalid.',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Student cards
                        Expanded(
                          child: ListView.builder(
                            itemCount: summonedReports.length,
                            itemBuilder: (context, index) {
                              final report = summonedReports[index];
                              final studentName = report['reported_student_name']?.toString() ?? 
                                                 report['student_name']?.toString() ?? 
                                                 'Unknown Student';
                              
                              final reporterName = report['reported_by']?['name']?.toString() ?? 
                                                  report['reporter_name']?.toString() ?? 
                                                  'Unknown Reporter';
                              
                              final violationType = report['violation_type']?.toString() ?? 'Unknown Violation';
                              final reportTitle = report['title']?.toString() ?? 'Untitled Report';
                              final reportDate = _formatDate(report['created_at']?.toString() ?? report['date']?.toString());
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 14),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.orange.shade200, width: 2),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header with student avatar
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 28,
                                            backgroundColor: Colors.orange.shade100,
                                            child: Icon(Icons.person, color: Colors.orange.shade700, size: 28),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  studentName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 17,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade100,
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.notifications_active, size: 14, color: Colors.orange.shade700),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'SUMMONED',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.orange.shade700,
                                                          fontWeight: FontWeight.bold,
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
                                      
                                      const Divider(height: 24),
                                      
                                      // Report details
                                      _buildDetailRow(Icons.report, 'Report', reportTitle),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(Icons.warning, 'Violation', violationType),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(Icons.person_outline, 'Reported by', reporterName),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(Icons.calendar_today, 'Date', reportDate),
                                      
                                      const SizedBox(height: 16),
                                      
                                      // Action buttons
                                      Row(
                                        children: [
                                          // Mark as Reviewed (Valid)
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.of(dialogContext).pop();
                                                _showMarkAsReviewedDialog(parentContext, report);
                                              },
                                              icon: const Icon(Icons.check_circle, size: 18),
                                              label: const Text(
                                                'Mark Reviewed',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                elevation: 2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Mark as Invalid
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.of(dialogContext).pop();
                                                _showMarkAsInvalidDialog(parentContext, report);
                                              },
                                              icon: const Icon(Icons.cancel, size: 18),
                                              label: const Text(
                                                'Mark Invalid',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                elevation: 2,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

  void _showMarkAsReviewedDialog(BuildContext context, Map<String, dynamic> report) {
  final notesController = TextEditingController(
    text: 'Counseling session completed. Violation confirmed after discussion with student and review of evidence.',
  );
  bool _isDisposed = false;

  // ✅ SAVE CONTEXT-DEPENDENT DATA BEFORE DIALOG
  final reportedStudentName = report['reported_student_name']?.toString() ?? 
                              report['student_name']?.toString() ?? 
                              report['student']?['name']?.toString() ?? 
                              'Unknown Student';

  // ✅ Create a GlobalKey for the dialog's own ScaffoldMessenger
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: Builder(
        builder: (messengerContext) => WillPopScope(
          onWillPop: () async {
            if (!_isDisposed) {
              notesController.dispose();
              _isDisposed = true;
            }
            return true;
          },
          child: AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green.shade700),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Mark as Reviewed')),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Marking as REVIEWED confirms the violation. '
                              'This report will be available for tallying.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Student Information
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, size: 20, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              const Text(
                                'Reported Student (Violator):',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.warning, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reportedStudentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.report, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Report: ${report['title'] ?? 'Untitled'}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          if (report['violation_type'] != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.gavel, size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Violation: ${report['violation_type']}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Reported by: ${report['reported_by']?['name'] ?? 'Unknown'}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                'Reported: ${_formatDate(report['created_at'])}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    const Text(
                      'Counseling Session Notes:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Document your counseling session with $reportedStudentName',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'e.g., $reportedStudentName admitted to the violation during counseling...',
                        helperText: 'These notes will be attached to the report',
                      ),
                      maxLines: 5,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Important Note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'After marking as reviewed, this violation by $reportedStudentName will appear in the "Tally Report" section where you can officially record it.',
                              style: const TextStyle(fontSize: 11),
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
              TextButton(
                onPressed: () {
                  if (!_isDisposed) {
                    notesController.dispose();
                    _isDisposed = true;
                  }
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  // ✅ Validate using dialog's own messenger
                  if (notesController.text.trim().isEmpty) {
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      const SnackBar(
                        content: Text('Please add counseling notes'),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  // ✅ SAVE ALL DATA BEFORE ASYNC
                  final outerContext = context; // Parent page context
                  final notes = notesController.text.trim();
                  final reportId = report['id'];
                  final reportType = report['report_type']?.toString() ?? 'student_report';
                  final studentName = reportedStudentName;
                  
                  // ✅ Get provider BEFORE disposing
                  final counselorProvider = Provider.of<CounselorProvider>(outerContext, listen: false);
                  
                  // ✅ Dispose BEFORE navigation
                  if (!_isDisposed) {
                    notesController.dispose();
                    _isDisposed = true;
                  }
                  
                  // ✅ Close dialog
                  Navigator.of(dialogContext).pop();
                  
                  // ✅ Show loading
                  if (outerContext.mounted) {
                    showDialog(
                      context: outerContext,
                      barrierDismissible: false,
                      builder: (loadingContext) => const Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Marking report as reviewed...'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  
                  // ✅ Do async operation
                  final success = await counselorProvider.updateReportStatus(
                    reportId,
                    'verified',
                    notes: notes,
                    reportType: reportType,
                  );

                  // ✅ Close loading
                  if (outerContext.mounted) {
                    Navigator.of(outerContext).pop();
                  }

                  // ✅ Refresh in background
                  counselorProvider.fetchStudentReports().catchError((e) {
                    debugPrint('⚠️ Failed to refresh reports: $e');
                  });

                  // ✅ Show result using parent context
                  if (outerContext.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      '✅ Report Marked as REVIEWED',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Violation by $studentName confirmed - ready for tallying',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Failed to mark report as reviewed'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Confirm Verified'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showMarkAsInvalidDialog(BuildContext context, Map<String, dynamic> report) {
  final reasonController = TextEditingController();
  bool _isDisposed = false;
  
  // ✅ SAVE PARENT CONTEXT AT THE START
  final parentContext = context;
  
  // ✅ SAVE CONTEXT-DEPENDENT DATA BEFORE DIALOG
  final reportedStudentName = report['reported_student_name']?.toString() ?? 
                              report['student_name']?.toString() ?? 
                              report['student']?['name']?.toString() ?? 
                              'Unknown Student';
  
  // ✅ CREATE A GLOBALKEY FOR DIALOG'S OWN SCAFFOLDMESSENGER
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => ScaffoldMessenger(
      key: scaffoldMessengerKey,
      child: Builder(
        builder: (messengerContext) => WillPopScope(
          onWillPop: () async {
            if (!_isDisposed) {
              reasonController.dispose();
              _isDisposed = true;
            }
            return true;
          },
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.cancel, color: Colors.red),
                SizedBox(width: 8),
                Expanded(child: Text('Mark Report as Invalid')),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(parentContext).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ WARNING BOX
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
                          const Expanded(
                            child: Text(
                              'Marking as INVALID will clear the student of all charges. '
                              'This report will be dismissed and not counted as a violation.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // ✅ STUDENT INFORMATION
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, size: 20, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              const Text(
                                'Student Being Cleared:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, size: 18, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  reportedStudentName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.report, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Report: ${report['title'] ?? 'Untitled'}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          if (report['violation_type'] != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.gavel, size: 16, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Accusation: ${report['violation_type']}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // ✅ REASON INPUT
                    const Text(
                      'Reason for Marking as Invalid:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Explain why this report is false or unsubstantiated (minimum 20 characters)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'e.g., After investigation, $reportedStudentName provided evidence...',
                        helperText: 'This reason will be permanently recorded',
                      ),
                      maxLines: 5,
                      maxLength: 20,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                        return Text(
                          '$currentLength/$maxLength characters',
                          style: TextStyle(
                            fontSize: 11,
                            color: currentLength < 20 ? Colors.red : Colors.grey,
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // ✅ IMPORTANT NOTE
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$reportedStudentName will be notified that the accusation has been dismissed.',
                              style: const TextStyle(fontSize: 11),
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
              TextButton(
                onPressed: () {
                  if (!_isDisposed) {
                    reasonController.dispose();
                    _isDisposed = true;
                  }
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  // ✅ VALIDATION: Use dialog's own messenger
                  final reason = reasonController.text.trim();
                  
                  if (reason.isEmpty) {
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a reason for marking as invalid'),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  if (reason.length < 20) {
                    scaffoldMessengerKey.currentState?.showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a more detailed reason (at least 20 characters)'),
                        backgroundColor: Colors.orange,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  // ✅ SAVE ALL DATA BEFORE ASYNC OPERATIONS
                  final reportId = report['id'];
                  final studentName = reportedStudentName;
                  
                  // ✅ Get provider IMMEDIATELY using saved parent context
                  final counselorProvider = Provider.of<CounselorProvider>(parentContext, listen: false);
                  
                  // ✅ Dispose controller BEFORE async operations
                  if (!_isDisposed) {
                    reasonController.dispose();
                    _isDisposed = true;
                  }
                  
                  // ✅ Close dialog immediately
                  Navigator.of(dialogContext).pop();
                  
                  // ✅ Show loading dialog using parent context
                  if (parentContext.mounted) {
                    showDialog(
                      context: parentContext,
                      barrierDismissible: false,
                      builder: (loadingContext) => const Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Marking report as invalid...'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  
                  // ✅ Do async operation with saved provider reference
                  final success = await counselorProvider.markReportAsInvalid(
                    reportId: reportId,
                    reason: reason,
                  );

                  // ✅ Close loading dialog
                  if (parentContext.mounted) {
                    Navigator.of(parentContext).pop();
                  }

                  // ✅ Refresh reports in background
                  counselorProvider.fetchStudentReports().catchError((e) {
                    debugPrint('⚠️ Failed to refresh reports: $e');
                  });

                  // ✅ Show result using parent context
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              success ? Icons.check_circle : Icons.error,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    success 
                                      ? '✅ Report Marked as INVALID'
                                      : '❌ Failed to mark report as invalid',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (success)
                                    Text(
                                      '$studentName has been cleared - accusation dismissed',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: success ? Colors.orange : Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.cancel),
                label: const Text('Confirm Invalid'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


void _showScheduleCounselingDialog(Map<String, dynamic> student) {
  final descriptionController = TextEditingController();
  final notesController = TextEditingController();
  DateTime selectedDate = DateTime.now();
  String selectedActionType = 'Individual Counseling';
  bool _isSubmitting = false;
  
  // ✅ SAVE PARENT CONTEXT BEFORE SHOWING DIALOG
  final parentContext = context;
  
  // ✅ Create a GlobalKey for the ScaffoldMessenger
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return ScaffoldMessenger(
        key: scaffoldMessengerKey,
        child: Builder(
          builder: (messengerContext) {
            return StatefulBuilder(
              builder: (builderContext, setState) => AlertDialog(
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.event_note, color: Colors.blue.shade700),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Schedule Counseling Session\n${student['name']}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(dialogContext).size.width * 0.9,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                                  Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Student requires counseling',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('ID: ${student['student_id'] ?? student['id']}'),
                              Text('Grade: ${student['grade_level']} ${student['section']}'),
                              if (student['contact_number'] != null && student['contact_number'].toString().isNotEmpty)
                                Text('Contact: ${student['contact_number']}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        const Text('Session Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedActionType,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            'Individual Counseling',
                            'Group Session',
                            'Parent Conference',
                            'Behavioral Intervention',
                            'Follow-up Meeting',
                            'Crisis Intervention',
                          ].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                          onChanged: _isSubmitting ? null : (value) => setState(() => selectedActionType = value!),
                        ),
                        const SizedBox(height: 16),
                        
                        const Text('Scheduled Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _isSubmitting ? null : () async {
                            final DateTime? picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: descriptionController,
                          enabled: !_isSubmitting,
                          decoration: const InputDecoration(
                            labelText: 'Reason for Counseling *',
                            hintText: 'Why does this student need counseling?',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: notesController,
                          enabled: !_isSubmitting,
                          decoration: const InputDecoration(
                            labelText: 'Initial Notes (Optional)',
                            hintText: 'Any observations or concerns',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () {
                      // ✅ Dispose controllers safely when canceling
                      descriptionController.dispose();
                      notesController.dispose();
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () async {
                      // ✅ Validate using the dialog's own ScaffoldMessenger
                      final description = descriptionController.text.trim();
                      if (description.isEmpty) {
                        scaffoldMessengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('Please provide a reason for counseling'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      
                      // ✅ Save all data BEFORE any state changes
                      final notes = notesController.text.trim();
                      final studentId = student['id'];
                      final studentName = student['name'];
                      final actionType = selectedActionType;
                      final scheduledDate = selectedDate;
                      
                      // ✅ Get provider using SAVED parent context
                      final counselorProvider = Provider.of<CounselorProvider>(parentContext, listen: false);
                      
                      setState(() => _isSubmitting = true);
                      
                      // ✅ DO NOT dispose yet - wait until after navigation
                      
                      // ✅ Show loading using parent context
                      if (parentContext.mounted) {
                        showDialog(
                          context: parentContext,
                          barrierDismissible: false,
                          builder: (loadingContext) => const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('Scheduling session...'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      
                      // ✅ Do async operation
                      final success = await counselorProvider.logCounselingAction({
                        'student_id': studentId,
                        'action_type': actionType,
                        'description': description,
                        'notes': notes,
                        'scheduled_date': scheduledDate.toUtc().toIso8601String(),
                        'mark_completed': false,
                      });
                      
                      // ✅ NOW safe to dispose after async completes
                      descriptionController.dispose();
                      notesController.dispose();
                      
                      // ✅ Close dialogs
                      if (parentContext.mounted) {
                        Navigator.of(parentContext).pop(); // Close loading
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(); // Close form dialog
                      }
                      
                      // ✅ Show result using parent context
                      if (parentContext.mounted) {
                        if (success) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          '✅ Counseling Session Scheduled',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'For $studentName on ${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}',
                                          style: const TextStyle(fontSize: 12),
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
                          
                          _fetchData().catchError((e) {
                            debugPrint('⚠️ Failed to refresh data: $e');
                          });
                        } else {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text('Failed to schedule session: ${counselorProvider.error}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: _isSubmitting 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.schedule),
                    label: Text(_isSubmitting ? 'Scheduling...' : 'Schedule Session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

  void _showTallyViolationDialog(Map<String, dynamic> report) {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => TallyViolationDialog(
        report: report,
        violationTypes: counselorProvider.violationTypes,
        onViolationTallied: () => _fetchData(),
      ),
    );
  }

  Widget _buildNavigationDrawer() {
  return Drawer(
    child: Column(
      children: [
        // Header - Match dashboard style
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
              const SizedBox(height: 12),
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return Text(
                    authProvider.username ?? 'Counselor',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const Text(
                'Counselor',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        
        // Navigation Items - SAME AS DASHBOARD
        ListTile(
          leading: const Icon(Icons.dashboard),
          title: const Text('Overview'),
          onTap: () {
            Navigator.pop(context); // Close drawer
            Navigator.pop(context); // Go back to dashboard
          },
        ),
        
        ListTile(
          leading: const Icon(Icons.people, color: Colors.blue),
          title: const Text(
            'Manage Students',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          selected: true,
          selectedTileColor: Colors.blue.withOpacity(0.1),
          onTap: () {
            Navigator.pop(context); // Just close drawer, already on this page
          },
        ),
        
        ListTile(
          leading: const Icon(Icons.report),
          title: const Text('Student Reports'),
          onTap: () {
            Navigator.pop(context); // Close drawer
            Navigator.pop(context); // Go back to dashboard
            // Dashboard will handle navigation to student reports tab
          },
        ),
        
        ListTile(
          leading: const Icon(Icons.school),
          title: const Text('Teacher Reports'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
        
        ListTile(
          leading: const Icon(Icons.analytics),
          title: const Text('Analytics'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
        
        const Divider(),
        
        // Quick Actions - SAME AS DASHBOARD
        ListTile(
          leading: const Icon(Icons.event_note),
          title: const Text('Counseling Sessions'),
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
          leading: const Icon(Icons.settings),
          title: const Text('Settings'),
          onTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.counselorSettings);
          },
        ),
        
        const Spacer(),
        
        // View Toggle (at bottom) - UNIQUE TO THIS PAGE
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _showFolderView ? Icons.folder : Icons.list,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _showFolderView ? 'Folder View' : 'List View',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Switch(
                value: _showFolderView,
                onChanged: (value) {
                  setState(() => _showFolderView = value);
                  Navigator.pop(context);
                },
                activeColor: Colors.blue,
              ),
            ],
          ),
        ),
        
        // Logout - SAME AS DASHBOARD
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.red),
          ),
          onTap: () async {
            final shouldLogout = await _showLogoutConfirmation();
            if (shouldLogout) {
              final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
              await counselorProvider.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            }
          },
        ),
        
        const SizedBox(height: 16),
      ],
    ),
  );
}

  Future<bool> _showLogoutConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    ) ?? false;
  }
}

// Add Student Dialog
class _AddStudentDialog extends StatefulWidget {
  final VoidCallback onStudentAdded;
  final Map<String, List<String>> gradeSections;

  const _AddStudentDialog({
    required this.onStudentAdded,
    required this.gradeSections,
  });

  @override
  State<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<_AddStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _contactController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianContactController = TextEditingController();

  String? _selectedGrade;
  String? _selectedSection;
  bool _isLoading = false;

  final List<String> grades = ['7', '8', '9', '10', '11', '12'];

  List<String> get availableSections {
    if (_selectedGrade == null) return [];
    return widget.gradeSections[_selectedGrade] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.person_add, color: Colors.blue),
          SizedBox(width: 8),
          Text('Add New Student'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Information
                const Text('Basic Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.trim().isEmpty == true ? 'First name is required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.trim().isEmpty == true ? 'Last name is required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty && !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _studentIdController,
                  decoration: const InputDecoration(
                    labelText: 'Student ID',
                    hintText: 'Leave empty to auto-generate',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 24),

                // Academic Information
                const Text('Academic Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGrade,
                        decoration: const InputDecoration(
                          labelText: 'Grade *',
                          border: OutlineInputBorder(),
                        ),
                        items: grades.map((grade) => DropdownMenuItem(
                          value: grade,
                          child: Text('Grade $grade'),
                        )).toList(),
                        onChanged: (value) => setState(() {
                          _selectedGrade = value;
                          _selectedSection = null; // Reset section
                        }),
                        validator: (value) => value == null ? 'Please select a grade' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSection,
                        decoration: const InputDecoration(
                          labelText: 'Section *',
                          border: OutlineInputBorder(),
                        ),
                        items: availableSections.map((section) => DropdownMenuItem(
                          value: section,
                          child: Text(section),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedSection = value),
                        validator: (value) => value == null ? 'Please select a section' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Contact Information
                const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Student Contact Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _guardianNameController,
                  decoration: const InputDecoration(
                    labelText: 'Guardian/Parent Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.family_restroom),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _guardianContactController,
                  decoration: const InputDecoration(
                    labelText: 'Guardian Contact Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.contact_phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [  // Move the actions inside the AlertDialog
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addStudent,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
              : const Text('Add Student', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _addStudent() async {
  if (!_formKey.currentState!.validate()) return;

  // ✅ SAVE CONTEXT AND MESSENGER BEFORE ANY ASYNC OPERATIONS
  final dialogContext = context;
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  
  setState(() => _isLoading = true);

  try {
    final studentData = {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'student_id': _studentIdController.text.trim(),
      'grade_level': _selectedGrade,
      'section': _selectedSection,
      'contact_number': _contactController.text.trim(),
      'guardian_name': _guardianNameController.text.trim(),
      'guardian_contact': _guardianContactController.text.trim(),
    };

    // ✅ Save data before async
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    // ✅ Get provider BEFORE closing dialog
    final counselorProvider = Provider.of<CounselorProvider>(dialogContext, listen: false);
    
    final success = await counselorProvider.addStudent(studentData);

    // ✅ Check if still mounted before UI updates
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
      widget.onStudentAdded();
      
      // ✅ Use saved messenger
      if (success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Student $firstName $lastName added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to add student: ${counselorProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    // ✅ Use saved messenger for errors
    if (dialogContext.mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error adding student: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _contactController.dispose();
    _guardianNameController.dispose();
    _guardianContactController.dispose();
    super.dispose();
  }
}

// Edit Student Dialog
class _EditStudentDialog extends StatefulWidget {
  final Map<String, dynamic> student;
  final VoidCallback onStudentUpdated;
  final Map<String, List<String>> gradeSections;

  const _EditStudentDialog({
    required this.student,
    required this.onStudentUpdated,
    required this.gradeSections,
  });

  @override
  State<_EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<_EditStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _studentIdController;
  late final TextEditingController _contactController;
  late final TextEditingController _guardianNameController;
  late final TextEditingController _guardianContactController;

  String? _selectedGrade;
  String? _selectedSection;
  bool _isLoading = false;

  final List<String> grades = ['7', '8', '9', '10', '11', '12'];

  List<String> get availableSections {
    if (_selectedGrade == null) return [];
    return widget.gradeSections[_selectedGrade] ?? [];
  }

  @override
  void initState() {
    super.initState();
    
    // Parse the full name
    final fullName = widget.student['name'] ?? '';
    final nameParts = fullName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    // Initialize controllers with existing student data
    _firstNameController = TextEditingController(text: firstName);
    _lastNameController = TextEditingController(text: lastName);
    _emailController = TextEditingController(text: widget.student['email'] ?? '');
    _studentIdController = TextEditingController(text: widget.student['student_id'] ?? '');
    _contactController = TextEditingController(text: widget.student['contact_number'] ?? '');
    _guardianNameController = TextEditingController(text: widget.student['guardian_name'] ?? '');
    _guardianContactController = TextEditingController(text: widget.student['guardian_contact'] ?? '');

    _selectedGrade = widget.student['grade_level']?.toString();
    _selectedSection = widget.student['section']?.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text('Edit Student - ${widget.student['name']}')),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student ID (non-editable)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Student ID: ${widget.student['student_id'] ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Basic Information
                const Text('Basic Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.trim().isEmpty == true ? 'First name is required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.trim().isEmpty == true ? 'Last name is required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value != null && value.isNotEmpty && !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Academic Information
                const Text('Academic Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGrade,
                        decoration: const InputDecoration(
                          labelText: 'Grade *',
                          border: OutlineInputBorder(),
                        ),
                        items: grades.map((grade) => DropdownMenuItem(
                          value: grade,
                          child: Text('Grade $grade'),
                        )).toList(),
                        onChanged: (value) => setState(() {
                          _selectedGrade = value;
                          _selectedSection = null; // Reset section
                        }),
                        validator: (value) => value == null ? 'Please select a grade' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: availableSections.contains(_selectedSection) ? _selectedSection : null,
                        decoration: const InputDecoration(
                          labelText: 'Section *',
                          border: OutlineInputBorder(),
                        ),
                        items: availableSections.map((section) => DropdownMenuItem(
                          value: section,
                          child: Text(section),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedSection = value),
                        validator: (value) => value == null ? 'Please select a section' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Contact Information
                const Text('Contact Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Student Contact Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _guardianNameController,
                  decoration: const InputDecoration(
                    labelText: 'Guardian/Parent Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.family_restroom),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _guardianContactController,
                  decoration: const InputDecoration(
                    labelText: 'Guardian Contact Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.contact_phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _showDeleteConfirmation,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete Student'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateStudent,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
              : const Text('Update Student', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _updateStudent() async {
  if (!_formKey.currentState!.validate()) return;

  // ✅ SAVE CONTEXT AND MESSENGER BEFORE ANY ASYNC OPERATIONS
  final dialogContext = context;
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  
  setState(() => _isLoading = true);

  try {
    final studentData = {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'grade_level': _selectedGrade,
      'section': _selectedSection,
      'contact_number': _contactController.text.trim(),
      'guardian_name': _guardianNameController.text.trim(),
      'guardian_contact': _guardianContactController.text.trim(),
    };

    // ✅ Save data before async
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();

    // ✅ Get provider BEFORE closing dialog
    final counselorProvider = Provider.of<CounselorProvider>(dialogContext, listen: false);
    
    final success = await counselorProvider.updateStudent(widget.student['id'], studentData);

    // ✅ Check if still mounted before UI updates
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
      widget.onStudentUpdated();
      
      // ✅ Use saved messenger
      if (success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Student $firstName $lastName updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to update student: ${counselorProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    // ✅ Use saved messenger for errors
    if (dialogContext.mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error updating student: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete ${widget.student['name']}?\n\n'
          'This action cannot be undone and will also delete all violation records associated with this student.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
  onPressed: () async {
    Navigator.of(context).pop(); // Close confirmation dialog
    
    // ✅ SAVE REFERENCES BEFORE ASYNC
    final parentContext = context; // Edit dialog context
    final scaffoldMessenger = ScaffoldMessenger.of(parentContext);
    
    try {
      final counselorProvider = Provider.of<CounselorProvider>(parentContext, listen: false);
      final success = await counselorProvider.deleteStudent(widget.student['id']);
      
      if (parentContext.mounted) {
        Navigator.of(parentContext).pop(); // Close edit dialog
        widget.onStudentUpdated(); // Refresh the list
        
        // ✅ Use saved messenger
        if (success) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Student deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to delete student: ${counselorProvider.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (parentContext.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting student: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.red,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  ),
  child: const Text('Delete', style: TextStyle(color: Colors.white)),
),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _contactController.dispose();
    _guardianNameController.dispose();
    _guardianContactController.dispose();
    super.dispose();
  }
}

// Quick Record Violation Dialog
class _RecordViolationDialog extends StatefulWidget {
  final Map<String, dynamic> preSelectedStudent;
  final List<Map<String, dynamic>> violationTypes;
  final VoidCallback onViolationRecorded;

  const _RecordViolationDialog({
    required this.preSelectedStudent,
    required this.violationTypes,
    required this.onViolationRecorded,
  });

  @override
  State<_RecordViolationDialog> createState() => _RecordViolationDialogState();
}

class _RecordViolationDialogState extends State<_RecordViolationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  Map<String, dynamic>? _selectedViolationType;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Add null safety checks for student data
    final studentName = widget.preSelectedStudent['name']?.toString() ?? 
                       widget.preSelectedStudent['full_name']?.toString() ?? 
                       'Unknown Student';
    
    final studentId = widget.preSelectedStudent['student_id']?.toString() ?? 
                     widget.preSelectedStudent['id']?.toString() ?? 
                     'N/A';
    
    final gradeLevel = widget.preSelectedStudent['grade_level']?.toString() ?? 'Unknown';
    final section = widget.preSelectedStudent['section']?.toString() ?? 'Unknown';

    return AlertDialog(
      title: Text('Record Violation - $studentName'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6, // Add fixed height
        child: SingleChildScrollView( // Add scroll capability
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pre-filled student info with null safety
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Text('$gradeLevel${section.isNotEmpty ? section[0] : ''}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('ID: $studentId'),
                              Text('Grade $gradeLevel $section'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Violation Type Selection with fixed overflow
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedViolationType,
                  decoration: const InputDecoration(
                    labelText: 'Violation Type *',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true, // Add this to prevent overflow
                  items: widget.violationTypes.map((type) {
                    // Add null safety for violation type properties
                    final typeName = type['name']?.toString() ?? 'Unknown Violation';
                    final category = type['category']?.toString() ?? 'Unknown';
                    final severity = type['severity_level']?.toString() ?? 'Medium';
                    
                    return DropdownMenuItem(
                      value: type,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            typeName,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            '$category • $severity',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedViolationType = value),
                  validator: (value) => value == null ? 'Please select a violation type' : null,
                  selectedItemBuilder: (BuildContext context) {
                    // Custom builder for selected item to show only the name
                    return widget.violationTypes.map<Widget>((type) {
                      final typeName = type['name']?.toString() ?? 'Unknown Violation';
                      return Text(
                        typeName,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      );
                    }).toList();
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    hintText: 'Describe what happened...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) => value?.trim().isEmpty == true ? 'Description is required' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _recordViolation,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
              : const Text('Record Violation', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _recordViolation() async {
  if (!_formKey.currentState!.validate()) return;

  // ✅ CRITICAL: Save context and messenger BEFORE any async operations
  final dialogContext = context;
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  
  setState(() => _isLoading = true);

  try {
    final studentId = widget.preSelectedStudent['id']?.toString() ?? 
                     widget.preSelectedStudent['student_id']?.toString();
      
    if (studentId == null) {
      throw Exception('Student ID is required but not found');
    }

    final violationTypeId = _selectedViolationType!['id'];
    if (violationTypeId == null) {
      throw Exception('Violation type ID is required but not found');
    }

    // ✅ Save all needed data BEFORE any state changes
    final studentName = widget.preSelectedStudent['name']?.toString() ?? 
                       widget.preSelectedStudent['full_name']?.toString() ?? 
                       'the student';
    
    final violationTypeName = _selectedViolationType!['name']?.toString() ?? 'violation';
    final description = _descriptionController.text.trim();
    final severity = _selectedViolationType!['severity_level']?.toString() ?? 'Medium';

    // ✅ Get provider reference BEFORE closing dialog
    final counselorProvider = Provider.of<CounselorProvider>(dialogContext, listen: false);
    
    // ✅ SIMPLIFIED: Just record the violation directly
    final violationData = {
      'title': 'Manual Violation Record - $violationTypeName',
      'description': description,
      'violation_type': violationTypeName,
      'reported_student_id': studentId,
      'severity': severity,
    };

    final success = await counselorProvider.createSystemReport(violationData);

    // ✅ Check if dialog is still mounted before showing messages
    if (dialogContext.mounted) {
      // Close the dialog first
      Navigator.of(dialogContext).pop();
      
      // Call the callback to refresh
      widget.onViolationRecorded();
      
      // Show result using saved messenger
      if (success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('✅ Violation recorded for $studentName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to record violation: ${counselorProvider.error ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    // ✅ Use saved messenger for error messages
    if (dialogContext.mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error recording violation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    // ✅ Only update state if still mounted
    if (mounted && dialogContext.mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}

// Violation History Dialog
class _ViolationHistoryDialog extends StatelessWidget {
  final Map<String, dynamic> student;
  final List<Map<String, dynamic>> violations;

  const _ViolationHistoryDialog({
    required this.student,
    required this.violations,
  });

  @override
  Widget build(BuildContext context) {
    // Sort violations by date (most recent first)
    final sortedViolations = List<Map<String, dynamic>>.from(violations);
    sortedViolations.sort((a, b) {
      try {
        final dateA = DateTime.parse(a['incident_date']);
        final dateB = DateTime.parse(b['incident_date']);
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    return AlertDialog(
      title: Text('Violation History - ${student['name']}'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: violations.isEmpty
            ? const Center(child: Text('No violations recorded'))
            : ListView.builder(
                itemCount: sortedViolations.length,
                itemBuilder: (context, index) {
                  final violation = sortedViolations[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(violation['status']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          _getStatusIcon(violation['status']),
                          color: _getStatusColor(violation['status']),
                          size: 20,
                        ),
                      ),
                      title: Text(violation['violation_type']['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(violation['description'] ?? 'No description'),
                          Text(
                            _formatDate(violation['incident_date']),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(violation['status']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          violation['status'].toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: _getStatusColor(violation['status']),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange;
    case 'reviewed':
      return Colors.blue;
    case 'resolved':
      return Colors.green;
    case 'invalid':
    case 'dismissed':
      return Colors.red; // ✅ Add red color for invalid/dismissed
    default:
      return Colors.grey;
  }
}

  IconData _getStatusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Icons.pending;
    case 'reviewed':
      return Icons.check_circle;
    case 'resolved':
      return Icons.assignment_turned_in;
    case 'invalid':
    case 'dismissed':
      return Icons.cancel; // ✅ Add cancel icon for invalid/dismissed
    default:
      return Icons.info;
  }
}

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "Unknown";
    try {
      final date = DateTime.parse(dateStr);
      return "${date.day}/${date.month}/${date.year}";
    } catch (e) {
      return dateStr;
    }
  }
}

class _BulkAddStudentsDialog extends StatefulWidget {
  final VoidCallback onStudentsAdded;
  final Map<String, List<String>> gradeSections;

  const _BulkAddStudentsDialog({
    required this.onStudentsAdded,
    required this.gradeSections,
  });

  @override
  State<_BulkAddStudentsDialog> createState() => _BulkAddStudentsDialogState();
}

class _BulkAddStudentsDialogState extends State<_BulkAddStudentsDialog> {
  final _textController = TextEditingController();
  String? _selectedGrade;
  String? _selectedSection;
  bool _isLoading = false;
  final List<String> grades = ['7', '8', '9', '10', '11', '12'];

  List<String> get availableSections {
    if (_selectedGrade == null) return [];
    return widget.gradeSections[_selectedGrade] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.group_add, color: Colors.blue),
          SizedBox(width: 8),
          Text('Bulk Add Students'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add multiple students at once. Enter one student per line in the format:\n'
              'FirstName LastName, Email (optional)',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Grade and Section selection
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGrade,
                    decoration: const InputDecoration(
                      labelText: 'Grade *',
                      border: OutlineInputBorder(),
                    ),
                    items: grades.map((grade) => DropdownMenuItem(
                      value: grade,
                      child: Text('Grade $grade'),
                    )).toList(),
                    onChanged: (value) => setState(() {
                      _selectedGrade = value;
                      _selectedSection = null; // Reset section
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: availableSections.contains(_selectedSection) ? _selectedSection : null,
                    decoration: const InputDecoration(
                      labelText: 'Section *',
                      border: OutlineInputBorder(),
                    ),
                    items: availableSections.map((section) => DropdownMenuItem(
                      value: section,
                      child: Text(section),
                    )).toList(),
                    onChanged: (value) => setState(() => _selectedSection = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Instructions and Text Area for student names
            const Text(
              'Enter student names below:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: 'Student Names',
                  border: OutlineInputBorder(),
                  hintText: 'John Doe, john@example.com\nJane Smith, jane@example.com',
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _bulkAddStudents,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
              : const Text('Add Students', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _bulkAddStudents() async {
  // ✅ SAVE CONTEXT AND MESSENGER FIRST
  final dialogContext = context;
  final scaffoldMessenger = ScaffoldMessenger.of(context);
  
  if (_selectedGrade == null || _selectedSection == null) {
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Please select grade and section'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (_textController.text.trim().isEmpty) {
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Please enter student names'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    final lines = _textController.text.trim().split('\n');
    final students = <Map<String, dynamic>>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      
      final parts = line.split(',');
      final fullName = parts[0].trim();
      final email = parts.length > 1 ? parts[1].trim() : '';

      final nameParts = fullName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first : '';
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      students.add({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'grade_level': _selectedGrade,
        'section': _selectedSection,
      });
    }

    // ✅ Save count before async
    final studentCount = students.length;

    // ✅ Get provider BEFORE closing dialog
    final counselorProvider = Provider.of<CounselorProvider>(dialogContext, listen: false);
    
    final success = await counselorProvider.bulkAddStudents(students);

    // ✅ Check if still mounted
    if (dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
      widget.onStudentsAdded();
      
      // ✅ Use saved messenger
      if (success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('$studentCount students added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to add students: ${counselorProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    // ✅ Use saved messenger for errors
    if (dialogContext.mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error adding students: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
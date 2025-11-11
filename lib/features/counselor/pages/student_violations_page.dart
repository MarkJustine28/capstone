import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/counselor_provider.dart';
import '../widgets/tally_violation_dialog.dart';
import '../../../widgets/school_year_banner.dart';

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
      return allSections;
    }
    return ['All', ...gradeSections[_selectedGrade] ?? []];
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

  @override
Widget build(BuildContext context) {
  return Consumer<CounselorProvider>(
    builder: (context, provider, child) {
      // ✅ FIX: Filter students based on search and filters INCLUDING school year
      final filteredStudents = provider.studentsList.where((student) {
        final matchesSearch = _searchQuery.isEmpty ||
            (student['name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
            (student['student_id']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        
        final matchesGrade = _selectedGrade == 'All' || 
            student['grade_level']?.toString() == _selectedGrade;
        
        final matchesSection = _selectedSection == 'All' || 
            student['section']?.toString() == _selectedSection;
        
        // ✅ FIX: Proper school year filtering
        final studentSchoolYear = student['school_year']?.toString() ?? '';
        final matchesSchoolYear = studentSchoolYear == _selectedSchoolYear;

        // Filter by violation status if needed
        if (_showOnlyWithViolations) {
          final studentViolations = provider.studentViolations.where((v) {
            final violationStudentId = v['student_id']?.toString() ?? 
                                       v['student']?['id']?.toString();
            final currentStudentId = student['id']?.toString();
            return violationStudentId == currentStudentId;
          }).toList();
          return matchesSearch && matchesGrade && matchesSection && 
                 matchesSchoolYear && studentViolations.isNotEmpty;
        }
        
        return matchesSearch && matchesGrade && matchesSection && matchesSchoolYear;
      }).toList();

      // Sort students by grade and section
      filteredStudents.sort((a, b) {
        final gradeCompare = (a['grade_level'] ?? '').toString().compareTo((b['grade_level'] ?? '').toString());
        if (gradeCompare != 0) return gradeCompare;
        return (a['section'] ?? '').toString().compareTo((b['section'] ?? '').toString());
      });

      return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Students Management",
                style: TextStyle(fontSize: 18),
              ),
              Text(
                '${filteredStudents.length} students • S.Y. $_selectedSchoolYear', // ✅ Show school year
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          actions: [
            // View Toggle Button (Keep visible)
            IconButton(
              icon: Icon(_showFolderView ? Icons.list : Icons.folder),
              onPressed: () => setState(() => _showFolderView = !_showFolderView),
              tooltip: _showFolderView ? "Switch to List View" : "Switch to Folder View",
            ),
            
            // Refresh Button (Keep visible)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchData,
              tooltip: "Refresh",
            ),
            
            // Three-dot menu with all other actions
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'add_student':
                    _showAddStudentDialog(context);
                    break;
                  case 'bulk_add':
                    _showBulkAddDialog();
                    break;
                  case 'send_notice':
                    _showSendGuidanceNoticeDialog(context);
                    break;
                  case 'tally_report':
                    _showTallyReportDialog(context);
                    break;
                  case 'export_list':
                    _exportStudentsList();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add_student',
                  child: Row(
                    children: [
                      Icon(Icons.person_add, size: 20, color: Colors.black),
                      SizedBox(width: 12),
                      Text('Add Student'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'bulk_add',
                  child: Row(
                    children: [
                      Icon(Icons.group_add, size: 20, color: Colors.black),
                      SizedBox(width: 12),
                      Text('Bulk Add Students'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'send_notice',
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active, size: 20, color: Colors.blue),
                      SizedBox(width: 12),
                      Text('Send Guidance Notice'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'tally_report',
                  child: Row(
                    children: [
                      Icon(Icons.assignment, size: 20, color: Colors.orange),
                      SizedBox(width: 12),
                      Text('Tally Report'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'export_list',
                  child: Row(
                    children: [
                      Icon(Icons.download, size: 20, color: Colors.black),
                      SizedBox(width: 12),
                      Text('Export List'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // ✅ NEW: School Year Banner
            const SchoolYearBanner(),
            
            // Search and Filter Section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Search by student name or ID...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 12),
                  
                  // Filter dropdowns and toggle
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 600) {
                        // Mobile layout - Remove school year dropdown (shown in banner)
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedGrade,
                                    decoration: InputDecoration(
                                      labelText: "Grade",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: grades.map((grade) => DropdownMenuItem(
                                      value: grade,
                                      child: Text(grade == 'All' ? 'All Grades' : 'Grade $grade'),
                                    )).toList(),
                                    onChanged: (value) => setState(() {
                                      _selectedGrade = value!;
                                      _selectedSection = 'All';
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: availableSections.contains(_selectedSection) ? _selectedSection : 'All',
                                    decoration: InputDecoration(
                                      labelText: "Section",
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: availableSections.map((section) => DropdownMenuItem(
                                      value: section,
                                      child: Text(section == 'All' ? 'All Sections' : section),
                                    )).toList(),
                                    onChanged: (value) => setState(() => _selectedSection = value!),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              title: const Text("Show only students with violations"),
                              value: _showOnlyWithViolations,
                              onChanged: (value) => setState(() => _showOnlyWithViolations = value ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        );
                      }
                      
                      // Desktop/Tablet layout - Remove school year dropdown (shown in banner)
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedGrade,
                                  decoration: InputDecoration(
                                    labelText: "Grade",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: grades.map((grade) => DropdownMenuItem(
                                    value: grade,
                                    child: Text(grade == 'All' ? 'All Grades' : 'Grade $grade'),
                                  )).toList(),
                                  onChanged: (value) => setState(() {
                                    _selectedGrade = value!;
                                    _selectedSection = 'All';
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: availableSections.contains(_selectedSection) ? _selectedSection : 'All',
                                  decoration: InputDecoration(
                                    labelText: "Section",
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: availableSections.map((section) => DropdownMenuItem(
                                    value: section,
                                    child: Text(section == 'All' ? 'All' : section),
                                  )).toList(),
                                  onChanged: (value) => setState(() => _selectedSection = value!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: CheckboxListTile(
                                  title: const Text("With Violations Only"),
                                  value: _showOnlyWithViolations,
                                  onChanged: (value) => setState(() => _showOnlyWithViolations = value ?? false),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
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
            ),
            
            // Students List - Switch between folder and list view
            Expanded(
              child: provider.isLoadingStudentsList
                  ? const Center(child: CircularProgressIndicator())
                  : filteredStudents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty 
                                    ? "No students found matching your search" 
                                    : "No students for S.Y. $_selectedSchoolYear", // ✅ Show school year context
                                style: const TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              if (_searchQuery.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Try changing the school year filter or add new students',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _showAddStudentDialog(context),
                                  icon: const Icon(Icons.person_add),
                                  label: const Text("Add Student"),
                                ),
                              ],
                            ],
                          ),
                        )
                      : _showFolderView
                          ? _buildFolderView(filteredStudents, provider)
                          : _buildListView(filteredStudents, provider),
            ),
          ],
        ),
      );
    },
  );
}

  // NEW: List View - Simple table-like structure
  Widget _buildListView(List<Map<String, dynamic>> students, CounselorProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getTalliedViolationColor(talliedCount),
              child: Text(
                talliedCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(
              student['name']?.toString() ?? 'Unknown Student',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: ${student['student_id'] ?? 'N/A'} • Grade ${student['grade_level']} ${student['section']}'),
                if (student['email']?.toString().isNotEmpty == true)
                  Text(
                    student['email'].toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (talliedCount > 0) ...[
                      _buildChip('Tallied: $talliedCount', Colors.blue),
                      const SizedBox(width: 4),
                      if (activeTallied > 0)
                        _buildChip('Active: $activeTallied', Colors.orange),
                    ] else
                      _buildChip('No tallied violations', Colors.grey),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
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
                      Icon(Icons.add_alert, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Add Violation'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit_student',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
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
                        Icon(Icons.history, color: Colors.green),
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
      
      // Ensure container structures exist
      if (!gradeGroups.containsKey(grade)) {
        gradeGroups[grade] = {};
      }
      if (!gradeGroups[grade]!.containsKey(section)) {
        gradeGroups[grade]![section] = [];
      }
      
      gradeGroups[grade]![section]!.add(student);
    }

    // Sort grades in ascending order (7, 8, 9, 10, 11, 12, Unknown)
    final sortedGrades = gradeGroups.keys.toList()..sort((a, b) {
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedGrades.length,
      itemBuilder: (context, gradeIndex) {
        final grade = sortedGrades[gradeIndex];
        final sections = gradeGroups[grade]!;
        final totalStudentsInGrade = sections.values.fold<int>(0, (sum, students) => sum + students.length);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(
                Icons.folder,
                color: totalStudentsInGrade > 0 ? Colors.blue.shade700 : Colors.grey.shade400,
                size: 32,
              ),
              title: Text(
                'Grade $grade',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: totalStudentsInGrade > 0 ? Colors.black : Colors.grey.shade600,
                ),
              ),
              subtitle: Text(
                totalStudentsInGrade > 0
                    ? '$totalStudentsInGrade students • ${sections.length} sections'
                    : 'Empty • ${sections.length} sections',
                style: TextStyle(
                  color: totalStudentsInGrade > 0 ? Colors.grey : Colors.grey.shade500,
                ),
              ),
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: _buildSectionsForGrade(sections, provider, grade),
                ),
              ],
            ),
          ),
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
  Widget _buildCompactStudentCard(Map<String, dynamic> student, CounselorProvider provider, {bool isPlaceholder = false}) {
    final studentName = student['name']?.toString() ?? 
                       student['full_name']?.toString() ?? 
                       (() {
                         final firstName = student['first_name']?.toString() ?? '';
                         final lastName = student['last_name']?.toString() ?? '';
                         final fullName = '$firstName $lastName'.trim();
                         return fullName.isNotEmpty ? fullName : (student['username']?.toString() ?? 'Unknown Student');
                       })();
    
    // Get the primary student ID for matching
    final primaryStudentId = student['id']?.toString();
    
    if (primaryStudentId == null && !isPlaceholder) {
      print('⚠️ Warning: Student has no ID: $studentName');
    }
    
    // DEBUG: Print to see what we're working with
    if (!isPlaceholder) {
      print('🔍 DEBUG - Student: $studentName (ID: $primaryStudentId)');
      print('📊 Total violations in provider: ${provider.studentViolations.length}');
    }
    
    // Count ALL violations for this student first
    final allStudentViolations = provider.studentViolations.where((violation) {
      final violationStudentId = violation['student_id']?.toString() ??
                                violation['student']?['id']?.toString();
      
      if (!isPlaceholder && violationStudentId == primaryStudentId) {
        print('  ✓ Found violation: ${violation['violation_type']?['name'] ?? 'Unknown'}');
        print('    - Has related_report_id: ${violation['related_report_id']}');
        print('    - Has related_report: ${violation['related_report']}');
        print('    - Full violation data: $violation');
      }
      
      return violationStudentId == primaryStudentId;
    }).toList();
    
    if (!isPlaceholder) {
      print('📝 Total violations for this student: ${allStudentViolations.length}');
    }
    
    // For now, show ALL violations (we'll filter in next update after confirming data)
    final studentViolations = allStudentViolations;

    // Safely get student properties with multiple fallbacks
    final studentId = student['student_id']?.toString() ?? 
                     student['id']?.toString() ?? 
                     'No ID';
    
    final gradeSection = 'Grade ${student['grade_level'] ?? 'Unknown'} ${student['section'] ?? 'Unknown'}';
    final email = student['email']?.toString() ?? '';
    final isActive = student['is_active'] == true || student['status']?.toString() == 'active';

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

    // Determine if student needs attention
    final needsAttention = totalViolations >= 3 || highSeverityViolations >= 1;
    final criticalAttention = totalViolations >= 5 || highSeverityViolations >= 2;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      elevation: 2,
      // Add colored border for students needing attention
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
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
              radius: 24,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    totalViolations.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'tallied',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            // Alert badge for critical cases
            if (criticalAttention)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high,
                    color: Colors.white,
                    size: 12,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.black : Colors.grey,
                ),
              ),
            ),
            // Attention badge
            if (needsAttention)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: criticalAttention ? Colors.red : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      criticalAttention ? Icons.warning : Icons.info,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      criticalAttention ? 'URGENT' : 'ATTENTION',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
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
              style: const TextStyle(fontSize: 12),
            ),
            if (email.isNotEmpty)
              Text(
                email,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            const SizedBox(height: 4),
            // Prominent violation summary
            Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: _getTalliedViolationColor(totalViolations).withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
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
            size: 16,
            color: _getTalliedViolationColor(totalViolations),
          ),
          const SizedBox(width: 6),
          // ✅ FIX: Wrap text in Expanded to prevent overflow
          Expanded(
            child: Text(
              '$totalViolations Tallied Violation${totalViolations != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 13,
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
        const SizedBox(height: 4),
        // ✅ FIX: Use Column instead of Wrap to prevent overflow
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activeViolations > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _buildChip('Active: $activeViolations', Colors.orange),
              ),
            if (resolvedViolations > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _buildChip('Resolved: $resolvedViolations', Colors.green),
              ),
            if (highSeverityViolations > 0)
              _buildChip('High Severity: $highSeverityViolations', Colors.red),
          ],
        ),
      ],
      // Action recommendation
      if (needsAttention) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: criticalAttention 
                ? Colors.red.withOpacity(0.1) 
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                criticalAttention ? Icons.phone : Icons.notifications_active,
                size: 14,
                color: criticalAttention ? Colors.red : Colors.orange,
              ),
              const SizedBox(width: 6),
              // ✅ FIX: Wrap text in Expanded
              Expanded(
                child: Text(
                  criticalAttention 
                      ? '⚠️ Requires immediate counselor intervention'
                      : '📞 Consider calling student for counseling',
                  style: TextStyle(
                    fontSize: 11,
                    color: criticalAttention ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2, // Allow 2 lines
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Details
                _buildStudentDetailsSection(student),
                const SizedBox(height: 16),
                
                // Tallied Violations List
                _buildStudentViolationsSection(studentViolations),
                const SizedBox(height: 16),
                
                // Action Buttons
                _buildStudentActionButtons(student, needsAttention),
              ],
            ),
          ),
        ],
      ),
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
  Widget _buildChip(String label, Color color) {
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
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
          _buildDetailRow('Full Name', student['name']?.toString() ?? 'N/A'),
          _buildDetailRow('Student ID', student['student_id']?.toString() ?? student['id']?.toString() ?? 'N/A'),
          _buildDetailRow('Grade & Section', 'Grade ${student['grade_level'] ?? 'Unknown'} ${student['section'] ?? 'Unknown'}'),
          _buildDetailRow('Email', student['email']?.toString() ?? 'N/A'),
          _buildDetailRow('Contact', student['contact_number']?.toString() ?? student['phone']?.toString() ?? 'N/A'),
          _buildDetailRow('Guardian', student['guardian_name']?.toString() ?? student['parent_name']?.toString() ?? 'N/A'),
          _buildDetailRow('Guardian Contact', student['guardian_contact']?.toString() ?? student['parent_contact']?.toString() ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
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
    return Row(
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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Exporting students list...'),
            ],
          ),
        ),
      );

      final success = await counselorProvider.exportStudentsList(
        gradeFilter: _selectedGrade,
        sectionFilter: _selectedSection,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Students list exported successfully'
                : 'Failed to export students list'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTallyReportDialog(BuildContext context) {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);

  // Fetch reviewed reports if not already loaded
  if (counselorProvider.counselorStudentReports.isEmpty) {
    counselorProvider.fetchCounselorStudentReports();
  }

  showDialog(
    context: context,
    builder: (context) => Consumer<CounselorProvider>(
      builder: (context, provider, child) {
        // ✅ Filter for ONLY reviewed reports (after counseling, validated)
        final reviewedReports = provider.counselorStudentReports
            .where((report) {
              final status = report['status']?.toString().toLowerCase();
              return status == 'reviewed'; // Only show reviewed reports ready for tallying
            })
            .toList();

        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment, color: Colors.orange.shade700, size: 20),
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
                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'These reports have been reviewed after counseling and are confirmed valid. '
                          'Tally them to add violations to student records.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Reports list
                Expanded(
                  child: provider.isLoadingCounselorStudentReports
                      ? const Center(child: CircularProgressIndicator())
                      : reviewedReports.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No reviewed reports to tally',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Reports must be:\n'
                                    '• Summoned (student notified)\n'
                                    '• Counseled (session completed)\n'
                                    '• Marked as "Reviewed" (validated)',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: reviewedReports.length,
                              itemBuilder: (context, index) {
                                final report = reviewedReports[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Icon(Icons.check_circle, color: Colors.green.shade700),
                                    ),
                                    title: Text(
                                      report['title'] ?? 'Untitled Report',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Student: ${report['reported_student_name'] ?? report['student_name'] ?? 'Unknown'}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          'Date: ${_formatDate(report['created_at'] ?? report['date'])}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                        if (report['violation_type'] != null)
                                          Text(
                                            'Type: ${report['violation_type']}',
                                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                                          ),
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.verified, size: 12, color: Colors.green.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Reviewed & Validated',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.bold,
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

  void _showSendGuidanceNoticeDialog(BuildContext context) {
  final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);

  if (counselorProvider.studentReports.isEmpty) {
    counselorProvider.fetchStudentReports();
  }

  showDialog(
    context: context,
    builder: (context) => Consumer<CounselorProvider>(
      builder: (context, provider, child) {
        // ✅ DEBUG: Print all reports to see their statuses
        print('📊 Total student reports: ${provider.studentReports.length}');
        for (var report in provider.studentReports) {
          print('  Report #${report['id']}: status="${report['status']}", type="${report['report_type']}", reported_by_role="${report['reported_by']?['role']}"');
        }

        // ✅ FIX: Updated filter - show ALL summoned student reports regardless of type
        final summonedReports = provider.studentReports
            .where((report) {
              final status = report['status']?.toString().toLowerCase();
              
              // ✅ DEBUG: Show which reports match
              if (status == 'summoned') {
                print('✅ Found summoned report: #${report['id']} - ${report['title']}');
              }
              
              // ✅ FIX: Just check for summoned status, don't filter by report_type
              // All reports in studentReports are already student-related reports
              return status == 'summoned';
            })
            .toList();

        print('📢 Summoned reports to display: ${summonedReports.length}');

        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.notifications_active, color: Colors.orange.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('📢 Summoned Students', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Post-Counseling Validation (${summonedReports.length} students):',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'These students have been summoned for counseling to validate their reports.\n\n'
                              '• Mark as REVIEWED if report is valid (will appear in Tally Report)\n'
                              '• Mark as INVALID if report is false or unsubstantiated',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Reports list
                Expanded(
                  child: provider.isLoadingCounselorStudentReports
                      ? const Center(child: CircularProgressIndicator())
                      : summonedReports.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.groups, size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No summoned students',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Students will appear here after sending guidance notices from the Student Reports tab',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await provider.fetchStudentReports();
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Refresh'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: summonedReports.length,
                              itemBuilder: (context, index) {
                                final report = summonedReports[index];
                                
                                // ✅ Better handling of report type display
                                String reportTypeDisplay = 'Student Report';
                                if (report['report_type'] == 'peer_report') {
                                  reportTypeDisplay = 'Peer Report';
                                } else if (report['report_type'] == 'self_report') {
                                  reportTypeDisplay = 'Self-Report';
                                }
                                
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  color: Colors.orange.shade50,
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.orange.shade700,
                                      child: const Icon(Icons.person, color: Colors.white),
                                    ),
                                    title: Text(
                                      report['title'] ?? 'Untitled Report',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Student: ${report['reported_student_name'] ?? report['student_name'] ?? 'Unknown'}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Reported by: ${report['reported_by']?['name'] ?? 'Unknown'} ($reportTypeDisplay)',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          'Summoned: ${_formatDate(report['updated_at'] ?? report['created_at'])}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade700,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.schedule, size: 10, color: Colors.white),
                                              SizedBox(width: 3),
                                              Flexible(
                                                child: Text(
                                                  'AWAITING VALIDATION',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        color: Colors.white,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Report Details
                                            Text(
                                              'Report Details:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade700,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            if (report['violation_type'] != null)
                                              _buildDetailRow('Violation', report['violation_type'].toString()),
                                            if (report['content'] != null)
                                              _buildDetailRow('Description', report['content'].toString()),
                                            _buildDetailRow('Report Type', reportTypeDisplay),
                                            _buildDetailRow('Report ID', '#${report['id']}'),
                                            
                                            const SizedBox(height: 16),
                                            const Divider(),
                                            const SizedBox(height: 16),

                                            // Validation Instructions
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.blue.shade200),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                                                  const SizedBox(width: 8),
                                                  const Expanded(
                                                    child: Text(
                                                      'After validating the report through counseling, choose an action:',
                                                      style: TextStyle(fontSize: 11),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const SizedBox(height: 12),

                                            // Action Buttons
                                            Row(
                                              children: [
                                                // Mark as Reviewed (Valid Report)
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                      _showMarkAsReviewedDialog(context, report);
                                                    },
                                                    icon: const Icon(Icons.check_circle, size: 16),
                                                    label: const Text(
                                                      'Valid Report\n(Mark Reviewed)',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(fontSize: 10),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.green,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Mark as Invalid (False Report)
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                      _showMarkAsInvalidDialog(context, report);
                                                    },
                                                    icon: const Icon(Icons.cancel, size: 16),
                                                    label: const Text(
                                                      'False Report\n(Mark Invalid)',
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(fontSize: 10),
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
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
            if (summonedReports.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  await provider.fetchStudentReports();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
          ],
        );
      },
    ),
  );
}

  void _showMarkAsReviewedDialog(BuildContext context, Map<String, dynamic> report) {
  final notesController = TextEditingController(
    text: 'Counseling session completed. Violation confirmed after discussion with student and review of evidence.',
  );

  // ✅ FIX: Get the reported student's name (the one who committed the violation)
  final reportedStudentName = report['reported_student_name']?.toString() ?? 
                              report['student_name']?.toString() ?? 
                              report['student']?['name']?.toString() ?? 
                              'Unknown Student';

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
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
              
              // Student Information - REPORTED STUDENT (violator)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50, // Changed to red to indicate violator
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
            notesController.dispose();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            if (notesController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please add counseling notes'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
            
            final success = await counselorProvider.updateReportStatus(
              report['id'],
              'reviewed',
              notes: notesController.text.trim(),
            );

            if (success && context.mounted) {
              notesController.dispose();
              Navigator.of(context).pop();
              
              await counselorProvider.fetchStudentReports();
              
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
                              '✅ Report Marked as REVIEWED',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Violation by $reportedStudentName is now ready for tallying',
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
            } else if (context.mounted) {
              notesController.dispose();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Failed to mark report as reviewed'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          icon: const Icon(Icons.check),
          label: const Text('Confirm Reviewed'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    ),
  );
}

void _showMarkAsInvalidDialog(BuildContext context, Map<String, dynamic> report) {
  final reasonController = TextEditingController();
  
  // ✅ FIX: Get the reported student's name (the one who was accused)
  final reportedStudentName = report['reported_student_name']?.toString() ?? 
                              report['student_name']?.toString() ?? 
                              report['student']?['name']?.toString() ?? 
                              'Unknown Student';
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cancel, color: Colors.red),
          SizedBox(width: 8),
          Expanded(child: Text('Mark Report as Invalid')),
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
                        'This report will be marked as INVALID and closed. '
                        'It will NOT be tallied as a violation.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Student Information - REPORTED STUDENT (accused student)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50, // Changed to blue since report is invalid
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, size: 20, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Reported Student (Accused):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.shield, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reportedStudentName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 12, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Will be cleared - Report is false/unsubstantiated',
                            style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
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
                          const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Alleged Violation: ${report['violation_type']}',
                              style: const TextStyle(fontSize: 13),
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
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              const Text(
                'Reason for Marking as Invalid: *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Explain why the accusation against $reportedStudentName is invalid',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'e.g., After investigation, $reportedStudentName was found innocent. The report was unsubstantiated, no evidence found, false accusation...',
                  border: const OutlineInputBorder(),
                  helperText: 'Provide a clear explanation for dismissing this accusation',
                  helperMaxLines: 2,
                ),
                maxLines: 4,
              ),
              
              const SizedBox(height: 16),
              
              // Warning Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'What happens next:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• $reportedStudentName will NOT receive any violation record\n'
                            '• Both the reporter and $reportedStudentName will be notified\n'
                            '• The report will be closed and archived\n'
                            '• This action can be reviewed in audit logs',
                            style: const TextStyle(fontSize: 11),
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
      ),
      actions: [
        TextButton(
          onPressed: () {
            reasonController.dispose();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            if (reasonController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please provide a reason for marking as invalid'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            if (reasonController.text.trim().length < 20) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please provide a more detailed reason (at least 20 characters)'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
            
            final success = await counselorProvider.markReportAsInvalid(
              reportId: report['id'],
              reason: reasonController.text.trim(),
            );

            if (success && context.mounted) {
              reasonController.dispose();
              Navigator.of(context).pop();
              
              await counselorProvider.fetchStudentReports();
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '✅ Report Marked as INVALID',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '$reportedStudentName has been cleared - accusation dismissed',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            } else if (context.mounted) {
              reasonController.dispose();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Failed to mark report as invalid'),
                  backgroundColor: Colors.red,
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

      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      final success = await counselorProvider.addStudent(studentData);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          widget.onStudentAdded();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Student ${_firstNameController.text} ${_lastNameController.text} added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add student: ${counselorProvider.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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

      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      final success = await counselorProvider.updateStudent(widget.student['id'], studentData);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          widget.onStudentUpdated();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Student ${_firstNameController.text} ${_lastNameController.text} updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update student: ${counselorProvider.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
              
              // Proceed with deletion
              try {
                final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
                final success = await counselorProvider.deleteStudent(widget.student['id']);
                
                if (mounted) {
                  if (success) {
                    Navigator.of(context).pop(); // Close edit dialog
                    widget.onStudentUpdated(); // Refresh the list
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Student deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete student: ${counselorProvider.error}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
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

    setState(() => _isLoading = true);

    try {
      // Add null safety for the violation data
      final studentId = widget.preSelectedStudent['id']?.toString() ?? 
                       widget.preSelectedStudent['student_id']?.toString();
        
      if (studentId == null) {
        throw Exception('Student ID is required but not found');
      }

      final violationTypeId = _selectedViolationType!['id'];
      if (violationTypeId == null) {
        throw Exception('Violation type ID is required but not found');
      }

      final violationData = {
        'student_id': studentId,
        'violation_type_id': violationTypeId,
        'incident_date': DateTime.now().toIso8601String(),
        'description': _descriptionController.text.trim(),
        'location': '',
        'witnesses': '',
        'counselor_notes': '',
        'action_taken': '',
        'follow_up_required': false,
        'severity_override': _selectedViolationType!['severity_level']?.toString() ?? 'Medium',
        'parent_notified': false,
        'is_repeat_offense': false,
        'violation_count_for_student': 1,
      };

      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      final success = await counselorProvider.recordViolation(violationData);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          widget.onViolationRecorded();
          
          final studentName = widget.preSelectedStudent['name']?.toString() ?? 
                             widget.preSelectedStudent['full_name']?.toString() ?? 
                             'the student';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Violation recorded for $studentName'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to record violation: ${counselorProvider.error ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording violation: $e'),
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
    if (_selectedGrade == null || _selectedSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select grade and section'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
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

      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      final success = await counselorProvider.bulkAddStudents(students);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          widget.onStudentsAdded();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${students.length} students added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add students: ${counselorProvider.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
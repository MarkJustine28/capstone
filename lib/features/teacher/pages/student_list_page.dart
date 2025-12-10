import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/teacher_provider.dart';
import '../../../config/routes.dart';

class StudentListPage extends StatefulWidget {
  const StudentListPage({Key? key}) : super(key: key);

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  String _searchQuery = '';
  String _selectedGradeFilter = 'All';
  String _selectedStrandFilter = 'All';
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
      await teacherProvider.fetchAdvisingStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Advising Students'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.check : Icons.edit),
            onPressed: () {
              setState(() {
                _editMode = !_editMode;
              });
              if (!_editMode) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Changes will be saved automatically'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            tooltip: _editMode ? 'Done Editing' : 'Edit Student Info',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
              teacherProvider.fetchAdvisingStudents();
            },
          ),
        ],
      ),
      body: Consumer<TeacherProvider>(
        builder: (context, teacherProvider, child) {
          if (teacherProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (teacherProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Error: ${teacherProvider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => teacherProvider.fetchAdvisingStudents(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final profile = teacherProvider.teacherProfile;
          final isAdviser = profile != null &&
            (profile['advising_grade']?.toString().isNotEmpty ?? false) &&
            (profile['advising_section']?.toString().isNotEmpty ?? false);

          if (!isAdviser) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'You are not assigned as an adviser for any class.\nStudent list is only available for advisers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            );
          }

          final allStudents = teacherProvider.advisingStudents;
          final filteredStudents = _filterStudents(allStudents);

          if (allStudents.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No students in your advising class',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildAdvisingClassHeader(teacherProvider),
              if (_editMode) _buildEditModeBanner(),
              _buildSearchAndFilterSection(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await teacherProvider.fetchAdvisingStudents();
                  },
                  child: filteredStudents.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No students match your filters',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            return _buildStudentCard(student);
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditModeBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.edit, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Edit Mode: Update student sections and information for the current school year',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisingClassHeader(TeacherProvider teacherProvider) {
    final profile = teacherProvider.teacherProfile;
    if (profile == null) return const SizedBox();

    final advisingInfo = _getAdvisingClassInfo(profile);
    
    return Container(
      width: double.infinity,
      color: Colors.blue.shade50,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.class_, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Advising Class',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            advisingInfo,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${teacherProvider.advisingStudents.length} students',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search students...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          Consumer<TeacherProvider>(
            builder: (context, teacherProvider, child) {
              final students = teacherProvider.advisingStudents;
              final grades = students
                  .map((s) => s['grade_level']?.toString() ?? '')
                  .where((g) => g.isNotEmpty)
                  .toSet()
                  .toList();
              
              final strands = students
                  .where((s) => ['11', '12'].contains(s['grade_level']?.toString()))
                  .map((s) => s['strand']?.toString() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toSet()
                  .toList();

              if (grades.length <= 1 && strands.length <= 1) {
                return const SizedBox();
              }

              return Row(
                children: [
                  if (grades.length > 1)
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGradeFilter,
                        decoration: const InputDecoration(
                          labelText: 'Grade',
                          border: OutlineInputBorder(),
                        ),
                        items: ['All', ...grades]
                            .map((grade) => DropdownMenuItem(
                                  value: grade,
                                  child: Text(grade == 'All' ? 'All Grades' : 'Grade $grade'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGradeFilter = value ?? 'All';
                          });
                        },
                      ),
                    ),
                  
                  if (grades.length > 1 && strands.isNotEmpty)
                    const SizedBox(width: 12),
                  
                  if (strands.length > 1)
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStrandFilter,
                        decoration: const InputDecoration(
                          labelText: 'Strand',
                          border: OutlineInputBorder(),
                        ),
                        items: ['All', ...strands]
                            .map((strand) => DropdownMenuItem(
                                  value: strand,
                                  child: Text(strand == 'All' ? 'All Strands' : strand),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStrandFilter = value ?? 'All';
                          });
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final fullName = '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim();
    final displayName = fullName.isNotEmpty ? fullName : student['username'] ?? 'Unknown';
    
    final violationsCurrent = student['violations_current_year'] ?? 0;
    final violationsAllTime = student['violations_all_time'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade700,
          child: Text(
            displayName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LRN: ${student['lrn'] ?? student['student_id'] ?? 'N/A'}'),
            Text(_getStudentGradeInfo(student)),
            if (violationsAllTime > 0)
              Row(
                children: [
                  Icon(Icons.warning, size: 14, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Violations: $violationsCurrent this year, $violationsAllTime all-time',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: _editMode
            ? Icon(Icons.edit, color: Colors.orange.shade700)
            : IconButton(
                icon: const Icon(Icons.report, color: Colors.red),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.teacherSubmitReport,
                    arguments: {'selected_student': student},
                  );
                },
                tooltip: 'Report Violation',
              ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editMode)
                  _buildEditStudentForm(student)
                else
                  _buildViewStudentInfo(student),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditStudentForm(Map<String, dynamic> student) {
    final gradeController = TextEditingController(text: student['grade_level']?.toString() ?? '');
    final sectionController = TextEditingController(text: student['section']?.toString() ?? '');
    final strandController = TextEditingController(text: student['strand']?.toString() ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '✏️ Edit Student Information',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        
        TextField(
          controller: gradeController,
          decoration: const InputDecoration(
            labelText: 'Grade Level',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.grade),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        
        TextField(
          controller: sectionController,
          decoration: const InputDecoration(
            labelText: 'Section',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.class_),
          ),
        ),
        const SizedBox(height: 12),
        
        if (['11', '12'].contains(student['grade_level']?.toString()))
          TextField(
            controller: strandController,
            decoration: const InputDecoration(
              labelText: 'Strand (e.g., ICT, ABM, HUMSS)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.school),
            ),
          ),
        
        const SizedBox(height: 16),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await _updateStudentInfo(
                student['id'],
                gradeController.text,
                sectionController.text,
                strandController.text,
              );
            },
            icon: const Icon(Icons.save),
            label: const Text('Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewStudentInfo(Map<String, dynamic> student) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contact Information',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildInfoRow('Phone', student['contact_number'] ?? 'Not provided'),
        _buildInfoRow('Guardian', student['guardian_name'] ?? 'Not provided'),
        _buildInfoRow('Guardian Contact', student['guardian_contact'] ?? 'Not provided'),
        
        const SizedBox(height: 16),
        
        if (student['violations_all_time'] != null && student['violations_all_time'] > 0)
          OutlinedButton.icon(
            onPressed: () => _showViolationHistoryDialog(student),
            icon: Icon(Icons.history, color: Colors.orange.shade700),
            label: Text(
              'View Violation History (${student['violations_all_time']} total)',
              style: TextStyle(color: Colors.orange.shade900),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.orange.shade700),
            ),
          ),
        
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.teacherSubmitReport,
                    arguments: {'selected_student': student},
                  );
                },
                icon: const Icon(Icons.report),
                label: const Text('Report Violation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _showStudentDetailsDialog(student);
                },
                icon: const Icon(Icons.info),
                label: const Text('View Details'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _updateStudentInfo(
    int studentId,
    String gradeLevel,
    String section,
    String strand,
  ) async {
    final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
    
    final success = await teacherProvider.updateStudentInfo(
      studentId: studentId,
      gradeLevel: gradeLevel,
      section: section,
      strand: strand,
    );
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ Student information updated successfully'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        await teacherProvider.fetchAdvisingStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update: ${teacherProvider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showViolationHistoryDialog(Map<String, dynamic> student) async {
    final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    final history = await teacherProvider.fetchStudentViolationHistory(student['id']);
    
    if (!mounted) return;
    Navigator.pop(context);
    
    if (history == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to load violation history'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.history, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Violation History\n${student['first_name']} ${student['last_name']}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: SingleChildScrollView(
            child: Column(
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
                      Text(
                        'Total Violations: ${history['total_violations_all_time']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Current: Grade ${history['student']['current_grade']} ${history['student']['current_section']}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                ...((history['violations_by_school_year'] as List?) ?? []).map((yearData) {
                  final schoolYear = yearData['school_year'];
                  final violations = (yearData['violations'] as List?) ?? [];
                  final count = yearData['violations_count'] ?? 0;
                  
                  if (count == 0) return const SizedBox();
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      title: Text(
                        'School Year $schoolYear',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '$count violations - ${yearData['grade_level']} ${yearData['section']}',
                      ),
                      children: violations.map<Widget>((v) {
                        return ListTile(
                          leading: Icon(
                            Icons.warning,
                            color: _getSeverityColor(v['severity']),
                          ),
                          title: Text(v['violation_type'] ?? 'Unknown'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v['description'] ?? ''),
                              Text(
                                'Date: ${_formatDate(v['incident_date'])}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'minor':
        return Colors.yellow.shade700;
      case 'major':
        return Colors.orange.shade700;
      case 'severe':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
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

  List<Map<String, dynamic>> _filterStudents(List<Map<String, dynamic>> students) {
    return students.where((student) {
      if (_searchQuery.isNotEmpty) {
        final fullName = '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.toLowerCase();
        final username = student['username']?.toString().toLowerCase() ?? '';
        final studentId = student['student_id']?.toString().toLowerCase() ?? '';
        
        if (!fullName.contains(_searchQuery) &&
            !username.contains(_searchQuery) &&
            !studentId.contains(_searchQuery)) {
          return false;
        }
      }
      
      if (_selectedGradeFilter != 'All') {
        if (student['grade_level']?.toString() != _selectedGradeFilter) {
          return false;
        }
      }
      
      if (_selectedStrandFilter != 'All') {
        if (student['strand']?.toString() != _selectedStrandFilter) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  String _getStudentGradeInfo(Map<String, dynamic> student) {
    final grade = student['grade_level']?.toString() ?? '';
    final strand = student['strand']?.toString() ?? '';
    final section = student['section']?.toString() ?? '';
    
    if (['11', '12'].contains(grade) && strand.isNotEmpty) {
      return 'Grade $grade $strand - Section $section';
    } else if (grade.isNotEmpty && section.isNotEmpty) {
      return 'Grade $grade - Section $section';
    }
    return 'Grade $grade';
  }

  String _getAdvisingClassInfo(Map<String, dynamic> profile) {
    final grade = profile['advising_grade']?.toString() ?? '';
    final strand = profile['advising_strand']?.toString() ?? '';
    final section = profile['advising_section']?.toString() ?? '';
    
    if (grade.isNotEmpty && section.isNotEmpty) {
      if (['11', '12'].contains(grade) && strand.isNotEmpty) {
        return 'Grade $grade $strand - Section $section';
      } else {
        return 'Grade $grade - Section $section';
      }
    }
    return 'No advising class assigned';
  }

  void _showStudentDetailsDialog(Map<String, dynamic> student) {
    final fullName = '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim();
    final displayName = fullName.isNotEmpty ? fullName : student['username'] ?? 'Unknown';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(displayName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogInfoRow('LRN', student['lrn'] ?? student['student_id'] ?? 'N/A'),
              _buildDialogInfoRow('Username', student['username'] ?? 'N/A'),
              _buildDialogInfoRow('Grade Info', _getStudentGradeInfo(student)),
              _buildDialogInfoRow('Email', student['email'] ?? 'Not provided'),
              _buildDialogInfoRow('Phone', student['contact_number'] ?? 'Not provided'),
              _buildDialogInfoRow('Guardian', student['guardian_name'] ?? 'Not provided'),
              _buildDialogInfoRow('Guardian Contact', student['guardian_contact'] ?? 'Not provided'),
              if (student['created_at'] != null)
                _buildDialogInfoRow('Enrolled', _formatDate(student['created_at'])),
              if (student['violations_all_time'] != null && student['violations_all_time'] > 0)
                _buildDialogInfoRow(
                  'Violations',
                  '${student['violations_current_year']} this year, ${student['violations_all_time']} all-time',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                AppRoutes.teacherSubmitReport,
                arguments: {'selected_student': student},
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Report Violation'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
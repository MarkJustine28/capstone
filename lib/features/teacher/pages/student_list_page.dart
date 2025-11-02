import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/teacher_provider.dart';

class StudentListPage extends StatefulWidget {
  const StudentListPage({Key? key}) : super(key: key);

  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  String _searchQuery = '';
  String _selectedGradeFilter = 'All';
  String _selectedStrandFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
      teacherProvider.fetchAdvisingStudents();
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
              // Advising Class Info Header
              _buildAdvisingClassHeader(teacherProvider),
              
              // Search and Filter Section
              _buildSearchAndFilterSection(),
              
              // Students List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    teacherProvider.fetchAdvisingStudents();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/teacher/submit-report');
        },
        icon: const Icon(Icons.add_circle),
        label: const Text('Report Violation'),
        backgroundColor: Colors.red.shade600,
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
          // Search Bar
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
          
          // Filter Row (if needed for multiple grades/strands)
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
                return const SizedBox(); // No need for filters
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
            Text('ID: ${student['student_id'] ?? 'N/A'}'),
            Text(_getStudentGradeInfo(student)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.report, color: Colors.red),
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/teacher/submit-report',
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
                const Text(
                  'Contact Information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Phone', student['contact_number'] ?? 'Not provided'),
                _buildInfoRow('Guardian', student['guardian_name'] ?? 'Not provided'),
                _buildInfoRow('Guardian Contact', student['guardian_contact'] ?? 'Not provided'),
                
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/teacher/submit-report',
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
            ),
          ),
        ],
      ),
    );
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
      // Search filter
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
      
      // Grade filter
      if (_selectedGradeFilter != 'All') {
        if (student['grade_level']?.toString() != _selectedGradeFilter) {
          return false;
        }
      }
      
      // Strand filter
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
              _buildDialogInfoRow('Student ID', student['student_id'] ?? 'N/A'),
              _buildDialogInfoRow('Username', student['username'] ?? 'N/A'),
              _buildDialogInfoRow('Grade Info', _getStudentGradeInfo(student)),
              _buildDialogInfoRow('Email', student['email'] ?? 'Not provided'),
              _buildDialogInfoRow('Phone', student['contact_number'] ?? 'Not provided'),
              _buildDialogInfoRow('Guardian', student['guardian_name'] ?? 'Not provided'),
              _buildDialogInfoRow('Guardian Contact', student['guardian_contact'] ?? 'Not provided'),
              if (student['created_at'] != null)
                _buildDialogInfoRow('Enrolled', _formatDate(student['created_at'])),
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
                '/teacher/submit-report',
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

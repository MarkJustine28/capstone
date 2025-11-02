import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/teacher_provider.dart';
import 'package:intl/intl.dart';

class SubmitReportPage extends StatefulWidget {
  final Map<String, dynamic>? selectedStudent;
  
  const SubmitReportPage({
    Key? key,
    this.selectedStudent,
  }) : super(key: key);

  @override
  State<SubmitReportPage> createState() => _SubmitReportPageState();
}

class _SubmitReportPageState extends State<SubmitReportPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _otherTitleController = TextEditingController();
  
  // Student selection controllers
  final TextEditingController _otherStudentNameController = TextEditingController();
  final TextEditingController _otherStudentIdController = TextEditingController();
  final TextEditingController _otherStudentGradeController = TextEditingController();
  final TextEditingController _otherStudentSectionController = TextEditingController();
  final TextEditingController _otherStudentStrandController = TextEditingController();
  
  Map<String, dynamic>? _selectedStudent;
  Map<String, dynamic>? _selectedViolationType;
  bool _isSubmitting = false;
  bool _showOtherField = false;
  
  // Student reporting mode
  bool _isReportingOtherStudent = false;
  
  // Teacher info
  Map<String, dynamic>? _teacherInfo;
  bool _loadingTeacherInfo = true;

  @override
  void initState() {
    super.initState();
    // Set selected student if passed from previous page
    _selectedStudent = widget.selectedStudent;
    
    // Fetch required data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
      teacherProvider.fetchAdvisingStudents();
      teacherProvider.fetchViolationTypes();
      _fetchTeacherInfo();
    });
  }

  Future<void> _fetchTeacherInfo() async {
    try {
      final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
      await teacherProvider.fetchProfile();
      
      setState(() {
        _teacherInfo = teacherProvider.teacherProfile;
        _loadingTeacherInfo = false;
      });
      
      debugPrint("✅ Teacher info loaded: $_teacherInfo");
    } catch (e) {
      debugPrint("❌ Error fetching teacher info: $e");
      setState(() => _loadingTeacherInfo = false);
    }
  }

  String _getTeacherName() {
    if (_teacherInfo != null) {
      final fullName = _teacherInfo!['full_name']?.toString() ?? '';
      if (fullName.isNotEmpty) return fullName;
      
      final firstName = _teacherInfo!['first_name']?.toString() ?? '';
      final lastName = _teacherInfo!['last_name']?.toString() ?? '';
      final combined = '$firstName $lastName'.trim();
      
      if (combined.isNotEmpty) return combined;
      
      return _teacherInfo!['username']?.toString() ?? 'Teacher';
    }
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.username ?? 'Teacher';
  }

  String _getTeacherClassInfo() {
    if (_teacherInfo == null) return 'No class assigned';
    
    final grade = _teacherInfo!['advising_grade']?.toString() ?? '';
    final strand = _teacherInfo!['advising_strand']?.toString() ?? '';
    final section = _teacherInfo!['advising_section']?.toString() ?? '';
    
    if (grade.isEmpty || section.isEmpty) return 'No class assigned';
    
    if (['11', '12'].contains(grade) && strand.isNotEmpty) {
      return 'Grade $grade $strand - Section $section';
    }
    return 'Grade $grade - Section $section';
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'bullying': return Colors.red;
      case 'substance': return Colors.brown;
      case 'violence': return Colors.deepOrange;
      case 'academic': return Colors.blue;
      case 'attendance': return Colors.orange;
      case 'behavioral': return Colors.purple;
      case 'dress code': return Colors.teal;
      case 'mental health': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _getSubmissionTitle() {
    if (_selectedViolationType?['name'] == 'Other (Specify below)') {
      return _otherTitleController.text.trim();
    }
    return _selectedViolationType?['name'] ?? '';
  }

  DateTime _getGMTPlus8Time() {
    final utcNow = DateTime.now().toUtc();
    final gmtPlus8Time = utcNow.add(const Duration(hours: 8));
    
    debugPrint("🌍 UTC time: $utcNow");
    debugPrint("🇵🇭 GMT+8 time: $gmtPlus8Time");
    
    return gmtPlus8Time;
  }

  String _formatGMTPlus8DateTime(DateTime dateTime) {
    final formatter = DateFormat("yyyy-MM-ddTHH:mm:ss.SSS");
    final formattedTime = "${formatter.format(dateTime)}+08:00";
    
    debugPrint("🕐 Formatted GMT+8 datetime: $formattedTime");
    
    return formattedTime;
  }

  String _getStudentInfoForReport() {
    if (_isReportingOtherStudent) {
      // Manual student info
      final name = _otherStudentNameController.text.trim();
      final studentId = _otherStudentIdController.text.trim();
      final grade = _otherStudentGradeController.text.trim();
      final section = _otherStudentSectionController.text.trim();
      final strand = _otherStudentStrandController.text.trim();
      
      String gradeSection = 'N/A';
      if (grade.isNotEmpty && section.isNotEmpty) {
        if (['11', '12'].contains(grade) && strand.isNotEmpty) {
          gradeSection = 'Grade $grade $strand - Section $section';
        } else {
          gradeSection = 'Grade $grade - Section $section';
        }
      } else if (grade.isNotEmpty) {
        gradeSection = 'Grade $grade';
      }
      
      return '''$name
Student's Grade/Section: $gradeSection
Student ID: ${studentId.isNotEmpty ? studentId : 'N/A'}
[Note: Student is NOT from teacher's advising section]''';
    } else {
      // From advising section
      final studentFirstName = _selectedStudent!['first_name'] ?? '';
      final studentLastName = _selectedStudent!['last_name'] ?? '';
      final studentFullName = '$studentFirstName $studentLastName'.trim();
      final displayStudentName = studentFullName.isNotEmpty 
          ? studentFullName 
          : _selectedStudent!['name'] ?? 'Unknown';
      
      final studentGrade = _selectedStudent!['grade_level']?.toString() ?? 'N/A';
      final studentSection = _selectedStudent!['section']?.toString() ?? 'N/A';
      final studentStrand = _selectedStudent!['strand']?.toString() ?? '';
      final studentId = _selectedStudent!['student_id']?.toString() ?? 'N/A';
      
      String gradeSection = studentGrade.isNotEmpty && studentSection.isNotEmpty
          ? (['11', '12'].contains(studentGrade) && studentStrand.isNotEmpty
              ? 'Grade $studentGrade $studentStrand - Section $studentSection'
              : 'Grade $studentGrade - Section $studentSection')
          : 'N/A';
      
      return '''$displayStudentName
Student's Grade/Section: $gradeSection
Student ID: $studentId
[Note: Student is from teacher's advising section]''';
    }
  }

  String _getStudentNameForSubmission() {
    if (_isReportingOtherStudent) {
      return _otherStudentNameController.text.trim();
    } else {
      final studentFirstName = _selectedStudent!['first_name'] ?? '';
      final studentLastName = _selectedStudent!['last_name'] ?? '';
      final studentFullName = '$studentFirstName $studentLastName'.trim();
      return studentFullName.isNotEmpty 
          ? studentFullName 
          : _selectedStudent!['name'] ?? 'Unknown';
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _getSubmissionTitle();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Please select an incident type"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate student selection
    if (!_isReportingOtherStudent && _selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Please select a student from your advising section"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isReportingOtherStudent && _otherStudentNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Please enter the student's name"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);

    try {
      final gmtPlus8Time = _getGMTPlus8Time();
      final formattedDateTime = _formatGMTPlus8DateTime(gmtPlus8Time);
      
      final teacherName = _getTeacherName();
      final teacherClassInfo = _getTeacherClassInfo();
      final studentInfo = _getStudentInfoForReport();
      final studentName = _getStudentNameForSubmission();
      
      // Build comprehensive report content
      final reportDescription = '''Teacher Report

Reported by: $teacherName
Teacher's Class: $teacherClassInfo
Teacher's Username: ${authProvider.username}
Employee ID: ${_teacherInfo?['employee_id'] ?? 'N/A'}

Student Being Reported: $studentInfo

Report Date: ${DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())}

Violation Type: $title
${_selectedViolationType != null && _selectedViolationType!['name'] != 'Other (Specify below)' ? 'Category: ${_selectedViolationType!['category']}\nSeverity: ${_selectedViolationType!['severity_level']}' : ''}

Incident Details:
${_descriptionController.text.trim()}''';
      
      // Prepare report data for submission
      final reportData = {
        'title': title,
        'content': reportDescription,
        'description': _descriptionController.text.trim(),
        'report_type': 'teacher_report',
        'incident_date': formattedDateTime,
        'violation_type_id': _selectedViolationType?['id'],
        'custom_violation': _selectedViolationType?['name'] == 'Other (Specify below)' 
            ? _otherTitleController.text.trim() 
            : null,
        'student_name': studentName,
        'teacher_name': teacherName,
        'is_other_student': _isReportingOtherStudent,
        'status': 'pending',
        // Only include student_id if from advising section
        if (!_isReportingOtherStudent && _selectedStudent != null) 
          'student_id': _selectedStudent!['id'],
        // Include other student details if reporting outside section
        if (_isReportingOtherStudent) ...{
          'other_student_name': _otherStudentNameController.text.trim(),
          'other_student_id': _otherStudentIdController.text.trim(),
          'other_student_grade': _otherStudentGradeController.text.trim(),
          'other_student_section': _otherStudentSectionController.text.trim(),
          'other_student_strand': _otherStudentStrandController.text.trim(),
        },
      };

      debugPrint("📝 Report submitted by: $teacherName");
      debugPrint("📝 Student being reported: $studentName");
      debugPrint("📝 Report type: teacher_report");
      debugPrint("📝 Is other student: $_isReportingOtherStudent");
      debugPrint("📝 Report data: $reportData");

      final success = await teacherProvider.submitStudentReport(reportData);

      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text("✅ Report for $studentName submitted successfully!"),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Reset form
        setState(() {
          _selectedStudent = null;
          _selectedViolationType = null;
          _showOtherField = false;
          _isReportingOtherStudent = false;
        });
        _descriptionController.clear();
        _otherTitleController.clear();
        _otherStudentNameController.clear();
        _otherStudentIdController.clear();
        _otherStudentGradeController.clear();
        _otherStudentSectionController.clear();
        _otherStudentStrandController.clear();
        
        // Return true to indicate success
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed to submit report: ${teacherProvider.error ?? 'Unknown error'}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error submitting report: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacherProvider = Provider.of<TeacherProvider>(context);
    final teacherName = _getTeacherName();
    final teacherClassInfo = _getTeacherClassInfo();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Student Violation"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Teacher Info
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.report_problem, color: Colors.blue.shade700, size: 32),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Teacher Violation Report",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Submit a formal report about student behavior",
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Teacher Information Display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: _loadingTeacherInfo 
                          ? const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text("Loading teacher info...", style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person, color: Colors.blue.shade600, size: 18),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Report submitted by:",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  teacherName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Advising: $teacherClassInfo',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                if (_teacherInfo?['employee_id'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    "Employee ID: ${_teacherInfo!['employee_id']}",
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Student Selection Mode Toggle
              Card(
                color: Colors.purple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.swap_horiz, color: Colors.purple.shade700, size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            "Select Student Type",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Toggle Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isReportingOtherStudent = false;
                                  // Clear other student fields
                                  _otherStudentNameController.clear();
                                  _otherStudentIdController.clear();
                                  _otherStudentGradeController.clear();
                                  _otherStudentSectionController.clear();
                                  _otherStudentStrandController.clear();
                                });
                              },
                              icon: Icon(
                                _isReportingOtherStudent ? Icons.radio_button_unchecked : Icons.radio_button_checked,
                                size: 20,
                              ),
                              label: const Text(
                                'My Section',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _isReportingOtherStudent ? Colors.white : Colors.green.shade50,
                                foregroundColor: _isReportingOtherStudent ? Colors.grey : Colors.green.shade700,
                                side: BorderSide(
                                  color: _isReportingOtherStudent ? Colors.grey.shade300 : Colors.green.shade700,
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isReportingOtherStudent = true;
                                  // Clear advising section student
                                  _selectedStudent = null;
                                });
                              },
                              icon: Icon(
                                _isReportingOtherStudent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                size: 20,
                              ),
                              label: const Text(
                                'Other Student',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _isReportingOtherStudent ? Colors.orange.shade50 : Colors.white,
                                foregroundColor: _isReportingOtherStudent ? Colors.orange.shade700 : Colors.grey,
                                side: BorderSide(
                                  color: _isReportingOtherStudent ? Colors.orange.shade700 : Colors.grey.shade300,
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.purple.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isReportingOtherStudent 
                                    ? "You're reporting a student outside your advising section"
                                    : "You're reporting a student from your advising section",
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Student Selection or Input
              if (!_isReportingOtherStudent) ...[
                // FROM ADVISING SECTION
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.school, color: Colors.green.shade700, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              "Student from My Advising Section",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        const Text(
                          "Select Student *",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        
                        if (teacherProvider.isLoading)
                          Container(
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: const Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 12),
                                  Text("Loading students..."),
                                ],
                              ),
                            ),
                          )
                        else
                          DropdownButtonFormField<Map<String, dynamic>>(
                            value: _selectedStudent,
                            decoration: InputDecoration(
                              hintText: "Select a student from your advising class",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixIcon: Icon(Icons.person_outline, color: Colors.green.shade600),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            isExpanded: true,
                            menuMaxHeight: 300,
                            items: teacherProvider.advisingStudents.map((student) {
                              final firstName = student['first_name'] ?? '';
                              final lastName = student['last_name'] ?? '';
                              final fullName = '$firstName $lastName'.trim();
                              final displayName = fullName.isNotEmpty 
                                  ? fullName 
                                  : student['name'] ?? 'Unknown';
                              
                              final grade = student['grade_level'] ?? 'N/A';
                              final section = student['section'] ?? 'N/A';
                              final studentId = student['student_id'] ?? 'N/A';
                              
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: student,
                                child: Text(
                                  '$displayName (Grade $grade-$section, ID: $studentId)',
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (student) {
                              setState(() => _selectedStudent = student);
                            },
                            validator: (value) {
                              if (!_isReportingOtherStudent && value == null) {
                                return "Please select a student";
                              }
                              return null;
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // OTHER STUDENT (MANUAL INPUT)
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_add, color: Colors.orange.shade700, size: 24),
                            const SizedBox(width: 12),
                            const Text(
                              "Student from Other Section",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        const Text(
                          "Student Name *",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _otherStudentNameController,
                          decoration: InputDecoration(
                            hintText: "Enter student's full name",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(Icons.person, color: Colors.orange.shade600),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (_isReportingOtherStudent && (value == null || value.trim().isEmpty)) {
                              return "Please enter student's name";
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        const Text(
                          "Student ID (Optional)",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _otherStudentIdController,
                          decoration: InputDecoration(
                            hintText: "Enter student ID if known",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(Icons.badge, color: Colors.orange.shade600),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Grade Level",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _otherStudentGradeController,
                                    decoration: InputDecoration(
                                      hintText: "e.g., 7, 11",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixIcon: Icon(Icons.grade, color: Colors.orange.shade600),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Section",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _otherStudentSectionController,
                                    decoration: InputDecoration(
                                      hintText: "e.g., A, B",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      prefixIcon: Icon(Icons.class_, color: Colors.orange.shade600),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        const Text(
                          "Strand (if Grade 11/12)",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _otherStudentStrandController,
                          decoration: InputDecoration(
                            hintText: "e.g., STEM, ABM, HUMSS (if applicable)",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(Icons.school_outlined, color: Colors.orange.shade600),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  "Provide as much information as possible about the student",
                                  style: TextStyle(fontSize: 11, color: Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Violation Type Selection
              const Text(
                "Violation Type *",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedViolationType,
                decoration: InputDecoration(
                  hintText: "Select violation type",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.list_alt, color: Colors.blue.shade600),
                ),
                isExpanded: true,
                menuMaxHeight: 400,
                items: [
                  ...teacherProvider.violationTypes.map((violation) {
                    final category = violation['category'] ?? 'Other';
                    final severity = violation['severity_level'] ?? 'Medium';
                    final color = _getCategoryColor(category);
                    
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: violation,
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                                children: [
                                  TextSpan(
                                    text: violation['name'],
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  TextSpan(
                                    text: ' ($category • $severity)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  // Add "Other" option
                  DropdownMenuItem<Map<String, dynamic>>(
                    value: {'id': null, 'name': 'Other (Specify below)', 'category': 'Other'},
                    child: const Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Other (Specify below)'),
                      ],
                    ),
                  ),
                ],
                onChanged: (violation) {
                  setState(() {
                    _selectedViolationType = violation;
                    _showOtherField = violation?['name'] == 'Other (Specify below)';
                    if (!_showOtherField) {
                      _otherTitleController.clear();
                    }
                  });
                },
                validator: (value) {
                  if (value == null) return "Please select a violation type";
                  return null;
                },
              ),

              // Show selected violation details
              if (_selectedViolationType != null && _selectedViolationType!['name'] != 'Other (Specify below)')
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(_selectedViolationType!['category'] ?? 'Other').withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getCategoryColor(_selectedViolationType!['category'] ?? 'Other').withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: _getCategoryColor(_selectedViolationType!['category'] ?? 'Other'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Category: ${_selectedViolationType!['category']} • Severity: ${_selectedViolationType!['severity_level']}",
                          style: TextStyle(
                            fontSize: 12,
                            color: _getCategoryColor(_selectedViolationType!['category'] ?? 'Other'),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Other field
              if (_showOtherField) ...[
                const SizedBox(height: 16),
                const Text(
                  "Specify Other Violation *",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _otherTitleController,
                  decoration: InputDecoration(
                    hintText: "Please specify what violation was committed",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.edit, color: Colors.blue.shade600),
                  ),
                  validator: (value) {
                    if (_showOtherField && (value == null || value.trim().isEmpty)) {
                      return "Please specify the violation type";
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 24),

              // Description Field
              const Text(
                "Incident Description *",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: "Provide detailed description of the incident...\n\nInclude:\n• What exactly happened?\n• When did it occur?\n• Where did it happen?\n• Were there any witnesses?",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 100.0),
                    child: Icon(Icons.description, color: Colors.blue.shade600),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please provide incident description";
                  }
                  if (value.trim().length < 10) {
                    return "Description must be at least 10 characters";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Guidelines Card
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber.shade700),
                          const SizedBox(width: 8),
                          Text(
                            "Reporting Guidelines",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "• Be objective and factual in your report\n"
                        "• Only report violations you directly witnessed\n"
                        "• Provide as much detail as possible\n"
                        "• Include date, time, and location of incident\n"
                        "• List any witnesses present\n"
                        "• Maintain professional language\n"
                        "• Report serious incidents immediately",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitReport,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  label: Text(
                    _isSubmitting ? "Submitting Report..." : "Submit Report",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _otherTitleController.dispose();
    _otherStudentNameController.dispose();
    _otherStudentIdController.dispose();
    _otherStudentGradeController.dispose();
    _otherStudentSectionController.dispose();
    _otherStudentStrandController.dispose();
    super.dispose();
  }
}
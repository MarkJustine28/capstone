import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../services/api_services.dart'; // ✅ Import ApiService

class SubmitIncidentPage extends StatefulWidget {
  const SubmitIncidentPage({super.key});

  @override
  State<SubmitIncidentPage> createState() => _SubmitIncidentPageState();
}

class _SubmitIncidentPageState extends State<SubmitIncidentPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _otherTitleController = TextEditingController();
  final TextEditingController _reportedStudentController = TextEditingController();

  Map<String, dynamic>? _selectedViolationType;
  List<Map<String, dynamic>> _violationTypes = [];
  bool _isSubmitting = false;
  bool _showOtherField = false;
  bool _loadingViolationTypes = true;

  // Student info from API
  Map<String, dynamic>? _studentInfo;
  bool _loadingStudentInfo = true;

  @override
  void initState() {
    super.initState();
    _fetchViolationTypes();
    _fetchStudentInfo();
  }

  // ✅ FIXED: Fetch student info using ApiService
  Future<void> _fetchStudentInfo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.token == null) {
        debugPrint("❌ Missing token");
        setState(() => _loadingStudentInfo = false);
        return;
      }
      
      debugPrint("🌐 Fetching student info from: ${ApiService.baseUrl}/profile/");
      
      // ✅ Use ApiService instead of manual HTTP
      final result = await ApiService.instance.get(
        endpoint: '/profile/',
        token: authProvider.token,
      );

      debugPrint("📡 Student info response: ${result['success']}");
      
      if (result['success'] == true) {
        setState(() {
          _studentInfo = result['data']['user'] ?? {};
          _loadingStudentInfo = false;
        });
        debugPrint("✅ Successfully loaded student info: $_studentInfo");
      } else {
        debugPrint("❌ API returned success: false");
        setState(() => _loadingStudentInfo = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching student info: $e");
      setState(() => _loadingStudentInfo = false);
    }
  }

  // ✅ FIXED: Fetch violation types using ApiService
  Future<void> _fetchViolationTypes() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.token == null) {
        debugPrint("❌ Missing token");
        _setupFallbackViolationTypes();
        return;
      }
      
      debugPrint("🌐 Fetching violation types from: ${ApiService.baseUrl}/violation-types/");
      
      // ✅ Use ApiService instead of manual HTTP
      final result = await ApiService.instance.getViolationTypes(
        token: authProvider.token!,
      );

      debugPrint("📡 Response status: ${result['success']}");
      
      if (result['success'] == true) {
        final violationTypesData = result['data']['violation_types'] ?? result['data'];
        
        setState(() {
          _violationTypes = List<Map<String, dynamic>>.from(violationTypesData);
          // Add "Others" option
          _violationTypes.add({
            'id': null,
            'name': 'Others',
            'category': 'Others',
            'severity_level': 'Medium',
            'description': 'Other incidents not listed'
          });
          _loadingViolationTypes = false;
        });
        debugPrint("✅ Successfully loaded ${_violationTypes.length} violation types");
      } else {
        debugPrint("❌ API returned success: false - ${result['error']}");
        _setupFallbackViolationTypes();
      }
    } catch (e) {
      debugPrint("❌ Error fetching violation types: $e");
      _setupFallbackViolationTypes();
    }
  }

  void _setupFallbackViolationTypes() {
    setState(() {
      _violationTypes = [
        {'id': 1, 'name': 'Tardiness', 'category': 'Tardiness', 'severity_level': 'Low'},
        {'id': 2, 'name': 'Using Vape/Cigarette', 'category': 'Using Vape/Cigarette', 'severity_level': 'High'},
        {'id': 3, 'name': 'Misbehavior', 'category': 'Misbehavior', 'severity_level': 'Medium'},
        {'id': 4, 'name': 'Bullying - Physical, Verbal/Emotional, Cyberbullying, Sexual, Racism', 'category': 'Bullying', 'severity_level': 'High'},
        {'id': 5, 'name': 'Gambling', 'category': 'Gambling', 'severity_level': 'Medium'},
        {'id': 6, 'name': 'Haircut', 'category': 'Haircut', 'severity_level': 'Low'},
        {'id': 7, 'name': 'Not Wearing Proper Uniform/ID', 'category': 'Not Wearing Proper Uniform/ID', 'severity_level': 'Low'},
        {'id': 8, 'name': 'Cheating', 'category': 'Cheating', 'severity_level': 'High'},
        {'id': 9, 'name': 'Cutting Classes', 'category': 'Cutting Classes', 'severity_level': 'Medium'},
        {'id': 10, 'name': 'Absenteeism', 'category': 'Absenteeism', 'severity_level': 'Medium'},
        {'id': null, 'name': 'Others', 'category': 'Others', 'severity_level': 'Medium'},
      ];
      _loadingViolationTypes = false;
    });
    debugPrint("⚠️ Using fallback violation types");
  }

  String _getSubmissionTitle() {
    if (_selectedViolationType?['name'] == 'Others') {
      return _otherTitleController.text.trim();
    }
    return _selectedViolationType?['name'] ?? '';
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'tardiness': return Colors.orange;
      case 'using vape/cigarette': return Colors.brown;
      case 'bullying': return Colors.red;
      case 'gambling': return Colors.deepOrange;
      case 'haircut': return Colors.teal;
      case 'not wearing proper uniform/id': return Colors.blue;
      case 'cheating': return Colors.purple;
      case 'cutting classes': return Colors.pink;
      case 'absenteeism': return Colors.indigo;
      case 'misbehavior': return Colors.deepPurple;
      case 'others': return Colors.grey;
      default: return Colors.grey;
    }
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

  String _getStudentName() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Try to get from API data first
    if (_studentInfo != null) {
      final firstName = _studentInfo!['first_name']?.toString() ?? '';
      final lastName = _studentInfo!['last_name']?.toString() ?? '';
      
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        return '$firstName $lastName';
      } else if (firstName.isNotEmpty) {
        return firstName;
      } else if (lastName.isNotEmpty) {
        return lastName;
      }
    }
    
    // Fallback to username from AuthProvider
    return authProvider.username ?? 'Unknown Student';
  }

  String _getStudentGradeInfo() {
    if (_studentInfo != null) {
      final gradeLevel = _studentInfo!['grade_level']?.toString() ?? '';
      final section = _studentInfo!['section']?.toString() ?? '';
      final strand = _studentInfo!['strand']?.toString() ?? '';
      
      if (gradeLevel.isNotEmpty && section.isNotEmpty) {
        if (strand.isNotEmpty && (gradeLevel == '11' || gradeLevel == '12')) {
          return 'Grade $gradeLevel $strand - $section';
        }
        return 'Grade $gradeLevel - $section';
      } else if (gradeLevel.isNotEmpty) {
        return 'Grade $gradeLevel';
      }
    }
    
    return 'Grade/Section not specified';
  }

  // ✅ FIXED: Submit report using ApiService
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _getSubmissionTitle();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an incident type")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (authProvider.token != null) {
        final gmtPlus8Time = _getGMTPlus8Time();
        final formattedDateTime = _formatGMTPlus8DateTime(gmtPlus8Time);
        
        final reporterName = _getStudentName();
        final reporterGradeInfo = _getStudentGradeInfo();
        final reportedStudentName = _reportedStudentController.text.trim();
        
        final reportDescription = '''Reported by: $reporterName
Reporter's Class: $reporterGradeInfo
Reporter's Username: ${authProvider.username}

Student Being Reported: $reportedStudentName

Incident Details:
${_descriptionController.text.trim()}''';
        
        final reportData = {
          'title': title,
          'content': reportDescription,
          'report_type': 'peer_report',
          'incident_date': formattedDateTime,
          'violation_type_id': _selectedViolationType?['id'],
          'custom_violation': _selectedViolationType?['name'] == 'Others'
              ? _otherTitleController.text.trim()
              : null,
          'reported_by_name': reporterName,
          'reported_student_name': reportedStudentName,
          'student_grade_info': reporterGradeInfo,
          'is_self_report': false,
        };

        debugPrint("📝 Submitting report via ApiService");
        debugPrint("📝 Report submitted by: $reporterName");
        debugPrint("📝 Student being reported: $reportedStudentName");

        // ✅ Use ApiService
        final result = await ApiService.instance.post(
          endpoint: '/student/reports/',
          token: authProvider.token,
          data: reportData,
        );

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Report about $reportedStudentName submitted successfully by $reporterName!"),
                backgroundColor: Colors.green,
              ),
            );

            setState(() {
              _selectedViolationType = null;
              _showOtherField = false;
            });
            _descriptionController.clear();
            _otherTitleController.clear();
            _reportedStudentController.clear();

            // Refresh reports list
            final studentProvider = Provider.of<StudentProvider>(context, listen: false);
            await studentProvider.fetchReports(authProvider.token!);
            
            // Navigate back
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed to submit report: ${result['error']}"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Authentication token missing.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to submit report: $e"),
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
    final reporterName = _getStudentName();
    final reporterGradeInfo = _getStudentGradeInfo();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Report Student Incident"),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Reporter Info
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.report_problem, color: Colors.red.shade700, size: 32),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Student Incident Report",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Report incidents involving other students",
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Reporter Information Display
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: _loadingStudentInfo 
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
                                  Text("Loading reporter info...", style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person, color: Colors.red.shade600, size: 18),
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
                                  reporterName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reporterGradeInfo,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                if (Provider.of<AuthProvider>(context, listen: false).username != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    "Username: ${Provider.of<AuthProvider>(context, listen: false).username}",
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

              // Student Being Reported Section
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_outline, color: Colors.orange.shade700, size: 24),
                          const SizedBox(width: 12),
                          const Text(
                            "Student Being Reported",
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
                        controller: _reportedStudentController,
                        decoration: InputDecoration(
                          hintText: "Enter the full name of the student who committed the violation",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: Icon(Icons.person_outline, color: Colors.orange.shade600),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Please enter the name of the student being reported";
                          }
                          if (value.trim().length < 2) {
                            return "Please enter a valid student name";
                          }
                          return null;
                        },
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
                                "Please enter the full name exactly as it appears in school records",
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

              const SizedBox(height: 24),

              // Incident Type Dropdown
              const Text(
                "Violation Type *",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              
              if (_loadingViolationTypes)
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
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
                        Text("Loading violation types..."),
                      ],
                    ),
                  ),
                )
              else
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedViolationType,
                  decoration: InputDecoration(
                    hintText: "Select violation type",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.list_alt, color: Colors.red.shade600),
                  ),
                  isExpanded: true,
                  menuMaxHeight: 400,
                  items: _violationTypes.map((Map<String, dynamic> violation) {
                    final category = violation['category'] ?? 'Other';
                    final severity = violation['severity_level'] ?? 'Medium';
                    final color = _getCategoryColor(category);
                    
                    return DropdownMenuItem<Map<String, dynamic>>(
                      value: violation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: violation['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: violation['name'].toString().startsWith('Bullying') 
                                            ? Colors.red.shade700 
                                            : Colors.black87,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' ($category • $severity)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (Map<String, dynamic>? newValue) {
                    setState(() {
                      _selectedViolationType = newValue;
                      _showOtherField = newValue?['name'] == 'Others';
                      if (!_showOtherField) {
                        _otherTitleController.clear();
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return "Please select a violation type";
                    }
                    return null;
                  },
                ),

              // Show selected violation details
              if (_selectedViolationType != null && _selectedViolationType!['name'] != 'Others')
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

              // Show "Other" text field when "Others" is selected
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
                    prefixIcon: Icon(Icons.edit, color: Colors.red.shade600),
                  ),
                  validator: (value) {
                    if (_showOtherField && (value == null || value.trim().isEmpty)) {
                      return "Please specify what violation was committed";
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
                  hintText: "Provide detailed description of what the student did...\n\nInclude:\n• What exactly happened?\n• When did it occur?\n• Where did it happen?\n• Were there any witnesses?",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 100.0),
                    child: Icon(Icons.description, color: Colors.red.shade600),
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
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            "Reporting Guidelines",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "• Be honest and accurate in your report\n"
                        "• Only report actual violations you witnessed\n"
                        "• Provide as much detail as possible\n"
                        "• Include names of witnesses if any\n"
                        "• Do not make false accusations\n"
                        "• Your identity as the reporter will be kept confidential\n"
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
                    backgroundColor: Colors.red.shade700,
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
    _reportedStudentController.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  
  // Student-specific controllers
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController guardianNameController = TextEditingController();
  final TextEditingController guardianContactController = TextEditingController();
  
  // Teacher-specific controllers
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController advisingSectionController = TextEditingController();
  final TextEditingController employeeIdController = TextEditingController();
  final TextEditingController specializationController = TextEditingController();

  String selectedRole = "student";
  String? selectedGradeLevel;
  String? selectedAdvisingGrade;
  String? selectedStrand;
  String selectedSection = "";
  String? selectedSchoolYear;
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool isAdviser = false;

  final List<String> grades = ['7', '8', '9', '10', '11', '12'];
  
  // Regular sections for grades 7-10
  final Map<String, List<String>> gradeSections = {
    '7': ['Newton', 'Armstrong', 'Moseley', 'Boyle', 'Edison', 'Marconi', 'Locke', 'Morse', 'Kepler', 'Roentgen', 'Einstein', 'Ford', 'Faraday'],
    '8': ['Pasteur', 'Aristotle', 'Cooper', 'Mendel', 'Darwin', 'Harvey', 'Davis', 'Linnaeus', 'Brown', 'Fleming', 'Hooke'],
    '9': ['Dalton', 'Calvin', 'Lewis', 'Bunsen', 'Maxwell', 'Curie', 'Garnett', 'Perkins', 'Bosch', 'Meyer'],
    '10': ['Galileo', 'Rutherford', 'Thompson', 'Ampere', 'Volta', 'Siemens', 'Archimedes', 'Chadwick', 'Pascal', 'Hamilton', 'Franklin', 'Anderson'],
  };

  // Strands for Grade 11 and 12
  final Map<String, List<String>> gradeStrands = {
    '11': ['STEM', 'PBM', 'ABM', 'HUMSS', 'HOME ECONOMICS', 'HOME ECONOMICS/ICT', 'ICT', 'EIM-SMAW', 'SMAW'],
    '12': ['SMAW', 'EIM', 'ICT', 'HE', 'HUMSS', 'ABM', 'PBM', 'STEM'],
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

  bool get hasStrands => selectedGradeLevel == '11' || selectedGradeLevel == '12';

  List<String> get availableStrands {
    if (selectedGradeLevel == null || !hasStrands) return [];
    return gradeStrands[selectedGradeLevel!] ?? [];
  }

  List<String> get availableSections {
    if (selectedGradeLevel == null) return [];
    
    if (hasStrands && selectedStrand != null) {
      return strandSections[selectedGradeLevel!]?[selectedStrand!] ?? [];
    }
    
    return gradeSections[selectedGradeLevel!] ?? [];
  }

  List<String> get availableAdvisingSections {
    if (selectedAdvisingGrade == null) return [];
    
    if (selectedAdvisingGrade == '11' || selectedAdvisingGrade == '12') {
      List<String> allSections = [];
      final strandsForGrade = gradeStrands[selectedAdvisingGrade!] ?? [];
      for (String strand in strandsForGrade) {
        final sectionsForStrand = strandSections[selectedAdvisingGrade!]?[strand] ?? [];
        allSections.addAll(sectionsForStrand);
      }
      return allSections;
    }
    
    return gradeSections[selectedAdvisingGrade!] ?? [];
  }

  List<String> get availableSchoolYears {
  final currentYear = DateTime.now().year;
  final month = DateTime.now().month;
  
  // School year starts in June (month 6)
  int startYear = month >= 6 ? currentYear : currentYear - 1;
  
  // Generate current and next 2 school years
  List<String> years = [];
  for (int i = 0; i < 3; i++) {
    final year = startYear + i;
    years.add('$year-${year + 1}');
  }
  
  return years;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Icon(Icons.person_add, size: 80, color: Colors.blue.shade700),
              const SizedBox(height: 16),
              Text(
                "Create Account",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
              ),
              const SizedBox(height: 32),

              // Role Selection - ✅ Only Student and Teacher
              const Text("Select Role *", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.work_outline),
                ),
                items: const [
                  DropdownMenuItem(value: "student", child: Text("Student")),
                  DropdownMenuItem(value: "teacher", child: Text("Teacher")),
                  // ✅ REMOVED: Counselor option
                ],
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                    selectedGradeLevel = null;
                    selectedAdvisingGrade = null;
                    selectedStrand = null;
                    selectedSection = "";
                    isAdviser = false;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Basic Information
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: firstNameController,
                      decoration: InputDecoration(
                        labelText: "First Name*",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (value) => value?.trim().isEmpty == true ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: lastNameController,
                      decoration: InputDecoration(
                        labelText: "Last Name *",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      validator: (value) => value?.trim().isEmpty == true ? "Required" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: "Username *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.account_circle),
                ),
                validator: (value) => value?.trim().isEmpty == true ? "Username is required" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email),
                ),
                validator: (value) {
                  if (value?.trim().isEmpty == true) return "Email is required";
                  if (!value!.contains('@')) return "Enter a valid email";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password fields
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscurePassword = !obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty == true) return "Password is required";
                  if (value!.length < 6) return "Password must be at least 6 characters";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: "Confirm Password *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                  ),
                ),
                validator: (value) {
                  if (value != passwordController.text) return "Passwords do not match";
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Role-specific fields
              if (selectedRole == "student") ..._buildStudentFields(),
              if (selectedRole == "teacher") ..._buildTeacherFields(),
              // ✅ REMOVED: counselor fields

              const SizedBox(height: 32),

              // Register Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Register", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),

              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text("Login here", style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStudentFields() {
  return [
    const Text("Student Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
    const SizedBox(height: 16),
    
    // ✅ NEW: School Year Dropdown
    DropdownButtonFormField<String>(
      value: selectedSchoolYear,
      decoration: InputDecoration(
        labelText: "School Year *",
        hintText: "Select academic year",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.calendar_today),
        helperText: "Current enrollment year",
      ),
      items: availableSchoolYears.map((year) => DropdownMenuItem(
        value: year,
        child: Text(year),
      )).toList(),
      onChanged: (value) => setState(() => selectedSchoolYear = value),
      validator: (value) => value == null ? "School year is required" : null,
    ),
    const SizedBox(height: 16),
    
    DropdownButtonFormField<String>(
      value: selectedGradeLevel,
      decoration: InputDecoration(
        labelText: "Grade Level *",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.school),
      ),
      items: grades.map((grade) => DropdownMenuItem(value: grade, child: Text("Grade $grade"))).toList(),
      onChanged: (value) => setState(() {
        selectedGradeLevel = value;
        selectedStrand = null;
        selectedSection = "";
      }),
      validator: (value) => value == null ? "Required" : null,
    ),
    const SizedBox(height: 16),

    if (hasStrands) ...[
      DropdownButtonFormField<String>(
        value: selectedStrand,
        decoration: InputDecoration(
          labelText: "Strand *",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.category),
        ),
        items: availableStrands.map((strand) => DropdownMenuItem(value: strand, child: Text(strand))).toList(),
        onChanged: (value) => setState(() {
          selectedStrand = value;
          selectedSection = "";
        }),
        validator: (value) => hasStrands && value == null ? "Required" : null,
      ),
      const SizedBox(height: 16),
    ],

    DropdownButtonFormField<String>(
      value: selectedSection.isEmpty ? null : selectedSection,
      decoration: InputDecoration(
        labelText: "Section *",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.class_),
      ),
      items: availableSections.map((section) => DropdownMenuItem(value: section, child: Text(section))).toList(),
      onChanged: (value) => setState(() => selectedSection = value ?? ""),
      validator: (value) => value == null ? "Required" : null,
    ),
    const SizedBox(height: 16),

    TextFormField(
      controller: contactNumberController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: "Contact Number",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.phone),
      ),
    ),
    const SizedBox(height: 16),

    TextFormField(
      controller: guardianNameController,
      decoration: InputDecoration(
        labelText: "Guardian Name",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.family_restroom),
      ),
    ),
    const SizedBox(height: 16),

    TextFormField(
      controller: guardianContactController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: "Guardian Contact",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.contact_phone),
      ),
    ),
    const SizedBox(height: 16),
  ];
}

  List<Widget> _buildTeacherFields() {
    return [
      const Text("Teacher Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
      const SizedBox(height: 16),

      TextFormField(
        controller: employeeIdController,
        decoration: InputDecoration(
          labelText: "Employee ID *",
          hintText: "e.g., T-2024-001",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.badge),
        ),
        validator: (value) {
          if (value?.trim().isEmpty == true) return "Employee ID is required";
          return null;
        },
      ),
      const SizedBox(height: 16),

      TextFormField(
        controller: departmentController,
        decoration: InputDecoration(
          labelText: "Department *",
          hintText: "e.g., Mathematics, Science, English",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.business),
        ),
        validator: (value) {
          if (value?.trim().isEmpty == true) return "Department is required";
          return null;
        },
      ),
      const SizedBox(height: 16),

      TextFormField(
        controller: specializationController,
        decoration: InputDecoration(
          labelText: "Specialization (Optional)",
          hintText: "e.g., Algebra, Physics, Literature",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          prefixIcon: const Icon(Icons.school_outlined),
        ),
      ),
      const SizedBox(height: 24),

      Divider(thickness: 1, color: Colors.grey.shade300),
      const SizedBox(height: 16),

      CheckboxListTile(
        title: const Text("I am a class adviser", style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text("Optional: Check if you handle an advisory class"),
        value: isAdviser,
        onChanged: (value) {
          setState(() {
            isAdviser = value ?? false;
            if (!isAdviser) {
              selectedAdvisingGrade = null;
              advisingSectionController.clear();
            }
          });
        },
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: Colors.blue.shade700,
      ),

      if (isAdviser) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Advisory Class Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedAdvisingGrade,
                      decoration: InputDecoration(
                        labelText: "Advising Grade *",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.school),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: grades.map((grade) => DropdownMenuItem(
                        value: grade,
                        child: Text("Grade $grade"),
                      )).toList(),
                      onChanged: (value) => setState(() {
                        selectedAdvisingGrade = value;
                        advisingSectionController.clear();
                      }),
                      validator: (value) => isAdviser && value == null ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: advisingSectionController.text.isEmpty ? null : advisingSectionController.text,
                      decoration: InputDecoration(
                        labelText: "Section *",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.class_),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: availableAdvisingSections.map((section) => DropdownMenuItem(
                        value: section,
                        child: Text(section),
                      )).toList(),
                      onChanged: (value) => setState(() => advisingSectionController.text = value ?? ""),
                      validator: (value) => isAdviser && value == null ? "Required" : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    ];
  }

  // ✅ REMOVED: _buildCounselorFields() method

  Future<void> registerUser() async {
  if (!_formKey.currentState!.validate()) return;

  final serverIp = dotenv.env['SERVER_IP'];
  if (serverIp == null || serverIp.isEmpty) {
    _showErrorSnackBar("Server IP not configured");
    return;
  }

  setState(() => isLoading = true);

  try {
    String baseUrl = serverIp;
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'http://$baseUrl';
    }

    final url = Uri.parse("$baseUrl/api/register/");
    debugPrint("🌐 Attempting registration to: $url");

    final Map<String, dynamic> requestData = {
      "username": usernameController.text.trim(),
      "password": passwordController.text.trim(),
      "role": selectedRole,
      "first_name": firstNameController.text.trim(),
      "last_name": lastNameController.text.trim(),
      "email": emailController.text.trim(),
    };

    if (selectedRole == "student") {
      requestData.addAll({
        "school_year": selectedSchoolYear, // ✅ Added school year
        "grade_level": selectedGradeLevel,
        "strand": hasStrands ? selectedStrand : null,
        "section": selectedSection,
        "contact_number": contactNumberController.text.trim(),
        "guardian_name": guardianNameController.text.trim(),
        "guardian_contact": guardianContactController.text.trim(),
      });
    } else if (selectedRole == "teacher") {
      requestData.addAll({
        "employee_id": employeeIdController.text.trim(),
        "department": departmentController.text.trim(),
        "specialization": specializationController.text.trim(),
        "advising_grade": isAdviser ? selectedAdvisingGrade : null,
        "advising_section": isAdviser ? advisingSectionController.text.trim() : null,
      });
    }

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(requestData),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 201 && data['success'] == true) {
      if (mounted) {
        if (selectedRole == "teacher" && data['approval_status'] == 'pending') {
          _showTeacherPendingDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? "Registration successful!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } else {
      _showErrorSnackBar(data['error'] ?? "Registration failed");
    }
  } catch (e) {
    debugPrint("❌ Registration error: $e");
    _showErrorSnackBar("Network error: $e");
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}

  void _showTeacherPendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.pending_actions, color: Colors.orange, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('Registration Submitted')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your teacher account has been created successfully!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
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
                        Icon(Icons.info, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pending Admin Approval',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('⏳ Your account is awaiting approval from the school administrator.', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 4),
                    Text('✅ You will receive a notification once your account is approved.', style: TextStyle(fontSize: 13)),
                    SizedBox(height: 4),
                    Text('📧 Check your notifications regularly for updates.', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text('What happens next?', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              _buildStep('1', 'Admin receives your registration request'),
              _buildStep('2', 'Admin reviews your information'),
              _buildStep('3', 'You get notified of approval/rejection'),
              _buildStep('4', 'Once approved, you can login and access the Teacher Dashboard'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Understood', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(number, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
            ),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    contactNumberController.dispose();
    guardianNameController.dispose();
    guardianContactController.dispose();
    departmentController.dispose();
    advisingSectionController.dispose();
    employeeIdController.dispose();
    specializationController.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

// Routes
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/counselor_provider.dart';
import '../../providers/teacher_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;
  late final String? serverIp;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    serverIp = dotenv.env['SERVER_IP'];
    debugPrint("🌐 Loaded SERVER_IP: $serverIp");

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Helper function to safely convert dynamic map to Map<String, dynamic>
  Map<String, dynamic> _safeCastToStringMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    } else if (data is Map) {
      return Map<String, dynamic>.from(data);
    } else {
      throw Exception("Invalid data format: expected Map but got ${data.runtimeType}");
    }
  }

  Future<void> loginUser() async {
    if (serverIp == null || serverIp!.isEmpty) {
      _showErrorSnackBar("Server IP not configured");
      return;
    }

    setState(() => isLoading = true);

    try {
      String baseUrl = serverIp!;
      if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
        baseUrl = 'http://$baseUrl';
      }
      
      final url = Uri.parse("$baseUrl/api/login/");
      debugPrint("🌐 Attempting login to: $url");
      
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": usernameController.text.trim(),
          "password": passwordController.text.trim(),
        }),
      );

      debugPrint("📩 Status Code: ${response.statusCode}");
      debugPrint("📩 Raw Response: ${response.body}");
      
      // ✅ Handle 403 - Teacher approval status
      if (response.statusCode == 403) {
        setState(() => isLoading = false);
        
        try {
          final decoded = jsonDecode(response.body);
          final Map<String, dynamic> data = _safeCastToStringMap(decoded);
          final approvalStatus = data['approval_status'];
          
          if (approvalStatus == 'pending') {
            _showPendingApprovalDialog();
          } else if (approvalStatus == 'rejected') {
            _showRejectedDialog();
          } else {
            _showErrorSnackBar(data['error']?.toString() ?? 'Access denied');
          }
        } catch (e) {
          _showErrorSnackBar('Access denied');
        }
        return;
      }
      
      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          debugPrint("🔍 Decoded type: ${decoded.runtimeType}");
          debugPrint("🔍 Decoded data: $decoded");

          final Map<String, dynamic> data = _safeCastToStringMap(decoded);

          if (data["success"] == true) {
            final token = data["token"]?.toString();
            final userMap = data["user"];
            final username = usernameController.text.trim();

            String? role;
            if (userMap != null && userMap is Map) {
              role = userMap["role"]?.toString();
            }

            if (token == null || role == null) {
              setState(() => isLoading = false);
              debugPrint("❌ Missing data - Token: $token, Role: $role");
              _showErrorSnackBar("Invalid response: missing token or role");
              return;
            }

            debugPrint("✅ TOKEN: $token");
            debugPrint("✅ ROLE: $role");
            debugPrint("✅ USERNAME: $username");

            try {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              debugPrint("🔧 Setting auth provider...");
              await authProvider.login(token, username, role, context);

              if (role == "student") {
                debugPrint("🔧 Setting student provider...");
                final studentProvider = Provider.of<StudentProvider>(context, listen: false);
                studentProvider.setToken(token);
              } else if (role == "counselor") {
                debugPrint("🔧 Setting counselor provider...");
                final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
                counselorProvider.setToken(token);
              } else if (role == "teacher") {
                debugPrint("🔧 Setting teacher provider...");
                final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
                teacherProvider.setToken(token);
              }

              debugPrint("✅ All providers set successfully");
              
              setState(() => isLoading = false);
              _showSuccessSnackBar(data["message"]?.toString() ?? "Welcome back, $username!");

              await Future.delayed(const Duration(milliseconds: 500));

              try {
                if (role == "student") {
                  debugPrint("🚀 Navigating to student dashboard...");
                  Navigator.pushReplacementNamed(context, AppRoutes.studentDashboard);
                } else if (role == "teacher") {
                  debugPrint("🚀 Navigating to teacher dashboard...");
                  Navigator.pushReplacementNamed(
                    context, 
                    AppRoutes.teacherDashboard,
                    arguments: {
                      'username': username,
                      'role': role,
                    },
                  );
                } else if (role == "counselor") {
                  debugPrint("🚀 Navigating to counselor dashboard...");
                  Navigator.pushReplacementNamed(
                    context, 
                    AppRoutes.counselorDashboard,
                    arguments: {
                      'username': username,
                      'role': role,
                    },
                  );
                } else {
                  debugPrint("❌ Unknown role: $role");
                  _showErrorSnackBar("Unknown user role: $role");
                }
                debugPrint("✅ Navigation completed");
              } catch (navigationError) {
                debugPrint("❌ Navigation error: $navigationError");
                _showErrorSnackBar("Navigation error: $navigationError");
              }

            } catch (providerError) {
              setState(() => isLoading = false);
              debugPrint("❌ Provider error: $providerError");
              _showErrorSnackBar("Provider setup error: $providerError");
            }

          } else {
            setState(() => isLoading = false);
            _showErrorSnackBar(data['error']?.toString() ?? 'Login failed');
          }
          
        } catch (parseError) {
          setState(() => isLoading = false);
          debugPrint("❌ JSON parsing error: $parseError");
          _showErrorSnackBar("Response parsing error. Please try again.");
        }
        
      } else {
        setState(() => isLoading = false);
        try {
          final decoded = jsonDecode(response.body);
          final Map<String, dynamic> errorData = _safeCastToStringMap(decoded);
          final errorMessage = errorData['error']?.toString() ?? 
                              errorData['detail']?.toString() ?? 
                              'Login failed';
          _showErrorSnackBar(errorMessage);
        } catch (e) {
          debugPrint("❌ Error parsing error response: $e");
          _showErrorSnackBar("Login failed (${response.statusCode})");
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("❌ Network error: $e");
      
      String errorMessage = "Network error: Please check your connection";
      if (e.toString().contains("type '_Map<dynamic, dynamic>' is not a subtype")) {
        errorMessage = "Server response format error. Please try again.";
      }
      
      _showErrorSnackBar(errorMessage);
    }
  }

  // ✅ NEW: Show pending approval dialog
  void _showPendingApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.pending_actions, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Account Pending Approval')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.hourglass_empty, size: 56, color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      'Your teacher account is awaiting admin approval.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'You will receive a notification once your account is approved. Please check back later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Contact the school administrator if you have any questions.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
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
            child: Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: Show rejected dialog
  void _showRejectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cancel, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Account Rejected')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200, width: 2),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 56, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Your teacher account application has been rejected.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red.shade900,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Please contact the school administrator for more information about the rejection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.contact_support, color: Colors.amber.shade900, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You may reapply or contact administration for clarification.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
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
            child: Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFFE53E3E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFF38A169),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: screenWidth > 400 ? 400 : screenWidth * 0.9,
                    ),
                    child: Card(
                      elevation: 20,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Logo and Title
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF667eea).withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.school,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                "Welcome Back!",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3748),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Sign in to your account",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Username Field
                              TextFormField(
                                controller: usernameController,
                                decoration: InputDecoration(
                                  labelText: "Username",
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF7FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty ? "Enter username" : null,
                              ),
                              const SizedBox(height: 20),

                              // Password Field
                              TextFormField(
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF7FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty ? "Enter password" : null,
                              ),
                              const SizedBox(height: 16),

                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, AppRoutes.forgotPassword);
                                  },
                                  child: const Text(
                                    "Forgot Password?",
                                    style: TextStyle(color: Color(0xFF667eea)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Login Button
                              isLoading
                                  ? Container(
                                      width: double.infinity,
                                      height: 54,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: double.infinity,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF667eea).withOpacity(0.3),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (_formKey.currentState!.validate()) {
                                            loginUser();
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          "Sign In",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                              const SizedBox(height: 24),

                              // Divider
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey[300])),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      "OR",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Colors.grey[300])),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Register Button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, AppRoutes.register);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF667eea), width: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    "Create an Account",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF667eea),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
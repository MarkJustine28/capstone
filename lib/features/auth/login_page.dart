import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// ❌ REMOVE: import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_breakpoints.dart';
import '../../config/env.dart'; // ✅ ADD: Import your Env class

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
    
    // ✅ FIXED: Use Env class instead of dotenv directly
    final serverIpValue = Env.serverIp;
    serverIp = serverIpValue;
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
    
    // ✅ NEW: Handle 429 - Account locked
    if (response.statusCode == 429) {
      setState(() => isLoading = false);
      
      try {
        final decoded = jsonDecode(response.body);
        final Map<String, dynamic> data = _safeCastToStringMap(decoded);
        _showAccountLockedDialog(data);
      } catch (e) {
        _showErrorSnackBar('Account temporarily locked due to too many failed attempts');
      }
      return;
    }
    
    // ✅ Handle 403 - Teacher approval status (existing code)
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
    
    // ✅ Handle 401 - Invalid credentials with attempt warning
    if (response.statusCode == 401) {
      setState(() => isLoading = false);
      
      try {
        final decoded = jsonDecode(response.body);
        final Map<String, dynamic> data = _safeCastToStringMap(decoded);
        
        final errorMessage = data['error']?.toString() ?? 'Invalid credentials';
        final failedAttempts = data['failed_attempts'] ?? 0;
        final remainingAttempts = data['remaining_attempts'] ?? 0;
        
        // Show warning if close to lockout
        if (remainingAttempts > 0 && remainingAttempts <= 2) {
          _showErrorSnackBar(
            '$errorMessage\n⚠️ Warning: $remainingAttempts attempt(s) remaining before lockout',
          );
        } else {
          _showErrorSnackBar(errorMessage);
        }
      } catch (e) {
        _showErrorSnackBar('Invalid credentials');
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
            int? userId;
            String? firstName;
            String? lastName;
            
            if (userMap != null && userMap is Map) {
              role = userMap["role"]?.toString();
              userId = userMap["id"] as int?;
              firstName = userMap["first_name"]?.toString().trim();
              lastName = userMap["last_name"]?.toString().trim();
            }

            if (token == null || role == null || userId == null) {
              setState(() => isLoading = false);
              debugPrint("❌ Missing data - Token: $token, Role: $role, UserId: $userId");
              _showErrorSnackBar("Invalid response: missing required data");
              return;
            }

            debugPrint("✅ TOKEN: $token");
            debugPrint("✅ ROLE: $role");
            debugPrint("✅ USERNAME: $username");
            debugPrint("✅ USER_ID: $userId");
            debugPrint("✅ FIRST_NAME: ${firstName ?? '(none)'}");
            debugPrint("✅ LAST_NAME: ${lastName ?? '(none)'}");

            try {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              debugPrint("🔧 Setting auth provider...");
              
              await authProvider.login(
                token: token,
                username: username,
                role: role,
                userId: userId,
                firstName: firstName?.isNotEmpty == true ? firstName : null,
                lastName: lastName?.isNotEmpty == true ? lastName : null,
                email: userMap["email"]?.toString(), // ✅ ADD THIS
                password: passwordController.text.trim(),
              );

              debugPrint("✅ AuthProvider login completed");
              debugPrint("   Display Name: ${authProvider.displayName}");

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
              _showSuccessSnackBar(data["message"]?.toString() ?? "Welcome back, ${authProvider.displayName}!");

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

  void _showPendingApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  void _showRejectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  void _showAccountLockedDialog(Map<String, dynamic> data) {
  final failedAttempts = data['failed_attempts'] ?? 5;
  final remainingMinutes = data['lockout_minutes_remaining'] ?? 30;
  final message = data['message'] ?? 'Your account is temporarily locked due to too many failed login attempts.';

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.lock_clock, color: Colors.red.shade700, size: 28),
          SizedBox(width: 12),
          Expanded(child: Text('Account Locked', style: TextStyle(color: Colors.red.shade700))),
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
                  Icon(Icons.warning_amber_rounded, size: 56, color: Colors.red.shade700),
                  SizedBox(height: 16),
                  Text(
                    'Too Many Failed Attempts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.red.shade900,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '$failedAttempts failed attempts detected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer, color: Colors.orange.shade700, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Locked for $remainingMinutes more minute(s)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'What you can do:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text('• Wait $remainingMinutes minutes before trying again', style: TextStyle(fontSize: 13)),
                  Text('• Make sure you\'re using the correct credentials', style: TextStyle(fontSize: 13)),
                  Text('• Use "Forgot Password" if you can\'t remember your password', style: TextStyle(fontSize: 13)),
                  Text('• Contact the administrator if you need immediate access', style: TextStyle(fontSize: 13)),
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

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = AppBreakpoints.isDesktop(screenWidth);
    final isTablet = AppBreakpoints.isTablet(screenWidth);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black26, BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppBreakpoints.getPadding(screenWidth)),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1200 : (isTablet ? 900 : screenWidth * 0.9),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left side - Welcome section (Desktop & Tablet only)
                        if (isDesktop || isTablet)
                          Expanded(
                            flex: isDesktop ? 5 : 4,
                            child: Padding(
                              padding: EdgeInsets.only(right: isDesktop ? 48 : 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [                                  
                                  // Title
                                  Text(
                                    'Welcome to\nInciTrack',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 48 : 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.2,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: isDesktop ? 20 : 16),
                                  
                                  // Subtitle
                                  Text(
                                    'Empowering educators and students with comprehensive guidance management',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 18 : 16,
                                      color: Colors.white.withOpacity(0.9),
                                      height: 1.6,
                                    ),
                                  ),
                                  SizedBox(height: isDesktop ? 40 : 32),
                                  
                                  // Features
                                  _buildFeatureItem(Icons.analytics_outlined, 'Real-time Analytics & Insights'),
                                  const SizedBox(height: 20),
                                  _buildFeatureItem(Icons.security_outlined, 'Secure Data Management'),
                                  const SizedBox(height: 20),
                                  _buildFeatureItem(Icons.people_outline, 'Multi-role Support'),
                                  const SizedBox(height: 20),
                                  _buildFeatureItem(Icons.notifications_active_outlined, 'Instant Notifications'),
                                  
                                  if (isDesktop) ...[
                                    SizedBox(height: 40),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline, color: Colors.white, size: 20),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Sign in with your valid credentials',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white.withOpacity(0.95),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                        // Right side - Login form
                        Flexible(
                          flex: isDesktop ? 4 : (isTablet ? 5 : 1),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: isDesktop ? 480 : 400,
                            ),
                            child: Card(
                              color: Colors.white.withOpacity(0.7),
                              elevation: 24,
                              shadowColor: Colors.black.withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(isDesktop ? 48.0 : (isTablet ? 40.0 : 32.0)),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Title
                                      Text(
                                        "Welcome Back!",
                                        style: TextStyle(
                                          fontSize: isDesktop ? 32 : 28,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2D3748),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Sign in to continue",
                                        style: TextStyle(
                                          fontSize: isDesktop ? 18 : 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: isDesktop ? 40 : 32),

                                      // Username Field
                                      TextFormField(
                                        controller: usernameController,
                                        decoration: InputDecoration(
                                          labelText: "Username",
                                          hintText: "Enter your username",
                                          prefixIcon: const Icon(Icons.person_outline),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFF7FAFC),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: isDesktop ? 20 : 16,
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null || value.isEmpty ? "Enter your username" : null,
                                      ),
                                      const SizedBox(height: 20),

                                      // Password Field
                                      TextFormField(
                                        controller: passwordController,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          labelText: "Password",
                                          hintText: "Enter your password",
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
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: isDesktop ? 20 : 16,
                                          ),
                                        ),
                                        validator: (value) =>
                                            value == null || value.isEmpty ? "Enter your password" : null,
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
                                            style: TextStyle(
                                              color: Color.fromARGB(255, 58, 58, 58),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: isDesktop ? 32 : 24),

                                      // Login Button
                                      isLoading
                                          ? Container(
                                              width: double.infinity,
                                              height: isDesktop ? 58 : 54,
                                              child: const Center(
                                                child: CircularProgressIndicator(
                                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: double.infinity,
                                              height: isDesktop ? 58 : 54,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF667eea).withOpacity(0.4),
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
                                                child: Text(
                                                  "Sign In",
                                                  style: TextStyle(
                                                    fontSize: isDesktop ? 18 : 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                      SizedBox(height: isDesktop ? 32 : 24),

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
                                      SizedBox(height: isDesktop ? 32 : 24),

                                      // Register Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: isDesktop ? 58 : 54,
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
                                          child: Text(
                                            "Create an Account",
                                            style: TextStyle(
                                              fontSize: isDesktop ? 18 : 16,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF667eea),
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
                      ],
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
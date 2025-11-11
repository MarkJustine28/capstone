import 'package:flutter/material.dart';

// Auth
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/forgot_password_page.dart';

// Student
import '../features/student/pages/dashboard_page.dart' as student;
import '../features/student/pages/records_page.dart';
import '../features/student/pages/incident_report_page.dart';
import '../features/student/pages/notifications_page.dart';
import '../features/student/pages/settings_page.dart';

// Teacher
import '../features/teacher/pages/dashboard_page.dart';
import '../features/teacher/pages/student_list_page.dart';
import '../features/teacher/pages/submit_report_page.dart';

// Counselor
import '../features/counselor/pages/dashboard_page.dart';
import '../features/counselor/pages/student_report_page.dart';
import '../features/counselor/pages/teacher_reports_page.dart';
import '../features/counselor/pages/counseling_session_page.dart';
import '../features/counselor/pages/settings_page.dart'; // ✅ NEW: Import counselor settings

class AppRoutes {
  // Authentication
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Dashboards
  static const String studentDashboard = '/student-dashboard';
  static const String teacherDashboard = '/teacher-dashboard';
  static const String counselorDashboard = '/counselor-dashboard';

  // Student extra pages
  static const String myReports = '/my-reports';
  static const String submitReport = '/student-submit-report';
  static const String notifications = '/notifications';
  static const String settings = '/settings';

  // Teacher extra pages
  static const String studentList = '/teacher-student-list';
  static const String teacherSubmitReport = '/teacher-submit-report';

  // Counselor extra pages
  static const String counselorStudentReports = '/counselor-student-reports';
  static const String counselorTeacherReports = '/counselor-teacher-reports';
  static const String counselorAppointments = '/counselor-appointments';
  static const String counselorSettings = '/counselor-settings'; // ✅ ADDED: Counselor settings route

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Extract arguments if provided
    final args = settings.arguments as Map<String, dynamic>?;

    switch (settings.name) {
      // Login
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      // Register
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());

      // Forgot Password
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordPage());

      // Student Dashboard
      case studentDashboard:
        return MaterialPageRoute(
          builder: (_) => const student.StudentDashboardPage(),
        );

      // Student extra pages
      case myReports:
        return MaterialPageRoute(builder: (_) => const ViewRecordsPage());
      case submitReport:
        return MaterialPageRoute(builder: (_) => const SubmitIncidentPage());
      case notifications:
        return MaterialPageRoute(
            builder: (_) => const StudentNotificationsPage());
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());

      // Teacher Dashboard - No parameters needed (uses AuthProvider)
      case teacherDashboard:
        return MaterialPageRoute(
          builder: (_) => const TeacherDashboardPage(),
        );

      // Teacher extra pages
      case studentList:
        return MaterialPageRoute(builder: (_) => const StudentListPage());
      case teacherSubmitReport:
        return MaterialPageRoute(builder: (_) => const SubmitReportPage());

      // Counselor Dashboard - FIXED: Pass username and role parameters
      case counselorDashboard:
        return MaterialPageRoute(
          builder: (_) => CounselorDashboardPage(
            username: args?['username'] ?? 'Counselor',
            role: args?['role'] ?? 'counselor',
          ),
        );

      // Counselor extra pages
      case counselorStudentReports:
        return MaterialPageRoute(builder: (_) => const StudentReportPage());
      case counselorTeacherReports:
        return MaterialPageRoute(builder: (_) => const TeacherReportsPage());
      case counselorAppointments:
        return MaterialPageRoute(
            builder: (_) => const CounselingSessionPage());
      
      // ✅ NEW: Counselor Settings Route
      case counselorSettings:
        return MaterialPageRoute(builder: (_) => const CounselorSettingsPage());

      // Fallback
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}

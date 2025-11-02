import 'package:flutter/material.dart';

// Auth
import 'features/auth/login_page.dart';

// Student
import 'features/student/pages/dashboard_page.dart' as student;

// Teacher
import 'features/teacher/pages/dashboard_page.dart';
import 'features/teacher/pages/student_list_page.dart';
import 'features/teacher/pages/submit_report_page.dart';

// Counselor
import 'features/counselor/pages/dashboard_page.dart';
import 'features/counselor/pages/student_report_page.dart';
import 'features/counselor/pages/teacher_reports_page.dart';
import 'features/counselor/pages/counseling_session_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Records & Incident Management',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/login',

      // Named routes
      routes: {
        // Authentication
        '/login': (context) => const LoginPage(),

        // Student routes
        '/student-dashboard': (context) => const student.StudentDashboardPage(),

        // Teacher routes
        '/teacher-dashboard': (context) => const TeacherDashboardPage(),
        '/teacher-student-list': (context) => const StudentListPage(),
        '/teacher-submit-report': (context) => const SubmitReportPage(),
        '/teacher/submit-report': (context) => const SubmitReportPage(),

        // Counselor routes
        '/counselor-dashboard': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return CounselorDashboardPage(
            username: args?['username'] ?? 'Counselor',
            role: args?['role'] ?? 'counselor',
          );
        },
        
        // FIXED: Counselor sub-pages without username/role parameters
        '/counselor-student-reports': (context) => const StudentReportPage(),
        '/counselor-teacher-reports': (context) => const TeacherReportsPage(),
        '/counselor-appointments': (context) => const CounselingSessionPage(),

        // TODO: Add admin routes later
      },
    );
  }
}

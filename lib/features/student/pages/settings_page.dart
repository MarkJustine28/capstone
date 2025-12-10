import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../providers/auth_provider.dart';
import '../../../providers/student_provider.dart';
import '../../../config/routes.dart';
import '../../../config/env.dart'; // ✅ Use existing Env class

class StudentSettingsPage extends StatefulWidget {
  const StudentSettingsPage({super.key});

  @override
  State<StudentSettingsPage> createState() => _StudentSettingsPageState();
}

class _StudentSettingsPageState extends State<StudentSettingsPage> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
  }

  Future<void> _loadStudentInfo() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);

    if (authProvider.token != null) {
      setState(() => _isLoading = true);
      await studentProvider.fetchStudentInfo(authProvider.token!);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final studentProvider = Provider.of<StudentProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudentInfo,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStudentInfo,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSchoolYearSection(studentProvider),
                  const SizedBox(height: 16),
                  _buildProfileSection(context, authProvider, studentProvider),
                  const SizedBox(height: 16),
                  _buildAccountSection(context, authProvider),
                  const SizedBox(height: 16),
                  _buildAppSection(context),
                  const SizedBox(height: 24),
                  _buildLogoutButton(context, authProvider),
                ],
              ),
            ),
    );
  }

  Widget _buildSchoolYearSection(StudentProvider provider) {
    final schoolYear = provider.currentSchoolYear;
    final grade = provider.gradeLevel;
    final section = provider.section;
    final strand = provider.studentInfo?['strand'] as String?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF4CAF50),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Academic Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.school, color: Color(0xFF4CAF50)),
            title: const Text('School Year'),
            subtitle: Text(schoolYear),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isCurrentSchoolYear(schoolYear)
                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isCurrentSchoolYear(schoolYear) ? 'Current' : 'Historical',
                style: TextStyle(
                  fontSize: 11,
                  color: _isCurrentSchoolYear(schoolYear)
                      ? const Color(0xFF4CAF50)
                      : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.grade, color: Color(0xFF4CAF50)),
            title: const Text('Grade Level'),
            subtitle: Text(grade != 'N/A' ? 'Grade $grade' : 'Not Set'),
          ),
          if (strand != null && strand.isNotEmpty && (grade == '11' || grade == '12'))
            ListTile(
              leading: const Icon(Icons.category, color: Color(0xFF4CAF50)),
              title: const Text('Strand'),
              subtitle: Text(strand),
            ),
          ListTile(
            leading: const Icon(Icons.group, color: Color(0xFF4CAF50)),
            title: const Text('Section'),
            subtitle: Text(section != 'N/A' ? section : 'Not Set'),
          ),
        ],
      ),
    );
  }

  bool _isCurrentSchoolYear(String schoolYear) {
    if (schoolYear == 'N/A') return false;
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final currentSY = month >= 6 ? '$year-${year + 1}' : '${year - 1}-$year';
    return schoolYear == currentSY;
  }

  Widget _buildProfileSection(
    BuildContext context,
    AuthProvider authProvider,
    StudentProvider studentProvider,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                authProvider.firstNameOrUsername.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            title: Text(
              authProvider.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(authProvider.username ?? 'N/A'),
            trailing: const Icon(Icons.edit, size: 20),
            onTap: () => _showEditProfileDialog(context, authProvider, studentProvider),
          ),
          if (studentProvider.studentInfo != null && studentProvider.studentInfo!['lrn'] != null)
            ListTile(
              leading: const Icon(Icons.badge, color: Colors.blue),
              title: const Text('LRN'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentProvider.studentInfo?['lrn']?.toString() ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  const Text(
                    'Learner Reference Number',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          if (studentProvider.studentInfo?['contact_number'] != null &&
              (studentProvider.studentInfo!['contact_number'] as String).isNotEmpty)
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.blue),
              title: const Text('Contact Number'),
              subtitle: Text(studentProvider.studentInfo?['contact_number'] ?? 'N/A'),
            ),
          if (studentProvider.studentInfo?['guardian_name'] != null &&
              (studentProvider.studentInfo!['guardian_name'] as String).isNotEmpty)
            ListTile(
              leading: const Icon(Icons.family_restroom, color: Colors.blue),
              title: const Text('Guardian'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(studentProvider.studentInfo?['guardian_name'] ?? 'N/A'),
                  if (studentProvider.studentInfo?['guardian_contact'] != null &&
                      (studentProvider.studentInfo!['guardian_contact'] as String).isNotEmpty)
                    Text(
                      'Contact: ${studentProvider.studentInfo?['guardian_contact']}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    AuthProvider authProvider,
    StudentProvider studentProvider,
  ) {
    final firstNameController = TextEditingController(text: authProvider.firstName ?? '');
    final lastNameController = TextEditingController(text: authProvider.lastName ?? '');
    final contactController = TextEditingController(
      text: studentProvider.studentInfo?['contact_number'] ?? '',
    );
    final guardianNameController = TextEditingController(
      text: studentProvider.studentInfo?['guardian_name'] ?? '',
    );
    final guardianContactController = TextEditingController(
      text: studentProvider.studentInfo?['guardian_contact'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: guardianNameController,
                decoration: const InputDecoration(
                  labelText: 'Guardian Name',
                  prefixIcon: Icon(Icons.family_restroom),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: guardianContactController,
                decoration: const InputDecoration(
                  labelText: 'Guardian Contact',
                  prefixIcon: Icon(Icons.phone_in_talk),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (firstNameController.text.trim().isEmpty ||
                  lastNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('First name and last name are required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );

                // ✅ Use Env.serverIp from existing config
                final serverIp = Env.serverIp;

                final response = await http.put(
                  Uri.parse('$serverIp/api/student/profile/update/'),
                  headers: {
                    'Authorization': 'Token ${authProvider.token}',
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'first_name': firstNameController.text.trim(),
                    'last_name': lastNameController.text.trim(),
                    'contact_number': contactController.text.trim(),
                    'guardian_name': guardianNameController.text.trim(),
                    'guardian_contact': guardianContactController.text.trim(),
                  }),
                );

                Navigator.of(context).pop();

                if (response.statusCode == 200) {
                  final data = json.decode(response.body);

                  if (data['success'] == true) {
                    await studentProvider.fetchStudentInfo(authProvider.token!);
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    await _loadStudentInfo();
                  } else {
                    throw Exception(data['error'] ?? 'Failed to update profile');
                  }
                } else {
                  throw Exception('Server error: ${response.statusCode}');
                }
              } catch (e) {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error updating profile: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, AuthProvider authProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.account_circle, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.person_outline, color: Colors.orange),
            title: const Text('Username'),
            subtitle: Text(authProvider.username ?? 'N/A'),
          ),
          ListTile(
            leading: const Icon(Icons.admin_panel_settings, color: Colors.orange),
            title: const Text('Role'),
            subtitle: Text(authProvider.role?.toUpperCase() ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSection(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.settings, color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('App Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.purple),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'InciTrack',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.school, size: 50, color: Color(0xFF4CAF50)),
                children: [
                  const Text(
                    'A comprehensive incident tracking and student guidance system for Aldresto T. Sandoval Memorial National High School.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthProvider authProvider) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.red.shade50,
      child: InkWell(
        onTap: () => _showLogoutDialog(context, authProvider),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: Colors.red.shade700),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              authProvider.logout();
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
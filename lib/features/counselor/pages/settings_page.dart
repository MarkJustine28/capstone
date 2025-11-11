import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ ADD THIS
import '../../../providers/counselor_provider.dart';
import '../../../config/routes.dart'; // ✅ ADD THIS for logout navigation

class CounselorSettingsPage extends StatefulWidget {
  const CounselorSettingsPage({Key? key}) : super(key: key);

  @override
  State<CounselorSettingsPage> createState() => _CounselorSettingsPageState();
}

class _CounselorSettingsPageState extends State<CounselorSettingsPage> {
  bool _isLoading = false;
  String? _selectedSchoolYear;
  List<String> _availableSchoolYears = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    // Initialize school year if not already done
    await counselorProvider.initializeSchoolYear();
    
    // Get currently selected school year
    _selectedSchoolYear = counselorProvider.selectedSchoolYear;
    
    // Fetch available school years from backend
    await counselorProvider.fetchAvailableSchoolYears();
    
    setState(() {
      _availableSchoolYears = counselorProvider.availableSchoolYears;
      _isLoading = false;
    });
  }

  Future<void> _changeSchoolYear(String newYear) async {
    setState(() => _isLoading = true);

    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Change School Year?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change from:'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '📅 $_selectedSchoolYear',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Change to:'),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '📅 $newYear',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'All pages will refresh to show data from the selected school year.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Change Year'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      setState(() => _isLoading = false);
      return;
    }

    // Update school year in provider
    final success = await counselorProvider.setSchoolYear(newYear);

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        setState(() {
          _selectedSchoolYear = newYear;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('✅ School year changed to $newYear\nAll data has been refreshed.'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to change school year'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ NEW: Logout function
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Clear all data
      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      counselorProvider.clearData();
      
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Navigate to login
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // School Year Section
                  _buildSectionHeader('School Year Filter', Icons.calendar_today),
                  const SizedBox(height: 12),
                  _buildSchoolYearCard(),
                  
                  const SizedBox(height: 32),
                  
                  // Affected Pages Info
                  _buildSectionHeader('What This Affects', Icons.info_outline),
                  const SizedBox(height: 12),
                  _buildAffectedPagesCard(),
                  
                  const SizedBox(height: 32),
                  
                  // Profile Section
                  _buildSectionHeader('Profile Information', Icons.person),
                  const SizedBox(height: 12),
                  _buildProfileCard(),
                  
                  const SizedBox(height: 32),
                  
                  // App Info
                  _buildSectionHeader('About', Icons.apps),
                  const SizedBox(height: 12),
                  _buildAboutCard(),
                  
                  const SizedBox(height: 32),
                  
                  // ✅ NEW: Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildSchoolYearCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active School Year',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'All reports and violations will be filtered by this year',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // Current Selection Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Currently Viewing',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _selectedSchoolYear ?? 'Loading...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedSchoolYear != null && _getCurrentSchoolYear() == _selectedSchoolYear)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'CURRENT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Available School Years List
            const Text(
              'Select School Year:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            
            if (_availableSchoolYears.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No school years available'),
                ),
              )
            else
              ..._availableSchoolYears.map((year) {
                final isCurrent = year == _getCurrentSchoolYear();
                final isSelected = year == _selectedSchoolYear;
                
                return Card(
                  color: isSelected ? Colors.blue.shade50 : null,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Radio<String>(
                      value: year,
                      groupValue: _selectedSchoolYear,
                      onChanged: (value) {
                        if (value != null && value != _selectedSchoolYear) {
                          _changeSchoolYear(value);
                        }
                      },
                    ),
                    title: Row(
                      children: [
                        Text(
                          year,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'CURRENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      if (year != _selectedSchoolYear) {
                        _changeSchoolYear(year);
                      }
                    },
                  ),
                );
              }).toList(),
            
            // "All Years" Option
            Card(
  color: _selectedSchoolYear == 'all' ? Colors.blue.shade50 : null,
  margin: const EdgeInsets.only(bottom: 8),
  child: ListTile(
    leading: Radio<String>(
      value: 'all',
      groupValue: _selectedSchoolYear,
      onChanged: (value) {
        if (value != null && value != _selectedSchoolYear) {
          _changeSchoolYear(value);
        }
      },
    ),
    title: Row(
      children: [
        // ✅ FIX: Wrap text in Flexible to prevent overflow
        Flexible(
          child: Text(
            'All Years (Combined View)',
            style: TextStyle(
              fontWeight: _selectedSchoolYear == 'all' ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis, // ✅ Add ellipsis if still too long
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.merge_type,
          size: 16,
          color: Colors.orange.shade700,
        ),
      ],
    ),
    subtitle: const Text(
      'View data from all school years combined',
      style: TextStyle(fontSize: 11),
    ),
    onTap: () {
      if (_selectedSchoolYear != 'all') {
        _changeSchoolYear('all');
      }
    },
  ),
),
          ],
        ),
      ),
    );
  }

  Widget _buildAffectedPagesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'The selected school year will filter data on these pages:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildAffectedPageItem(Icons.dashboard, 'Dashboard', 'Statistics and overview'),
            _buildAffectedPageItem(Icons.report, 'Student Reports', 'Submitted reports'),
            _buildAffectedPageItem(Icons.warning, 'Student Violations', 'Violation records'),
            _buildAffectedPageItem(Icons.people, 'Student Management', 'Student sections and info'),
            _buildAffectedPageItem(Icons.notifications, 'Send Guidance Notice', 'Summoned students'),
            _buildAffectedPageItem(Icons.bar_chart, 'Analytics', 'Charts and statistics'),
          ],
        ),
      ),
    );
  }

  Widget _buildAffectedPageItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Consumer<CounselorProvider>(
      builder: (context, counselorProvider, child) {
        final profile = counselorProvider.counselorProfile;
        
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.shade700,
                  child: Text(
                    _getInitials(profile),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _getFullName(profile),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  profile?['email'] ?? 'No email',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                _buildProfileRow('Employee ID', profile?['employee_id'] ?? 'N/A'),
                _buildProfileRow('Department', profile?['department'] ?? 'Guidance'),
                _buildProfileRow('Role', 'Guidance Counselor'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.school, size: 48, color: Colors.blue.shade700),
            const SizedBox(height: 12),
            const Text(
              'Guidance Tracker',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              'Student behavior tracking and management system',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentSchoolYear() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    return month >= 6 ? '$year-${year + 1}' : '${year - 1}-$year';
  }

  String _getInitials(Map<String, dynamic>? profile) {
    if (profile == null) return 'C';
    
    final firstName = profile['first_name']?.toString() ?? '';
    final lastName = profile['last_name']?.toString() ?? '';
    
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    return 'C';
  }

  String _getFullName(Map<String, dynamic>? profile) {
    if (profile == null) return 'Counselor';
    
    final firstName = profile['first_name']?.toString() ?? '';
    final lastName = profile['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    
    return fullName.isNotEmpty ? fullName : (profile['username']?.toString() ?? 'Counselor');
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/counselor_provider.dart';

class CounselingSessionPage extends StatefulWidget {
  const CounselingSessionPage({Key? key}) : super(key: key);

  @override
  State<CounselingSessionPage> createState() => _CounselingSessionPageState();
}

class _CounselingSessionPageState extends State<CounselingSessionPage> {
  @override
  void initState() {
    super.initState();
    // Fetch counseling sessions when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CounselorProvider>().fetchCounselingSessions();
    });
  }

  void _addSession() {
    final counselorProvider = context.read<CounselorProvider>();

    showDialog(
      context: context,
      builder: (context) {
        String studentId = "";
        String studentName = "";
        String date = "";
        String time = "";
        String notes = "";

        return AlertDialog(
          title: const Text("New Counseling Session"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: "Student ID"),
                onChanged: (val) => studentId = val,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Student Name"),
                onChanged: (val) => studentName = val,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Date (YYYY-MM-DD)"),
                onChanged: (val) => date = val,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Time (HH:MM)"),
                onChanged: (val) => time = val,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Notes (Optional)"),
                onChanged: (val) => notes = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (studentId.isNotEmpty && studentName.isNotEmpty && date.isNotEmpty && time.isNotEmpty) {
                  final sessionData = {
                    'student_id': int.tryParse(studentId) ?? 0,
                    'student_name': studentName,
                    'date': date,
                    'time': time,
                    'notes': notes,
                    'status': 'scheduled',
                  };

                  final success = await counselorProvider.createCounselingSession(sessionData);
                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Counseling session created successfully')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(counselorProvider.error ?? 'Failed to create session')),
                    );
                  }
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CounselorProvider>(
      builder: (context, counselorProvider, child) {
        final sessions = counselorProvider.counselingSessions;
        final isLoading = counselorProvider.isLoadingCounselingSessions;

        if (isLoading) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Counseling Sessions"),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("Counseling Sessions"),
          ),
          body: sessions.isEmpty
              ? const Center(
                  child: Text("No counseling sessions scheduled."),
                )
              : RefreshIndicator(
                  onRefresh: () => counselorProvider.fetchCounselingSessions(),
                  child: ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.person, color: Colors.green),
                          title: Text(session["student_name"] ?? session["student"] ?? "Unknown Student"),
                          subtitle: Text("${session["date"] ?? ""} • ${session["time"] ?? ""}"),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(session["status"] ?? ""),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatStatus(session["status"] ?? ""),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          onTap: () => _showSessionDetails(context, session),
                        ),
                      );
                    },
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _addSession,
            backgroundColor: Colors.green,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
      case 'upcoming':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return 'Scheduled';
      case 'upcoming':
        return 'Upcoming';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'in_progress':
        return 'In Progress';
      default:
        return status;
    }
  }

  void _showSessionDetails(BuildContext context, Map<String, dynamic> session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Session Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Student: ${session["student_name"] ?? session["student"] ?? "Unknown"}"),
            Text("Date: ${session["date"] ?? ""}"),
            Text("Time: ${session["time"] ?? ""}"),
            Text("Status: ${_formatStatus(session["status"] ?? "")}"),
            if (session["notes"] != null && session["notes"].toString().isNotEmpty)
              Text("Notes: ${session["notes"]}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          if (session["status"] == "scheduled")
            ElevatedButton(
              onPressed: () async {
                final counselorProvider = context.read<CounselorProvider>();
                final success = await counselorProvider.updateCounselingSessionStatus(
                  session["id"] ?? 0,
                  "completed"
                );
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Session marked as completed')),
                  );
                }
              },
              child: const Text("Mark Completed"),
            ),
        ],
      ),
    );
  }
}

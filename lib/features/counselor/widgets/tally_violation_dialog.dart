import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/counselor_provider.dart';
import '../pages/student_violations_page.dart';

class TallyViolationDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final List<Map<String, dynamic>> violationTypes;
  final VoidCallback onViolationTallied;

  const TallyViolationDialog({
    super.key,
    required this.report,
    required this.violationTypes,
    required this.onViolationTallied,
  });

  @override
  State<TallyViolationDialog> createState() => _TallyViolationDialogState();
}

class _TallyViolationDialogState extends State<TallyViolationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _invalidReasonController = TextEditingController();
  
  DateTime? _selectedDate;
  bool _isSending = false;
  bool _showInvalidSection = false;

  String get reportStatus => widget.report['status']?.toString().toLowerCase() ?? '';
  bool get isAlreadySummoned => reportStatus == 'summoned';

  @override
  void initState() {
    super.initState();
    _messageController.text = 'Please bring any relevant documents or information regarding this incident.';
  }

  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _sendSummons() async {
    setState(() => _isSending = true);

    try {
      final dynamic counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      
      final success = await counselorProvider.sendCounselingSummons(
        reportId: widget.report['id'],
        scheduledDate: _selectedDate?.toIso8601String(),
        message: _messageController.text.trim(),
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        widget.onViolationTallied();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '✅ Summons Sent Successfully',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Student has been notified to report to guidance office',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        throw Exception('Failed to send summons');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _markAsInvalid() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isSending = true);

  try {
    final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
    
    // ✅ Use the markReportAsInvalid method
    final success = await counselorProvider.markReportAsInvalid(
      reportId: widget.report['id'],
      reason: _invalidReasonController.text.trim(),
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      widget.onViolationTallied();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cancel, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '✅ Report Marked as Invalid',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Notifications sent to student and reporter',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    } else {
      throw Exception('Failed to mark report as invalid');
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isSending = false);
    }
  }
}

  void _proceedToTally() {
    // Close current dialog and show tally dialog
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) => _OriginalTallyDialog(
        report: widget.report,
        violationTypes: widget.violationTypes,
        onViolationTallied: widget.onViolationTallied,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentName = widget.report['reported_student_name']?.toString() ?? 
                       widget.report['student']?['name']?.toString() ?? 
                       widget.report['student_name']?.toString() ??
                       'Unknown Student';

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAlreadySummoned ? Colors.orange.shade100 : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAlreadySummoned ? Icons.assignment_ind : Icons.notifications_active,
              color: isAlreadySummoned ? Colors.orange.shade700 : Colors.blue.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAlreadySummoned ? 'Student Summoned' : 'Call Student for Counseling',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Report Information
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.report, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.report['title'] ?? 'Untitled Report',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Student: $studentName'),
                      Text('Violation: ${widget.report['violation_type'] ?? 'N/A'}'),
                      Text('Status: ${reportStatus.toUpperCase()}', 
                        style: TextStyle(
                          color: isAlreadySummoned ? Colors.orange : Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),

                if (isAlreadySummoned) ...[
                  // Student has been summoned - show action options
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Student has been summoned. After counseling session, choose an action:',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Action buttons
                  const Text(
                    'Counseling Session Result:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  // Option 1: Tally (Violation Confirmed)
                  Card(
                    color: Colors.red.shade50,
                    child: InkWell(
                      onTap: _isSending ? null : _proceedToTally,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.gavel, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tally Violation',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Student admitted/confirmed violation',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Option 2: Mark as Invalid
                  Card(
                    color: Colors.grey.shade100,
                    child: InkWell(
                      onTap: _isSending ? null : () => setState(() => _showInvalidSection = !_showInvalidSection),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.cancel, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mark as Invalid',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'No violation found/report unsubstantiated',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _showInvalidSection ? Icons.expand_less : Icons.expand_more,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Invalid reason input
                  if (_showInvalidSection) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reason for Marking as Invalid:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _invalidReasonController,
                            decoration: const InputDecoration(
                              hintText: 'Explain why this report is invalid...',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (_showInvalidSection && (value == null || value.trim().isEmpty)) {
                                return 'Please provide a reason';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSending ? null : _markAsInvalid,
                              icon: _isSending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.cancel),
                              label: Text(_isSending ? 'Processing...' : 'Confirm Mark as Invalid'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ] else ...[
                  // Student not yet summoned - show summons form
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Before tallying, the student must be called for counseling to verify the violation.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Schedule Date/Time
                  const Text(
                    'Schedule Counseling Session (Optional):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDateTime,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? DateFormat('EEEE, MMMM d, y @ h:mm a').format(_selectedDate!)
                                  : 'Select date and time (optional)',
                              style: TextStyle(
                                color: _selectedDate != null ? Colors.black : Colors.grey,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Additional Message
                  const Text(
                    'Additional Message (Optional):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Add any special instructions...',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!isAlreadySummoned)
          ElevatedButton.icon(
            onPressed: _isSending ? null : _sendSummons,
            icon: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: Text(_isSending ? 'Sending...' : 'Send Notif'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _invalidReasonController.dispose();
    super.dispose();
  }
}

// Original Tally Dialog (for when violation is confirmed after counseling)
class _OriginalTallyDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final List<Map<String, dynamic>> violationTypes;
  final VoidCallback onViolationTallied;

  const _OriginalTallyDialog({
    required this.report,
    required this.violationTypes,
    required this.onViolationTallied,
  });

  @override
  State<_OriginalTallyDialog> createState() => _OriginalTallyDialogState();
}

class _OriginalTallyDialogState extends State<_OriginalTallyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _counselorNotesController = TextEditingController();
  Map<String, dynamic>? _selectedViolationType;
  DateTime _incidentDate = DateTime.now();
  String _severity = 'Medium';
  bool _isTallying = false;

  @override
  void initState() {
    super.initState();
    // Pre-select violation type from report if available
    if (widget.report['violation_type_id'] != null) {
      _selectedViolationType = widget.violationTypes.firstWhere(
        (type) => type['id'] == widget.report['violation_type_id'],
        orElse: () => widget.violationTypes.first,
      );
      if (_selectedViolationType != null) {
        _severity = _selectedViolationType!['severity_level'] ?? 'Medium';
      }
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _incidentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_incidentDate),
      );

      if (pickedTime != null) {
        setState(() {
          _incidentDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _tallyViolation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTallying = true);

    try {
      final studentId = widget.report['reported_student_id']?.toString() ??
          widget.report['student']?['id']?.toString() ??
          widget.report['student_id']?.toString();

      if (studentId == null) {
        throw Exception('Student ID not found in report');
      }

      final violationData = {
        'student_id': studentId,
        'violation_type_id': _selectedViolationType!['id'],
        'incident_date': _incidentDate.toIso8601String(),
        'description': 'Reported by: ${widget.report['reported_by']?['name'] ?? 'Unknown'}\n\n'
                      '${widget.report['content'] ?? widget.report['description'] ?? 'Violation tallied from report: ${widget.report['title']}'}',
        'location': widget.report['location'] ?? '',
        'severity_override': _severity,
        'related_report_id': widget.report['id'],
        'status': 'active',
        'counselor_notes': _counselorNotesController.text.trim(),
      };

      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      
      final success = await counselorProvider.recordViolation(violationData);

      if (success && mounted) {
        // Mark report as resolved
        await counselorProvider.updateReportStatus(
          widget.report['id'],
          'resolved',
        );
        
        // Refresh data
        await counselorProvider.fetchStudentsList();
        await counselorProvider.fetchStudentViolations();
        await counselorProvider.fetchCounselorStudentReports();
        
        Navigator.of(context).pop();
        widget.onViolationTallied();
        
        final studentName = widget.report['reported_student_name']?.toString() ?? 
                           widget.report['student']?['name']?.toString() ?? 
                           'student';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '✅ Violation Tallied Successfully',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Notifications sent to $studentName and reporter',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StudentViolationsPage(),
                  ),
                );
              },
            ),
          ),
        );
      } else {
        throw Exception('Failed to tally violation');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTallying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = widget.report['reported_student_name']?.toString() ?? 
                       widget.report['student']?['name']?.toString() ?? 
                       'Unknown Student';

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.gavel, color: Colors.red),
          SizedBox(width: 8),
          Text('Confirm and Tally Violation'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Violation confirmed after counseling session. Proceed to tally.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),

                // Student Name
                Text('Student: $studentName', style: const TextStyle(fontWeight: FontWeight.bold)),
                
                const SizedBox(height: 16),

                // Incident Date
                const Text('Incident Date & Time *', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDateTime(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, MMMM d, y @ h:mm a').format(_incidentDate),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Violation Type
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedViolationType,
                  decoration: const InputDecoration(
                    labelText: 'Violation Type *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.violationTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type['name'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() {
                    _selectedViolationType = value;
                    if (value != null) {
                      _severity = value['severity_level'] ?? 'Medium';
                    }
                  }),
                  validator: (value) => value == null ? 'Please select a violation type' : null,
                ),
                
                const SizedBox(height: 16),

                // Severity
                DropdownButtonFormField<String>(
                  value: _severity,
                  decoration: const InputDecoration(
                    labelText: 'Severity Level *',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Low', 'Medium', 'High', 'Critical'].map((severity) {
                    return DropdownMenuItem(
                      value: severity,
                      child: Text(severity),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _severity = value ?? 'Medium'),
                ),
                
                const SizedBox(height: 16),

                // Counselor Notes
                TextFormField(
                  controller: _counselorNotesController,
                  decoration: const InputDecoration(
                    labelText: 'Counselor Session Notes *',
                    hintText: 'Summary of counseling session and student response...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please add notes about the counseling session';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTallying ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isTallying ? null : _tallyViolation,
          icon: _isTallying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.gavel),
          label: Text(_isTallying ? 'Tallying...' : 'Tally Violation'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _counselorNotesController.dispose();
    super.dispose();
  }
}
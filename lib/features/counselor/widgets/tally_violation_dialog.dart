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
  bool get isPending => reportStatus == 'pending';
  bool get isSummoned => reportStatus == 'summoned';
  bool get isReviewed => reportStatus == 'reviewed';  // ✅ Add reviewed state
  bool get canTally => isSummoned || isReviewed;  // ✅ Both can be tallied

  @override
  void initState() {
    super.initState();
    _messageController.text = 
      'You are being called to the Guidance Office regarding an incident report.\n\n'
      'Please report as soon as possible to discuss this matter.\n\n'
      'Bring any relevant information or documents that may help clarify the situation.';
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

  Future<void> _sendGuidanceNotice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final counselorProvider = Provider.of<CounselorProvider>(context, listen: false);
      
      final success = await counselorProvider.sendCounselingSummons(
        reportId: widget.report['id'],
        scheduledDate: _selectedDate?.toIso8601String(),
        message: _messageController.text.trim(),
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        widget.onViolationTallied();
        
        final studentName = widget.report['reported_student_name']?.toString() ?? 
                           widget.report['student']?['name']?.toString() ?? 
                           widget.report['student_name']?.toString() ??
                           'the student';

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
                        '📢 Guidance Notice Sent!',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        '$studentName has been notified to report to the guidance office.',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      } else {
        throw Exception('Failed to send guidance notice');
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
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Notifications sent to student and reporter',
                        style: TextStyle(fontSize: 12, color: Colors.white),
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
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) => _TallyConfirmationDialog(
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
              color: isPending 
                  ? Colors.blue.shade100 
                  : isSummoned 
                      ? Colors.orange.shade100 
                      : isReviewed  // ✅ Green for reviewed
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPending 
                  ? Icons.notifications_active 
                  : isSummoned 
                      ? Icons.assignment_ind 
                      : isReviewed  // ✅ Check icon for reviewed
                          ? Icons.check_circle
                          : Icons.info,
              color: isPending 
                  ? Colors.blue.shade700 
                  : isSummoned 
                      ? Colors.orange.shade700 
                      : isReviewed
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPending 
                  ? 'Send Guidance Notice' 
                  : isSummoned 
                      ? 'Student Summoned' 
                      : isReviewed  // ✅ Title for reviewed
                          ? 'Tally Violation'
                          : 'Process Report',
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
                // Report Information Card
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
                      const Divider(height: 16),
                      _buildInfoRow('Student', studentName, Icons.person),
                      _buildInfoRow(
                        'Reported by', 
                        widget.report['reported_by']?['name']?.toString() ?? 'Unknown',
                        Icons.person_outline,
                      ),
                      _buildInfoRow(
                        'Status', 
                        reportStatus.toUpperCase(),
                        Icons.info,
                        statusColor: isPending 
                            ? Colors.blue 
                            : isSummoned 
                                ? Colors.orange 
                                : isReviewed
                                    ? Colors.green
                                    : Colors.grey,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),

                // PENDING STATE - Send Guidance Notice
                if (isPending) ...[
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
                            'Before processing this report, the student must be notified to report to your office for counseling.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Schedule Date/Time (Optional)
                  const Text(
                    'Schedule Appointment (Optional):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                          Icon(Icons.calendar_today, size: 20, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? DateFormat('EEEE, MMMM d, y @ h:mm a').format(_selectedDate!)
                                  : 'Tap to schedule date & time',
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

                  // Notice Message
                  const Text(
                    'Notice Message:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Message for the student...',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.message, color: Colors.blue.shade700),
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a message';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),

                  // Quick Actions for Pending
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSending ? null : () {
                            setState(() => _showInvalidSection = !_showInvalidSection);
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('Mark Invalid'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: BorderSide(color: Colors.orange.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_showInvalidSection) ...[
                    const SizedBox(height: 12),
                    _buildInvalidSection(),
                  ],
                ],

                // SUMMONED STATE - Post-Counseling Actions
                if (isSummoned) ...[
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
                            'Student has been summoned. After the counseling session, choose an appropriate action:',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  const Text(
                    'Counseling Session Result:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  // Option 1: Tally Violation (Confirmed)
                  _buildActionCard(
                    title: 'Tally Violation',
                    subtitle: 'Student admitted to or violation was confirmed',
                    icon: Icons.gavel,
                    color: Colors.red,
                    onTap: _isSending ? null : _proceedToTally,
                  ),

                  const SizedBox(height: 8),

                  // Option 2: Mark as Invalid
                  _buildActionCard(
                    title: 'Mark as Invalid',
                    subtitle: 'No violation found or report unsubstantiated',
                    icon: Icons.cancel,
                    color: Colors.grey.shade600,
                    onTap: _isSending ? null : () {
                      setState(() => _showInvalidSection = !_showInvalidSection);
                    },
                    trailing: Icon(
                      _showInvalidSection ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                  ),

                  if (_showInvalidSection) ...[
                    const SizedBox(height: 12),
                    _buildInvalidSection(),
                  ],
                ],

                // ✅ NEW: REVIEWED STATE - Ready to Tally
                if (isReviewed) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200, width: 2),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.green.shade700,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Report Reviewed & Validated ✅',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'This violation has been confirmed through counseling and is ready to be officially recorded.',
                                    style: TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Violation Summary
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(        ),
                              if (widget.report['counselor_notes'] != null) ...[
                                const Divider(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.notes, color: Colors.grey.shade600, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.report['counselor_notes'].toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Tally Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSending ? null : _proceedToTally,
                            icon: _isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.gavel, size: 24),
                            label: Text(
                              _isSending ? 'Processing...' : 'Tally Violation',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Info text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'This will officially record the violation in the student\'s record',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
        if (isPending && !_showInvalidSection)
          ElevatedButton.icon(
            onPressed: _isSending ? null : _sendGuidanceNotice,
            icon: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: Text(_isSending ? 'Sending...' : 'Send Notice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: statusColor ?? Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: statusColor ?? Colors.black87,
                      fontWeight: statusColor != null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      color: color == Colors.red ? Colors.red.shade50 : Colors.grey.shade100,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvalidSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reason for Marking as Invalid:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _invalidReasonController,
            decoration: const InputDecoration(
              hintText: 'Explain why this report is invalid (e.g., unsubstantiated, false accusation, lack of evidence)...',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            maxLines: 3,
            validator: (value) {
              if (_showInvalidSection && (value == null || value.trim().isEmpty)) {
                return 'Please provide a reason for marking as invalid';
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
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _invalidReasonController.dispose();
    super.dispose();
  }
}

// Tally Confirmation Dialog (shown after counseling for confirmed violations)
class _TallyConfirmationDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final List<Map<String, dynamic>> violationTypes;
  final VoidCallback onViolationTallied;

  const _TallyConfirmationDialog({
    required this.report,
    required this.violationTypes,
    required this.onViolationTallied,
  });

  @override
  State<_TallyConfirmationDialog> createState() => _TallyConfirmationDialogState();
}

class _TallyConfirmationDialogState extends State<_TallyConfirmationDialog> {
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
      try {
        _selectedViolationType = widget.violationTypes.firstWhere(
          (type) => type['id'] == widget.report['violation_type_id'],
          orElse: () => widget.violationTypes.isNotEmpty ? widget.violationTypes.first : {},
        );
        if (_selectedViolationType != null && _selectedViolationType!.isNotEmpty) {
          _severity = _selectedViolationType!['severity_level'] ?? 'Medium';
        }
      } catch (e) {
        debugPrint('Error pre-selecting violation type: $e');
      }
    }

    // Pre-fill counselor notes with report details
    _counselorNotesController.text = 
      'Counseling Session Summary:\n'
      '- Student admitted to the violation\n'
      '- Discussion held about the incident\n'
      '- Student understands the consequences\n\n'
      'Additional Notes:\n';
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

      if (_selectedViolationType == null) {
        throw Exception('Please select a violation type');
      }

      final violationData = {
        'student_id': studentId,
        'violation_type_id': _selectedViolationType!['id'],
        'incident_date': _incidentDate.toIso8601String(),
        'description': 'Report Title: ${widget.report['title'] ?? 'N/A'}\n\n'
                      'Reported by: ${widget.report['reported_by']?['name'] ?? 'Unknown'}\n\n'
                      'Original Report:\n${widget.report['content'] ?? widget.report['description'] ?? 'No description available'}\n\n'
                      'Counseling Notes:\n${_counselorNotesController.text.trim()}',
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
        
        // Refresh all data
        await Future.wait([
          counselorProvider.fetchStudentsList(),
          counselorProvider.fetchStudentViolations(),
          counselorProvider.fetchCounselorStudentReports(forceRefresh: true),
        ]);
        
        if (mounted) {
          Navigator.of(context).pop();
          widget.onViolationTallied();
          
          final studentName = widget.report['reported_student_name']?.toString() ?? 
                             widget.report['student']?['name']?.toString() ?? 
                             widget.report['student_name']?.toString() ??
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
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Notifications sent to $studentName and the reporter',
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
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
        }
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
                       widget.report['student_name']?.toString() ??
                       'Unknown Student';

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.gavel, color: Colors.red.shade700),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Confirm and Tally Violation')),
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
                          'Violation confirmed after counseling session. Proceeding to tally.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),

                // Student Name
                Row(
                  children: [
                    const Icon(Icons.person, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Student: $studentName',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                
                const Divider(height: 24),

                // Incident Date
                const Text(
                  'Incident Date & Time *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
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
                        const Icon(Icons.edit, size: 16),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Violation Type
                const Text(
                  'Violation Type *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedViolationType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  isExpanded: true,
                  items: widget.violationTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type['name'] ?? 'Unknown',
                        overflow: TextOverflow.ellipsis,
                      ),
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
                const Text(
                  'Severity Level *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _severity,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: ['Low', 'Medium', 'High', 'Critical'].map((severity) {
                    return DropdownMenuItem(
                      value: severity,
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: severity == 'Low' 
                                ? Colors.green 
                                : severity == 'Medium' 
                                    ? Colors.orange 
                                    : severity == 'High'
                                        ? Colors.red
                                        : Colors.purple,
                          ),
                          const SizedBox(width: 8),
                          Text(severity),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _severity = value ?? 'Medium'),
                ),
                
                const SizedBox(height: 16),

                // Counselor Notes
                const Text(
                  'Counseling Session Notes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _counselorNotesController,
                  decoration: const InputDecoration(
                    hintText: 'Document the counseling session and student\'s response...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 6,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please add notes about the counseling session';
                    }
                    if (value.trim().length < 20) {
                      return 'Please provide more detailed notes (at least 20 characters)';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Info box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Once tallied, the violation will be added to the student\'s record and both the student and reporter will be notified.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
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
          label: Text(_isTallying ? 'Tallying...' : 'Confirm & Tally'),
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
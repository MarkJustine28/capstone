from django.db import models
from django.contrib.auth.models import User

class Student(models.Model):
    GRADE_CHOICES = [
        ('7', 'Grade 7'),
        ('8', 'Grade 8'),
        ('9', 'Grade 9'),
        ('10', 'Grade 10'),
        ('11', 'Grade 11'),
        ('12', 'Grade 12'),
    ]
    
    # Strand choices for Senior High School (Grades 11-12)
    STRAND_CHOICES = [
        # Grade 11 Strands
        ('STEM', 'Science, Technology, Engineering, and Mathematics'),
        ('PBM', 'Pre-Baccalaureate Maritime'),
        ('ABM', 'Accountancy, Business and Management'),
        ('HUMSS', 'Humanities and Social Sciences'),
        ('HOME_ECONOMICS', 'Home Economics'),
        ('HOME_ECONOMICS_ICT', 'Home Economics/ICT'),
        ('ICT', 'Information and Communications Technology'),
        ('EIM_SMAW', 'Electrical Installation and Maintenance - Shielded Metal Arc Welding'),
        ('SMAW', 'Shielded Metal Arc Welding'),
        # Grade 12 Strands (same options but different sections)
        ('HE', 'Home Economics'),  # Shortened for Grade 12
        ('EIM', 'Electrical Installation and Maintenance'),  # Shortened for Grade 12
    ]
    
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    student_id = models.CharField(max_length=20, unique=True, blank=True, null=True)
    grade_level = models.CharField(max_length=2, choices=GRADE_CHOICES, blank=True, null=True)
    
    # NEW: Add strand field for Senior High School
    strand = models.CharField(max_length=30, choices=STRAND_CHOICES, blank=True, null=True, 
                             help_text="Required for Grade 11 and 12 students")
    
    section = models.CharField(max_length=50, blank=True, null=True)
    
    # Contact Information
    contact_number = models.CharField(max_length=15, blank=True, null=True)
    guardian_name = models.CharField(max_length=100, blank=True, null=True)
    guardian_contact = models.CharField(max_length=15, blank=True, null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)

    def clean(self):
        """Custom validation to ensure strand is provided for grades 11-12"""
        from django.core.exceptions import ValidationError
        
        if self.grade_level in ['11', '12'] and not self.strand:
            raise ValidationError('Strand is required for Grade 11 and 12 students.')
        
        if self.grade_level not in ['11', '12'] and self.strand:
            raise ValidationError('Strand should only be specified for Grade 11 and 12 students.')

    def get_full_grade_section(self):
        """Get the complete grade, strand, and section info"""
        if self.grade_level in ['11', '12'] and self.strand:
            return f"Grade {self.grade_level} {self.strand} - {self.section}"
        elif self.grade_level and self.section:
            return f"Grade {self.grade_level} {self.section}"
        return f"Grade {self.grade_level or 'Unknown'}"

    def __str__(self):
        full_name = self.user.get_full_name() or self.user.username
        if self.grade_level and self.section:
            if self.grade_level in ['11', '12'] and self.strand:
                return f"{full_name} - Grade {self.grade_level} {self.strand} {self.section}"
            return f"{full_name} - Grade {self.grade_level} {self.section}"
        return f"{full_name} - Student"

    class Meta:
        # Ensure unique combination of grade, strand, and section per student
        constraints = [
            models.UniqueConstraint(
                fields=['grade_level', 'strand', 'section', 'student_id'],
                condition=models.Q(student_id__isnull=False),
                name='unique_student_placement'
            )
        ]

class Teacher(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    employee_id = models.CharField(max_length=20, unique=True, blank=True, null=True)  # ✅ Make nullable
    department = models.CharField(max_length=100, blank=True, default='')
    specialization = models.CharField(max_length=100, blank=True, default='')
    
    # Advising Information
    advising_grade = models.CharField(max_length=2, choices=Student.GRADE_CHOICES, blank=True, null=True)
    advising_strand = models.CharField(max_length=30, choices=Student.STRAND_CHOICES, blank=True, null=True,
                                     help_text="Required if advising Grade 11 or 12")
    advising_section = models.CharField(max_length=50, blank=True, null=True)
    
    # 🆕 NEW: Approval fields
    is_approved = models.BooleanField(default=False, verbose_name="Account Approved")
    approval_status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending Approval'),
            ('approved', 'Approved'),
            ('rejected', 'Rejected'),
        ],
        default='pending',
        verbose_name="Approval Status"
    )
    approved_by = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        related_name='approved_teachers',
        verbose_name="Approved By"
    )
    approved_at = models.DateTimeField(null=True, blank=True, verbose_name="Approval Date")
    rejection_reason = models.TextField(blank=True, default='', verbose_name="Rejection Reason")
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def clean(self):
        """Custom validation for teacher advising"""
        from django.core.exceptions import ValidationError
        
        if self.advising_grade in ['11', '12'] and not self.advising_strand:
            raise ValidationError('Strand is required when advising Grade 11 or 12.')
        
        if self.advising_grade not in ['11', '12'] and self.advising_strand:
            raise ValidationError('Strand should only be specified when advising Grade 11 or 12.')

    def get_advising_info(self):
        """Get complete advising information"""
        if self.advising_grade and self.advising_section:
            if self.advising_grade in ['11', '12'] and self.advising_strand:
                return f"Grade {self.advising_grade} {self.advising_strand} {self.advising_section}"
            return f"Grade {self.advising_grade} {self.advising_section}"
        return "No Advisory Class"

    def __str__(self):
        full_name = self.user.get_full_name() or self.user.username
        status_icon = {
            'pending': '⏳',
            'approved': '✅',
            'rejected': '❌'
        }.get(self.approval_status, '')
        
        if self.advising_grade and self.advising_section:
            return f"{status_icon} {full_name} - Adviser of {self.get_advising_info()}"
        return f"{status_icon} {full_name} - Teacher"

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Teacher'
        verbose_name_plural = 'Teachers'

class Counselor(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    employee_id = models.CharField(max_length=20, unique=True, blank=True, null=True)
    specialization = models.CharField(max_length=100, blank=True, null=True)
    office = models.CharField(max_length=100, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.get_full_name() or self.user.username} - Counselor"

class ViolationType(models.Model):
    """Predefined violation types for better categorization"""
    name = models.CharField(max_length=100, unique=True)
    category = models.CharField(max_length=100, choices=[
        ('Tardiness', 'Tardiness'),
        ('Using Vape/Cigarette', 'Using Vape/Cigarette'),
        ('Misbehavior', 'Misbehavior'),
        ('Bullying', 'Bullying - Physical, Verbal/Emotional, Cyberbullying, Sexual, Racism'),
        ('Gambling', 'Gambling'),
        ('Haircut', 'Haircut'),
        ('Not Wearing Proper Uniform/ID', 'Not Wearing Proper Uniform/ID'),
        ('Cheating', 'Cheating'),
        ('Cutting Classes', 'Cutting Classes'),
        ('Absenteeism', 'Absenteeism'),
        ('Others', 'Others'),
    ])
    severity_level = models.CharField(max_length=20, choices=[
        ('Low', 'Low'),
        ('Medium', 'Medium'),
        ('High', 'High'),
        ('Critical', 'Critical'),
    ], default='Medium')
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    
    # NEW: Applicable grade levels
    applicable_grades = models.CharField(max_length=50, default='7,8,9,10,11,12',
                                       help_text="Comma-separated grade levels (e.g., '7,8,9')")
    
    created_at = models.DateTimeField(auto_now_add=True)

    def get_applicable_grades_list(self):
        """Return list of applicable grades"""
        return [grade.strip() for grade in self.applicable_grades.split(',') if grade.strip()]

    def is_applicable_for_grade(self, grade_level):
        """Check if this violation type applies to a specific grade"""
        return str(grade_level) in self.get_applicable_grades_list()

    def __str__(self):
        return f"{self.name} ({self.category})"

    class Meta:
        ordering = ['category', 'name']

class Report(models.Model):
    """Enhanced Report model with verification and counseling tracking"""
    REPORT_STATUS_CHOICES = [
        ('pending', 'Pending Review'),
        ('under_review', 'Under Review'),
        ('under_investigation', 'Under Investigation'),
        ('summons_sent', 'Summons Sent - Awaiting Counseling'),
        ('verified', 'Verified - Case Confirmed'),
        ('dismissed', 'Dismissed - Case Not Verified'),
        ('resolved', 'Resolved'),
        ('escalated', 'Escalated'),
    ]

    REPORT_TYPE_CHOICES = [
        ('incident', 'Incident Report'),
        ('self_report', 'Self Report'),
        ('teacher_report', 'Teacher Report'),
        ('counselor_note', 'Counselor Note'),
        ('peer_report', 'Peer Report'),
    ]
    
    VERIFICATION_CHOICES = [
        ('pending', 'Pending Verification'),
        ('verified', 'Verified'),
        ('dismissed', 'Not Verified/Dismissed'),
    ]

    # Basic Information
    title = models.CharField(max_length=200)
    content = models.TextField()
    description = models.TextField(blank=True, null=True)
    status = models.CharField(max_length=30, choices=REPORT_STATUS_CHOICES, default='pending')
    report_type = models.CharField(max_length=20, choices=REPORT_TYPE_CHOICES, default='incident')
    reporter_type = models.CharField(max_length=50, blank=True, null=True)
    
    # ✅ NEW: Verification status
    verification_status = models.CharField(
        max_length=20, 
        choices=VERIFICATION_CHOICES, 
        default='pending',
        help_text="Status of case verification through counseling"
    )
    
    # Related Users
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='reports', null=True, blank=True)
    student_name = models.CharField(max_length=255, blank=True, null=True)
    reported_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='submitted_reports')
    assigned_counselor = models.ForeignKey(Counselor, on_delete=models.SET_NULL, null=True, blank=True)
    
    # Violation Details
    violation_type = models.ForeignKey(ViolationType, on_delete=models.SET_NULL, null=True, blank=True)
    custom_violation = models.CharField(max_length=200, blank=True, null=True)
    severity = models.CharField(max_length=20, choices=[
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
        ('critical', 'Critical'),
    ], default='medium')
    
    # ✅ NEW: Counseling session fields
    requires_counseling = models.BooleanField(
        default=True,
        help_text="Can be toggled by counselor for minor cases"
    )
    counseling_date = models.DateTimeField(null=True, blank=True)
    counseling_notes = models.TextField(blank=True)
    counseling_completed = models.BooleanField(default=False)
    
    # ✅ NEW: Summons tracking
    summons_sent_at = models.DateTimeField(null=True, blank=True)
    summons_sent_to_reporter = models.BooleanField(default=False)
    summons_sent_to_student = models.BooleanField(default=False)
    
    # ✅ NEW: Verification details
    verified_by = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='verified_reports',
        help_text="Counselor who verified the case"
    )
    verified_at = models.DateTimeField(null=True, blank=True)
    verification_notes = models.TextField(
        blank=True,
        help_text="Counselor's notes after verification session"
    )

    # ✅ NEW: Counselor's follow-up notes
    counselor_notes = models.TextField(blank=True, null=True, help_text="Notes from counselor about this report")
    
    # Timestamps
    incident_date = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    
    # Context Information
    location = models.CharField(max_length=200, blank=True, null=True)
    witnesses = models.TextField(blank=True, null=True)
    follow_up_required = models.BooleanField(default=False)
    parent_notified = models.BooleanField(default=False)
    disciplinary_action = models.TextField(blank=True, null=True)
    
    # Review tracking
    is_reviewed = models.BooleanField(default=False)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    
    # Academic context for SHS students
    subject_involved = models.CharField(max_length=100, blank=True, null=True,
                                       help_text="Subject/course related to the incident")
    academic_impact = models.TextField(blank=True, null=True,
                                      help_text="Impact on academic performance")

    def is_critical_case(self):
        """Check if this is a critical severity case"""
        return self.severity == 'critical'
    
    def should_require_counseling(self):
        """Determine if counseling is required based on severity"""
        # Critical cases always require counseling unless counselor explicitly skips
        if self.severity == 'critical':
            return True
        # High severity cases require counseling
        if self.severity == 'high':
            return True
        # Medium cases - counselor can decide
        if self.severity == 'medium':
            return self.requires_counseling
        # Low cases - optional
        return False

    def get_violation_name(self):
        """Get the violation name (either from type or custom)"""
        if self.violation_type:
            return self.violation_type.name
        return self.custom_violation or self.title

    def get_days_open(self):
        """Calculate how many days the report has been open"""
        from django.utils import timezone
        if self.resolved_at:
            return (self.resolved_at - self.created_at).days
        return (timezone.now() - self.created_at).days

    def get_student_grade_info(self):
        """Get formatted student grade and strand info"""
        if self.student:
            return self.student.get_full_grade_section()
        return "N/A"

    def __str__(self):
        student_display = self.student_name if self.student_name else (self.student.user.username if self.student else "Unknown")
        return f"{self.get_violation_name()} - {student_display}"

    class Meta:
        ordering = ['-created_at']


# ✅ NEW MODEL: Track counseling sessions for report verification
class CounselingSession(models.Model):
    """Track counseling sessions for report verification"""
    STATUS_CHOICES = [
        ('scheduled', 'Scheduled'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
        ('no_show', 'Student No Show'),
        ('rescheduled', 'Rescheduled'),
    ]
    
    report = models.ForeignKey(Report, on_delete=models.CASCADE, related_name='counseling_sessions')
    counselor = models.ForeignKey(Counselor, on_delete=models.CASCADE)
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    reporter = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True, related_name='counseling_as_reporter')
    
    scheduled_date = models.DateTimeField()
    actual_date = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='scheduled')
    
    # Attendance tracking
    student_attended = models.BooleanField(default=False)
    reporter_attended = models.BooleanField(default=False)
    
    # Session notes and outcome
    session_notes = models.TextField(blank=True, help_text="Detailed notes from the counseling session")
    case_verified = models.BooleanField(
        default=False,
        help_text="True if case is confirmed, False if dismissed"
    )
    
    # Notifications sent
    summons_sent = models.BooleanField(default=False)
    reminder_sent = models.BooleanField(default=False)
    
    # Additional context
    session_duration_minutes = models.IntegerField(null=True, blank=True)
    follow_up_required = models.BooleanField(default=False)
    next_session_date = models.DateTimeField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['-scheduled_date']
        verbose_name = 'Counseling Session'
        verbose_name_plural = 'Counseling Sessions'
    
    def __str__(self):
        status_icon = {
            'scheduled': '📅',
            'completed': '✅',
            'cancelled': '❌',
            'no_show': '⚠️',
            'rescheduled': '🔄'
        }.get(self.status, '📋')
        
        return f"{status_icon} {self.report.title} - {self.scheduled_date.strftime('%Y-%m-%d %H:%M')}"

class ViolationHistory(models.Model):
    """Track violation patterns for individual students"""
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='violation_history')
    report = models.OneToOneField(Report, on_delete=models.CASCADE)
    violation_count = models.IntegerField(default=1)
    is_repeat_offense = models.BooleanField(default=False)
    previous_violation_date = models.DateTimeField(null=True, blank=True)
    
    # NEW: Track violations across different academic levels
    violations_in_current_grade = models.IntegerField(default=1)
    violations_in_strand = models.IntegerField(default=0,
                                             help_text="For SHS students - violations within the same strand")
    
    created_at = models.DateTimeField(auto_now_add=True)

    def update_violation_counts(self):
        """Update violation counts for this student"""
        # Count violations in current grade
        current_grade_violations = ViolationHistory.objects.filter(
            student=self.student,
            report__student__grade_level=self.student.grade_level
        ).count()
        self.violations_in_current_grade = current_grade_violations
        
        # Count violations in current strand (for SHS students)
        if self.student.strand:
            strand_violations = ViolationHistory.objects.filter(
                student=self.student,
                report__student__strand=self.student.strand
            ).count()
            self.violations_in_strand = strand_violations
        
        self.save()

    class Meta:
        unique_together = ['student', 'report']

class CounselorAction(models.Model):
    """Track counselor actions and interventions"""
    ACTION_CHOICES = [
        ('counseling', 'Individual Counseling'),
        ('group_session', 'Group Session'),
        ('parent_meeting', 'Parent Meeting'),
        ('academic_support', 'Academic Support'),
        ('career_counseling', 'Career Counseling'),
        ('referral', 'External Referral'),
        ('suspension', 'Suspension Recommended'),
        ('warning', 'Verbal Warning'),
        ('detention', 'Detention'),
        ('community_service', 'Community Service'),
        ('follow_up', 'Follow-up Session'),
        ('peer_mediation', 'Peer Mediation'),
        ('behavioral_contract', 'Behavioral Contract'),
    ]

    report = models.ForeignKey(Report, on_delete=models.CASCADE, related_name='counselor_actions')
    counselor = models.ForeignKey(Counselor, on_delete=models.CASCADE)
    action_type = models.CharField(max_length=50, choices=ACTION_CHOICES)
    description = models.TextField()
    scheduled_date = models.DateTimeField(null=True, blank=True)
    completed_date = models.DateTimeField(null=True, blank=True)
    is_completed = models.BooleanField(default=False)
    effectiveness_rating = models.IntegerField(null=True, blank=True, 
                                             help_text="Rate effectiveness 1-5")
    
    # NEW: Additional context for SHS students
    involves_academic_performance = models.BooleanField(default=False)
    involves_career_guidance = models.BooleanField(default=False)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.action_type} for {self.report.student.user.username}"

class Notification(models.Model):
    NOTIFICATION_TYPES = [
        ('system_alert', 'System Alert'),
        ('report_submitted', 'Report Submitted'),
        ('report_updated', 'Report Updated'),
        ('reminder', 'Reminder'),
        ('announcement', 'Announcement'),
        ('grade_promotion', 'Grade Promotion'),
        ('strand_change', 'Strand Change'),
    ]
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=200, blank=True, default='')
    message = models.TextField()
    type = models.CharField(max_length=20, choices=NOTIFICATION_TYPES, default='system_alert')
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    related_report = models.ForeignKey(Report, on_delete=models.CASCADE, null=True, blank=True)
    
    class Meta:
        ordering = ['-created_at']
        db_table = 'api_notification'
    
    def __str__(self):
        return f"{self.title} - {self.user.username}"
    
    # Backward compatibility properties
    @property
    def recipient(self):
        return self.user
    
    @property
    def notification_type(self):
        return self.type

class StudentViolationRecord(models.Model):
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('resolved', 'Resolved'),
        ('dismissed', 'Dismissed'),
        ('appealed', 'Under Appeal'),
    ]
    
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='violation_records')
    violation_type = models.ForeignKey(ViolationType, on_delete=models.CASCADE)
    counselor = models.ForeignKey(Counselor, on_delete=models.CASCADE)
    related_report = models.ForeignKey('Report', on_delete=models.CASCADE, blank=True, null=True)
    
    incident_date = models.DateTimeField()
    description = models.TextField()
    location = models.CharField(max_length=100, blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    counselor_notes = models.TextField(blank=True, null=True)
    action_taken = models.TextField(blank=True, null=True)
    
    # NEW: Academic context
    academic_quarter = models.CharField(max_length=10, blank=True, null=True,
                                       help_text="Q1, Q2, Q3, Q4")
    academic_year = models.CharField(max_length=10, blank=True, null=True,
                                    help_text="e.g., 2024-2025")
    
    recorded_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def get_academic_context(self):
        """Get formatted academic context"""
        context_parts = []
        if self.academic_year:
            context_parts.append(f"AY {self.academic_year}")
        if self.academic_quarter:
            context_parts.append(self.academic_quarter)
        return " - ".join(context_parts) if context_parts else "Not specified"

    class Meta:
        ordering = ['-recorded_at']

    def __str__(self):
        student_name = self.student.user.get_full_name() or self.student.user.username
        return f"{student_name} - {self.violation_type.name}"

class StudentViolationTally(models.Model):
    """Track violation tallies for each student - for quick reporting"""
    student = models.OneToOneField(Student, on_delete=models.CASCADE, related_name='violation_tally')
    
    # Total counts
    total_violations = models.IntegerField(default=0)
    active_violations = models.IntegerField(default=0)
    resolved_violations = models.IntegerField(default=0)
    
    # Severity counts
    low_severity_count = models.IntegerField(default=0)
    medium_severity_count = models.IntegerField(default=0)
    high_severity_count = models.IntegerField(default=0)
    critical_severity_count = models.IntegerField(default=0)
    
    # Category counts
    tardiness_violations = models.IntegerField(default=0)
    using_vape_cigarette_violations = models.IntegerField(default=0)
    misbehavior_violations = models.IntegerField(default=0)
    bullying_violations = models.IntegerField(default=0)
    gambling_violations = models.IntegerField(default=0)
    haircut_violations = models.IntegerField(default=0)
    not_wearing_uniform_violations = models.IntegerField(default=0)
    cheating_violations = models.IntegerField(default=0)
    cutting_classes_violations = models.IntegerField(default=0)
    absenteeism_violations = models.IntegerField(default=0)
    other_violations = models.IntegerField(default=0)
    
    # NEW: Academic period tracking
    current_grade_violations = models.IntegerField(default=0)
    current_strand_violations = models.IntegerField(default=0)  # For SHS students
    current_quarter_violations = models.IntegerField(default=0)
    
    # Tracking
    last_violation_date = models.DateTimeField(null=True, blank=True)
    first_violation_date = models.DateTimeField(null=True, blank=True)
    last_updated = models.DateTimeField(auto_now=True)

    def update_counts(self):
        """Recalculate all violation counts for this student"""
        violations = StudentViolationRecord.objects.filter(student=self.student)
        
        # Basic counts
        self.total_violations = violations.count()
        self.active_violations = violations.filter(status='active').count()
        self.resolved_violations = violations.filter(status='resolved').count()
        
        # Severity counts
        self.low_severity_count = violations.filter(violation_type__severity_level='Low').count()
        self.medium_severity_count = violations.filter(violation_type__severity_level='Medium').count()
        self.high_severity_count = violations.filter(violation_type__severity_level='High').count()
        self.critical_severity_count = violations.filter(violation_type__severity_level='Critical').count()
        
        # Category counts
        self.tardiness_violations = violations.filter(violation_type__category='Tardiness').count()
        self.using_vape_cigarette_violations = violations.filter(violation_type__category='Using Vape/Cigarette').count()
        self.misbehavior_violations = violations.filter(violation_type__category='Misbehavior').count()
        self.bullying_violations = violations.filter(violation_type__category='Bullying').count()
        self.gambling_violations = violations.filter(violation_type__category='Gambling').count()
        self.haircut_violations = violations.filter(violation_type__category='Haircut').count()
        self.not_wearing_uniform_violations = violations.filter(violation_type__category='Not Wearing Proper Uniform/ID').count()
        self.cheating_violations = violations.filter(violation_type__category='Cheating').count()
        self.cutting_classes_violations = violations.filter(violation_type__category='Cutting Classes').count()
        self.absenteeism_violations = violations.filter(violation_type__category='Absenteeism').count()
        self.other_violations = violations.filter(violation_type__category='Others').count()
        
        # Academic period counts
        if self.student.grade_level:
            self.current_grade_violations = violations.filter(
                student__grade_level=self.student.grade_level
            ).count()
        
        if self.student.strand:
            self.current_strand_violations = violations.filter(
                student__strand=self.student.strand
            ).count()
        
        # Date tracking
        if violations.exists():
            self.last_violation_date = violations.order_by('-incident_date').first().incident_date
            self.first_violation_date = violations.order_by('incident_date').first().incident_date
        
        self.save()
    
    def get_violation_summary(self):
        """Get a summary of violations for display"""
        return {
            'total': self.total_violations,
            'active': self.active_violations,
            'resolved': self.resolved_violations,
            'current_grade': self.current_grade_violations,
            'current_strand': self.current_strand_violations if self.student.strand else None,
        }
    
    class Meta:
        db_table = 'api_studentviolationtally'

    def __str__(self):
        student_name = self.student.user.get_full_name() or self.student.user.username
        return f"{student_name} - {self.total_violations} violations"

# NEW: Track strand changes for SHS students
class StrandChangeHistory(models.Model):
    CHANGE_REASONS = [
        ('academic_performance', 'Academic Performance'),
        ('career_interest', 'Change in Career Interest'),
        ('family_decision', 'Family Decision'),
        ('counselor_recommendation', 'Counselor Recommendation'),
        ('administrative', 'Administrative Decision'),
        ('other', 'Other'),
    ]
    
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='strand_changes')
    previous_strand = models.CharField(max_length=30, choices=Student.STRAND_CHOICES)
    new_strand = models.CharField(max_length=30, choices=Student.STRAND_CHOICES)
    previous_section = models.CharField(max_length=50, blank=True, null=True)
    new_section = models.CharField(max_length=50, blank=True, null=True)
    
    change_reason = models.CharField(max_length=30, choices=CHANGE_REASONS)
    reason_details = models.TextField(blank=True, null=True)
    
    approved_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    counselor_notes = models.TextField(blank=True, null=True)
    
    effective_date = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']
    
    def __str__(self):
        student_name = self.student.user.get_full_name() or self.student.user.username
        return f"{student_name}: {self.previous_strand} → {self.new_strand}"

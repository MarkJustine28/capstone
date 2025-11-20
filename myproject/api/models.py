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
    is_archived = models.BooleanField(default=False)
    
    # NEW: Add strand field for Senior High School
    strand = models.CharField(max_length=30, choices=STRAND_CHOICES, blank=True, null=True, 
                             help_text="Required for Grade 11 and 12 students")
    
    section = models.CharField(max_length=50, blank=True, null=True)
    
    # Contact Information
    contact_number = models.CharField(max_length=15, blank=True, null=True)
    guardian_name = models.CharField(max_length=100, blank=True, null=True)
    guardian_contact = models.CharField(max_length=15, blank=True, null=True)
    
    created_at = models.DateTimeField(auto_now_add=True)

    school_year = models.CharField(max_length=10, default='2024-2025')

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
        db_table = 'students'
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
    is_archived = models.BooleanField(default=False)
    
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

class StudentReport(models.Model):
    """Reports submitted by students (self-reporting incidents they experienced or witnessed)"""
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
    
    VERIFICATION_CHOICES = [
        ('pending', 'Pending Verification'),
        ('verified', 'Verified'),
        ('dismissed', 'Not Verified/Dismissed'),
    ]

    # Basic Information
    title = models.CharField(max_length=200)
    description = models.TextField()
    status = models.CharField(max_length=30, choices=REPORT_STATUS_CHOICES, default='pending')
    
    is_archived = models.BooleanField(default=False)

    # ✅ Verification status
    verification_status = models.CharField(
        max_length=20, 
        choices=VERIFICATION_CHOICES, 
        default='pending',
        help_text="Status of case verification through counseling"
    )
    
    # ✅ Reporter (the student who submitted the report)
    reporter_student = models.ForeignKey(
        Student, 
        on_delete=models.CASCADE, 
        related_name='submitted_reports',
        help_text="Student who submitted this report"
    )
    
    # ✅ Reported student (if reporting another student's violation)
    # Can be null if reporting their own incident
    reported_student = models.ForeignKey(
        Student, 
        on_delete=models.CASCADE, 
        related_name='received_reports',
        null=True,
        blank=True,
        help_text="Student being reported (leave blank if self-reporting)"
    )
    
    # Assigned counselor
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
    
    # ✅ Counseling session fields
    requires_counseling = models.BooleanField(default=True)
    counseling_date = models.DateTimeField(null=True, blank=True)
    counseling_notes = models.TextField(blank=True)
    counseling_completed = models.BooleanField(default=False)
    
    # ✅ Summons tracking - only for students involved
    summons_sent_at = models.DateTimeField(null=True, blank=True)
    summons_sent_to_reporter = models.BooleanField(
        default=False,
        help_text="Summons sent to the student who reported"
    )
    summons_sent_to_reported = models.BooleanField(
        default=False,
        help_text="Summons sent to the student being reported"
    )
    
    # ✅ Verification details
    verified_by = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='verified_student_reports'
    )
    verified_at = models.DateTimeField(null=True, blank=True)
    verification_notes = models.TextField(blank=True)
    
    # Counselor's notes
    counselor_notes = models.TextField(blank=True, null=True)
    
    # Timestamps
    incident_date = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    
    # ✅ School year tracking
    school_year = models.CharField(
        max_length=20, 
        blank=True, 
        null=True,
        help_text="School year when report was submitted (e.g., 2024-2025)"
    )
    
    # Context Information
    location = models.CharField(max_length=200, blank=True, null=True)
    witnesses = models.TextField(blank=True, null=True)
    follow_up_required = models.BooleanField(default=False)
    parent_notified = models.BooleanField(default=False)
    disciplinary_action = models.TextField(blank=True, null=True)
    
    # Review tracking
    is_reviewed = models.BooleanField(default=False)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    def is_self_report(self):
        """Check if this is a self-report"""
        return self.reported_student is None or self.reporter_student == self.reported_student

    def get_violation_name(self):
        """Get the violation name"""
        if self.violation_type:
            return self.violation_type.name
        return self.custom_violation or self.title

    def __str__(self):
        if self.is_self_report():
            return f"Self-Report: {self.get_violation_name()} by {self.reporter_student.user.username}"
        return f"{self.get_violation_name()} - {self.reporter_student.user.username} reported {self.reported_student.user.username}"

    class Meta:
        db_table = 'student_reports'
        ordering = ['-created_at']


class TeacherReport(models.Model):
    """Reports submitted by teachers about student violations"""
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
    
    VERIFICATION_CHOICES = [
        ('pending', 'Pending Verification'),
        ('verified', 'Verified'),
        ('dismissed', 'Not Verified/Dismissed'),
    ]

    # Basic Information
    title = models.CharField(max_length=200)
    description = models.TextField()
    status = models.CharField(max_length=30, choices=REPORT_STATUS_CHOICES, default='pending')
    
    is_archived = models.BooleanField(default=False)

    # ✅ Verification status
    verification_status = models.CharField(
        max_length=20, 
        choices=VERIFICATION_CHOICES, 
        default='pending'
    )
    
    # ✅ Reporter (the teacher who submitted the report)
    reporter_teacher = models.ForeignKey(
        Teacher, 
        on_delete=models.CASCADE, 
        related_name='submitted_reports',
        help_text="Teacher who submitted this report"
    )
    
    # ✅ Reported student
    reported_student = models.ForeignKey(
        Student, 
        on_delete=models.CASCADE, 
        related_name='teacher_reports',
        help_text="Student being reported by teacher"
    )
    
    # Assigned counselor
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
    
    # ✅ Counseling session fields
    requires_counseling = models.BooleanField(default=True)
    counseling_date = models.DateTimeField(null=True, blank=True)
    counseling_notes = models.TextField(blank=True)
    counseling_completed = models.BooleanField(default=False)
    
    # ✅ Summons tracking - only for reported student
    # (Teacher is not summoned, only the student)
    summons_sent_at = models.DateTimeField(null=True, blank=True)
    summons_sent_to_student = models.BooleanField(
        default=False,
        help_text="Summons sent to the reported student"
    )
    teacher_notified = models.BooleanField(
        default=False,
        help_text="Teacher notified about counseling session"
    )
    
    # ✅ Verification details
    verified_by = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='verified_teacher_reports'
    )
    verified_at = models.DateTimeField(null=True, blank=True)
    verification_notes = models.TextField(blank=True)
    
    # Counselor's notes
    counselor_notes = models.TextField(blank=True, null=True)
    
    # Timestamps
    incident_date = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    
    # ✅ School year tracking
    school_year = models.CharField(
        max_length=20, 
        blank=True, 
        null=True,
        help_text="School year when report was submitted"
    )
    
    # Context Information
    location = models.CharField(max_length=200, blank=True, null=True)
    witnesses = models.TextField(blank=True, null=True)
    follow_up_required = models.BooleanField(default=False)
    parent_notified = models.BooleanField(default=False)
    disciplinary_action = models.TextField(blank=True, null=True)
    
    # Academic context
    subject_involved = models.CharField(
        max_length=100, 
        blank=True, 
        null=True,
        help_text="Subject/course where incident occurred"
    )
    
    # Review tracking
    is_reviewed = models.BooleanField(default=False)
    reviewed_at = models.DateTimeField(null=True, blank=True)

    def get_violation_name(self):
        """Get the violation name"""
        if self.violation_type:
            return self.violation_type.name
        return self.custom_violation or self.title

    def __str__(self):
        return f"{self.get_violation_name()} - {self.reporter_teacher.user.username} reported {self.reported_student.user.username}"

    class Meta:
        db_table = 'teacher_reports'
        ordering = ['-created_at']

class ArchivedStudent(Student):
    """Proxy model for archived students"""
    class Meta:
        proxy = True
        verbose_name = 'Archived Student'
        verbose_name_plural = 'Archived Students'

class ArchivedTeacher(Teacher):
    """Proxy model for archived teachers"""
    class Meta:
        proxy = True
        verbose_name = 'Archived Teacher'
        verbose_name_plural = 'Archived Teachers'

class ArchivedStudentReport(StudentReport):
    """Proxy model for archived student reports"""
    class Meta:
        proxy = True
        verbose_name = 'Archived Student Report'
        verbose_name_plural = 'Archived Student Reports'

class ArchivedTeacherReport(TeacherReport):
    """Proxy model for archived teacher reports"""
    class Meta:
        proxy = True
        verbose_name = 'Archived Teacher Report'
        verbose_name_plural = 'Archived Teacher Reports'
        
class CounselingLog(models.Model):
    """Track counseling actions taken by counselors"""
    STATUS_CHOICES = [
        ('scheduled', 'Scheduled'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ]
    
    counselor = models.ForeignKey(Counselor, on_delete=models.CASCADE, related_name='counseling_logs')
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='counseling_logs')
    action_type = models.CharField(max_length=100)  # e.g., "Individual Counseling", "Group Session"
    description = models.TextField()
    scheduled_date = models.DateTimeField()
    completion_date = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='scheduled')
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    school_year = models.CharField(max_length=20)
    
    class Meta:
        ordering = ['-created_at']
        db_table = 'counseling_logs'
        
    def __str__(self):
        return f"{self.action_type} - {self.student.user.get_full_name()} by {self.counselor.user.get_full_name()}"
        
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
    
    # ✅ Generic relation to either StudentReport or TeacherReport
    student_report = models.ForeignKey(
        StudentReport, 
        on_delete=models.CASCADE, 
        related_name='counseling_sessions',
        null=True,
        blank=True
    )
    teacher_report = models.ForeignKey(
        TeacherReport, 
        on_delete=models.CASCADE, 
        related_name='counseling_sessions',
        null=True,
        blank=True
    )
    
    counselor = models.ForeignKey(Counselor, on_delete=models.CASCADE)
    
    # ✅ Students involved (can be 1 or 2)
    reporter_student = models.ForeignKey(
        Student, 
        on_delete=models.CASCADE,
        related_name='counseling_as_reporter',
        null=True,
        blank=True,
        help_text="Student who reported (if student report)"
    )
    reported_student = models.ForeignKey(
        Student, 
        on_delete=models.CASCADE,
        related_name='counseling_as_reported',
        null=True,
        blank=True,
        help_text="Student being counseled/reported"
    )
    
    scheduled_date = models.DateTimeField()
    actual_date = models.DateTimeField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='scheduled')
    
    # Attendance tracking
    reporter_attended = models.BooleanField(
        default=False,
        help_text="Did the reporter student attend?"
    )
    reported_attended = models.BooleanField(
        default=False,
        help_text="Did the reported student attend?"
    )
    
    # Session notes and outcome
    session_notes = models.TextField(blank=True)
    case_verified = models.BooleanField(default=False)
    
    # Notifications
    summons_sent = models.BooleanField(default=False)
    reminder_sent = models.BooleanField(default=False)
    
    # Additional context
    session_duration_minutes = models.IntegerField(null=True, blank=True)
    follow_up_required = models.BooleanField(default=False)
    next_session_date = models.DateTimeField(null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def get_report(self):
        """Get the associated report"""
        return self.student_report or self.teacher_report
    
    def is_student_report(self):
        """Check if this is for a student report"""
        return self.student_report is not None
    
    class Meta:
        ordering = ['-scheduled_date']
        verbose_name = 'Counseling Session'
        verbose_name_plural = 'Counseling Sessions'
    
    def __str__(self):
        report = self.get_report()
        report_type = "Student Report" if self.is_student_report() else "Teacher Report"
        return f"{report_type}: {report.title} - {self.scheduled_date.strftime('%Y-%m-%d %H:%M')}"

class ViolationHistory(models.Model):
    """Track violation patterns for individual students"""
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='violation_history')
    
    # ✅ Can be linked to either type of report
    student_report = models.OneToOneField(StudentReport, on_delete=models.CASCADE, null=True, blank=True)
    teacher_report = models.OneToOneField(TeacherReport, on_delete=models.CASCADE, null=True, blank=True)
    
    violation_count = models.IntegerField(default=1)
    is_repeat_offense = models.BooleanField(default=False)
    previous_violation_date = models.DateTimeField(null=True, blank=True)
    
    violations_in_current_grade = models.IntegerField(default=1)
    violations_in_strand = models.IntegerField(default=0)
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    def get_report(self):
        """Get the associated report"""
        return self.student_report or self.teacher_report

    class Meta:
        db_table = 'violation_history'

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

    # ✅ Can be linked to either type of report
    student_report = models.ForeignKey(
        StudentReport, 
        on_delete=models.CASCADE, 
        related_name='counselor_actions',
        null=True,
        blank=True
    )
    teacher_report = models.ForeignKey(
        TeacherReport, 
        on_delete=models.CASCADE, 
        related_name='counselor_actions',
        null=True,
        blank=True
    )
    
    counselor = models.ForeignKey(Counselor, on_delete=models.CASCADE)
    action_type = models.CharField(max_length=50, choices=ACTION_CHOICES)
    description = models.TextField()
    scheduled_date = models.DateTimeField(null=True, blank=True)
    completed_date = models.DateTimeField(null=True, blank=True)
    is_completed = models.BooleanField(default=False)
    effectiveness_rating = models.IntegerField(null=True, blank=True)
    
    involves_academic_performance = models.BooleanField(default=False)
    involves_career_guidance = models.BooleanField(default=False)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def get_report(self):
        """Get the associated report"""
        return self.student_report or self.teacher_report

    def __str__(self):
        report = self.get_report()
        if report:
            student = report.reported_student if hasattr(report, 'reported_student') else report.reporter_student
            return f"{self.action_type} for {student.user.username}"
        return f"{self.action_type}"
    
    class Meta:
        db_table = 'counselor_actions'

class Notification(models.Model):
    NOTIFICATION_TYPES = [
        ('system_alert', 'System Alert'),
        ('report_submitted', 'Report Submitted'),
        ('report_updated', 'Report Updated'),
        ('summons', 'Counseling Summons'),
        ('reminder', 'Reminder'),
        ('announcement', 'Announcement'),
    ]
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=200, blank=True, default='')
    message = models.TextField()
    type = models.CharField(max_length=20, choices=NOTIFICATION_TYPES, default='system_alert')
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    
    # ✅ Can be related to either report type
    related_student_report = models.ForeignKey(
        StudentReport, 
        on_delete=models.CASCADE, 
        null=True, 
        blank=True,
        related_name='notifications'
    )
    related_teacher_report = models.ForeignKey(
        TeacherReport, 
        on_delete=models.CASCADE, 
        null=True, 
        blank=True,
        related_name='notifications'
    )
    
    class Meta:
        ordering = ['-created_at']
        db_table = 'api_notification'
    
    def __str__(self):
        return f"{self.title} - {self.user.username}"

class StudentSchoolYearHistory(models.Model):
    """Track student section changes across school years"""
    student = models.ForeignKey(Student, on_delete=models.CASCADE, related_name='school_year_history')
    school_year = models.CharField(max_length=20)  # e.g., "2024-2025"
    grade_level = models.CharField(max_length=10)
    section = models.CharField(max_length=50)
    strand = models.CharField(max_length=50, blank=True, null=True)
    adviser = models.ForeignKey(Teacher, on_delete=models.SET_NULL, null=True, blank=True, related_name='advised_students_history')
    date_enrolled = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)  # Current school year enrollment
    
    class Meta:
        db_table = 'student_school_year_history'
        unique_together = ['student', 'school_year']
        ordering = ['-school_year', 'grade_level', 'section']
    
    def __str__(self):
        return f"{self.student.user.get_full_name()} - {self.school_year} ({self.grade_level} {self.section})"

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
    related_student_report = models.ForeignKey(
        StudentReport, 
        on_delete=models.CASCADE, 
        blank=True, 
        null=True,
        related_name='violation_records'
    )
    related_teacher_report = models.ForeignKey(
        TeacherReport, 
        on_delete=models.CASCADE, 
        blank=True, 
        null=True,
        related_name='violation_records'
    )
    
    incident_date = models.DateTimeField()
    description = models.TextField()
    location = models.CharField(max_length=100, blank=True, null=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='active')
    counselor_notes = models.TextField(blank=True, null=True)
    action_taken = models.TextField(blank=True, null=True)
    
    # Academic context
    academic_quarter = models.CharField(max_length=10, blank=True, null=True,
                                       help_text="Q1, Q2, Q3, Q4")
    academic_year = models.CharField(max_length=10, blank=True, null=True,
                                    help_text="e.g., 2024-2025")
    
    # ✅ UPDATED: School year tracking with auto-calculation
    school_year = models.CharField(max_length=20, blank=True, null=True)  # Changed from default to blank=True
    
    recorded_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        """Auto-populate school_year if not set"""
        if not self.school_year:
            from datetime import datetime
            current_year = datetime.now().year
            current_month = datetime.now().month
            # School year starts in June (month 6)
            if current_month >= 6:
                self.school_year = f"{current_year}-{current_year + 1}"
            else:
                self.school_year = f"{current_year - 1}-{current_year}"
        super().save(*args, **kwargs)

    @classmethod
    def get_total_violations_all_years(cls, student_id):
        """Get total violations for a student across ALL school years"""
        return cls.objects.filter(student_id=student_id).count()
    
    @classmethod
    def get_violations_by_school_year(cls, student_id):
        """Get violations grouped by school year"""
        from django.db.models import Count
        return cls.objects.filter(
            student_id=student_id
        ).values('school_year').annotate(
            count=Count('id'),
            first_incident=models.Min('incident_date'),
            last_incident=models.Max('incident_date')
        ).order_by('-school_year')

    def get_academic_context(self):
        """Get formatted academic context"""
        context_parts = []
        if self.school_year:
            context_parts.append(f"S.Y. {self.school_year}")
        if self.academic_quarter:
            context_parts.append(self.academic_quarter)
        return " - ".join(context_parts) if context_parts else "Not specified"

    class Meta:
        ordering = ['-recorded_at']

    def __str__(self):
        student_name = self.student.user.get_full_name() or self.student.user.username
        return f"{student_name} - {self.violation_type.name} ({self.school_year or 'N/A'})"

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

class SystemSettings(models.Model):
    """System-wide settings controlled by admin"""
    
    # School Year Management
    current_school_year = models.CharField(
        max_length=20,
        default='2024-2025',
        help_text='Current active school year (e.g., 2024-2025)'
    )
    school_year_start_date = models.DateField(
        null=True,
        blank=True,
        help_text='Official start date of current school year'
    )
    school_year_end_date = models.DateField(
        null=True,
        blank=True,
        help_text='Official end date of current school year'
    )
    
    # System Status
    is_system_active = models.BooleanField(
        default=True,
        help_text='Set to False to freeze system during breaks'
    )
    system_message = models.TextField(
        blank=True,
        null=True,
        help_text='Message to display when system is frozen'
    )
    
    # Metadata
    last_updated = models.DateTimeField(auto_now=True)
    updated_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='system_settings_updates'
    )
    
    class Meta:
        verbose_name = 'System Setting'
        verbose_name_plural = 'System Settings'
    
    def __str__(self):
        status = "ACTIVE" if self.is_system_active else "FROZEN"
        return f"System Settings - S.Y. {self.current_school_year} ({status})"
    
    @classmethod
    def get_current_settings(cls):
        """Get or create system settings singleton"""
        settings, created = cls.objects.get_or_create(id=1)
        if created:
            # Auto-detect current school year on first run
            settings.current_school_year = cls.auto_detect_school_year()
            settings.save()
        return settings
    
    @staticmethod
    def auto_detect_school_year():
        """
        Auto-detect school year based on DepEd calendar logic:
        - School year starts in June/July
        - If current month >= June, use current_year-next_year
        - If current month < June, use previous_year-current_year
        """
        now = timezone.now()
        current_year = now.year
        
        # DepEd school year typically starts in June
        if now.month >= 6:  # June onwards = new school year starts
            return f"{current_year}-{current_year + 1}"
        else:  # Jan-May = still in previous school year
            return f"{current_year - 1}-{current_year}"
    
    def save(self, *args, **kwargs):
        # Ensure only one settings record exists
        self.pk = 1
        super().save(*args, **kwargs)
    
    def delete(self, *args, **kwargs):
        # Prevent deletion
        pass
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import User, Group
from django.utils.html import format_html
from django.urls import reverse
from django.db.models import Count, Q
from .models import (
    Student, Teacher, Counselor, StudentReport, TeacherReport, ViolationType, 
    ViolationHistory, Notification, SystemSettings, ArchivedStudent, ArchivedTeacher, ArchivedStudentReport, ArchivedTeacherReport
)

# Customize admin site
admin.site.site_header = "Guidance Tracker Administration"
admin.site.site_title = "Guidance Tracker Admin"
admin.site.index_title = "Dashboard"


# ============= INLINE ADMINS =============

class StudentInline(admin.StackedInline):
    model = Student
    can_delete = False
    verbose_name_plural = 'Student Profile'
    fk_name = 'user'
    extra = 0
    fields = ['student_id', 'grade_level', 'section', 'strand', 'school_year', 'guardian_name', 'guardian_contact', 'contact_number']


class TeacherInline(admin.StackedInline):
    model = Teacher
    can_delete = False
    verbose_name_plural = 'Teacher Profile'
    fk_name = 'user'
    extra = 0


class CounselorInline(admin.StackedInline):
    model = Counselor
    can_delete = False
    verbose_name_plural = 'Counselor Profile'
    fk_name = 'user'
    extra = 0


# ============= USER ADMIN =============

class CustomUserAdmin(BaseUserAdmin):
    list_display = ['username', 'email', 'first_name', 'last_name', 'user_role', 'is_active', 'date_joined']
    list_filter = ['is_active', 'is_staff', 'is_superuser', 'date_joined']
    search_fields = ['username', 'first_name', 'last_name', 'email']
    ordering = ['-date_joined']
    actions = ['activate_users', 'deactivate_users']
    
    def user_role(self, obj):
        if hasattr(obj, 'student'):
            return 'Student'
        elif hasattr(obj, 'teacher'):
            return 'Teacher'
        elif hasattr(obj, 'counselor'):
            return 'Counselor'
        elif obj.is_superuser:
            return 'Super Admin'
        elif obj.is_staff:
            return 'Admin'
        else:
            return 'User'
    user_role.short_description = 'Role'
    
    def activate_users(self, request, queryset):
        updated = queryset.update(is_active=True)
        self.message_user(request, f'{updated} user(s) successfully activated.')
    activate_users.short_description = "Activate selected users"
    
    def deactivate_users(self, request, queryset):
        updated = queryset.update(is_active=False)
        self.message_user(request, f'{updated} user(s) successfully deactivated.')
    deactivate_users.short_description = "Deactivate selected users"
    
    def get_inline_instances(self, request, obj=None):
        if not obj:
            return []
        
        inlines = []
        if hasattr(obj, 'student'):
            inlines.append(StudentInline(self.model, self.admin_site))
        elif hasattr(obj, 'teacher'):
            inlines.append(TeacherInline(self.model, self.admin_site))
        elif hasattr(obj, 'counselor'):
            inlines.append(CounselorInline(self.model, self.admin_site))
        
        return inlines


# ============= STUDENT ADMIN =============

@admin.register(Student)
class StudentAdmin(admin.ModelAdmin):
    list_display = [
        'student_id', 
        'full_name',
        'grade_level', 
        'section', 
        'school_year', 
        'report_count',
        'is_archived'
    ]
    list_filter = ['grade_level', 'section', 'school_year', 'strand', 'is_archived']
    search_fields = ['student_id', 'user__first_name', 'user__last_name', 'user__username']
    ordering = ['student_id']
    actions = ['archive_students', 'restore_students', 'delete_permanently']

    def archive_teachers(self, request, queryset):
        count = 0
        for teacher in queryset:
            teacher.is_archived = True
            teacher.user.is_active = False  # Disable login
            teacher.user.save()
            teacher.save()
            count += 1
        self.message_user(request, f'{count} teacher(s) archived and login disabled.')
    archive_teachers.short_description = "Archive selected teachers"

    def restore_teachers(self, request, queryset):
        count = 0
        for teacher in queryset:
            teacher.is_archived = False
            teacher.user.is_active = True  # Re-enable login
            teacher.user.save()
            teacher.save()
            count += 1
        self.message_user(request, f'{count} teacher(s) restored and login enabled.')
    restore_teachers.short_description = "Restore selected teachers"

    def has_delete_permission(self, request, obj=None):
        return False

    def delete_permanently(self, request, queryset):
        count = 0
        for student in queryset:
            if student.is_archived:
                user = student.user
                student.delete()
                user.delete()
                count += 1
        self.message_user(request, f'{count} archived student(s) permanently deleted.')
    delete_permanently.short_description = "Delete permanently (archived only)"

    def get_actions(self, request):
        actions = super().get_actions(request)
        if 'delete_selected' in actions:
            del actions['delete_selected']
        return actions

    def full_name(self, obj):
        return obj.user.get_full_name() or obj.user.username
    full_name.short_description = 'Full Name'

    def report_count(self, obj):
        # Count both student and teacher reports for this student
        student_reports = obj.received_reports.count()
        teacher_reports = obj.teacher_reports.count()
        return student_reports + teacher_reports
    report_count.short_description = 'Report Count'

# ============= TEACHER ADMIN =============

@admin.register(Teacher)
class TeacherAdmin(admin.ModelAdmin):
    list_display = [
        'employee_id', 'full_name', 'approval_status',
        'advising_class_display', 'department', 'created_at', 'is_archived'
    ]
    list_filter = [
        'approval_status', 'is_approved', 'created_at', 'department',
        'advising_grade', 'advising_strand', 'is_archived'
    ]
    search_fields = [
        'employee_id', 'user__first_name', 'user__last_name',
        'user__username', 'user__email', 'advising_section'
    ]
    ordering = ['-created_at']
    actions = ['archive_teachers', 'restore_teachers', 'approve_teachers', 'reject_teachers', 'mark_pending']

    fieldsets = (
        ('User Account', {
            'fields': ('user',)
        }),
        ('Teacher Information', {
            'fields': ('employee_id', 'department', 'specialization')
        }),
        ('Advisory Class', {
            'fields': ('advising_grade', 'advising_strand', 'advising_section'),
            'classes': ('collapse',),
            'description': 'Assign this teacher as class adviser (optional)'
        }),
        ('Approval Status', {
            'fields': ('approval_status', 'is_approved', 'approved_by', 'approved_at', 'rejection_reason'),
            'description': 'Manage teacher account approval status'
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )

    readonly_fields = ['created_at', 'updated_at', 'approved_by', 'approved_at']

    def full_name(self, obj):
        full = f"{obj.user.first_name} {obj.user.last_name}".strip()
        email = f" ({obj.user.email})" if obj.user.email else ""
        return f"{full if full else obj.user.username}{email}"
    full_name.short_description = 'Full Name'

    def advising_class_display(self, obj):
        if not obj.advising_grade or not obj.advising_section:
            return "N/A"
        grade_display = f"Grade {obj.advising_grade}"
        if obj.advising_grade in ['11', '12'] and obj.advising_strand:
            return f"{grade_display} {obj.advising_strand} - {obj.advising_section}"
        else:
            return f"{grade_display} - {obj.advising_section}"
    advising_class_display.short_description = 'Advisory Class'

    def approval_status(self, obj):
        return obj.get_approval_status_display()
    approval_status.short_description = 'Status'

    # Batch actions
    def approve_teachers(self, request, queryset):
        from django.utils import timezone
        updated = 0
        for teacher in queryset.filter(approval_status='pending'):
            teacher.approval_status = 'approved'
            teacher.is_approved = True
            teacher.approved_by = request.user
            teacher.approved_at = timezone.now()
            teacher.user.is_active = True
            teacher.user.save()
            teacher.save()
            Notification.objects.create(
                user=teacher.user,
                title="Account Approved!",
                message=f"Your teacher account has been approved by {request.user.get_full_name()}. You now have full access to the Teacher Dashboard.",
                type='account_approved'
            )
            updated += 1
        self.message_user(request, f'{updated} teacher account(s) approved.')
    approve_teachers.short_description = "Approve Selected Teachers"

    def reject_teachers(self, request, queryset):
        updated = 0
        for teacher in queryset.filter(approval_status='pending'):
            teacher.approval_status = 'rejected'
            teacher.is_approved = False
            teacher.user.is_active = False
            teacher.rejection_reason = "Account rejected by administrator"
            teacher.user.save()
            teacher.save()
            Notification.objects.create(
                user=teacher.user,
                title="Account Rejected",
                message="Your teacher account application has been rejected. Please contact the administrator for more information.",
                type='account_rejected'
            )
            updated += 1
        self.message_user(request, f'{updated} teacher account(s) rejected.')
    reject_teachers.short_description = "Reject Selected Teachers"

    def mark_pending(self, request, queryset):
        updated = queryset.update(approval_status='pending', is_approved=False)
        self.message_user(request, f'{updated} teacher(s) marked as pending.')
    mark_pending.short_description = "Mark as Pending Review"

    def archive_teachers(self, request, queryset):
        updated = queryset.update(is_archived=True)
        self.message_user(request, f'{updated} teacher(s) archived.')
    archive_teachers.short_description = "Archive selected teachers"

    def restore_teachers(self, request, queryset):
        updated = queryset.update(is_archived=False)
        self.message_user(request, f'{updated} teacher(s) restored from archive.')
    restore_teachers.short_description = "Restore selected teachers"

    def has_delete_permission(self, request, obj=None):
        # Disable delete everywhere except for archived teachers
        if obj and hasattr(obj, 'is_archived'):
            return obj.is_archived
        return False

    def get_actions(self, request):
        actions = super().get_actions(request)
        # Remove default delete action
        if 'delete_selected' in actions:
            del actions['delete_selected']
        return actions

    def save_model(self, request, obj, form, change):
        from django.utils import timezone
        if change and 'approval_status' in form.changed_data:
            if obj.approval_status == 'approved':
                obj.is_approved = True
                obj.approved_by = request.user
                obj.approved_at = timezone.now()
                obj.user.is_active = True
                obj.user.save()
                Notification.objects.create(
                    user=obj.user,
                    title="Account Approved!",
                    message="Your teacher account has been approved. You now have full access.",
                    type='account_approved'
                )
            elif obj.approval_status == 'rejected':
                obj.is_approved = False
                obj.user.is_active = False
                obj.user.save()
                Notification.objects.create(
                    user=obj.user,
                    title="Account Rejected",
                    message=f"Reason: {obj.rejection_reason or 'Not specified'}",
                    type='account_rejected'
                )
        super().save_model(request, obj, form, change)


# ============= COUNSELOR ADMIN =============

@admin.register(Counselor)
class CounselorAdmin(admin.ModelAdmin):
    list_display = ['employee_id', 'full_name', 'specialization', 'reports_handled']
    list_filter = ['specialization']
    search_fields = ['employee_id', 'user__first_name', 'user__last_name', 'user__username']
    ordering = ['employee_id']
    
    def full_name(self, obj):
        full = f"{obj.user.first_name} {obj.user.last_name}".strip()
        return full if full else obj.user.username
    full_name.short_description = 'Full Name'
    
    def reports_handled(self, obj):
        student_reports = StudentReport.objects.filter(assigned_counselor=obj).count()
        teacher_reports = TeacherReport.objects.filter(assigned_counselor=obj).count()
        return f"{student_reports + teacher_reports} (S:{student_reports}, T:{teacher_reports})"
    reports_handled.short_description = 'Reports Handled'


# ============= STUDENT REPORT ADMIN =============

@admin.register(StudentReport)
class StudentReportAdmin(admin.ModelAdmin):
    list_display = [
        'id', 'title', 'get_reporter', 'get_reported', 'status', 
        'verification_status', 'school_year', 'created_at', 'is_archived'
    ]
    list_filter = [
        'status', 'verification_status', 'severity', 'school_year', 
        'requires_counseling', 'created_at', 'is_archived'
    ]
    search_fields = [
        'title', 'description', 'reporter_student__user__first_name', 
        'reporter_student__user__last_name', 'reported_student__user__first_name', 
        'reported_student__user__last_name'
    ]
    date_hierarchy = 'created_at'
    ordering = ['-created_at']
    actions = [
        'archive_reports', 'restore_reports', 
        'mark_as_reviewed', 'mark_as_resolved', 'send_summons'
    ]
    readonly_fields = [
        'created_at', 'updated_at', 'summons_sent_at', 'verified_at', 'resolved_at'
    ]
    
    fieldsets = (
        ('Report Information', {
            'fields': ('title', 'description', 'status', 'verification_status')
        }),
        ('Students Involved', {
            'fields': ('reporter_student', 'reported_student')
        }),
        ('Violation Details', {
            'fields': ('violation_type', 'custom_violation', 'severity', 'school_year')
        }),
        ('Counseling', {
            'fields': ('assigned_counselor', 'requires_counseling', 'counseling_date', 
                      'counseling_notes', 'counseling_completed')
        }),
        ('Summons & Verification', {
            'fields': ('summons_sent_at', 'summons_sent_to_reporter', 'summons_sent_to_reported',
                      'verified_by', 'verified_at', 'verification_notes')
        }),
        ('Additional Details', {
            'fields': ('location', 'witnesses', 'incident_date', 'counselor_notes',
                      'follow_up_required', 'parent_notified', 'disciplinary_action'),
            'classes': ('collapse',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at', 'resolved_at'),
            'classes': ('collapse',)
        }),
    )
    
    def get_reporter(self, obj):
        if obj.reporter_student:
            return obj.reporter_student.user.get_full_name() or obj.reporter_student.user.username
        return 'N/A'
    get_reporter.short_description = 'Reporter'
    
    def get_reported(self, obj):
        if obj.reported_student:
            return obj.reported_student.user.get_full_name() or obj.reported_student.user.username
        return 'Self-Report'
    get_reported.short_description = 'Reported Student'
    
    def mark_as_reviewed(self, request, queryset):
        updated = queryset.update(status='under_review', is_reviewed=True)
        self.message_user(request, f'{updated} report(s) marked as reviewed.')
    mark_as_reviewed.short_description = "Mark as Reviewed"
    
    def mark_as_resolved(self, request, queryset):
        from django.utils import timezone
        updated = queryset.update(status='resolved', resolved_at=timezone.now())
        self.message_user(request, f'{updated} report(s) marked as resolved.')
    mark_as_resolved.short_description = "Mark as Resolved"
    
    def send_summons(self, request, queryset):
        from django.utils import timezone
        updated = 0
        for report in queryset:
            if not report.summons_sent_at:
                report.summons_sent_at = timezone.now()
                report.summons_sent_to_reporter = True
                if report.reported_student:
                    report.summons_sent_to_reported = True
                report.status = 'summons_sent'
                report.save()
                updated += 1
        self.message_user(request, f'{updated} summons sent.')
    send_summons.short_description = "Send Summons"

    def archive_reports(self, request, queryset):
        updated = queryset.update(is_archived=True)
        self.message_user(request, f'{updated} report(s) archived.')
    archive_reports.short_description = "Archive selected reports"

    def restore_reports(self, request, queryset):
        updated = queryset.update(is_archived=False)
        self.message_user(request, f'{updated} report(s) restored from archive.')
    restore_reports.short_description = "Restore selected reports"


# ============= TEACHER REPORT ADMIN =============

@admin.register(TeacherReport)
class TeacherReportAdmin(admin.ModelAdmin):
    list_display = [
        'id', 'title', 'get_teacher', 'get_student', 'status',
        'verification_status', 'school_year', 'created_at', 'is_archived'
    ]
    list_filter = [
        'status', 'verification_status', 'severity', 'school_year',
        'requires_counseling', 'created_at', 'is_archived'
    ]
    search_fields = [
        'title', 'description', 'reporter_teacher__user__first_name', 'reporter_teacher__user__last_name',
        'reported_student__user__first_name', 'reported_student__user__last_name'
    ]
    date_hierarchy = 'created_at'
    ordering = ['-created_at']
    actions = [
        'archive_reports', 'restore_reports',
        'mark_as_reviewed', 'mark_as_resolved', 'send_summons_to_student'
    ]
    readonly_fields = ['created_at', 'updated_at', 'summons_sent_at', 'verified_at', 'resolved_at']

    fieldsets = (
        ('Report Information', {
            'fields': ('title', 'description', 'status', 'verification_status')
        }),
        ('Reporter & Student', {
            'fields': ('reporter_teacher', 'reported_student', 'subject_involved')
        }),
        ('Violation Details', {
            'fields': ('violation_type', 'custom_violation', 'severity', 'school_year')
        }),
        ('Counseling', {
            'fields': ('assigned_counselor', 'requires_counseling', 'counseling_date',
                      'counseling_notes', 'counseling_completed')
        }),
        ('Notifications', {
            'fields': ('summons_sent_at', 'summons_sent_to_student', 'teacher_notified',
                      'verified_by', 'verified_at', 'verification_notes')
        }),
        ('Additional Details', {
            'fields': ('location', 'witnesses', 'incident_date', 'counselor_notes',
                      'follow_up_required', 'parent_notified', 'disciplinary_action'),
            'classes': ('collapse',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at', 'resolved_at'),
            'classes': ('collapse',)
        }),
    )

    def get_teacher(self, obj):
        if obj.reporter_teacher:
            return obj.reporter_teacher.user.get_full_name() or obj.reporter_teacher.user.username
        return 'N/A'
    get_teacher.short_description = 'Reporting Teacher'

    def get_student(self, obj):
        if obj.reported_student:
            return obj.reported_student.user.get_full_name() or obj.reported_student.user.username
        return 'N/A'
    get_student.short_description = 'Student'

    def mark_as_reviewed(self, request, queryset):
        updated = queryset.update(status='under_review', is_reviewed=True)
        self.message_user(request, f'{updated} report(s) marked as reviewed.')
    mark_as_reviewed.short_description = "Mark as Reviewed"

    def mark_as_resolved(self, request, queryset):
        from django.utils import timezone
        updated = queryset.update(status='resolved', resolved_at=timezone.now())
        self.message_user(request, f'{updated} report(s) marked as resolved.')
    mark_as_resolved.short_description = "Mark as Resolved"

    def send_summons_to_student(self, request, queryset):
        from django.utils import timezone
        updated = 0
        for report in queryset:
            if not report.summons_sent_at:
                report.summons_sent_at = timezone.now()
                report.summons_sent_to_student = True
                report.teacher_notified = True
                report.status = 'summons_sent'
                report.save()
                updated += 1
        self.message_user(request, f'{updated} summons sent to students.')
    send_summons_to_student.short_description = "Send Summons to Student"

    def archive_reports(self, request, queryset):
        updated = queryset.update(is_archived=True)
        self.message_user(request, f'{updated} report(s) archived.')
    archive_reports.short_description = "Archive selected reports"

    def restore_reports(self, request, queryset):
        updated = queryset.update(is_archived=False)
        self.message_user(request, f'{updated} report(s) restored from archive.')
    restore_reports.short_description = "Restore selected reports"

    def has_delete_permission(self, request, obj=None):
        # Only allow delete for archived reports
        if obj and hasattr(obj, 'is_archived'):
            return obj.is_archived
        return False

    def get_actions(self, request):
        actions = super().get_actions(request)
        if 'delete_selected' in actions:
            del actions['delete_selected']
        return actions


# ============= VIOLATION TYPE ADMIN =============

@admin.register(ViolationType)
class ViolationTypeAdmin(admin.ModelAdmin):
    list_display = ['name', 'category', 'severity_level', 'is_active']
    list_filter = ['category', 'severity_level', 'is_active']
    search_fields = ['name', 'description']
    ordering = ['category', 'name']
    actions = ['activate_violations', 'deactivate_violations']
    
    def activate_violations(self, request, queryset):
        updated = queryset.update(is_active=True)
        self.message_user(request, f'{updated} violation type(s) activated.')
    activate_violations.short_description = "Activate selected"
    
    def deactivate_violations(self, request, queryset):
        updated = queryset.update(is_active=False)
        self.message_user(request, f'{updated} violation type(s) deactivated.')
    deactivate_violations.short_description = "Deactivate selected"


# ============= VIOLATION HISTORY ADMIN =============

@admin.register(ViolationHistory)
class ViolationHistoryAdmin(admin.ModelAdmin):
    list_display = ['id', 'student_name_display', 'get_report_type', 'created_at']
    list_filter = ['created_at']
    search_fields = ['student__user__first_name', 'student__user__last_name', 'student__student_id']
    date_hierarchy = 'created_at'
    ordering = ['-created_at']
    readonly_fields = ['created_at']
    
    def student_name_display(self, obj):
        return obj.student.user.get_full_name() or obj.student.user.username
    student_name_display.short_description = 'Student'
    
    def get_report_type(self, obj):
        if obj.student_report:
            return f'Student Report #{obj.student_report.id}'
        elif obj.teacher_report:
            return f'Teacher Report #{obj.teacher_report.id}'
        return 'N/A'
    get_report_type.short_description = 'Related Report'


# ============= NOTIFICATION ADMIN =============

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['id', 'user', 'title', 'type', 'is_read', 'created_at']
    list_filter = ['type', 'is_read', 'created_at']
    search_fields = ['title', 'message', 'user__username']
    date_hierarchy = 'created_at'
    ordering = ['-created_at']
    actions = ['mark_as_read', 'mark_as_unread']
    readonly_fields = ['created_at']
    
    def mark_as_read(self, request, queryset):
        updated = queryset.update(is_read=True)
        self.message_user(request, f'{updated} notification(s) marked as read.')
    mark_as_read.short_description = "Mark as Read"
    
    def mark_as_unread(self, request, queryset):
        updated = queryset.update(is_read=False)
        self.message_user(request, f'{updated} notification(s) marked as unread.')
    mark_as_unread.short_description = "Mark as Unread"


# Unregister default User admin and register custom one
admin.site.unregister(User)
admin.site.register(User, CustomUserAdmin)

@admin.register(SystemSettings)
class SystemSettingsAdmin(admin.ModelAdmin):
    list_display = ['current_school_year', 'is_system_active', 'school_year_start_date', 'school_year_end_date', 'last_updated']
    readonly_fields = ['last_updated', 'updated_by']
    
    fieldsets = (
        ('School Year Management', {
            'fields': ('current_school_year', 'school_year_start_date', 'school_year_end_date')
        }),
        ('System Status', {
            'fields': ('is_system_active', 'system_message')
        }),
        ('Metadata', {
            'fields': ('last_updated', 'updated_by'),
            'classes': ('collapse',)
        }),
    )
    
    def has_add_permission(self, request):
        # Only allow one settings instance
        return not SystemSettings.objects.exists()
    
    def has_delete_permission(self, request, obj=None):
        # Prevent deletion
        return False

# ============= ARCHIVED STUDENT ADMIN =============

@admin.register(ArchivedStudent)
class ArchivedStudentAdmin(admin.ModelAdmin):
    list_display = [
        'student_id', 'full_name', 'grade_level', 'section', 
        'school_year', 'report_count', 'created_at'
    ]
    list_filter = ['grade_level', 'section', 'school_year', 'strand']
    search_fields = ['student_id', 'user__first_name', 'user__last_name', 'user__username']
    ordering = ['student_id']
    actions = ['restore_students', 'delete_permanently']

    def get_queryset(self, request):
        return super().get_queryset(request).filter(is_archived=True)

    def full_name(self, obj):
        return obj.user.get_full_name() or obj.user.username
    full_name.short_description = 'Full Name'

    def report_count(self, obj):
        student_reports = obj.received_reports.count()
        teacher_reports = obj.teacher_reports.count()
        return student_reports + teacher_reports
    report_count.short_description = 'Report Count'

    def restore_students(self, request, queryset):
        count = 0
        for student in queryset:
            student.is_archived = False
            student.user.is_active = True  # Re-enable login
            student.user.save()
            student.save()
            count += 1
        self.message_user(request, f'{count} student(s) restored and login enabled.')
    restore_students.short_description = "Restore selected students"

    def delete_permanently(self, request, queryset):
        count = 0
        for student in queryset:
            user = student.user
            student.delete()
            user.delete()
            count += 1
        self.message_user(request, f'{count} student(s) permanently deleted.')
    delete_permanently.short_description = "Delete permanently"

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return True


# ============= ARCHIVED TEACHER ADMIN =============

@admin.register(ArchivedTeacher)
class ArchivedTeacherAdmin(admin.ModelAdmin):
    list_display = [
        'employee_id', 'full_name', 'department', 
        'advising_class_display', 'created_at'
    ]
    list_filter = ['department', 'advising_grade', 'advising_strand']
    search_fields = ['employee_id', 'user__first_name', 'user__last_name', 'user__username']
    ordering = ['-created_at']
    actions = ['restore_teachers', 'delete_permanently']

    def get_queryset(self, request):
        return super().get_queryset(request).filter(is_archived=True)

    def full_name(self, obj):
        return obj.user.get_full_name() or obj.user.username
    full_name.short_description = 'Full Name'

    def advising_class_display(self, obj):
        if not obj.advising_grade or not obj.advising_section:
            return "N/A"
        return obj.get_advising_info()
    advising_class_display.short_description = 'Advisory Class'

    def restore_teachers(self, request, queryset):
        count = 0
        for teacher in queryset:
            teacher.is_archived = False
            teacher.user.is_active = True  # Re-enable login
            teacher.user.save()
            teacher.save()
            count += 1
        self.message_user(request, f'{count} teacher(s) restored and login enabled.')
    restore_teachers.short_description = "Restore selected teachers"

    def delete_permanently(self, request, queryset):
        count = 0
        for teacher in queryset:
            user = teacher.user
            teacher.delete()
            user.delete()
            count += 1
        self.message_user(request, f'{count} teacher(s) permanently deleted.')
    delete_permanently.short_description = "Delete permanently"

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return True


# ============= ARCHIVED STUDENT REPORT ADMIN =============

@admin.register(ArchivedStudentReport)
class ArchivedStudentReportAdmin(admin.ModelAdmin):
    list_display = [
        'id', 'title', 'get_reporter', 'get_reported', 'status',
        'verification_status', 'school_year', 'created_at'
    ]
    list_filter = ['status', 'verification_status', 'severity', 'school_year']
    search_fields = ['title', 'description', 'reporter_student__user__username']
    date_hierarchy = 'created_at'
    ordering = ['-created_at']
    actions = ['restore_reports', 'delete_permanently']

    def get_queryset(self, request):
        return super().get_queryset(request).filter(is_archived=True)

    def get_reporter(self, obj):
        if obj.reporter_student:
            return obj.reporter_student.user.get_full_name() or obj.reporter_student.user.username
        return 'N/A'
    get_reporter.short_description = 'Reporter'

    def get_reported(self, obj):
        if obj.reported_student:
            return obj.reported_student.user.get_full_name() or obj.reported_student.user.username
        return 'Self-Report'
    get_reported.short_description = 'Reported Student'

    def restore_reports(self, request, queryset):
        updated = queryset.update(is_archived=False)
        self.message_user(request, f'{updated} report(s) restored from archive.')
    restore_reports.short_description = "Restore selected reports"

    def delete_permanently(self, request, queryset):
        count = queryset.count()
        queryset.delete()
        self.message_user(request, f'{count} report(s) permanently deleted.')
    delete_permanently.short_description = "Delete permanently"

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return True


# ============= ARCHIVED TEACHER REPORT ADMIN =============

@admin.register(ArchivedTeacherReport)
class ArchivedTeacherReportAdmin(admin.ModelAdmin):
    list_display = [
        'id', 'title', 'get_teacher', 'get_student', 'status',
        'verification_status', 'school_year', 'created_at'
    ]
    list_filter = ['status', 'verification_status', 'severity', 'school_year']
    search_fields = ['title', 'description', 'reporter_teacher__user__username']
    date_hierarchy = 'created_at'
    ordering = ['-created_at']
    actions = ['restore_reports', 'delete_permanently']

    def get_queryset(self, request):
        return super().get_queryset(request).filter(is_archived=True)

    def get_teacher(self, obj):
        if obj.reporter_teacher:
            return obj.reporter_teacher.user.get_full_name() or obj.reporter_teacher.user.username
        return 'N/A'
    get_teacher.short_description = 'Reporting Teacher'

    def get_student(self, obj):
        if obj.reported_student:
            return obj.reported_student.user.get_full_name() or obj.reported_student.user.username
        return 'N/A'
    get_student.short_description = 'Student'

    def restore_reports(self, request, queryset):
        updated = queryset.update(is_archived=False)
        self.message_user(request, f'{updated} report(s) restored from archive.')
    restore_reports.short_description = "Restore selected reports"

    def delete_permanently(self, request, queryset):
        count = queryset.count()
        queryset.delete()
        self.message_user(request, f'{count} report(s) permanently deleted.')
    delete_permanently.short_description = "Delete permanently"

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return True
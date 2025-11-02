from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import User, Group
from django.utils.html import format_html
from django.urls import reverse
from django.db.models import Count, Q
from .models import (
    Student, Teacher, Counselor, Report, ViolationType, 
    ViolationHistory, Notification
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
    fields = ['student_id', 'grade_level', 'section', 'strand', 'guardian_name', 'guardian_contact', 'contact_number']


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
    list_display = ['student_id', 'full_name', 'grade_level', 'section', 'violation_count']
    list_filter = ['grade_level', 'section']
    search_fields = ['student_id', 'user__first_name', 'user__last_name', 'user__username']
    ordering = ['student_id']
    
    def full_name(self, obj):
        full = f"{obj.user.first_name} {obj.user.last_name}".strip()
        return full if full else obj.user.username
    full_name.short_description = 'Full Name'
    
    def violation_count(self, obj):
        try:
            tally = obj.violation_tally
            count = tally.total_violations
            return f"{count} (L:{tally.low_severity_count} M:{tally.medium_severity_count} H:{tally.high_severity_count} C:{tally.critical_severity_count})"
        except:
            return "0"
    violation_count.short_description = 'Violations'


# ============= TEACHER ADMIN =============

@admin.register(Teacher)
class TeacherAdmin(admin.ModelAdmin):
    list_display = ['employee_id', 'full_name', 'approval_status', 'advising_class_display', 'department', 'created_at']
    list_filter = ['approval_status', 'is_approved', 'created_at', 'department', 'advising_grade', 'advising_strand']
    search_fields = ['employee_id', 'user__first_name', 'user__last_name', 'user__username', 'user__email', 'advising_section']
    ordering = ['-created_at']
    actions = ['approve_teachers', 'reject_teachers', 'mark_pending']
    
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
        count = Report.objects.filter(assigned_counselor=obj).count()
        return count
    reports_handled.short_description = 'Reports Handled'


# ============= REPORT ADMIN =============

@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = ['id', 'title', 'student_name_display', 'reporter', 'report_type', 'status', 'created_at']
    list_filter = ['report_type', 'status', 'created_at']
    search_fields = ['title', 'content', 'student__user__first_name', 'student__user__last_name', 'student_name']
    date_hierarchy = 'created_at'
    ordering = ['-created_at']
    actions = ['mark_as_reviewed', 'mark_as_resolved']
    readonly_fields = ['created_at', 'updated_at']
    
    def student_name_display(self, obj):
        if obj.student:
            return obj.student.user.get_full_name() or obj.student.user.username
        return obj.student_name or 'N/A'
    student_name_display.short_description = 'Student'
    
    def reporter(self, obj):
        if obj.reported_by:
            return f"{obj.reported_by.get_full_name() or obj.reported_by.username}"
        return 'Unknown'
    reporter.short_description = 'Reported By'
    
    def mark_as_reviewed(self, request, queryset):
        updated = queryset.update(status='reviewed', is_reviewed=True)
        self.message_user(request, f'{updated} report(s) marked as reviewed.')
    mark_as_reviewed.short_description = "Mark as Reviewed"
    
    def mark_as_resolved(self, request, queryset):
        updated = queryset.update(status='resolved')
        self.message_user(request, f'{updated} report(s) marked as resolved.')
    mark_as_resolved.short_description = "Mark as Resolved"


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
    list_display = ['id', 'student_name_display', 'violation_type_name', 'severity', 'recorded_by_name', 'created_at']
    list_filter = ['created_at']
    search_fields = ['student__user__first_name', 'student__user__last_name', 'student__student_id', 'notes']
    date_hierarchy = 'created_at'
    ordering = ['-created_at']
    readonly_fields = ['created_at']
    
    def student_name_display(self, obj):
        return obj.student.user.get_full_name() or obj.student.user.username
    student_name_display.short_description = 'Student'
    
    def violation_type_name(self, obj):
        return obj.violation_type.name if obj.violation_type else 'N/A'
    violation_type_name.short_description = 'Violation Type'
    
    def recorded_by_name(self, obj):
        return f"{obj.recorded_by.get_full_name() or obj.recorded_by.username}"
    recorded_by_name.short_description = 'Recorded By'
    
    def severity(self, obj):
        return obj.violation_type.severity_level.upper() if obj.violation_type else 'MEDIUM'
    severity.short_description = 'Severity'


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
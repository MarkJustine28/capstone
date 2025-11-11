from django.urls import path
from . import views

urlpatterns = [
    # Authentication
    path('login/', views.login_view, name='login'),
    path('register/', views.register_view, name='register'),  # ✅ Fixed: was 'register', now 'register_view'
    path('forgot-password/', views.forgot_password_view, name='forgot_password'),
    
    # Profile
    path('profile/', views.profile_view, name='profile'),
    
    # Teacher endpoints
    path('teacher/profile/', views.teacher_profile, name='teacher_profile'),
    path('teacher/advising-students/', views.teacher_advising_students, name='teacher_advising_students'),
    path('teacher/reports/', views.teacher_reports, name='teacher_reports'),
    path('teacher/notifications/', views.teacher_notifications, name='teacher_notifications'),
    
    # Student endpoints
    path('student/notifications/', views.student_notifications, name='student_notifications'),
    path('student/reports/', views.student_reports, name='student_reports'),
    
    # General endpoints
    path('students/', views.get_students_list, name='students_list'),
    path('violation-types/', views.violation_types, name='violation_types'),
    path('students-list/', views.get_students_list, name='students_list_alias'),
    path('get-violation-types/', views.get_violation_types, name='get_violation_types'),
    path('update-students-school-year/', views.update_students_school_year, name='update_students_school_year'),
    path('counselor/reports/<int:report_id>/send-guidance-notice/', views.send_guidance_notice, name='send_guidance_notice'),
    
    # Student management (counselor only)
    path('add-student/', views.add_student, name='add_student'),
    path('update-student/<int:student_id>/', views.update_student, name='update_student'),
    path('delete-student/<int:student_id>/', views.delete_student, name='delete_student'),
    
    # Violation management
    path('record-violation/', views.record_violation, name='record_violation'),
    path('mark-report-reviewed/', views.mark_report_reviewed, name='mark_report_reviewed'),
    
    # Counselor endpoints
    path('counselor/dashboard/', views.counselor_dashboard, name='counselor_dashboard'),
    path('counselor/dashboard-analytics/', views.counselor_dashboard_analytics, name='counselor_dashboard_analytics'),
    path('counselor/teacher-reports/', views.counselor_teacher_reports, name='counselor_teacher_reports'),
    path('counselor/student-reports/', views.counselor_student_reports, name='counselor_student_reports'),
    path('counselor/students/', views.counselor_students_list, name='counselor_students_list'),
    path('counselor/student-violations/', views.counselor_student_violations, name='counselor_student_violations'),
    path('counselor/violation-types/', views.counselor_violation_types, name='counselor_violation_types'),
    path('counselor/violation-analytics/', views.counselor_violation_analytics, name='counselor_violation_analytics'),
    path('counselor/update-teacher-report-status/<int:report_id>/', views.counselor_update_teacher_report_status, name='counselor_update_teacher_report_status'),
    path('counselor/reports/<int:report_id>/send-guidance-notice/', 
         views.send_guidance_notice, 
         name='send_guidance_notice'),
    
    # Reports
    path('reports/<int:report_id>/update-status/', views.update_report_status, name='update_report_status'),
    
    # 🆕 NEW: Counseling summons and report validation
    path('reports/<int:report_id>/send-summons/', views.send_counseling_summons, name='send_counseling_summons'),
    path('reports/<int:report_id>/mark-invalid/', views.mark_report_invalid, name='mark_report_invalid'),
    
    # Tally records
    path('tally-records/', views.tally_records, name='tally_records'),
    
    # Notifications
    path('notifications/', views.notifications_list, name='notifications_list'),
    path('notifications/<int:notification_id>/mark-read/', views.notification_mark_read, name='notification_mark_read'),
    path('notifications/mark-all-read/', views.notifications_mark_all_read, name='notifications_mark_all_read'),
    path('notifications/<int:notification_id>/', views.notification_delete, name='notification_delete'),
    path('notifications/unread-count/', views.notifications_unread_count, name='notifications_unread_count'),
    
    # Counseling notifications
    path('send-counseling-notification/', views.send_counseling_notification, name='send_counseling_notification'),
    path('send-bulk-notifications/', views.send_bulk_notifications, name='send_bulk_notifications'),

    # ✅ NEW: School year management
    path('admin/rollover-school-year/', views.rollover_school_year, name='rollover_school_year'),
    # ✅ NEW: Adviser section management
    path('teacher/advisory-section/', views.adviser_manage_section, name='adviser_manage_section'),
    # ✅ NEW: Student violation history
    path('students/<int:student_id>/violation-history/', views.get_student_violation_history, name='student_violation_history'),
]
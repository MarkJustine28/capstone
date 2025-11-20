from django.urls import path
from . import views

# Import all the view functions explicitly if needed
from .views import (
    login_view,
    register_view,
    forgot_password_view,
    profile_view,
    teacher_profile,
    teacher_advising_students,
    teacher_reports,
    teacher_notifications,
    student_notifications,
    student_reports,
    get_students_list,
    get_student_violations,
    violation_types,
    get_violation_types,
    add_student,
    update_student,
    delete_student,
    record_violation,
    mark_report_reviewed,
    counselor_teacher_reports,
    counselor_dashboard_analytics,
    counselor_update_teacher_report_status,
    tally_records,
    counselor_dashboard,
    counselor_student_reports,
    counselor_students_list,
    counselor_student_violations,
    counselor_violation_types,
    counselor_violation_analytics,
    update_report_status,
    send_counseling_notification,
    send_bulk_notifications,
    notifications_list,
    notification_mark_read,
    notifications_mark_all_read,
    notification_delete,
    notifications_unread_count,
    send_counseling_summons,
    mark_report_invalid,
    send_guidance_notice,
    update_students_school_year,
    rollover_school_year,
    adviser_manage_section,
    get_student_violation_history,
    get_available_school_years,
    get_counselor_dashboard_stats,
    promote_students,
    bulk_promote_grade,
    get_promotion_preview,
    student_profile,
    get_system_settings,
    update_system_settings,
    archived_students_list,
    restore_student,
    delete_student_permanent,
    bulk_add_students,
    create_system_report,
    get_counseling_logs,
    log_counseling_action,
    update_counseling_session
)

urlpatterns = [
    # Authentication
    path('login/', login_view, name='login'),
    path('register/', register_view, name='register'),
    path('forgot-password/', forgot_password_view, name='forgot_password'),
    path('profile/', profile_view, name='profile'),
    
    # Teacher endpoints
    path('teacher/profile/', teacher_profile, name='teacher_profile'),
    path('teacher/advising-students/', teacher_advising_students, name='teacher_advising_students'),
    path('teacher/reports/', teacher_reports, name='teacher_reports'),
    path('teacher/notifications/', teacher_notifications, name='teacher_notifications'),
    
    # Student endpoints
    path('student/profile/', student_profile, name='student_profile'),
    path('student/notifications/', student_notifications, name='student_notifications'),
    path('student/reports/', student_reports, name='student_reports'),
    
    # Counselor endpoints
    path('counselor/dashboard/', counselor_dashboard, name='counselor_dashboard'),
    path('counselor/dashboard/analytics/', counselor_dashboard_analytics, name='counselor_dashboard_analytics'),
    path('counselor/dashboard/stats/', get_counselor_dashboard_stats, name='get_counselor_dashboard_stats'),
    path('counselor/teacher-reports/', counselor_teacher_reports, name='counselor_teacher_reports'),
    path('counselor/teacher-reports/<int:report_id>/update-status/', counselor_update_teacher_report_status, name='counselor_update_teacher_report_status'),
    path('counselor/student-reports/', counselor_student_reports, name='counselor_student_reports'),
    path('counselor/students-list/', counselor_students_list, name='counselor_students_list'),
    path('counselor/student-violations/', counselor_student_violations, name='counselor_student_violations'),
    path('counselor/violation-types/', counselor_violation_types, name='counselor_violation_types'),
    path('counselor/violation-analytics/', counselor_violation_analytics, name='counselor_violation_analytics'),
    path('counselor/tally-records/', tally_records, name='tally_records'),
    path('counselor/available-school-years/', views.counselor_available_school_years, name='counselor_available_school_years'),
    
    path('record-violation/', views.record_violation, name='record_violation'),

    # ✅ ADD THESE COUNSELOR REPORT MANAGEMENT ROUTES:
    path('counselor/send-guidance-notice/<int:report_id>/', send_guidance_notice, name='counselor_send_guidance_notice'),
    path('counselor/update-report-status/<int:report_id>/', update_report_status, name='counselor_update_report_status'),
    path('counselor/mark-report-invalid/<int:report_id>/', mark_report_invalid, name='counselor_mark_report_invalid'),
    
    # General/shared endpoints
    path('students/', get_students_list, name='get_students_list'),
    path('students/add/', add_student, name='add_student'),
    path('students/<int:student_id>/', update_student, name='update_student'),
    path('students/<int:student_id>/delete/', delete_student, name='delete_student'),
    path('students/<int:student_id>/violation-history/', get_student_violation_history, name='get_student_violation_history'),
    path('counselor/bulk-add-students/', bulk_add_students, name='bulk_add_students'),

    path('violations/', get_student_violations, name='get_student_violations'),
    path('violations/record/', record_violation, name='record_violation'),
    path('violation-types/', violation_types, name='violation_types'),
    path('get-violation-types/', get_violation_types, name='get_violation_types'),
    
    # Report management (general - kept for backwards compatibility)
    path('reports/<int:report_id>/update-status/', update_report_status, name='update_report_status'),
    path('reports/<int:report_id>/mark-reviewed/', mark_report_reviewed, name='mark_report_reviewed'),
    path('reports/<int:report_id>/mark-invalid/', mark_report_invalid, name='mark_report_invalid'),
    path('reports/<int:report_id>/send-guidance-notice/', send_guidance_notice, name='send_guidance_notice'),
    path('reports/<int:report_id>/send-summons/', send_counseling_summons, name='send_counseling_summons'),
    
    # Notifications
    path('notifications/', notifications_list, name='notifications_list'),
    path('notifications/unread-count/', notifications_unread_count, name='notifications_unread_count'),
    path('notifications/<int:notification_id>/mark-read/', notification_mark_read, name='notification_mark_read'),
    path('notifications/mark-all-read/', notifications_mark_all_read, name='notifications_mark_all_read'),
    path('notifications/<int:notification_id>/delete/', notification_delete, name='notification_delete'),
    path('notifications/send-counseling/', send_counseling_notification, name='send_counseling_notification'),
    path('notifications/send-bulk/', send_bulk_notifications, name='send_bulk_notifications'),
    
    # School year management
    path('school-years/available/', get_available_school_years, name='get_available_school_years'),
    path('students/update-school-year/', update_students_school_year, name='update_students_school_year'),
    path('school-years/rollover/', rollover_school_year, name='rollover_school_year'),
    path('school-years/promote/', promote_students, name='promote_students'),
    path('school-years/bulk-promote/', bulk_promote_grade, name='bulk_promote_grade'),
    path('school-years/promotion-preview/', get_promotion_preview, name='get_promotion_preview'),
    
    # Adviser management
    path('adviser/manage-section/', adviser_manage_section, name='adviser_manage_section'),
    
    # System Settings
    path('system/settings/', get_system_settings, name='get_system_settings'),
    path('system/settings/update/', update_system_settings, name='update_system_settings'),

    path('search-students/', views.search_students, name='search-students'),

    path('students/archived/', archived_students_list, name='archived_students_list'),
    path('students/archived/<int:student_id>/restore/', restore_student, name='restore_student'),
    path('students/archived/<int:student_id>/delete/', delete_student_permanent, name='delete_student_permanent'),
    path('counselor/system-reports/', create_system_report, name='create_system_report'),

    path('counseling-logs/', get_counseling_logs, name='get_counseling_logs'),
    path('counseling-logs/create/', log_counseling_action, name='log_counseling_action'),
    path('counseling-logs/<int:session_id>/update/', update_counseling_session, name='update_counseling_session'),
]
import time
from django.shortcuts import render, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.models import User
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework import status
from rest_framework.authtoken.models import Token
from django.db import transaction, IntegrityError
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from django.db.models import Q, Count, Avg
import json
import logging
from django.db import models
from datetime import datetime

# Import your models (adjust these imports based on your actual models)
from .models import Student, Teacher, Counselor, StudentReport, TeacherReport, Notification, ViolationType, StudentViolationRecord, StudentViolationTally, StudentSchoolYearHistory, SystemSettings

# Set up logging
logger = logging.getLogger(__name__)

# Authentication Views
@csrf_exempt
@api_view(['POST'])
def login_view(request):
    try:
        data = json.loads(request.body)
        username = data.get('username')
        password = data.get('password')
        
        logger.info(f"Login attempt for username: {username}")
        
        if not username or not password:
            return Response({
                'success': False,
                'error': 'Username and password are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        user = authenticate(username=username, password=password)
        logger.info(f"Authentication result for {username}: {user is not None}")
        
        if user:
            # ✅ Check if user account is active
            if not user.is_active:
                logger.warning(f"❌ Inactive account login attempt: {username}")
                
                # ✅ Check if it's a teacher with pending approval
                if hasattr(user, 'teacher'):
                    teacher = user.teacher
                    approval_status = teacher.approval_status
                    
                    logger.info(f"Teacher approval status: {approval_status}")
                    
                    if approval_status == 'pending':
                        return Response({
                            'success': False,
                            'error': 'Your account is pending admin approval. Please wait for approval.',
                            'approval_status': 'pending'
                        }, status=status.HTTP_403_FORBIDDEN)
                    elif approval_status == 'rejected':
                        return Response({
                            'success': False,
                            'error': 'Your account has been rejected. Please contact the administrator.',
                            'approval_status': 'rejected'
                        }, status=status.HTTP_403_FORBIDDEN)
                
                # For other inactive accounts
                return Response({
                    'success': False,
                    'error': 'Your account has been deactivated. Please contact administration.'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # ✅ Double-check teacher approval status even if is_active=True
            if hasattr(user, 'teacher'):
                teacher = user.teacher
                if not teacher.is_approved or teacher.approval_status != 'approved':
                    logger.warning(f"❌ Unapproved teacher login attempt: {username}")
                    return Response({
                        'success': False,
                        'error': f'Your account is {teacher.get_approval_status_display().lower()}. Please wait for approval.',
                        'approval_status': teacher.approval_status
                    }, status=status.HTTP_403_FORBIDDEN)
            
            # ✅ User is authenticated and approved - generate token
            token, created = Token.objects.get_or_create(user=user)
            logger.info(f"Token created/retrieved for {username}: {token.key[:10]}...")
            
            # Determine user role with error handling
            role = 'student'  # default
            profile_data = {}
            
            try:
                if hasattr(user, 'teacher'):
                    logger.info(f"User {username} is a teacher")
                    role = 'teacher'
                    teacher = user.teacher
                    profile_data = {
                        'employee_id': getattr(teacher, 'employee_id', '') or '',
                        'department': getattr(teacher, 'department', '') or '',
                        'advising_grade': getattr(teacher, 'advising_grade', '') or '',
                        'advising_strand': getattr(teacher, 'advising_strand', '') or '',
                        'advising_section': getattr(teacher, 'advising_section', '') or '',
                        'approval_status': teacher.approval_status,
                        'is_approved': teacher.is_approved,
                    }
                    logger.info(f"Teacher profile data: {profile_data}")
                    
                elif hasattr(user, 'counselor'):
                    logger.info(f"User {username} is a counselor")
                    role = 'counselor'
                    counselor = user.counselor
                    profile_data = {
                        'employee_id': getattr(counselor, 'employee_id', '') or '',
                        'department': getattr(counselor, 'department', '') or '',
                    }
                    logger.info(f"Counselor profile data: {profile_data}")
                    
                elif hasattr(user, 'student'):
                    logger.info(f"User {username} is a student")
                    role = 'student'
                    student = user.student
                    profile_data = {
                        'student_id': getattr(student, 'student_id', '') or '',
                        'grade_level': getattr(student, 'grade_level', '') or '',
                        'section': getattr(student, 'section', '') or '',
                        'strand': getattr(student, 'strand', '') or '',
                    }
                    logger.info(f"Student profile data: {profile_data}")
                else:
                    logger.warning(f"User {username} has no associated profile (teacher/student/counselor)")
                    
            except Exception as profile_error:
                logger.error(f"Profile error for user {username}: {str(profile_error)}")
                logger.error(f"Profile error traceback: ", exc_info=True)
                # Continue with basic profile if there's an error
                profile_data = {}
            
            response_data = {
                'success': True,
                'token': token.key,
                'user': {
                    'id': user.id,
                    'username': user.username,
                    'first_name': user.first_name or '',
                    'last_name': user.last_name or '',
                    'email': user.email or '',
                    'role': role,
                    **profile_data
                },
                'message': f'Welcome back, {user.first_name or user.username}!'
            }
            
            logger.info(f"✅ Login successful for {username}, role: {role}")
            return Response(response_data)
            
        else:
            logger.warning(f"❌ Authentication failed for username: {username}")
            return Response({
                'success': False,
                'error': 'Invalid credentials'
            }, status=status.HTTP_401_UNAUTHORIZED)
            
    except json.JSONDecodeError as json_error:
        logger.error(f"JSON decode error: {str(json_error)}")
        return Response({
            'success': False,
            'error': 'Invalid JSON data'
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"❌ Login error: {str(e)}")
        logger.error(f"❌ Login traceback: ", exc_info=True)
        return Response({
            'success': False,
            'error': f'Login failed: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
@api_view(['POST'])
def register_view(request):
    try:
        data = json.loads(request.body)
        
        # Extract user data
        username = data.get('username')
        password = data.get('password')
        email = data.get('email')
        first_name = data.get('first_name', '')
        last_name = data.get('last_name', '')
        role = data.get('role', 'student')
        
        # Validate required fields
        if not all([username, password, email]):
            return Response({
                'success': False,
                'error': 'Username, password, and email are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Check if user already exists
        if User.objects.filter(username=username).exists():
            return Response({
                'success': False,
                'error': 'Username already exists'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        if User.objects.filter(email=email).exists():
            return Response({
                'success': False,
                'error': 'Email already registered'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        with transaction.atomic():
            # Create user
            user = User.objects.create_user(
                username=username,
                password=password,
                email=email,
                first_name=first_name,
                last_name=last_name,
                is_active=True if role != 'teacher' else False
            )
            
            logger.info(f"✅ User created: {username}, role: {role}, is_active: {user.is_active}")
            
            # Create role-specific profile
            if role == 'student':
                # ✅ Calculate current school year if not provided
                school_year = data.get('school_year')
                if not school_year:
                    current_year = datetime.now().year
                    current_month = datetime.now().month
                    school_year = f"{current_year}-{current_year + 1}" if current_month >= 6 else f"{current_year - 1}-{current_year}"
                
                # ✅ Generate student_id if not provided
                student_id = data.get('student_id', f"STU{user.id:06d}")
                
                student = Student.objects.create(
                    user=user,
                    student_id=student_id,
                    grade_level=data.get('grade_level', ''),
                    section=data.get('section', ''),
                    strand=data.get('strand', ''),
                    school_year=school_year,  # ✅ Save school_year
                    contact_number=data.get('contact_number', ''),
                    guardian_name=data.get('guardian_name', ''),
                    guardian_contact=data.get('guardian_contact', '')
                )
                logger.info(f"✅ Student profile created for {username} - School Year: {school_year}")
                
            elif role == 'teacher':
                # ✅ Create teacher with pending approval status
                teacher = Teacher.objects.create(
                    user=user,
                    employee_id=data.get('employee_id', ''),
                    department=data.get('department', ''),
                    specialization=data.get('specialization', ''),
                    advising_grade=data.get('advising_grade', ''),
                    advising_strand=data.get('advising_strand', ''),
                    advising_section=data.get('advising_section', ''),
                    approval_status='pending',  # ✅ Set to pending
                    is_approved=False,  # ✅ Not approved yet
                )
                
                logger.info(f"✅ Teacher profile created for {username} - Status: pending approval")
                
                # ✅ Notify all admins about new teacher registration
                admin_users = User.objects.filter(is_staff=True, is_active=True)
                for admin in admin_users:
                    Notification.objects.create(
                        user=admin,
                        title="New Teacher Registration",
                        message=(
                            f"New teacher registration requires approval:\n\n"
                            f"Name: {first_name} {last_name}\n"
                            f"Username: {username}\n"
                            f"Email: {email}\n"
                            f"Employee ID: {data.get('employee_id', 'Not provided')}\n"
                            f"Department: {data.get('department', 'Not provided')}\n\n"
                            f"Please review and approve/reject in the admin panel."
                        ),
                        type='teacher_reg'
                    )
                
                logger.info(f"✅ Notified {admin_users.count()} admin(s) about new teacher registration")
                
            elif role == 'counselor':
                Counselor.objects.create(
                    user=user,
                    employee_id=data.get('employee_id', ''),
                    department=data.get('department', ''),
                    specialization=data.get('specialization', '')
                )
                logger.info(f"✅ Counselor profile created for {username}")
            
            # ✅ Only create token for non-teachers or approved teachers
            if role == 'teacher':
                # Teachers in pending approval don't get token yet
                return Response({
                    'success': True,
                    'approval_status': 'pending',
                    'message': 'Registration submitted. Your account is pending admin approval.',
                    'user': {
                        'id': user.id,
                        'username': user.username,
                        'first_name': user.first_name,
                        'last_name': user.last_name,
                        'email': user.email,
                        'role': role
                    }
                }, status=status.HTTP_201_CREATED)
            else:
                # Students and counselors get immediate access
                token = Token.objects.create(user=user)
                
                return Response({
                    'success': True,
                    'approval_status': 'approved',
                    'token': token.key,
                    'user': {
                        'id': user.id,
                        'username': user.username,
                        'first_name': user.first_name,
                        'last_name': user.last_name,
                        'email': user.email,
                        'role': role
                    },
                    'message': 'Registration successful!'
                }, status=status.HTTP_201_CREATED)
            
    except json.JSONDecodeError:
        logger.error("❌ Invalid JSON data in registration")
        return Response({
            'success': False,
            'error': 'Invalid JSON data'
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"❌ Registration error: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': f'Registration failed: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
@api_view(['POST'])
def forgot_password_view(request):
    return Response({
        'success': True,
        'message': 'Password reset functionality not implemented yet'
    })

# Profile Views
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile_view(request):
    try:
        user = request.user
        profile_data = {
            'id': user.id,
            'username': user.username,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'email': user.email,
        }
        
        # Add role-specific data
        if hasattr(user, 'student'):
            student = user.student
            profile_data.update({
                'role': 'student',
                'student_id': getattr(student, 'student_id', '') or '',
                'grade_level': student.grade_level,
                'section': student.section,
                'strand': getattr(student, 'strand', '') or '',
                'contact_number': getattr(student, 'contact_number', '') or '',
                'guardian_name': getattr(student, 'guardian_name', '') or '',
                'guardian_contact': getattr(student, 'guardian_contact', '') or '',
            })
        elif hasattr(user, 'teacher'):
            teacher = user.teacher
            profile_data.update({
                'role': 'teacher',
                'employee_id': teacher.employee_id,
                'department': teacher.department,
                'advising_grade': teacher.advising_grade,
                'advising_strand': teacher.advising_strand,
                'advising_section': teacher.advising_section,
            })
        elif hasattr(user, 'counselor'):
            counselor = user.counselor
            profile_data.update({
                'role': 'counselor',
                'employee_id': counselor.employee_id,
                'department': counselor.department,
            })
        
        return Response({
            'success': True,
            'user': profile_data
        })
        
    except Exception as e:
        logger.error(f"Profile error: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to retrieve profile'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# Teacher Views
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def teacher_profile(request):
    """Get teacher profile information"""
    try:
        if not hasattr(request.user, 'teacher'):
            return Response({
                'success': False,
                'error': 'Teacher profile not found',
                'profile': None  # ✅ Add default profile
            }, status=status.HTTP_404_NOT_FOUND)
        
        teacher = request.user.teacher
        user = request.user
        
        # ✅ Build full name properly
        first_name = user.first_name or ''
        last_name = user.last_name or ''
        full_name = f"{first_name} {last_name}".strip()
        
        # If no name is set, use username as fallback
        if not full_name:
            full_name = user.username
        
        teacher_data = {
            'id': teacher.id,
            'user_id': user.id,
            'username': user.username,
            'first_name': first_name,
            'last_name': last_name,
            'full_name': full_name,  # ✅ Add explicit full_name field
            'email': user.email or '',
            'employee_id': teacher.employee_id or '',
            'department': teacher.department or '',
            'advising_grade': teacher.advising_grade or '',
            'advising_strand': teacher.advising_strand or '',
            'advising_section': teacher.advising_section or '',
            'contact_number': getattr(teacher, 'contact_number', '') or '',  # ✅ Add if field exists
            'created_at': teacher.created_at.isoformat() if hasattr(teacher, 'created_at') and teacher.created_at else None,
        }
        
        logger.info(f"✅ Teacher profile retrieved: {full_name} ({user.username})")
        
        return Response({
            'success': True,
            'profile': teacher_data,  # ✅ Changed from 'teacher' to 'profile' for consistency
            'message': 'Teacher profile retrieved successfully'
        })
        
    except Exception as e:
        logger.error(f"❌ Teacher profile error: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e),
            'profile': None  # ✅ Add default profile
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def teacher_advising_students(request):
    """Get students in teacher's advising section"""
    try:
        if not hasattr(request.user, 'teacher'):
            return Response({
                'success': False,
                'error': 'Teacher profile not found',
                'students': []
            }, status=status.HTTP_404_NOT_FOUND)
        
        teacher = request.user.teacher
        
        # Check if teacher has an advising section
        if not teacher.advising_section:
            return Response({
                'success': True,
                'students': [],
                'message': 'No advising section assigned'
            })
        
        # Filter students ONLY by section (since that's what exists in your Student table)
        students_query = Student.objects.select_related('user').filter(
            section=teacher.advising_section
        )
        
        logger.info(f"🔍 Teacher: {teacher.user.username}")
        logger.info(f"🔍 Advising Section: {teacher.advising_section}")
        logger.info(f"🔍 Found {students_query.count()} students in section {teacher.advising_section}")
        
        students_data = []
        for student in students_query:
            students_data.append({
                'id': student.id,
                'user_id': student.user.id,
                'first_name': student.user.first_name or '',
                'last_name': student.user.last_name or '',
                'username': student.user.username,
                'email': student.user.email or '',
                'student_id': getattr(student, 'student_id', '') or f"STU-{student.id:04d}",
                'grade_level': getattr(student, 'grade_level', '') or '',
                'strand': getattr(student, 'strand', '') or '',
                'section': student.section or '',
                'contact_number': getattr(student, 'contact_number', '') or '',
                'guardian_name': getattr(student, 'guardian_name', '') or '',
                'guardian_contact': getattr(student, 'guardian_contact', '') or '',
                'created_at': student.created_at.isoformat() if hasattr(student, 'created_at') and student.created_at else None,
            })
        
        return Response({
            'success': True,
            'students': students_data,
            'total_count': len(students_data),
            'advising_info': {
                'section': teacher.advising_section or '',
                'grade': getattr(teacher, 'advising_grade', '') or '',
                'strand': getattr(teacher, 'advising_strand', '') or '',
            },
            'filter_applied': f"section = {teacher.advising_section}"
        })
        
    except Exception as e:
        logger.error(f"❌ Error fetching advising students: {str(e)}")
        return Response({
            'success': False,
            'error': str(e),
            'students': []
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def teacher_reports(request):
    """Get or create teacher reports"""
    
    if request.method == 'GET':
        try:
            # Get teacher profile
            teacher = Teacher.objects.get(user=request.user)
            
            # Get all reports submitted by this teacher
            reports = Report.objects.filter(
                reported_by=request.user,
                report_type='teacher_report'
            ).select_related('student', 'violation_type').order_by('-created_at')
            
            reports_data = []
            for report in reports:
                # Get student name from either student object or student_name field
                student_name = 'Unknown Student'
                if report.student:
                    student_name = f"{report.student.user.first_name} {report.student.user.last_name}".strip()
                    if not student_name:
                        student_name = report.student.user.username
                elif hasattr(report, 'student_name') and report.student_name:
                    student_name = report.student_name
                
                reports_data.append({
                    'id': report.id,
                    'title': report.title,
                    'content': report.content,
                    'status': report.status,
                    'incident_date': report.incident_date.isoformat() if report.incident_date else None,
                    'created_at': report.created_at.isoformat(),
                    'student_name': student_name,
                    'student_id': report.student.id if report.student else None,
                    'violation_type': report.violation_type.name if report.violation_type else report.custom_violation,
                    'is_reviewed': report.is_reviewed,
                    'reviewed_at': report.reviewed_at.isoformat() if report.reviewed_at else None,
                })
            
            return Response({
                'success': True,
                'reports': reports_data
            })
            
        except Teacher.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Teacher profile not found',
                'reports': []
            }, status=404)
        except Exception as e:
            print(f"❌ Error fetching teacher reports: {e}")
            return Response({
                'success': False,
                'error': str(e),
                'reports': []
            }, status=500)
    
    elif request.method == 'POST':
        try:
            data = request.data
            print(f"📝 Received report data: {data}")
            
            # Get teacher profile
            teacher = Teacher.objects.get(user=request.user)
            
            # Get student if student_id is provided (for advising section students)
            student = None
            student_name = data.get('student_name', '')
            
            # Check if reporting student from advising section
            if not data.get('is_other_student', False) and data.get('student_id'):
                try:
                    student = Student.objects.get(id=data['student_id'])
                    student_name = f"{student.user.first_name} {student.user.last_name}".strip()
                    if not student_name:
                        student_name = student.user.username
                    print(f"✅ Found student: {student_name} (ID: {student.id})")
                except Student.DoesNotExist:
                    return Response({
                        'success': False,
                        'error': 'Student not found'
                    }, status=404)
            else:
                # Reporting other student - just use the name provided
                student = None
                student_name = data.get('student_name', data.get('other_student_name', ''))
                print(f"📝 Reporting other student: {student_name}")
            
            # Get violation type if provided
            violation_type = None
            if data.get('violation_type_id'):
                try:
                    violation_type = ViolationType.objects.get(id=data['violation_type_id'])
                except ViolationType.DoesNotExist:
                    pass
            
            # Parse incident date
            incident_date = None
            if data.get('incident_date'):
                try:
                    from django.utils import timezone
                    from datetime import datetime
                    
                    # Parse the GMT+8 datetime string
                    date_str = data['incident_date']
                    if '+' in date_str:
                        date_str = date_str.split('+')[0]
                    
                    incident_date = datetime.fromisoformat(date_str)
                    # Make it timezone-aware
                    if timezone.is_naive(incident_date):
                        incident_date = timezone.make_aware(incident_date)
                    
                    print(f"📅 Parsed incident date: {incident_date}")
                except Exception as e:
                    print(f"⚠️ Could not parse incident date: {e}")
                    incident_date = timezone.now()
            else:
                from django.utils import timezone
                incident_date = timezone.now()
            
            # Create the report - ONLY use fields that exist in the model
            report = Report.objects.create(
                student=student,  # Can be None for "other student" reports
                student_name=student_name,  # Store the name
                reported_by=request.user,
                title=data.get('title', 'Untitled Report'),
                content=data.get('content', ''),
                description=data.get('description', ''),  # Short description
                report_type='teacher_report',
                status=data.get('status', 'pending'),
                incident_date=incident_date,
                violation_type=violation_type,
                custom_violation=data.get('custom_violation'),
            )
            
            # ✅ ADD THIS DEBUG BLOCK
            logger.info(f"✅ Report created with ID: {report.id}, Status: {report.status}")
            logger.info(f"✅ Reported student: {reported_student.user.first_name} {reported_student.user.last_name} (ID: {reported_student.id})")
            logger.info(f"✅ Violation Type: {violation_type.name if violation_type else 'None'} (ID: {violation_type.id if violation_type else 'None'})")
            logger.info(f"✅ Violation Type ID passed in: {violation_type_id}")

            # ✅ Verify what's in the database
            saved_report = Report.objects.select_related('violation_type').get(id=report.id)
            logger.info(f"✅ VERIFICATION - Saved report violation_type: {saved_report.violation_type.name if saved_report.violation_type else 'None'}")
            logger.info(f"✅ VERIFICATION - Saved report violation_type ID: {saved_report.violation_type.id if saved_report.violation_type else 'None'}")
            print(f"✅ Report created successfully (ID: {report.id})")
            
            # Create notification for counselor
            try:
                counselors = User.objects.filter(counselor__isnull=False)
                for counselor_user in counselors:
                    Notification.objects.create(
                        user=counselor_user,
                        title=f"New Teacher Report: {report.title}",
                        message=f"Teacher {teacher.user.first_name} {teacher.user.last_name} reported: {student_name}",
                        type='report_submitted',
                        related_report=report
                    )
                print(f"✅ Notifications created for counselors")
            except Exception as e:
                print(f"⚠️ Could not create notifications: {e}")
            
            return Response({
                'success': True,
                'message': 'Report submitted successfully',
                'report': {
                    'id': report.id,
                    'title': report.title,
                    'status': report.status,
                    'student_name': student_name,
                    'created_at': report.created_at.isoformat(),
                }
            }, status=201)
            
        except Teacher.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Teacher profile not found'
            }, status=404)
        except Exception as e:
            print(f"❌ Error creating teacher report: {e}")
            import traceback
            traceback.print_exc()
            return Response({
                'success': False,
                'error': str(e)
            }, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def teacher_notifications(request):
    """Get notifications for the teacher"""
    try:
        notifications = Notification.objects.filter(
            user=request.user
        ).order_by('-created_at')
        
        notifications_data = []
        for notification in notifications:
            notifications_data.append({
                'id': notification.id,
                'title': notification.title,
                'message': notification.message,
                'type': getattr(notification, 'type', 'info'),
                'is_read': notification.is_read,
                'created_at': notification.created_at.isoformat(),
                'related_report_id': notification.related_report.id if hasattr(notification, 'related_report') and notification.related_report else None,
            })
        
        return Response({
            'success': True,
            'notifications': notifications_data,
            'unread_count': notifications.filter(is_read=False).count(),
            'total_count': len(notifications_data)
        })
        
    except Exception as e:
        logger.error(f"❌ Error fetching teacher notifications: {str(e)}")
        return Response({
            'success': False,
            'error': str(e),
            'notifications': []
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# Student Views
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def student_notifications(request):
    try:
        notifications = Notification.objects.filter(
            user=request.user
        ).order_by('-created_at')
        
        notifications_data = []
        for notification in notifications:
            notifications_data.append({
                'id': notification.id,
                'title': notification.title,
                'message': notification.message,
                'type': getattr(notification, 'type', 'info'),
                'is_read': notification.is_read,
                'created_at': notification.created_at.isoformat(),
            })
        
        return Response({
            'success': True,
            'notifications': notifications_data,
            'unread_count': notifications.filter(is_read=False).count()
        })
        
    except Exception as e:
        logger.error(f"Student notifications error: {str(e)}")
        return Response({
            'success': False,
            'error': 'Failed to fetch notifications'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
@api_view(['POST', 'GET'])
@permission_classes([IsAuthenticated])
def student_reports(request):
    """Handle student report submissions and retrieval"""
    
    if request.method == 'POST':
        # Handle report submission
        try:
            # Get the student instance
            try:
                student = Student.objects.get(user=request.user)
            except Student.DoesNotExist:
                logger.error(f"❌ Student profile not found for user: {request.user.username}")
                return Response({
                    'success': False,
                    'error': 'Student profile not found. Please contact administration.'
                }, status=400)
            
            # Extract data from request
            title = request.data.get('title', 'Incident Report')
            content = request.data.get('content', '')
            description = request.data.get('description', content)  # Use content as description if not provided
            violation_type_id = request.data.get('violation_type_id')
            custom_violation = request.data.get('custom_violation')
            incident_date = request.data.get('incident_date')
            reported_student_name = request.data.get('reported_student_name', '')
            severity = request.data.get('severity', 'medium')
            location = request.data.get('location', '')
            witnesses = request.data.get('witnesses', '')
            
            logger.info(f"📝 Report submission by: {student.user.username}")
            logger.info(f"📝 Student being reported: {reported_student_name}")
            logger.info(f"📝 Violation type ID: {violation_type_id}")
            
            # Validate required fields
            if not title or not description:
                return Response({
                    'success': False,
                    'error': 'Title and description are required'
                }, status=400)
            
            # Get violation type if provided
            violation_type = None
            if violation_type_id:
                try:
                    violation_type = ViolationType.objects.get(id=violation_type_id)
                    logger.info(f"📝 Found violation type: {violation_type.name}")
                except ViolationType.DoesNotExist:
                    logger.warning(f"📝 Violation type ID {violation_type_id} not found")
            
            # Parse incident date
            parsed_incident_date = None
            if incident_date:
                try:
                    from datetime import datetime
                    parsed_incident_date = datetime.fromisoformat(incident_date.replace('Z', '+00:00'))
                except Exception as e:
                    logger.warning(f"📝 Could not parse incident date: {e}")
                    parsed_incident_date = timezone.now()
            else:
                parsed_incident_date = timezone.now()
            
            # Find reported student (if reporting another student)
            reported_student = None
            if reported_student_name:
                try:
                    reported_student_name_clean = reported_student_name.strip()
                    logger.info(f"🔍 Searching for student: '{reported_student_name_clean}'")
                    
                    # Try to find the student by name
                    name_parts = reported_student_name_clean.split()
                    if len(name_parts) >= 2:
                        first_name = name_parts[0]
                        last_name = ' '.join(name_parts[1:])
                        
                        reported_student = Student.objects.filter(
                            user__first_name__iexact=first_name,
                            user__last_name__iexact=last_name
                        ).first()
                        
                        if reported_student:
                            logger.info(f"✅ Found student: {reported_student.user.first_name} {reported_student.user.last_name}")
                    
                    if not reported_student:
                        logger.warning(f"⚠️ Could not find student: '{reported_student_name_clean}'")
                        # For self-report or if student not found, set reported_student to reporter
                        reported_student = student
                        
                except Exception as e:
                    logger.error(f"❌ Error finding reported student: {e}")
                    reported_student = student  # Default to self-report
            else:
                # No student name provided - this is a self-report
                reported_student = student

            # ✅ CREATE STUDENTREPORT (not Report)
            report = StudentReport.objects.create(
                title=title,
                description=description,
                reporter_student=student,  # ✅ Who is submitting the report
                reported_student=reported_student,  # ✅ Who is being reported (can be same for self-report)
                violation_type=violation_type,
                custom_violation=custom_violation,
                severity=severity,
                status='pending',
                verification_status='pending',
                incident_date=parsed_incident_date,
                school_year=student.school_year,  # ✅ Auto-set from student
                location=location,
                witnesses=witnesses,
                requires_counseling=True,
            )

            logger.info(f"✅ StudentReport created: #{report.id}")
            logger.info(f"   Reporter: {student.student_id}")
            logger.info(f"   Reported: {reported_student.student_id if reported_student else 'N/A'}")
            logger.info(f"   School Year: {student.school_year}")
            
            # Create notification for counselors
            counselors = Counselor.objects.all()
            for counselor in counselors:
                Notification.objects.create(
                    user=counselor.user,
                    title='New Student Report Submitted',
                    message=f'Student {student.user.get_full_name() or student.user.username} submitted a report: {title}',
                    type='report_submitted',
                    related_student_report=report  # ✅ Use related_student_report
                )
            
            # Prepare response data
            report_data = {
                'id': report.id,
                'title': report.title,
                'description': report.description,
                'status': report.status,
                'verification_status': report.verification_status,
                'school_year': report.school_year,
                'created_at': report.created_at.isoformat(),
                'incident_date': report.incident_date.isoformat() if report.incident_date else None,
                'reporter': {
                    'id': request.user.id,
                    'name': f"{student.user.first_name} {student.user.last_name}".strip(),
                    'username': request.user.username,
                },
                'reported_student': {
                    'id': reported_student.id,
                    'name': f"{reported_student.user.first_name} {reported_student.user.last_name}".strip(),
                    'student_id': reported_student.student_id,
                } if reported_student else None,
                'violation_type': violation_type.name if violation_type else custom_violation,
                'is_self_report': report.is_self_report(),
            }
            
            return Response({
                'success': True,
                'message': 'Report submitted successfully.',
                'report': report_data
            }, status=201)
            
        except Exception as e:
            logger.error(f"❌ Error submitting report: {str(e)}")
            import traceback
            traceback.print_exc()
            return Response({
                'success': False,
                'error': f'Failed to submit report: {str(e)}'
            }, status=500)
    
    elif request.method == 'GET':
        # Handle fetching student's reports - ALREADY UPDATED IN PREVIOUS RESPONSE
        try:
            if not hasattr(request.user, 'student'):
                logger.error(f"❌ User {request.user.username} is not a student")
                return Response({
                    'success': False,
                    'error': 'Only students can view reports'
                }, status=status.HTTP_403_FORBIDDEN)
            
            student = request.user.student
            
            # Get reports where student is the reporter
            student_reports_as_reporter = StudentReport.objects.filter(
                reporter_student=student
            ).select_related('violation_type', 'assigned_counselor', 'reported_student__user')
            
            # Get reports where student is reported
            student_reports_as_reported = StudentReport.objects.filter(
                reported_student=student
            ).exclude(reporter_student=student).select_related('violation_type', 'assigned_counselor', 'reporter_student__user')
            
            teacher_reports = TeacherReport.objects.filter(
                reported_student=student
            ).select_related('violation_type', 'assigned_counselor', 'reporter_teacher__user')
            
            reports_data = []
            
            # Add reports where this student is the reporter
            for report in student_reports_as_reporter:
                reports_data.append({
                    'id': report.id,
                    'report_type': 'student_report',
                    'title': report.title,
                    'description': report.description,
                    'violation_type': report.violation_type.name if report.violation_type else report.custom_violation,
                    'severity': report.severity,
                    'status': report.status,
                    'verification_status': report.verification_status,
                    'school_year': report.school_year,
                    'role_in_report': 'reporter',
                    'reporter': student.user.get_full_name() or student.user.username,
                    'reported_student': (
                        report.reported_student.user.get_full_name() or report.reported_student.user.username
                    ) if report.reported_student else 'Self-Report',
                    'created_at': report.created_at.isoformat(),
                })
            
            # Add reports where this student is reported (by other students)
            for report in student_reports_as_reported:
                reports_data.append({
                    'id': report.id,
                    'report_type': 'student_report',
                    'title': report.title,
                    'description': report.description,
                    'violation_type': report.violation_type.name if report.violation_type else report.custom_violation,
                    'severity': report.severity,
                    'status': report.status,
                    'verification_status': report.verification_status,
                    'school_year': report.school_year,
                    'role_in_report': 'reported',
                    'reporter': (
                        report.reporter_student.user.get_full_name() or report.reporter_student.user.username
                    ),
                    'reported_student': student.user.get_full_name() or student.user.username,
                    'created_at': report.created_at.isoformat(),
                })
            
            # Add teacher reports
            for report in teacher_reports:
                reports_data.append({
                    'id': report.id,
                    'report_type': 'teacher_report',
                    'title': report.title,
                    'description': report.description,
                    'violation_type': report.violation_type.name if report.violation_type else report.custom_violation,
                    'severity': report.severity,
                    'status': report.status,
                    'verification_status': report.verification_status,
                    'school_year': report.school_year,
                    'role_in_report': 'reported',
                    'reporter': (
                        report.reporter_teacher.user.get_full_name() or report.reporter_teacher.user.username
                    ),
                    'reporter_type': 'teacher',
                    'reported_student': student.user.get_full_name() or student.user.username,
                    'created_at': report.created_at.isoformat(),
                })
            
            # Sort by created_at descending
            reports_data.sort(key=lambda x: x['created_at'], reverse=True)
            
            return Response({
                'success': True,
                'reports': reports_data,
                'total': len(reports_data),
            })
            
        except Exception as e:
            logger.error(f"❌ Error fetching reports: {str(e)}")
            return Response({
                'success': False,
                'error': str(e)
            }, status=500)

# General utility views (existing ones)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_students_list(request):
    """Get students list with optional school year filter"""
    try:
        # ✅ NEW: Get school year from query params
        school_year = request.GET.get('school_year', None)
        
        # Base query
        students_query = Student.objects.select_related('user')
        
        # ✅ NEW: Filter by school year if provided
        if school_year and school_year != 'all':
            students_query = students_query.filter(school_year=school_year)
            logger.info(f"📅 Filtering students by school year: {school_year}")
        
        students = students_query.order_by('user__last_name', 'user__first_name')
        
        students_data = []
        for student in students:
            students_data.append({
                'id': student.id,
                'student_id': student.student_id,
                'username': student.user.username,
                'first_name': student.user.first_name,
                'last_name': student.user.last_name,
                'email': student.user.email,
                'grade_level': student.grade_level,
                'section': student.section,
                'strand': student.strand,
                'school_year': student.school_year,  # ✅ Include school year
                'contact_number': student.contact_number,
                'guardian_name': student.guardian_name,
                'guardian_contact': student.guardian_contact,
            })
        
        return Response({
            'success': True,
            'students': students_data,
            'total': len(students_data),
            'filtered_by_school_year': school_year if school_year and school_year != 'all' else None,
        })
        
    except Exception as e:
        logger.error(f"❌ Error fetching students: {e}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_student_violations(request):
    """Get student violations with optional school year filter"""
    try:
        # ✅ NEW: Get school year from query params
        school_year = request.GET.get('school_year', None)
        
        # Base query
        violations_query = StudentViolationRecord.objects.select_related(
            'student__user',
            'violation_type',
            'counselor__user'
        )
        
        # ✅ NEW: Filter by school year if provided
        if school_year and school_year != 'all':
            violations_query = violations_query.filter(
                student__school_year=school_year
            )
            logger.info(f"📅 Filtering violations by school year: {school_year}")
        
        violations = violations_query.order_by('-incident_date')
        
        violations_data = []
        for v in violations:
            violations_data.append({
                'id': v.id,
                'student': {
                    'id': v.student.id,
                    'name': v.student.user.get_full_name(),
                    'student_id': v.student.student_id,
                    'grade_level': v.student.grade_level,
                    'section': v.student.section,
                    'school_year': v.student.school_year,  # ✅ Include school year
                },
                'violation_type': {
                    'id': v.violation_type.id if v.violation_type else None,
                    'name': v.violation_type.name if v.violation_type else 'Unknown',
                    'category': v.violation_type.category if v.violation_type else 'Unknown',
                },
                'severity_level': v.severity_level,
                'incident_date': v.incident_date.isoformat(),
                'description': v.description,
                'disciplinary_action': v.disciplinary_action,
                'status': v.status,
                'counselor': v.counselor.user.get_full_name() if v.counselor else None,
                'created_at': v.created_at.isoformat(),
            })
        
        return Response({
            'success': True,
            'violations': violations_data,
            'total': len(violations_data),
            'filtered_by_school_year': school_year if school_year and school_year != 'all' else None,
        })
        
    except Exception as e:
        logger.error(f"❌ Error fetching violations: {e}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def violation_types(request):
    """Get all violation types"""
    try:
        violation_types = ViolationType.objects.all().order_by('category', 'name')
        
        violation_types_data = []
        for vt in violation_types:
            violation_types_data.append({
                'id': vt.id,
                'name': vt.name,
                'description': vt.description or '',
                'category': vt.category,
                'severity_level': vt.severity_level,
                'points': getattr(vt, 'points', 0) or 0,
                'is_active': getattr(vt, 'is_active', True),
                'created_at': vt.created_at.isoformat() if hasattr(vt, 'created_at') else None,
            })
        
        return Response({
            'success': True,
            'violation_types': violation_types_data,
            'count': len(violation_types_data)
        })
        
    except Exception as e:
        logger.error(f"Violation types error: {str(e)}")
        return Response({
            'success': False,
            'error': str(e),
            'violation_types': [],
            'count': 0
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_violation_types(request):
    """Get violation types - alias for violation_types"""
    return violation_types(request)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_student(request):
    """Add a single student"""
    try:
        # Check if user is a counselor
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Access denied. Counselor role required.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        data = json.loads(request.body)
        
        # Create username from name
        first_name = data.get('first_name', '').strip()
        last_name = data.get('last_name', '').strip()
        
        if not first_name or not last_name:
            return Response({
                'success': False,
                'error': 'First name and last name are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Generate username
        base_username = f"{first_name.lower()}.{last_name.lower()}".replace(' ', '')
        username = base_username
        counter = 1
        while User.objects.filter(username=username).exists():
            username = f"{base_username}{counter}"
            counter += 1
        
        with transaction.atomic():
            # Create user
            user = User.objects.create_user(
                username=username,
                first_name=first_name,
                last_name=last_name,
                email=data.get('email', ''),
                password='student123'  # Default password
            )
            
            # Generate student ID
            student_id = data.get('student_id') or f"STU-{user.id:04d}"
            
            # Create student
            student = Student.objects.create(
                user=user,
                student_id=student_id,
                grade_level=data.get('grade_level'),
                section=data.get('section'),
                strand=data.get('strand', ''),
                contact_number=data.get('contact_number', ''),
                guardian_name=data.get('guardian_name', ''),
                guardian_contact=data.get('guardian_contact', '')
            )
        
        return Response({
            'success': True,
            'message': 'Student added successfully',
            'student': {
                'id': student.id,
                'username': username,
                'student_id': student_id,
                'name': f"{first_name} {last_name}"
            }
        }, status=status.HTTP_201_CREATED)
        
    except json.JSONDecodeError:
        return Response({
            'success': False,
            'error': 'Invalid JSON data'
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Add student error: {str(e)}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def update_student(request, student_id):
    """Update a student"""
    try:
        # Check if user is a counselor
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Access denied. Counselor role required.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student = Student.objects.get(id=student_id)
        except Student.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Student not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        data = json.loads(request.body)
        
        # Update user fields
        user = student.user
        if 'first_name' in data:
            user.first_name = data['first_name']
        if 'last_name' in data:
            user.last_name = data['last_name']
        if 'email' in data:
            user.email = data['email']
        user.save()
        
        # Update student fields
        if 'grade_level' in data:
            student.grade_level = data['grade_level']
        if 'section' in data:
            student.section = data['section']
        if 'strand' in data:
            student.strand = data['strand']
        if 'contact_number' in data:
            student.contact_number = data['contact_number']
        if 'guardian_name' in data:
            student.guardian_name = data['guardian_name']
        if 'guardian_contact' in data:
            student.guardian_contact = data['guardian_contact']
        
        student.save()
        
        return Response({
            'success': True,
            'message': 'Student updated successfully'
        })
        
    except json.JSONDecodeError:
        return Response({
            'success': False,
            'error': 'Invalid JSON data'
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        logger.error(f"Update student error: {str(e)}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_student(request, student_id):
    """Delete a student"""
    try:
        # Check if user is a counselor
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Access denied. Counselor role required.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student = Student.objects.get(id=student_id)
        except Student.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Student not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Delete the user (this will cascade delete the student)
        user = student.user
        user.delete()
        
        return Response({
            'success': True,
            'message': 'Student deleted successfully'
        })
        
    except Exception as e:
        logger.error(f"Delete student error: {str(e)}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def record_violation(request):
    """Record a new violation after report verification"""
    try:
        # Check if user is a counselor
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Access denied. Counselor role required.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        data = request.data
        logger.info(f"📝 Recording violation with data: {data}")
        
        student_id = data.get('student_id')
        violation_type_id = data.get('violation_type_id')
        
        if not student_id or not violation_type_id:
            return Response({
                'success': False,
                'error': 'Student ID and violation type ID are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            student = Student.objects.select_related('user').get(id=student_id)
            violation_type = ViolationType.objects.get(id=violation_type_id)
        except Student.DoesNotExist:
            logger.error(f"❌ Student with ID {student_id} not found")
            return Response({
                'success': False,
                'error': f'Student with ID {student_id} not found'
            }, status=status.HTTP_400_BAD_REQUEST)
        except ViolationType.DoesNotExist:
            logger.error(f"❌ Violation type with ID {violation_type_id} not found")
            return Response({
                'success': False,
                'error': f'Violation type with ID {violation_type_id} not found'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Parse incident date and make it timezone-aware
        incident_date = timezone.now()
        if data.get('incident_date'):
            try:
                parsed_date = parse_datetime(data.get('incident_date'))
                if parsed_date:
                    # Make timezone-aware if it's naive
                    if timezone.is_naive(parsed_date):
                        incident_date = timezone.make_aware(parsed_date)
                    else:
                        incident_date = parsed_date
            except Exception as e:
                logger.warning(f"⚠️ Could not parse incident_date: {e}")
                incident_date = timezone.now()
        
        # Get counselor
        counselor = request.user.counselor
        
        # Get related report if provided
        related_report = None
        if data.get('related_report_id'):
            try:
                related_report = Report.objects.get(id=data.get('related_report_id'))
            except Report.DoesNotExist:
                logger.warning(f"⚠️ Report {data.get('related_report_id')} not found")
        
        # Create violation record
        violation_record = StudentViolationRecord.objects.create(
            student=student,
            violation_type=violation_type,
            counselor=counselor,
            incident_date=incident_date,
            description=data.get('description', ''),
            location=data.get('location', ''),
            status=data.get('status', 'active'),
            counselor_notes=data.get('counselor_notes', ''),
            related_report=related_report,
        )
        
        logger.info(f"✅ Violation record created with ID: {violation_record.id}")
        
        # ✅ FIX: Update violation tally using the correct model structure
        # Get or create tally record for this student
        tally, created = StudentViolationTally.objects.get_or_create(
            student=student,
            defaults={
                'total_violations': 0,
                'first_violation_date': incident_date,
                'last_violation_date': incident_date,
            }
        )
        
        # ✅ Update the appropriate violation type field based on violation name
        violation_name = violation_type.name.lower()
        
        # Increment total violations
        tally.total_violations += 1
        tally.last_violation_date = incident_date
        
        # ✅ Increment specific violation type counter
        if 'bullying' in violation_name:
            tally.bullying_violations += 1
        elif 'tardiness' in violation_name or 'late' in violation_name:
            tally.tardiness_violations += 1
        elif 'absent' in violation_name:
            tally.absenteeism_violations += 1
        elif 'cutting' in violation_name or 'skip' in violation_name:
            tally.cutting_classes_violations += 1
        elif 'vape' in violation_name or 'cigarette' in violation_name or 'smoking' in violation_name:
            tally.using_vape_cigarette_violations += 1
        elif 'cheat' in violation_name:
            tally.cheating_violations += 1
        elif 'misbehavior' in violation_name or 'behavioral' in violation_name:
            tally.misbehavior_violations += 1
        elif 'gambl' in violation_name:
            tally.gambling_violations += 1
        elif 'uniform' in violation_name or 'dress code' in violation_name:
            tally.not_wearing_uniform_violations += 1
        elif 'hair' in violation_name:
            tally.haircut_violations += 1
        else:
            tally.other_violations += 1
        
        # Update severity counters
        severity = violation_type.severity_level.lower()
        if severity == 'low':
            tally.low_severity_count += 1
        elif severity == 'medium':
            tally.medium_severity_count += 1
        elif severity == 'high':
            tally.high_severity_count += 1
        elif severity == 'critical':
            tally.critical_severity_count += 1
        
        # Update active/resolved counters based on status
        if data.get('status', 'active').lower() in ['active', 'pending']:
            tally.active_violations += 1
        elif data.get('status', 'active').lower() in ['resolved', 'closed']:
            tally.resolved_violations += 1
        
        tally.save()
        
        logger.info(f"✅ Tally updated: {tally.total_violations} total violations for student {student.user.username}")
        
        # 🔔 Notify all counselors about the new violation
        counselors = Counselor.objects.select_related('user').all()
        
        for counselor_obj in counselors:
            if counselor_obj.user:
                student_name = f"{student.user.first_name} {student.user.last_name}".strip() or student.user.username
                
                notification_title = "🆕 New Violation Recorded"
                notification_message = (
                    f"A violation has been recorded for {student_name}.\n\n"
                    f"Violation Type: {violation_type.name}\n"
                    f"Category: {violation_type.category}\n"
                    f"Severity: {violation_type.severity_level}\n"
                    f"Total Count: {tally.total_violations}"
                )
                
                if data.get('description'):
                    notification_message += f"\n\nDescription: {data.get('description')}"
                
                create_notification(
                    user=counselor_obj.user,
                    title=notification_title,
                    message=notification_message,
                    notification_type='violation_recorded',
                    related_report=related_report
                )
        
        logger.info(f"✅ Notifications sent to {len(counselors)} counselor(s)")
        
        # 🔔 Notify the student about the violation
        if student.user:
            student_notification_title = "Violation Notice"
            student_notification_message = (
                f"A violation has been recorded in your file.\n\n"
                f"Violation Type: {violation_type.name}\n"
                f"Date: {incident_date.strftime('%B %d, %Y')}\n"
                f"Total Violations: {tally.total_violations}\n\n"
                f"Please visit the guidance office if you have any questions."
            )
            
            create_notification(
                user=student.user,
                title=student_notification_title,
                message=student_notification_message,
                notification_type='violation_recorded',
                related_report=related_report
            )
            
            logger.info(f"✅ Notification sent to student {student.user.username}")
        
        return Response({
            'success': True,
            'message': 'Violation recorded successfully and notifications sent',
            'violation': {
                'id': violation_record.id,
                'tally_count': tally.total_violations,
                'student_id': student.id,
                'student_name': f"{student.user.first_name} {student.user.last_name}".strip(),
                'violation_type': violation_type.name,
                'incident_date': incident_date.isoformat(),
            },
            'notifications_sent': len(counselors) + (1 if student.user else 0)
        }, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        logger.error(f"❌ Error recording violation: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': f'Failed to record violation: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_report_reviewed(request):
    """Mark a report as reviewed"""
    try:
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Access denied. Counselor role required.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        report_id = request.data.get('report_id')
        new_status = request.data.get('status', 'reviewed')
        
        if not report_id:
            return Response({
                'success': False,
                'error': 'Report ID is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            report = Report.objects.get(id=report_id)
            report.status = new_status
            report.save()
            
            return Response({
                'success': True,
                'message': f'Report marked as {new_status}',
                'report_id': report_id
            })
            
        except Report.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Report not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def counselor_teacher_reports(request):
    """Get all teacher-submitted reports for counselor review"""
    try:
        # ✅ FIX: Use TeacherReport instead of Report
        reports = TeacherReport.objects.select_related(
            'reported_student__user',
            'reporter_teacher__user',
            'violation_type',
            'assigned_counselor__user'
        ).order_by('-created_at')
        
        reports_data = []
        for report in reports:
            # Get student name
            student_name = 'Unknown Student'
            student_info = None
            if report.reported_student:
                student_name = f"{report.reported_student.user.first_name} {report.reported_student.user.last_name}".strip()
                if not student_name:
                    student_name = report.reported_student.user.username
                
                student_info = {
                    'id': report.reported_student.id,
                    'name': student_name,
                    'student_id': report.reported_student.student_id,
                    'grade_level': report.reported_student.grade_level,
                    'section': report.reported_student.section,
                }
            
            # Get reporter info
            reporter_info = None
            if report.reporter_teacher:
                reporter_info = {
                    'id': report.reporter_teacher.user.id,
                    'username': report.reporter_teacher.user.username,
                    'first_name': report.reporter_teacher.user.first_name,
                    'last_name': report.reporter_teacher.user.last_name,
                    'full_name': report.reporter_teacher.user.get_full_name(),
                }
            
            reports_data.append({
                'id': report.id,
                'title': report.title,
                'content': report.description,
                'description': report.description,
                'status': report.status,
                'verification_status': report.verification_status,
                'report_type': 'teacher_report',
                'incident_date': report.incident_date.isoformat() if report.incident_date else None,
                'created_at': report.created_at.isoformat(),
                'updated_at': report.updated_at.isoformat(),
                'student_id': report.reported_student.id if report.reported_student else None,
                'student_name': student_name,
                'student': student_info,
                'reported_student': student_info,
                'reported_by': reporter_info,
                'reporter': reporter_info,
                'reporter_type': 'teacher',
                'violation_type': report.violation_type.name if report.violation_type else report.custom_violation,
                'violation_type_id': report.violation_type.id if report.violation_type else None,
                'custom_violation': report.custom_violation,
                'severity_assessment': report.severity,
                'severity_level': report.severity,
                'is_reviewed': report.is_reviewed,
                'reviewed_at': report.reviewed_at.isoformat() if report.reviewed_at else None,
                'location': report.location,
                'witnesses': report.witnesses,
                'counselor_notes': report.counselor_notes,
                'school_year': report.school_year,
                'subject_involved': report.subject_involved if hasattr(report, 'subject_involved') else None,
            })
        
        logger.info(f"✅ Successfully fetched {len(reports_data)} teacher reports")
        
        return Response({
            'success': True,
            'reports': reports_data,
            'count': len(reports_data)
        })
        
    except Exception as e:
        logger.error(f"❌ Error fetching teacher reports: {e}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'message': f'Error fetching teacher reports: {str(e)}',
            'reports': []
        }, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def counselor_dashboard_analytics(request):
    """Get comprehensive analytics for counselor dashboard"""
    try:
        # Verify counselor authentication
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Counselor profile not found'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # ✅ Get school year filter from query params
        school_year = request.GET.get('school_year', None)
        logger.info(f"📊 Fetching dashboard analytics for school year: {school_year or 'all'}")
        
        # Base queries
        students_query = Student.objects.all()
        violations_query = StudentViolationRecord.objects.all()
        student_reports_query = StudentReport.objects.all()
        teacher_reports_query = TeacherReport.objects.all()
        
        # ✅ Apply school year filter if provided
        if school_year and school_year != 'all':
            students_query = students_query.filter(school_year=school_year)
            violations_query = violations_query.filter(student__school_year=school_year)
            student_reports_query = student_reports_query.filter(school_year=school_year)
            teacher_reports_query = teacher_reports_query.filter(school_year=school_year)
            logger.info(f"🔍 Filtering by school year: {school_year}")
        
        # Basic counts
        total_students = students_query.count()
        
        # ✅ Count both StudentReport and TeacherReport
        student_reports_count = student_reports_query.count()
        teacher_reports_count = teacher_reports_query.count()
        total_reports = student_reports_count + teacher_reports_count
        
        total_violations = violations_query.count()
        
        # ✅ Report status breakdown for both types
        pending_student_reports = student_reports_query.filter(status='pending').count()
        pending_teacher_reports = teacher_reports_query.filter(status='pending').count()
        pending_reports = pending_student_reports + pending_teacher_reports
        
        under_review_student = student_reports_query.filter(status='under_review').count()
        under_review_teacher = teacher_reports_query.filter(status='under_review').count()
        under_review_reports = under_review_student + under_review_teacher
        
        reviewed_student = student_reports_query.filter(status='reviewed').count()
        reviewed_teacher = teacher_reports_query.filter(status='reviewed').count()
        reviewed_reports = reviewed_student + reviewed_teacher
        
        resolved_student = student_reports_query.filter(status='resolved').count()
        resolved_teacher = teacher_reports_query.filter(status='resolved').count()
        resolved_reports = resolved_student + resolved_teacher
        
        # Violation analytics by type
        violation_type_counts = {}
        violation_records = violations_query.select_related('violation_type').all()
        
        for record in violation_records:
            if record.violation_type:
                type_name = record.violation_type.name
                if type_name not in violation_type_counts:
                    violation_type_counts[type_name] = {
                        'count': 0,
                        'category': record.violation_type.category,
                        'severity': record.violation_type.severity_level
                    }
                violation_type_counts[type_name]['count'] += 1
        
        # Sort by count and get top 5
        top_violations = sorted(
            violation_type_counts.items(),
            key=lambda x: x[1]['count'],
            reverse=True
        )[:5]
        
        # Monthly trend (last 6 months)
        from datetime import datetime, timedelta
        from django.db.models.functions import TruncMonth
        
        six_months_ago = datetime.now() - timedelta(days=180)
        
        # ✅ Combine monthly trends from both report types
        student_monthly = student_reports_query.filter(
            created_at__gte=six_months_ago
        ).annotate(
            month=TruncMonth('created_at')
        ).values('month').annotate(
            count=Count('id')
        ).order_by('month')
        
        teacher_monthly = teacher_reports_query.filter(
            created_at__gte=six_months_ago
        ).annotate(
            month=TruncMonth('created_at')
        ).values('month').annotate(
            count=Count('id')
        ).order_by('month')
        
        # Combine monthly data
        monthly_data = {}
        for item in student_monthly:
            month_key = item['month'].strftime('%Y-%m')
            if month_key not in monthly_data:
                monthly_data[month_key] = {'month': item['month'], 'student_reports': 0, 'teacher_reports': 0}
            monthly_data[month_key]['student_reports'] = item['count']
        
        for item in teacher_monthly:
            month_key = item['month'].strftime('%Y-%m')
            if month_key not in monthly_data:
                monthly_data[month_key] = {'month': item['month'], 'student_reports': 0, 'teacher_reports': 0}
            monthly_data[month_key]['teacher_reports'] = item['count']
        
        monthly_trends = []
        for key in sorted(monthly_data.keys()):
            data = monthly_data[key]
            monthly_trends.append({
                'month': data['month'].strftime('%B %Y'),
                'student_reports': data['student_reports'],
                'teacher_reports': data['teacher_reports'],
                'total': data['student_reports'] + data['teacher_reports']
            })
        
        # Status distribution for charts
        status_distribution = [
            {'status': 'Pending', 'count': pending_reports},
            {'status': 'Under Review', 'count': under_review_reports},
            {'status': 'Reviewed', 'count': reviewed_reports},
            {'status': 'Resolved', 'count': resolved_reports},
        ]
        
        # Recent activity (last 7 days)
        seven_days_ago = datetime.now() - timedelta(days=7)
        recent_student_reports = student_reports_query.filter(created_at__gte=seven_days_ago).count()
        recent_teacher_reports = teacher_reports_query.filter(created_at__gte=seven_days_ago).count()
        recent_reports_count = recent_student_reports + recent_teacher_reports
        recent_violations_count = violations_query.filter(
            incident_date__gte=seven_days_ago
        ).count()
        
        # ✅ Severity breakdown
        severity_breakdown = violations_query.values('violation_type__severity_level').annotate(
            count=Count('id')
        ).order_by('violation_type__severity_level')
        
        severity_data = {
            'low': 0,
            'medium': 0,
            'high': 0,
            'critical': 0
        }
        for item in severity_breakdown:
            level = (item.get('violation_type__severity_level') or 'medium').lower()
            severity_data[level] = item['count']
        
        # ✅ Grade-level breakdown
        students_by_grade = students_query.values('grade_level').annotate(
            count=Count('id')
        ).order_by('grade_level')
        
        grade_distribution = []
        for item in students_by_grade:
            grade = item['grade_level'] or 'Unknown'
            # Get violations for this grade
            grade_violations = violations_query.filter(
                student__grade_level=grade
            ).count()
            
            grade_distribution.append({
                'grade_level': grade,
                'student_count': item['count'],
                'violation_count': grade_violations
            })
        
        # ✅ Students with most violations (top 10)
        from django.db.models import Count as DBCount
        top_violators = violations_query.values(
            'student__id',
            'student__student_id',
            'student__user__first_name',
            'student__user__last_name',
            'student__grade_level',
            'student__section'
        ).annotate(
            violation_count=DBCount('id')
        ).order_by('-violation_count')[:10]
        
        top_violators_data = []
        for item in top_violators:
            full_name = f"{item['student__user__first_name']} {item['student__user__last_name']}".strip()
            top_violators_data.append({
                'student_id': item['student__student_id'],
                'name': full_name or 'Unknown',
                'grade_level': item['student__grade_level'],
                'section': item['student__section'],
                'violation_count': item['violation_count']
            })
        
        logger.info(f"✅ Dashboard analytics retrieved for counselor {counselor.user.username}")
        logger.info(f"   Total Students: {total_students}")
        logger.info(f"   Total Reports: {total_reports} (Student: {student_reports_count}, Teacher: {teacher_reports_count})")
        logger.info(f"   Total Violations: {total_violations}")
        logger.info(f"   Pending Reports: {pending_reports}")
        
        return Response({
            'success': True,
            'analytics': {
                'overview': {
                    'total_students': total_students,
                    'total_reports': total_reports,
                    'student_reports': student_reports_count,
                    'teacher_reports': teacher_reports_count,
                    'total_violations': total_violations,
                    'pending_reports': pending_reports,
                },
                'report_status': {
                    'pending': pending_reports,
                    'under_review': under_review_reports,
                    'reviewed': reviewed_reports,
                    'resolved': resolved_reports,
                },
                'report_breakdown': {
                    'student_reports': {
                        'total': student_reports_count,
                        'pending': pending_student_reports,
                        'under_review': under_review_student,
                        'reviewed': reviewed_student,
                        'resolved': resolved_student,
                    },
                    'teacher_reports': {
                        'total': teacher_reports_count,
                        'pending': pending_teacher_reports,
                        'under_review': under_review_teacher,
                        'reviewed': reviewed_teacher,
                        'resolved': resolved_teacher,
                    }
                },
                'status_distribution': status_distribution,
                'severity_breakdown': severity_data,
                'grade_distribution': grade_distribution,
                'top_violations': [
                    {
                        'name': name,
                        'count': data['count'],
                        'category': data['category'],
                        'severity': data['severity']
                    }
                    for name, data in top_violations
                ],
                'top_violators': top_violators_data,
                'monthly_trends': monthly_trends,
                'recent_activity': {
                    'reports_this_week': recent_reports_count,
                    'student_reports_this_week': recent_student_reports,
                    'teacher_reports_this_week': recent_teacher_reports,
                    'violations_this_week': recent_violations_count,
                }
            },
            'filtered_by_school_year': school_year if school_year and school_year != 'all' else None,
        })
        
    except Exception as e:
        logger.error(f"❌ Error fetching dashboard analytics: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def counselor_update_teacher_report_status(request, report_id):
    """Update teacher report status (same as update_report_status but explicit endpoint)"""
    return update_report_status(request, report_id)


# Add the tally_records function if missing:

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def tally_records(request):
    """Get or create tally records"""
    try:
        # Verify counselor
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Counselor profile not found'
            }, status=status.HTTP_403_FORBIDDEN)
        
        if request.method == 'GET':
            # Get all tally records
            tallies = StudentViolationTally.objects.select_related(
                'student',
                'student__user',
                'violation_type'
            ).all().order_by('-last_incident_date')
            
            tallies_data = []
            for tally in tallies:
                tallies_data.append({
                    'id': tally.id,
                    'student': {
                        'id': tally.student.id,
                        'name': f"{tally.student.user.first_name} {tally.student.user.last_name}",
                        'student_id': tally.student.student_id,
                    },
                    'violation_type': {
                        'id': tally.violation_type.id,
                        'name': tally.violation_type.name,
                        'category': tally.violation_type.category,
                        'severity': tally.violation_type.severity_level,
                    },
                    'count': tally.count,
                    'last_incident_date': tally.last_incident_date.isoformat() if tally.last_incident_date else None,
                    'created_at': tally.created_at.isoformat() if hasattr(tally, 'created_at') else None,
                })
            
            return Response({
                'success': True,
                'tallies': tallies_data,
                'count': len(tallies_data)
            })
        
        elif request.method == 'POST':
            # Create or update tally record
            student_id = request.data.get('student_id')
            violation_type_id = request.data.get('violation_type_id')
            
            if not student_id or not violation_type_id:
                return Response({
                    'success': False,
                    'error': 'student_id and violation_type_id are required'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            try:
                student = Student.objects.get(id=student_id)
                violation_type = ViolationType.objects.get(id=violation_type_id)
            except (Student.DoesNotExist, ViolationType.DoesNotExist):
                return Response({
                    'success': False,
                    'error': 'Invalid student or violation type'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Get or create tally
            tally, created = StudentViolationTally.objects.get_or_create(
                student=student,
                violation_type=violation_type,
                defaults={'count': 1, 'last_incident_date': timezone.now()}
            )
            
            if not created:
                tally.count += 1
                tally.last_incident_date = timezone.now()
                tally.save()
            
            return Response({
                'success': True,
                'message': 'Tally record updated',
                'tally': {
                    'id': tally.id,
                    'count': tally.count,
                    'last_incident_date': tally.last_incident_date.isoformat()
                }
            }, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"❌ Error with tally records: {str(e)}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def counselor_dashboard(request):
    """Get counselor dashboard data"""
    try:
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Access denied. Counselor role required.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Basic dashboard data
        return Response({
            'success': True,
            'message': 'Counselor dashboard data retrieved',
            'data': {
                'total_students': Student.objects.count(),
                'total_reports': Report.objects.count(),
                'pending_reports': Report.objects.filter(status='pending').count(),
                'violation_types_count': ViolationType.objects.count(),
            }
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def counselor_students_list(request):
    """
    Get list of all students with optional filtering
    Used by counselors to view student records
    """
    try:
        # Verify user is a counselor
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Only counselors can access this endpoint'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get school year parameter (optional)
        school_year = request.GET.get('school_year', None)
        
        logger.info(f"📊 Fetching students list, school_year parameter: {school_year}")
        
        # Base query - get all students with their user data
        students_query = Student.objects.select_related('user').order_by(
            'grade_level', 'section', 'user__last_name', 'user__first_name'
        )
        
        # Filter by school year if provided
        if school_year:
            students_query = students_query.filter(school_year=school_year)
            logger.info(f"🔍 Filtering by school year: {school_year}")
        
        # Serialize student data
        students_data = []
        for student in students_query:
            # Get violation count for this student
            violation_count = StudentViolationRecord.objects.filter(
                student=student,
                school_year=student.school_year
            ).count()
            
            student_data = {
                'id': student.id,
                'student_id': student.student_id,
                'user_id': student.user.id,
                'username': student.user.username,
                'email': student.user.email,
                'first_name': student.user.first_name,
                'last_name': student.user.last_name,
                'full_name': f"{student.user.first_name} {student.user.last_name}".strip(),
                'grade_level': student.grade_level,
                'strand': student.strand or '',
                'section': student.section,
                'school_year': student.school_year,
                'guardian_name': student.guardian_name or '',
                'guardian_contact': student.guardian_contact or '',
                'contact_number': student.contact_number or '',
                'violation_count': violation_count,
                'created_at': student.created_at.isoformat() if student.created_at else None,
            }
            students_data.append(student_data)
        
        logger.info(f"✅ Successfully fetched {len(students_data)} students")
        
        return Response({
            'success': True,
            'students': students_data,
            'total_count': len(students_data),
            'filtered_by_school_year': school_year
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"❌ Error fetching students: {str(e)}")
        logger.error(traceback.format_exc())
        return Response({
            'success': False,
            'error': f'Failed to fetch students: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def counselor_student_violations(request):
    """Get all student violations for counselor dashboard"""
    try:
        # Verify counselor authentication
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return JsonResponse({
                'success': False,
                'message': 'Counselor profile not found'
            }, status=403)

        # ✅ FIX: Update select_related to use new field names
        violations = StudentViolationRecord.objects.select_related(
            'student',
            'student__user',
            'violation_type',
            'counselor',
            'counselor__user',
            'related_student_report',  # ✅ Changed from 'related_report'
            'related_teacher_report'   # ✅ Added teacher report
        ).all().order_by('-incident_date')
        
        violations_data = []
        for violation in violations:
            try:
                # ✅ Get whichever report exists
                related_report = violation.related_student_report or violation.related_teacher_report
                
                violation_data = {
                    'id': violation.id,
                    'student_id': violation.student.id if violation.student else None,
                    'student': {
                        'id': violation.student.id,
                        'name': f"{violation.student.user.first_name} {violation.student.user.last_name}",
                        'student_id': violation.student.student_id,
                        'user_id': violation.student.user.id,
                        'grade_level': violation.student.grade_level,
                        'section': violation.student.section,
                    } if violation.student else None,
                    'violation_type': {
                        'id': violation.violation_type.id,
                        'name': violation.violation_type.name,
                        'category': violation.violation_type.category,
                        'severity_level': violation.violation_type.severity_level,
                    } if violation.violation_type else None,
                    'counselor': {
                        'id': violation.counselor.id,
                        'name': f"{violation.counselor.user.first_name} {violation.counselor.user.last_name}",
                    } if violation.counselor else None,
                    'incident_date': violation.incident_date.isoformat() if violation.incident_date else None,
                    'description': violation.description,
                    'location': violation.location,
                    'status': violation.status,
                    'severity_level': violation.violation_type.severity_level if violation.violation_type else 'Medium',
                    'counselor_notes': violation.counselor_notes,
                    'action_taken': violation.action_taken if hasattr(violation, 'action_taken') else '',
                    'recorded_at': violation.recorded_at.isoformat() if hasattr(violation, 'recorded_at') and violation.recorded_at else violation.incident_date.isoformat(),
                    
                    # ✅ Update these fields
                    'related_report_id': related_report.id if related_report else None,
                    'related_report': {
                        'id': related_report.id,
                        'title': related_report.title,
                        'status': related_report.status,
                        'report_type': 'student_report' if violation.related_student_report else 'teacher_report',
                    } if related_report else None,
                }
                
                violations_data.append(violation_data)
                
            except Exception as e:
                logger.warning(f"Error processing violation {violation.id}: {e}")
                continue

        logger.info(f"✅ Returning {len(violations_data)} student violations")
        
        tallied_count = sum(1 for v in violations_data if v.get('related_report_id'))
        
        return JsonResponse({
            'success': True,
            'violations': violations_data,
            'count': len(violations_data),
            'tallied_count': tallied_count,
        })

    except Exception as e:
        logger.error(f"Error fetching counselor student violations: {str(e)}")
        import traceback
        traceback.print_exc()
        return JsonResponse({
            'success': False,
            'message': f'Error fetching student violations: {str(e)}'
        }, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def counselor_violation_types(request):
    """Get violation types for counselor"""
    return violation_types(request)  # Reuse existing function

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def counselor_violation_analytics(request):
    """Get violation analytics for counselor dashboard"""
    try:
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Access denied. Counselor role required.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Basic analytics - you can expand this later
        violation_analytics = {}
        status_distribution = []
        monthly_trends = []
        
        # Get violation type counts
        violation_records = StudentViolationRecord.objects.select_related('violation_type').all()
        for record in violation_records:
            violation_name = record.violation_type.name if record.violation_type else 'Unknown'
            if violation_name not in violation_analytics:
                violation_analytics[violation_name] = {'count': 0}
            violation_analytics[violation_name]['count'] += 1
        
        # Get status distribution
        status_counts = {}
        for record in violation_records:
            status = record.status or 'active'
            status_counts[status] = status_counts.get(status, 0) + 1
        
        for status, count in status_counts.items():
            status_distribution.append({'status': status, 'count': count})
        
        return Response({
            'success': True,
            'violation_analytics': violation_analytics,
            'status_distribution': status_distribution,
            'monthly_trends': monthly_trends,
            'message': 'Violation analytics retrieved successfully'
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e),
            'violation_analytics': {},
            'status_distribution': [],
            'monthly_trends': []
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

def create_notification(user, title, message, notification_type='general', related_report=None):
    """Helper function to create a notification"""
    try:
        notification = Notification.objects.create(
            user=user,
            title=title,
            message=message,
            type=notification_type,
            related_report=related_report
        )
        logger.info(f"✅ Notification created for {user.username}: {title}")
        return notification
    except Exception as e:
        logger.error(f"❌ Error creating notification: {str(e)}")
        return None


# Now update the existing update_report_status function (around line 1450)
# Replace the entire function with this:

@csrf_exempt
@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def update_report_status(request, report_id):
    """Update the status of a report and send notifications"""
    try:
        data = json.loads(request.body)
        status_value = data.get('status')
        counselor_notes = data.get('counselor_notes', '')
        tally_notes = data.get('tally_notes', '')
        
        logger.info(f"📝 Updating report {report_id} status to {status_value}")
        logger.info(f"📝 Counselor notes: {counselor_notes}")
        logger.info(f"📝 Tally notes: {tally_notes}")
        
        # Verify user is authenticated
        if not request.user.is_authenticated:
            return JsonResponse({
                'success': False,
                'message': 'Authentication required'
            }, status=401)
        
        # Get counselor
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return JsonResponse({
                'success': False,
                'message': 'Only counselors can update report status'
            }, status=403)
        
        # Get the report
        try:
            report = Report.objects.select_related(
                'student', 
                'student__user', 
                'reported_by'
            ).get(id=report_id)
            
            old_status = report.status
            
            # Update status
            valid_statuses = ['pending', 'under_review', 'reviewed', 'investigating', 'resolved', 'dismissed', 'escalated']
            if status_value == 'tallied':
                report.status = 'resolved'
                report.resolved_at = timezone.now()
            elif status_value in valid_statuses:
                report.status = status_value
                if status_value == 'resolved':
                    report.resolved_at = timezone.now()
                elif status_value == 'reviewed':
                    report.is_reviewed = True
                    report.reviewed_at = timezone.now()
            else:
                report.status = 'under_review'
            
            # Add notes
            notes_to_add = []
            if counselor_notes:
                notes_to_add.append(f"Counselor Notes: {counselor_notes}")
            if tally_notes:
                notes_to_add.append(f"Tally Notes: {tally_notes}")
            
            if notes_to_add:
                timestamp = timezone.now().strftime('%Y-%m-%d %H:%M')
                current_action = report.disciplinary_action or ''
                new_notes = f"\n\n[{timestamp}]\n" + "\n".join(notes_to_add)
                report.disciplinary_action = (current_action + new_notes).strip()
            
            if counselor_notes and hasattr(report, 'counselor_notes'):
                report.counselor_notes = counselor_notes
            
            report.updated_at = timezone.now()
            report.save()
            
            logger.info(f"✅ Report {report_id} status updated from {old_status} to {report.status}")
            
            # 🔔 SEND NOTIFICATIONS
            
            # 1. Notify the reporter (teacher or student who submitted the report)
            if report.reported_by:
                notification_title = f"Report Update: {report.title}"
                notification_message = f"Your report has been updated to '{report.status}'."
                
                if counselor_notes:
                    notification_message += f"\n\nCounselor notes: {counselor_notes}"
                
                create_notification(
                    user=report.reported_by,
                    title=notification_title,
                    message=notification_message,
                    notification_type='report_reviewed',
                    related_report=report
                )
                logger.info(f"✅ Notification sent to reporter: {report.reported_by.username}")
            
            # 2. Notify the student who was reported (if different from reporter)
            if report.student and report.student.user:
                # Only notify if the student is not the one who reported
                if not report.reported_by or report.student.user.id != report.reported_by.id:
                    student_title = f"Report Update: {report.title}"
                    student_message = f"A report concerning you has been {report.status}."
                    
                    if report.status == 'resolved':
                        student_message += "\n\nThis matter has been resolved. If you have questions, please visit the guidance office."
                    elif report.status == 'reviewed':
                        student_message += "\n\nYour case has been reviewed by the guidance counselor."
                    elif report.status == 'under_review':
                        student_message += "\n\nThe guidance counselor is currently reviewing your case."
                    
                    if counselor_notes:
                        student_message += f"\n\nCounselor notes: {counselor_notes}"
                    
                    create_notification(
                        user=report.student.user,
                        title=student_title,
                        message=student_message,
                        notification_type='report_reviewed',
                        related_report=report
                    )
                    logger.info(f"✅ Notification sent to student: {report.student.user.username}")
            
            return JsonResponse({
                'success': True,
                'message': 'Report status updated and notifications sent',
                'report_id': report_id,
                'new_status': report.status,
                'notifications_sent': True
            })
            
        except Report.DoesNotExist:
            logger.error(f"❌ Report {report_id} not found")
            return JsonResponse({
                'success': False,
                'message': f'Report with ID {report_id} not found'
            }, status=404)
        
    except json.JSONDecodeError:
        return JsonResponse({
            'success': False,
            'message': 'Invalid JSON data'
        }, status=400)
    except Exception as e:
        logger.error(f"❌ Error updating report {report_id}: {str(e)}")
        import traceback
        traceback.print_exc()
        return JsonResponse({
            'success': False,
            'message': f'Error updating report: {str(e)}'
        }, status=500)


# Add new endpoints for sending notifications

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_counseling_notification(request):
    """Send counseling notification to a student"""
    try:
        # Verify counselor
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Only counselors can send counseling notifications'
            }, status=status.HTTP_403_FORBIDDEN)
        
        student_id = request.data.get('student_id')
        message = request.data.get('message')
        scheduled_date = request.data.get('scheduled_date')
        
        if not student_id or not message:
            return Response({
                'success': False,
                'error': 'student_id and message are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Get student
        try:
            student = Student.objects.select_related('user').get(id=student_id)
        except Student.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Student not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        if not student.user:
            return Response({
                'success': False,
                'error': 'Student has no associated user account'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Create notification
        title = "Counseling Session Scheduled"
        full_message = message
        
        if scheduled_date:
            try:
                date_obj = parse_datetime(scheduled_date)
                if date_obj:
                    formatted_date = date_obj.strftime('%B %d, %Y at %I:%M %p')
                    full_message += f"\n\nScheduled for: {formatted_date}"
            except:
                full_message += f"\n\nScheduled for: {scheduled_date}"
        
        notification = create_notification(
            user=student.user,
            title=title,
            message=full_message,
            notification_type='session_scheduled'
        )
        
        if notification:
            logger.info(f"✅ Counseling notification sent to student {student.user.username}")
            return Response({
                'success': True,
                'message': 'Counseling notification sent successfully',
                'notification': {
                    'id': notification.id,
                    'title': notification.title,
                    'message': notification.message,
                    'created_at': notification.created_at.isoformat(),
                }
            })
        else:
            return Response({
                'success': False,
                'error': 'Failed to create notification'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
    except Exception as e:
        logger.error(f"❌ Error sending counseling notification: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_bulk_notifications(request):
    """Send notifications to multiple users"""
    try:
        # Verify counselor
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Only counselors can send bulk notifications'
            }, status=status.HTTP_403_FORBIDDEN)
        
        user_ids = request.data.get('user_ids', [])
        title = request.data.get('title')
        message = request.data.get('message')
        notification_type = request.data.get('type', 'general')
        
        if not user_ids or not title or not message:
            return Response({
                'success': False,
                'error': 'user_ids, title, and message are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        notifications_created = 0
        users = User.objects.filter(id__in=user_ids)
        
        for user in users:
            notification = create_notification(
                user=user,
                title=title,
                message=message,
                notification_type=notification_type
            )
            if notification:
                notifications_created += 1
        
        logger.info(f"✅ Sent {notifications_created} bulk notifications")
        
        return Response({
            'success': True,
            'message': f'{notifications_created} notification(s) sent successfully',
            'count': notifications_created
        })
        
    except Exception as e:
        logger.error(f"❌ Error sending bulk notifications: {str(e)}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def notifications_list(request):
    """Get all notifications for the authenticated user"""
    try:
        notifications = Notification.objects.filter(
            user=request.user
        ).order_by('-created_at')
        
        notifications_data = []
        for notification in notifications:
            notifications_data.append({
                'id': notification.id,
                'title': notification.title,
                'message': notification.message,
                'type': notification.type if hasattr(notification, 'type') else 'general',
                'is_read': notification.is_read,
                'created_at': notification.created_at.isoformat(),
                'related_report_id': notification.related_report.id if hasattr(notification, 'related_report') and notification.related_report else None,
            })
        
        return Response({
            'success': True,
            'notifications': notifications_data,
            'unread_count': notifications.filter(is_read=False).count(),
            'total_count': len(notifications_data)
        })
        
    except Exception as e:
        logger.error(f"❌ Error fetching notifications: {str(e)}")
        return Response({
            'success': False,
            'error': str(e),
            'notifications': [],
            'unread_count': 0,
            'total_count': 0
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def notification_mark_read(request, notification_id):
    """Mark a single notification as read"""
    try:
        notification = Notification.objects.get(
            id=notification_id,
            user=request.user
        )
        
        notification.is_read = True
        notification.save()
        
        return Response({
            'success': True,
            'message': 'Notification marked as read'
        })
        
    except Notification.DoesNotExist:
        return Response({
            'success': False,
            'error': 'Notification not found'
        }, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"❌ Error marking notification as read: {str(e)}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def notifications_mark_all_read(request):
    """Mark all notifications as read for the authenticated user"""
    try:
        updated_count = Notification.objects.filter(
            user=request.user,
            is_read=False
        ).update(is_read=True)
        
        return Response({
            'success': True,
            'message': f'{updated_count} notification(s) marked as read',
            'updated_count': updated_count
        })
        
    except Exception as e:
        logger.error(f"❌ Error marking all notifications as read: {str(e)}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def notification_delete(request, notification_id):
    """Delete a notification"""
    try:
        notification = Notification.objects.get(
            id=notification_id,
            user=request.user
        )
        
        notification.delete()
        
        return Response({
            'success': True,
            'message': 'Notification deleted'
        }, status=status.HTTP_204_NO_CONTENT)
        
    except Notification.DoesNotExist:
        return Response({
            'success': False,
            'error': 'Notification not found'
        }, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        logger.error(f"❌ Error deleting notification: {str(e)}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def notifications_unread_count(request):
    """Get unread notification count"""
    try:
        unread_count = Notification.objects.filter(
            user=request.user,
            is_read=False
        ).count()
        
        return Response({
            'success': True,
            'unread_count': unread_count
        })
        
    except Exception as e:
        logger.error(f"❌ Error fetching unread count: {str(e)}")
        return Response({
            'success': False,
            'error': str(e),
            'unread_count': 0
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_counseling_notification(request):
    """Send counseling notification to a student"""
    try:
        # Verify counselor
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Only counselors can send counseling notifications'
            }, status=status.HTTP_403_FORBIDDEN)
        
        student_id = request.data.get('student_id')
        message = request.data.get('message')
        scheduled_date = request.data.get('scheduled_date')
        
        if not student_id or not message:
            return Response({
                'success': False,
                'error': 'student_id and message are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Get student
        try:
            student = Student.objects.select_related('user').get(id=student_id)
        except Student.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Student not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        if not student.user:
            return Response({
                'success': False,
                'error': 'Student has no associated user account'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Create notification
        title = "Counseling Session Scheduled"
        full_message = message
        
        if scheduled_date:
            full_message += f"\n\nScheduled for: {scheduled_date}"
        
        notification = create_notification(
            user=student.user,
            title=title,
            message=full_message,
            notification_type='session_scheduled'
        )
        
        if notification:
            logger.info(f"✅ Counseling notification sent to student {student.user.username}")
            return Response({
                'success': True,
                'message': 'Counseling notification sent successfully',
                'notification': {
                    'id': notification.id,
                    'title': notification.title,
                    'message': notification.message,
                    'created_at': notification.created_at.isoformat(),
                }
            })
        else:
            return Response({
                'success': False,
                'error': 'Failed to create notification'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
    except Exception as e:
        logger.error(f"❌ Error sending counseling notification: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_bulk_notifications(request):
    """Send notifications to multiple users"""
    try:
        # Verify counselor
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Only counselors can send bulk notifications'
            }, status=status.HTTP_403_FORBIDDEN)
        
        user_ids = request.data.get('user_ids', [])
        title = request.data.get('title')
        message = request.data.get('message')
        notification_type = request.data.get('type', 'general')
        
        if not user_ids or not title or not message:
            return Response({
                'success': False,
                'error': 'user_ids, title, and message are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        notifications_created = 0
        users = User.objects.filter(id__in=user_ids)
        
        for user in users:
            notification = create_notification(
                user=user,
                title=title,
                message=message,
                notification_type=notification_type
            )
            if notification:
                notifications_created += 1
        
        logger.info(f"✅ Sent {notifications_created} bulk notifications")
        
        return Response({
            'success': True,
            'message': f'{notifications_created} notification(s) sent successfully',
            'count': notifications_created
        })
        
    except Exception as e:
        logger.error(f"❌ Error sending bulk notifications: {str(e)}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_counseling_summons(request, report_id):
    """Send notification to student to come to guidance office for counseling"""
    try:
        # Verify counselor
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Only counselors can send counseling summons'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get the report
        try:
            report = Report.objects.select_related(
                'student',
                'student__user',
                'reported_by',
                'violation_type'
            ).get(id=report_id)
        except Report.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Report not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Check if student has user account
        if not report.student or not report.student.user:
            return Response({
                'success': False,
                'error': 'Student has no associated user account'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Get optional scheduled date/time
        scheduled_date = request.data.get('scheduled_date')
        additional_message = request.data.get('message', '')
        
        # Create notification for student
        student_name = f"{report.student.user.first_name} {report.student.user.last_name}".strip()
        violation_name = report.violation_type.name if report.violation_type else 'a reported incident'
        
        notification_title = "🏫 Summons to Guidance Office"
        notification_message = (
            f"Dear {student_name},\n\n"
            f"You are required to report to the Guidance Office regarding {violation_name}.\n\n"
            f"Report Details:\n"
            f"• Title: {report.title}\n"
            f"• Reported on: {report.created_at.strftime('%B %d, %Y')}\n"
        )
        
        if scheduled_date:
            try:
                date_obj = parse_datetime(scheduled_date)
                if date_obj:
                    formatted_date = date_obj.strftime('%B %d, %Y at %I:%M %p')
                    notification_message += f"• Scheduled: {formatted_date}\n"
            except:
                notification_message += f"• Scheduled: {scheduled_date}\n"
        
        if additional_message:
            notification_message += f"\n{additional_message}\n"
        
        notification_message += (
            "\n⚠️ IMPORTANT:\n"
            "Please come prepared to discuss the incident. Failure to appear may result in "
            "automatic tallying of the violation.\n\n"
            "If you cannot attend at the scheduled time, please inform the guidance office immediately."
        )
        
        # Create notification
        notification = create_notification(
            user=report.student.user,
            title=notification_title,
            message=notification_message,
            notification_type='counseling_summons',
            related_report=report
        )
        
        # Update report status to "summoned" (we'll add this status)
        report.status = 'summoned'
        report.counselor_notes = (report.counselor_notes or '') + f"\n[{timezone.now().strftime('%Y-%m-%d %H:%M')}] Student summoned to guidance office."
        report.save()
        
        logger.info(f"✅ Counseling summons sent to student {report.student.user.username} for report {report_id}")
        
        return Response({
            'success': True,
            'message': 'Counseling summons sent successfully',
            'notification': {
                'id': notification.id,
                'title': notification.title,
                'sent_to': student_name,
            },
            'report': {
                'id': report.id,
                'status': report.status,
            }
        })
        
    except Exception as e:
        logger.error(f"❌ Error sending counseling summons: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_report_invalid(request, report_id):
    """Mark a report as invalid after counseling session"""
    try:
        # Verify counselor
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Only counselors can mark reports as invalid'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get the report
        try:
            report = Report.objects.select_related(
                'student',
                'student__user',
                'reported_by'
            ).get(id=report_id)
        except Report.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Report not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        reason = request.data.get('reason', 'No violation found after investigation')
        
        # Update report status
        old_status = report.status
        report.status = 'invalid'
        report.is_reviewed = True
        report.reviewed_at = timezone.now()
        
        # Add counselor notes
        timestamp = timezone.now().strftime('%Y-%m-%d %H:%M')
        invalid_note = f"\n\n[{timestamp}] Report marked as INVALID\nReason: {reason}"
        report.disciplinary_action = (report.disciplinary_action or '') + invalid_note
        report.counselor_notes = (report.counselor_notes or '') + invalid_note
        report.save()
        
        # 🔔 Notify the reporter
        if report.reported_by:
            reporter_notification = (
                f"Your report '{report.title}' has been marked as INVALID after investigation.\n\n"
                f"Reason: {reason}\n\n"
                f"The reported incident was investigated and found to be unsubstantiated. "
                f"No violation will be tallied."
            )
            
            create_notification(
                user=report.reported_by,
                title=f"Report Invalid: {report.title}",
                message=reporter_notification,
                notification_type='report_invalid',
                related_report=report
            )
        
        # 🔔 Notify the student
        if report.student and report.student.user:
            student_notification = (
                f"Good news! After investigation, the report concerning you has been marked as INVALID.\n\n"
                f"Report: {report.title}\n"
                f"Reason: {reason}\n\n"
                f"No violation has been recorded in your file."
            )
            
            create_notification(
                user=report.student.user,
                title="Report Cleared - No Violation",
                message=student_notification,
                notification_type='report_cleared',
                related_report=report
            )
        
        logger.info(f"✅ Report {report_id} marked as invalid. Notifications sent.")
        
        return Response({
            'success': True,
            'message': 'Report marked as invalid and notifications sent',
            'report': {
                'id': report.id,
                'status': report.status,
                'old_status': old_status,
            }
        })
        
    except Exception as e:
        logger.error(f"❌ Error marking report as invalid: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_counseling_summons(request, report_id):
    """Send notification to student to come to guidance office for counseling"""
    try:
        # Verify counselor
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Only counselors can send counseling summons'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get the report
        try:
            report = Report.objects.select_related(
                'student',
                'student__user',
                'reported_by',
                'violation_type'
            ).get(id=report_id)
        except Report.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Report not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Check if student has user account
        if not report.student or not report.student.user:
            return Response({
                'success': False,
                'error': 'Student has no associated user account'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Get optional scheduled date/time
        scheduled_date = request.data.get('scheduled_date')
        additional_message = request.data.get('message', '')
        
        # Create notification for student
        student_name = f"{report.student.user.first_name} {report.student.user.last_name}".strip()
        violation_name = report.violation_type.name if report.violation_type else 'a reported incident'
        
        notification_title = "🏫 Summons to Guidance Office"
        notification_message = (
            f"Dear {student_name},\n\n"
            f"You are required to report to the Guidance Office regarding {violation_name}.\n\n"
            f"Report Details:\n"
            f"• Title: {report.title}\n"
            f"• Reported on: {report.created_at.strftime('%B %d, %Y')}\n"
        )
        
        if scheduled_date:
            try:
                from django.utils.dateparse import parse_datetime
                date_obj = parse_datetime(scheduled_date)
                if date_obj:
                    formatted_date = date_obj.strftime('%B %d, %Y at %I:%M %p')
                    notification_message += f"• Scheduled: {formatted_date}\n"
            except:
                notification_message += f"• Scheduled: {scheduled_date}\n"
        
        if additional_message:
            notification_message += f"\n{additional_message}\n"
        
        notification_message += (
            "\n⚠️ IMPORTANT:\n"
            "Please come prepared to discuss the incident. Failure to appear may result in "
            "automatic tallying of the violation.\n\n"
            "If you cannot attend at the scheduled time, please inform the guidance office immediately."
        )
        
        # Create notification
        notification = create_notification(
            user=report.student.user,
            title=notification_title,
            message=notification_message,
            notification_type='counseling_summons',
            related_report=report
        )
        
        # Update report status to "summoned"
        report.status = 'summoned'
        report.counselor_notes = (report.counselor_notes or '') + f"\n[{timezone.now().strftime('%Y-%m-%d %H:%M')}] Student summoned to guidance office."
        report.save()
        
        logger.info(f"✅ Counseling summons sent to student {report.student.user.username} for report {report_id}")
        
        return Response({
            'success': True,
            'message': 'Counseling summons sent successfully',
            'notification': {
                'id': notification.id,
                'title': notification.title,
                'sent_to': student_name,
            },
            'report': {
                'id': report.id,
                'status': report.status,
            }
        })
        
    except Exception as e:
        logger.error(f"❌ Error sending counseling summons: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_report_invalid(request, report_id):
    """Mark a report as invalid after counseling session"""
    try:
        # Verify counselor
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Only counselors can mark reports as invalid'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get the report
        try:
            report = Report.objects.select_related(
                'student',
                'student__user',
                'reported_by'
            ).get(id=report_id)
        except Report.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Report not found'
            }, status=status.HTTP_404_NOT_FOUND)
        
        reason = request.data.get('reason', 'No violation found after investigation')
        
        # Update report status
        old_status = report.status
        report.status = 'invalid'
        report.is_reviewed = True
        report.reviewed_at = timezone.now()
        
        # Add counselor notes
        timestamp = timezone.now().strftime('%Y-%m-%d %H:%M')
        invalid_note = f"\n\n[{timestamp}] Report marked as INVALID\nReason: {reason}"
        report.disciplinary_action = (report.disciplinary_action or '') + invalid_note
        report.counselor_notes = (report.counselor_notes or '') + invalid_note
        report.save()
        
        # 🔔 Notify the reporter
        if report.reported_by:
            reporter_notification = (
                f"Your report '{report.title}' has been marked as INVALID after investigation.\n\n"
                f"Reason: {reason}\n\n"
                f"The reported incident was investigated and found to be unsubstantiated. "
                f"No violation will be tallied."
            )
            
            create_notification(
                user=report.reported_by,
                title=f"Report Invalid: {report.title}",
                message=reporter_notification,
                notification_type='report_invalid',
                related_report=report
            )
        
        # 🔔 Notify the student
        if report.student and report.student.user:
            student_notification = (
                f"Good news! After investigation, the report concerning you has been marked as INVALID.\n\n"
                f"Report: {report.title}\n"
                f"Reason: {reason}\n\n"
                f"No violation has been recorded in your file."
            )
            
            create_notification(
                user=report.student.user,
                title="Report Cleared - No Violation",
                message=student_notification,
                notification_type='report_cleared',
                related_report=report
            )
        
        logger.info(f"✅ Report {report_id} marked as invalid. Notifications sent.")
        
        return Response({
            'success': True,
            'message': 'Report marked as invalid and notifications sent',
            'report': {
                'id': report.id,
                'status': report.status,
                'old_status': old_status,
            }
        })
        
    except Exception as e:
        logger.error(f"❌ Error marking report as invalid: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@csrf_exempt
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_report_status(request, report_id):
    """Update report status with notifications"""
    try:
        # Get report type from request
        report_type = request.data.get('report_type', 'student_report')
        
        logger.info(f"🔄 Updating {report_type} #{report_id} status")
        
        # ✅ FIX: Remove '__user' from select_related
        if report_type == 'teacher_report':
            try:
                report = TeacherReport.objects.select_related(
                    'reported_by',          # ✅ Just get the Teacher
                    'student',              # ✅ Just get the Student
                ).get(id=report_id)
            except TeacherReport.DoesNotExist:
                return Response({
                    'success': False,
                    'error': 'Teacher report not found'
                }, status=status.HTTP_404_NOT_FOUND)
        else:
            # student_report, peer_report, or self_report
            try:
                # ✅ FIX: Remove '__user' from all select_related paths
                report = StudentReport.objects.select_related(
                    'reporter_student',        # ✅ Just get the Student (reporter)
                    'reported_student',        # ✅ Just get the Student (reported)
                    'assigned_counselor',      # ✅ Just get the Counselor
                    'verified_by',             # ✅ Just get the Counselor (verifier)
                ).get(id=report_id)
            except StudentReport.DoesNotExist:
                return Response({
                    'success': False,
                    'error': 'Student report not found'
                }, status=status.HTTP_404_NOT_FOUND)
        
        # Verify user is a counselor
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Only counselors can update report status'
            }, status=status.HTTP_403_FORBIDDEN)
        
        counselor = request.user.counselor
        
        # Get new status and notes
        new_status = request.data.get('status')
        notes = request.data.get('notes', '')
        
        if not new_status:
            return Response({
                'success': False,
                'error': 'Status is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        old_status = report.status
        
        # Validate status transition based on model choices
        valid_statuses = [
            'pending', 'under_review', 'under_investigation', 
            'summons_sent', 'verified', 'dismissed', 
            'resolved', 'escalated'
        ]
        
        if new_status not in valid_statuses:
            return Response({
                'success': False,
                'error': f'Invalid status. Must be one of: {", ".join(valid_statuses)}'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Update report
        report.status = new_status
        report.assigned_counselor = counselor
        
        # Add notes if provided
        if notes:
            timestamp = timezone.now().strftime('%Y-%m-%d %H:%M')
            counselor_name = request.user.get_full_name() or request.user.username
            note_entry = f"[{timestamp}] {counselor_name}: {notes}"
            
            if report.counselor_notes:
                report.counselor_notes += f"\n\n{note_entry}"
            else:
                report.counselor_notes = note_entry
        
        # Update timestamps based on status
        if new_status == 'verified':
            report.verified_by = counselor
            if hasattr(report, 'verified_at'):
                report.verified_at = timezone.now()
        elif new_status == 'resolved':
            if hasattr(report, 'resolved_at'):
                report.resolved_at = timezone.now()
        
        report.save()
        
        logger.info(f"✅ {report_type} #{report_id} status updated: {old_status} → {new_status}")
        
        # Send notifications
        if report_type == 'teacher_report':
            reported_student = report.student
            reporter = report.reported_by
        else:
            reported_student = report.reported_student
            reporter = report.reporter_student
        
        # Notify reported student
        if reported_student and hasattr(reported_student, 'user') and reported_student.user:
            if new_status == 'verified':
                message = f'The report "{report.title}" has been validated after counseling. It will be tallied as a violation.'
            elif new_status == 'dismissed':
                message = f'The report "{report.title}" has been dismissed after investigation. No violation will be recorded.'
            elif new_status == 'resolved':
                message = f'The report "{report.title}" has been resolved and closed.'
            elif new_status == 'summons_sent':
                message = f'You have been summoned to the guidance office regarding "{report.title}". Please report as soon as possible.'
            else:
                message = f'Report "{report.title}" status updated to: {new_status}'
            
            Notification.objects.create(
                recipient=reported_student.user,
                title='Report Status Update',
                message=message,
                notification_type='report_update',
                related_report_id=report.id,
            )
            
            logger.info(f"📧 Notification sent to {reported_student.user.get_full_name()}")
        
        # Notify reporter
        if reporter and hasattr(reporter, 'user') and reporter.user:
            Notification.objects.create(
                recipient=reporter.user,
                title='Report Status Update',
                message=f'Report "{report.title}" has been updated to: {new_status}',
                notification_type='report_update',
                related_report_id=report.id,
            )
            
            logger.info(f"📧 Notification sent to reporter {reporter.user.get_full_name()}")
        
        return Response({
            'success': True,
            'message': f'Report status updated to {new_status}',
            'report': {
                'id': report.id,
                'status': report.status,
                'old_status': old_status,
                'counselor_notes': report.counselor_notes,
            }
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"❌ Error updating report status: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return Response({
            'success': False,
            'error': f'Failed to update report status: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_students_school_year(request):
    """Bulk update students' school year - ADMIN/COUNSELOR ONLY"""
    try:
        # Verify counselor or admin
        if not (request.user.is_staff or hasattr(request.user, 'counselor')):
            return Response({
                'success': False,
                'error': 'Access denied. Admin or counselor role required.'
            }, status=403)
        
        default_school_year = request.data.get('school_year')
        
        # Calculate current school year if not provided
        if not default_school_year:
            current_year = datetime.now().year
            current_month = datetime.now().month
            default_school_year = f"{current_year}-{current_year + 1}" if current_month >= 6 else f"{current_year - 1}-{current_year}"
        
        # Update all students without school_year
        students_without_sy = Student.objects.filter(
            models.Q(school_year__isnull=True) | models.Q(school_year='')
        )
        
        count = students_without_sy.count()
        students_without_sy.update(school_year=default_school_year)
        
        logger.info(f"✅ Updated {count} students to school year: {default_school_year}")
        
        return Response({
            'success': True,
            'message': f'Updated {count} students to school year {default_school_year}',
            'count': count,
            'school_year': default_school_year
        })
        
    except Exception as e:
        logger.error(f"❌ Error updating students school year: {e}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)

@csrf_exempt
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_guidance_notice(request, report_id):
    """Send guidance notice/summons to students involved in a report"""
    try:
        # Verify counselor authentication
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Only counselors can send guidance notices'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # ✅ Determine report type from request body
        report_type = request.data.get('report_type', 'student_report')  # Default to student_report
        
        logger.info(f"📢 Sending guidance notice for {report_type} #{report_id}")
        
        # ✅ Get the report based on type
        report = None
        report_model_name = ""
        
        if report_type == 'student_report':
            try:
                report = StudentReport.objects.select_related(
                    'reporter_student__user',
                    'reported_student__user',
                    'violation_type',
                    'assigned_counselor__user'
                ).get(id=report_id)
                report_model_name = "StudentReport"
            except StudentReport.DoesNotExist:
                return Response({
                    'success': False,
                    'message': f'Student report with ID {report_id} not found'
                }, status=status.HTTP_404_NOT_FOUND)
        
        elif report_type == 'teacher_report':
            try:
                report = TeacherReport.objects.select_related(
                    'reporter_teacher__user',
                    'reported_student__user',
                    'violation_type',
                    'assigned_counselor__user'
                ).get(id=report_id)
                report_model_name = "TeacherReport"
            except TeacherReport.DoesNotExist:
                return Response({
                    'success': False,
                    'message': f'Teacher report with ID {report_id} not found'
                }, status=status.HTTP_404_NOT_FOUND)
        
        else:
            return Response({
                'success': False,
                'message': f'Invalid report type: {report_type}'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Get notice details from request
        notice_message = request.data.get('message', '')
        scheduled_date_str = request.data.get('scheduled_date', '')
        
        if not notice_message:
            return Response({
                'success': False,
                'message': 'Notice message is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Parse scheduled date
        scheduled_date = None
        if scheduled_date_str:
            try:
                from datetime import datetime
                scheduled_date = datetime.fromisoformat(scheduled_date_str.replace('Z', '+00:00'))
            except Exception as e:
                logger.warning(f"⚠️ Could not parse scheduled date: {e}")
                scheduled_date = timezone.now()
        else:
            scheduled_date = timezone.now()
        
        logger.info(f"📨 Notice message: {notice_message[:50]}...")
        logger.info(f"📅 Scheduled date: {scheduled_date}")
        
        # ✅ Send notifications based on report type
        notifications_sent = []
        
        if report_type == 'student_report':
            # Send to reporter (if exists and not self-report)
            if report.reporter_student and report.reporter_student != report.reported_student:
                notification = Notification.objects.create(
                    user=report.reporter_student.user,
                    title='Guidance Office Notice',
                    message=notice_message,
                    type='summons',
                    related_student_report=report
                )
                notifications_sent.append({
                    'recipient': 'reporter',
                    'user': report.reporter_student.user.username,
                    'name': report.reporter_student.user.get_full_name()
                })
                logger.info(f"✅ Notification sent to reporter: {report.reporter_student.user.username}")
            
            # Send to reported student
            if report.reported_student:
                notification = Notification.objects.create(
                    user=report.reported_student.user,
                    title='Guidance Office Notice',
                    message=notice_message,
                    type='summons',
                    related_student_report=report
                )
                notifications_sent.append({
                    'recipient': 'reported_student',
                    'user': report.reported_student.user.username,
                    'name': report.reported_student.user.get_full_name()
                })
                logger.info(f"✅ Notification sent to reported student: {report.reported_student.user.username}")
            
            # Update report status
            report.summons_sent_at = timezone.now()
            report.summons_sent_to_reporter = True
            report.summons_sent_to_reported = True
            
        elif report_type == 'teacher_report':
            # Send notification to reported student
            if report.reported_student:
                notification = Notification.objects.create(
                    user=report.reported_student.user,
                    title='Guidance Office Notice',
                    message=notice_message,
                    type='summons',
                    related_teacher_report=report
                )
                notifications_sent.append({
                    'recipient': 'reported_student',
                    'user': report.reported_student.user.username,
                    'name': report.reported_student.user.get_full_name()
                })
                logger.info(f"✅ Notification sent to reported student: {report.reported_student.user.username}")
            
            # Optionally send to teacher (FYI)
            if report.reporter_teacher:
                notification = Notification.objects.create(
                    user=report.reporter_teacher.user,
                    title='Guidance Notice Sent',
                    message=f'A guidance notice has been sent regarding your report: {report.title}',
                    type='system_alert',
                    related_teacher_report=report
                )
                notifications_sent.append({
                    'recipient': 'teacher',
                    'user': report.reporter_teacher.user.username,
                    'name': report.reporter_teacher.user.get_full_name()
                })
                logger.info(f"✅ FYI notification sent to teacher: {report.reporter_teacher.user.username}")
            
            # Update report status
            report.summons_sent_at = timezone.now()
            report.summons_sent_to_student = True
            report.teacher_notified = True
        
        # Update report status if still pending
        if report.status == 'pending':
            report.status = 'summoned'
        
        report.save()
        
        logger.info(f"✅ Guidance notice sent successfully for {report_model_name} #{report_id}")
        logger.info(f"   Notifications sent to {len(notifications_sent)} recipient(s)")
        
        return Response({
            'success': True,
            'message': f'Guidance notice sent successfully to {len(notifications_sent)} recipient(s)',
            'report_id': report.id,
            'report_type': report_type,
            'notifications_sent': notifications_sent,
            'scheduled_date': scheduled_date.isoformat(),
            'report': {
                'id': report.id,
                'title': report.title,
                'status': report.status,
                'summons_sent_at': report.summons_sent_at.isoformat() if report.summons_sent_at else None,
            }
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"❌ Error sending guidance notice: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'message': f'Failed to send guidance notice: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def rollover_school_year(request):
    """
    Roll over students to new school year (Admin/Counselor only)
    - Archives current school year data
    - Preserves ALL violation records
    - Updates students to new school year
    - Promotes grade levels
    """
    try:
        # Verify admin or counselor
        if not (request.user.is_staff or hasattr(request.user, 'counselor')):
            return Response({
                'success': False,
                'error': 'Access denied. Admin or counselor role required.'
            }, status=403)
        
        new_school_year = request.data.get('new_school_year')
        dry_run = request.data.get('dry_run', False)
        
        # Calculate school year if not provided
        if not new_school_year:
            current_year = datetime.now().year
            current_month = datetime.now().month
            new_school_year = f"{current_year}-{current_year + 1}" if current_month >= 6 else f"{current_year - 1}-{current_year}"
        
        logger.info(f"{'🔍 DRY RUN' if dry_run else '🚀 EXECUTING'}: School Year Rollover to {new_school_year}")
        
        students = Student.objects.select_related('user').all()
        updated_count = 0
        archived_count = 0
        errors = []
        
        from api.models import StudentSchoolYearHistory
        
        with transaction.atomic():
            for student in students:
                try:
                    old_year = student.school_year or 'Unknown'
                    old_grade = student.grade_level
                    
                    # 1. Archive current year to history
                    history, created = StudentSchoolYearHistory.objects.get_or_create(
                        student=student,
                        school_year=old_year,
                        defaults={
                            'grade_level': old_grade,
                            'section': student.section,
                            'strand': student.strand,
                            'is_active': False,
                        }
                    )
                    
                    if created:
                        archived_count += 1
                        logger.info(f"📝 Archived: {student.user.get_full_name()} - {old_year} ({old_grade} {student.section})")
                    
                    if not dry_run:
                        # 2. Promote grade level (if not Grade 12)
                        new_grade = old_grade
                        if old_grade.isdigit():
                            grade_num = int(old_grade)
                            if grade_num < 12:
                                new_grade = str(grade_num + 1)
                        
                        # 3. Update student to new school year
                        student.school_year = new_school_year
                        student.grade_level = new_grade
                        # Note: Section stays same until adviser updates
                        student.save()
                        
                        # 4. Create new history entry for new year
                        StudentSchoolYearHistory.objects.create(
                            student=student,
                            school_year=new_school_year,
                            grade_level=new_grade,
                            section=student.section,
                            strand=student.strand,
                            is_active=True,
                        )
                        
                        updated_count += 1
                        logger.info(f"✅ Updated: {student.user.get_full_name()} - {old_grade} → {new_grade}")
                
                except Exception as e:
                    error_msg = f"Error updating student {student.id}: {str(e)}"
                    logger.error(error_msg)
                    errors.append(error_msg)
            
            if dry_run:
                logger.info("⚠️ DRY RUN COMPLETE - Rolling back transaction")
                transaction.set_rollback(True)
        
        # Get violation counts by school year
        from django.db.models import Count
        violation_counts = StudentViolationRecord.objects.values('student__school_year').annotate(
            count=Count('id')
        ).order_by('-student__school_year')
        
        return Response({
            'success': True,
            'message': f"{'DRY RUN: ' if dry_run else ''}School year rollover {'simulated' if dry_run else 'completed'}",
            'new_school_year': new_school_year,
            'students_updated': updated_count,
            'history_archived': archived_count,
            'total_students': students.count(),
            'errors': errors if errors else None,
            'violations_by_year': list(violation_counts),
            'note': 'Advisers should now update student sections for their advisory classes' if not dry_run else 'This was a dry run - no changes were made'
        })
        
    except Exception as e:
        logger.error(f"❌ Error in school year rollover: {e}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def adviser_manage_section(request):
    """
    GET: View current advisory section with violation history
    POST: Update students in advisory section
    """
    try:
        # Get teacher
        teacher = Teacher.objects.filter(user=request.user).first()
        if not teacher:
            return Response({
                'success': False,
                'error': 'Only teachers can manage advisory sections'
            }, status=403)
        
        # Get current school year
        current_year = datetime.now().year
        current_month = datetime.now().month
        current_sy = f"{current_year}-{current_year + 1}" if current_month >= 6 else f"{current_year - 1}-{current_year}"
        
        if request.method == 'GET':
            # Get current advisory students
            advisory_students = Student.objects.filter(
                school_year=current_sy,
                section=teacher.advising_section
            ).select_related('user').order_by('user__last_name', 'user__first_name')
            
            students_data = []
            for student in advisory_students:
                # Get violation counts
                current_year_violations = StudentViolationRecord.objects.filter(
                    student=student,
                    student__school_year=current_sy
                ).count()
                
                all_time_violations = StudentViolationRecord.objects.filter(
                    student=student
                ).count()
                
                # Get violations grouped by year
                from api.models import StudentSchoolYearHistory
                violations_by_year = []
                
                # Get all school years this student was enrolled
                history = StudentSchoolYearHistory.objects.filter(
                    student=student
                ).order_by('-school_year')
                
                for h in history:
                    year_violations = StudentViolationRecord.objects.filter(
                        student=student,
                        incident_date__year=int(h.school_year.split('-')[0])
                    ).count()
                    
                    violations_by_year.append({
                        'school_year': h.school_year,
                        'count': year_violations,
                        'grade_level': h.grade_level,
                        'section': h.section,
                    })
                
                students_data.append({
                    'id': student.id,
                    'student_id': student.student_id,
                    'name': student.user.get_full_name(),
                    'grade_level': student.grade_level,
                    'section': student.section,
                    'strand': student.strand,
                    'school_year': student.school_year,
                    'violations_current_year': current_year_violations,
                    'violations_all_time': all_time_violations,
                    'violations_by_year': violations_by_year,
                    'contact_number': student.contact_number,
                    'guardian_name': student.guardian_name,
                    'guardian_contact': student.guardian_contact,
                })
            
            return Response({
                'success': True,
                'school_year': current_sy,
                'advisory_section': teacher.advising_section,
                'advising_grade': teacher.advising_grade,
                'advising_strand': teacher.advising_strand,
                'students': students_data,
                'total_students': len(students_data),
            })
        
        elif request.method == 'POST':
            # Update section assignments
            updates = request.data.get('updates', [])
            # Expected format: [{'student_id': 1, 'section': 'Amber', 'grade_level': '12', 'strand': 'ICT'}, ...]
            
            updated_count = 0
            errors = []
            
            from api.models import StudentSchoolYearHistory
            
            with transaction.atomic():
                for update in updates:
                    try:
                        student = Student.objects.get(id=update['student_id'])
                        
                        # Update student info
                        if 'section' in update:
                            student.section = update['section']
                        if 'grade_level' in update:
                            student.grade_level = update['grade_level']
                        if 'strand' in update:
                            student.strand = update['strand']
                        
                        student.save()
                        
                        # Update active history record
                        history = StudentSchoolYearHistory.objects.filter(
                            student=student,
                            school_year=current_sy,
                            is_active=True
                        ).first()
                        
                        if history:
                            history.section = student.section
                            history.grade_level = student.grade_level
                            history.strand = student.strand
                            history.adviser = teacher
                            history.save()
                        else:
                            # Create new history if missing
                            StudentSchoolYearHistory.objects.create(
                                student=student,
                                school_year=current_sy,
                                grade_level=student.grade_level,
                                section=student.section,
                                strand=student.strand,
                                adviser=teacher,
                                is_active=True,
                            )
                        
                        updated_count += 1
                        logger.info(f"✅ Updated: {student.user.get_full_name()} - {student.grade_level} {student.section}")
                        
                    except Student.DoesNotExist:
                        errors.append(f"Student ID {update['student_id']} not found")
                    except Exception as e:
                        errors.append(f"Error updating student {update.get('student_id')}: {str(e)}")
            
            return Response({
                'success': True,
                'message': f'Updated {updated_count} students',
                'updated_count': updated_count,
                'errors': errors if errors else None,
            })
    
    except Exception as e:
        logger.error(f"❌ Error in adviser_manage_section: {e}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_student_violation_history(request, student_id):
    """Get complete violation history across ALL school years"""
    try:
        student = Student.objects.select_related('user').get(id=student_id)
        
        # Get all violations for this student (across all years)
        all_violations = StudentViolationRecord.objects.filter(
            student_id=student_id
        ).select_related(
            'violation_type',
            'counselor__user',
            'related_report'
        ).order_by('-incident_date')
        
        # Group by school year
        violations_by_year = {}
        for v in all_violations:
            # Determine school year from incident date
            incident_year = v.incident_date.year
            incident_month = v.incident_date.month
            sy = f"{incident_year}-{incident_year + 1}" if incident_month >= 6 else f"{incident_year - 1}-{incident_year}"
            
            if sy not in violations_by_year:
                violations_by_year[sy] = []
            
            violations_by_year[sy].append({
                'id': v.id,
                'violation_type': v.violation_type.name if v.violation_type else 'Unknown',
                'category': v.violation_type.category if v.violation_type else 'Unknown',
                'severity': v.severity_level,
                'incident_date': v.incident_date.isoformat(),
                'description': v.description,
                'counselor': v.counselor.user.get_full_name() if v.counselor else None,
                'status': v.status,
                'related_report_id': v.related_report.id if v.related_report else None,
            })
        
        # Get school year history
        from api.models import StudentSchoolYearHistory
        school_history = StudentSchoolYearHistory.objects.filter(
            student=student
        ).order_by('-school_year')
        
        history_data = []
        for h in school_history:
            year_violations = violations_by_year.get(h.school_year, [])
            history_data.append({
                'school_year': h.school_year,
                'grade_level': h.grade_level,
                'section': h.section,
                'strand': h.strand,
                'adviser': h.adviser.user.get_full_name() if h.adviser else None,
                'is_active': h.is_active,
                'violations_count': len(year_violations),
                'violations': year_violations,
            })
        
        return Response({
            'success': True,
            'student': {
                'id': student.id,
                'name': student.user.get_full_name(),
                'student_id': student.student_id,
                'current_grade': student.grade_level,
                'current_section': student.section,
                'current_school_year': student.school_year,
            },
            'total_violations_all_time': all_violations.count(),
            'violations_by_school_year': history_data,
        })
        
    except Student.DoesNotExist:
        return Response({
            'success': False,
            'error': 'Student not found'
        }, status=404)
    except Exception as e:
        logger.error(f"❌ Error getting violation history: {e}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_available_school_years(request):
    """
    Get list of all school years that have student data
    Returns both historical and current school years
    """
    try:
        # Get distinct school years from Student model
        from django.db.models import Q
        
        school_years = Student.objects.values_list('school_year', flat=True).distinct().order_by('-school_year')
        
        # Also get school years from StudentSchoolYearHistory
        from api.models import StudentSchoolYearHistory
        history_years = StudentSchoolYearHistory.objects.values_list('school_year', flat=True).distinct()
        
        # Combine and remove duplicates
        all_years = set(list(school_years) + list(history_years))
        all_years = sorted([y for y in all_years if y], reverse=True)  # Remove None values and sort
        
        # Calculate current school year
        current_year = datetime.now().year
        current_month = datetime.now().month
        current_sy = f"{current_year}-{current_year + 1}" if current_month >= 6 else f"{current_year - 1}-{current_year}"
        
        # Ensure current year is in the list
        if current_sy not in all_years:
            all_years.insert(0, current_sy)
        
        logger.info(f"📅 Available school years: {all_years}")
        
        return Response({
            'success': True,
            'school_years': all_years,
            'current_school_year': current_sy,
        })
        
    except Exception as e:
        logger.error(f"❌ Error getting school years: {e}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def counselor_student_reports(request):
    """Get student reports for counselor review"""
    try:
        # Check if user has counselor permissions
        try:
            counselor = Counselor.objects.get(user=request.user)
        except Counselor.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Access denied. Counselor role required.'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # ✅ FIX: Use StudentReport instead of Report
        reports = StudentReport.objects.select_related(
            'reporter_student__user',
            'reported_student__user', 
            'violation_type',
            'assigned_counselor__user'
        ).order_by('-created_at')
        
        reports_data = []
        for report in reports:
            try:
                # Get reporter information
                reporter_info = None
                if report.reporter_student:
                    reporter_info = {
                        'id': report.reporter_student.id,
                        'name': f"{report.reporter_student.user.first_name} {report.reporter_student.user.last_name}".strip(),
                        'username': report.reporter_student.user.username,
                        'student_id': report.reporter_student.student_id,
                        'grade_level': report.reporter_student.grade_level,
                        'section': report.reporter_student.section,
                    }
                
                # Get student being reported
                reported_student_info = None
                if report.reported_student:
                    reported_student_info = {
                        'id': report.reported_student.id,
                        'name': f"{report.reported_student.user.first_name} {report.reported_student.user.last_name}".strip(),
                        'student_id': report.reported_student.student_id,
                        'grade_level': report.reported_student.grade_level,
                        'section': report.reported_student.section,
                        'strand': getattr(report.reported_student, 'strand', 'N/A'),
                    }
                
                report_data = {
                    'id': report.id,
                    'title': report.title,
                    'description': report.description,
                    'content': report.description,
                    'status': report.status,
                    'verification_status': report.verification_status,
                    'incident_date': report.incident_date.isoformat() if report.incident_date else None,
                    'incident_location': report.location,
                    'created_at': report.created_at.isoformat(),
                    'reporter_type': 'Student',
                    'report_type': 'student_report',
                    
                    # Student info
                    'reported_student_id': report.reported_student.id if report.reported_student else None,
                    'reported_student': reported_student_info,
                    'student': reported_student_info,
                    'student_name': reported_student_info['name'] if reported_student_info else 'Unknown',
                    
                    # Reporter info
                    'reporter': reporter_info,
                    'reported_by': reporter_info,
                    
                    # Violation details
                    'violation_type': report.violation_type.name if report.violation_type else report.custom_violation or 'Other',
                    'custom_violation': report.custom_violation,
                    'severity_level': report.severity,
                    'severity_assessment': report.severity,
                    'witnesses': report.witnesses,
                    'counselor_notes': report.counselor_notes,
                    'school_year': report.school_year,
                    
                    # Counseling info
                    'requires_counseling': report.requires_counseling,
                    'counseling_completed': report.counseling_completed,
                    'summons_sent': report.summons_sent_at is not None,
                }
                
                reports_data.append(report_data)
                
            except Exception as e:
                logger.warning(f"⚠️ Error processing report {report.id}: {e}")
                continue
        
        logger.info(f"📋 Found {len(reports_data)} student reports")
        
        return Response({
            'success': True,
            'reports': reports_data,
            'count': len(reports_data),
        })
        
    except Exception as e:
        logger.error(f"❌ Error fetching counselor student reports: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e),
            'reports': [],
            'count': 0
        }, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_counselor_dashboard_stats(request):
    """Get dashboard statistics with optional school year filter"""
    try:
        counselor = Counselor.objects.filter(user=request.user).first()
        if not counselor:
            return Response({
                'success': False,
                'error': 'Counselor profile not found'
            }, status=404)
        
        # ✅ Get school year from query params
        school_year = request.GET.get('school_year', None)
        
        # Base queries
        students_query = Student.objects.all()
        violations_query = StudentViolationRecord.objects.all()
        reports_query = StudentReport.objects.all()
        
        # Filter by school year if provided
        if school_year and school_year != 'all':
            students_query = students_query.filter(school_year=school_year)
            violations_query = violations_query.filter(school_year=school_year)
            reports_query = reports_query.filter(reported_student__school_year=school_year)
            logger.info(f"📅 Filtering dashboard stats by school year: {school_year}")
        
        # Calculate statistics
        total_students = students_query.count()
        total_violations = violations_query.count()
        total_reports = reports_query.count()
        pending_reports = reports_query.filter(status='pending').count()
        
        # Violations by severity
        violations_by_severity = violations_query.values('severity_level').annotate(
            count=Count('id')
        )
        
        # Recent violations (last 10)
        recent_violations = violations_query.select_related(
            'student__user',
            'violation_type'
        ).order_by('-incident_date')[:10]
        
        recent_violations_data = []
        for v in recent_violations:
            recent_violations_data.append({
                'id': v.id,
                'student_name': v.student.user.get_full_name(),
                'student_id': v.student.student_id,
                'violation_type': v.violation_type.name if v.violation_type else 'Unknown',
                'severity_level': v.severity_level,
                'incident_date': v.incident_date.isoformat(),
                'school_year': v.school_year,
            })
        
        return Response({
            'success': True,
            'statistics': {
                'total_students': total_students,
                'total_violations': total_violations,
                'total_reports': total_reports,
                'pending_reports': pending_reports,
                'violations_by_severity': list(violations_by_severity),
                'recent_violations': recent_violations_data,
            },
            'filtered_by_school_year': school_year if school_year and school_year != 'all' else None,
        })
        
    except Exception as e:
        logger.error(f"❌ Error fetching dashboard stats: {e}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def promote_students(request):
    """
    Promote students to next grade level and school year
    Counselor can choose which students to promote or retain
    """
    try:
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Only counselors can promote students'
            }, status=403)
        
        # Get promotion data
        student_promotions = request.data.get('promotions', [])
        new_school_year = request.data.get('new_school_year')
        
        if not new_school_year:
            return Response({
                'success': False,
                'error': 'New school year is required'
            }, status=400)
        
        promoted_students = []
        retained_students = []
        graduated_students = []
        errors = []
        
        for promotion in student_promotions:
            student_id = promotion.get('student_id')
            action = promotion.get('action')  # 'promote', 'retain', 'graduate'
            new_grade = promotion.get('new_grade')
            new_section = promotion.get('new_section')
            
            try:
                student = Student.objects.get(id=student_id)
                
                # Archive current data to history
                StudentSchoolYearHistory.objects.create(
                    student=student,
                    school_year=student.school_year,
                    grade_level=student.grade_level,
                    section=student.section,
                )
                
                if action == 'promote':
                    # Promote to next grade
                    old_grade = student.grade_level
                    student.grade_level = new_grade
                    student.section = new_section
                    student.school_year = new_school_year
                    student.save()
                    
                    promoted_students.append({
                        'id': student.id,
                        'name': student.user.get_full_name(),
                        'old_grade': old_grade,
                        'new_grade': new_grade,
                        'new_section': new_section,
                    })
                    
                    logger.info(f"✅ Promoted: {student.user.get_full_name()} from Grade {old_grade} to Grade {new_grade}")
                    
                elif action == 'retain':
                    # Keep same grade, update school year
                    student.school_year = new_school_year
                    if new_section:
                        student.section = new_section
                    student.save()
                    
                    retained_students.append({
                        'id': student.id,
                        'name': student.user.get_full_name(),
                        'grade_level': student.grade_level,
                        'new_section': new_section,
                    })
                    
                    logger.info(f"🔄 Retained: {student.user.get_full_name()} in Grade {student.grade_level}")
                    
                elif action == 'graduate':
                    # Mark as graduated
                    student.school_year = f"{new_school_year} - GRADUATED"
                    student.is_active = False
                    student.save()
                    
                    graduated_students.append({
                        'id': student.id,
                        'name': student.user.get_full_name(),
                    })
                    
                    logger.info(f"🎓 Graduated: {student.user.get_full_name()}")
                
            except Student.DoesNotExist:
                errors.append(f"Student with ID {student_id} not found")
            except Exception as e:
                errors.append(f"Error processing student {student_id}: {str(e)}")
        
        return Response({
            'success': True,
            'promoted': promoted_students,
            'retained': retained_students,
            'graduated': graduated_students,
            'errors': errors,
            'total_processed': len(promoted_students) + len(retained_students) + len(graduated_students),
        })
        
    except Exception as e:
        logger.error(f"❌ Error promoting students: {e}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def bulk_promote_grade(request):
    """
    Bulk promote all students in a specific grade level
    """
    try:
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Only counselors can promote students'
            }, status=403)
        
        current_grade = request.data.get('current_grade')
        current_school_year = request.data.get('current_school_year')
        new_school_year = request.data.get('new_school_year')
        exclude_student_ids = request.data.get('exclude_students', [])  # Students to retain
        
        # Get students to promote
        students_to_promote = Student.objects.filter(
            grade_level=current_grade,
            school_year=current_school_year,
            is_active=True
        ).exclude(id__in=exclude_student_ids)
        
        promoted_count = 0
        next_grade = str(int(current_grade) + 1) if current_grade.isdigit() and int(current_grade) < 12 else current_grade
        
        for student in students_to_promote:
            # Archive to history
            StudentSchoolYearHistory.objects.create(
                student=student,
                school_year=student.school_year,
                grade_level=student.grade_level,
                section=student.section,
            )
            
            # Promote
            if int(current_grade) < 12:
                student.grade_level = next_grade
                student.school_year = new_school_year
                student.save()
                promoted_count += 1
            elif int(current_grade) == 12:
                # Graduate
                student.school_year = f"{new_school_year} - GRADUATED"
                student.is_active = False
                student.save()
                promoted_count += 1
        
        return Response({
            'success': True,
            'promoted_count': promoted_count,
            'message': f'Successfully promoted {promoted_count} students from Grade {current_grade}'
        })
        
    except Exception as e:
        logger.error(f"❌ Error in bulk promotion: {e}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_promotion_preview(request):
    """
    Get preview of students eligible for promotion
    Shows current grade distribution and suggested promotions
    """
    try:
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Only counselors can view promotion preview'
            }, status=403)
        
        current_school_year = request.GET.get('school_year')
        
        if not current_school_year:
            return Response({
                'success': False,
                'error': 'School year is required'
            }, status=400)
        
        # Get students by grade level
        students_by_grade = {}
        
        for grade in range(7, 13):  # Grades 7-12
            grade_str = str(grade)
            students = Student.objects.filter(
                grade_level=grade_str,
                school_year=current_school_year,
                is_active=True
            ).select_related('user')
            
            students_data = []
            for student in students:
                # Get violation count for this year
                violation_count = StudentViolationRecord.objects.filter(
                    student=student,
                    school_year=current_school_year
                ).count()
                
                # Suggest action based on violations
                suggested_action = 'promote'
                if violation_count >= 10:  # High violations
                    suggested_action = 'review'  # Needs manual review
                elif grade == 12:
                    suggested_action = 'graduate'
                
                students_data.append({
                    'id': student.id,
                    'student_id': student.student_id,
                    'name': student.user.get_full_name(),
                    'current_grade': grade_str,
                    'current_section': student.section,
                    'violation_count': violation_count,
                    'suggested_action': suggested_action,
                    'next_grade': str(grade + 1) if grade < 12 else 'Graduate',
                })
            
            students_by_grade[grade_str] = students_data
        
        return Response({
            'success': True,
            'current_school_year': current_school_year,
            'students_by_grade': students_by_grade,
            'total_students': sum(len(s) for s in students_by_grade.values()),
        })
        
    except Exception as e:
        logger.error(f"❌ Error getting promotion preview: {e}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=500)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def student_profile(request):
    """Get student profile information"""
    try:
        if not hasattr(request.user, 'student'):
            logger.error(f"❌ User {request.user.username} is not a student")
            return Response({
                'success': False,
                'error': 'Not a student account'
            }, status=status.HTTP_403_FORBIDDEN)
        
        student = request.user.student
        
        profile_data = {
            'id': student.id,
            'student_id': student.student_id,
            'user_id': request.user.id,
            'username': request.user.username,
            'email': request.user.email,
            'first_name': request.user.first_name,
            'last_name': request.user.last_name,
            'grade_level': student.grade_level,
            'section': student.section,
            'strand': student.strand if student.strand else '',
            'school_year': student.school_year,
            'contact_number': student.contact_number if student.contact_number else '',
            'guardian_name': student.guardian_name if student.guardian_name else '',
            'guardian_contact': student.guardian_contact if student.guardian_contact else '',
            # ✅ REMOVED: 'is_active': student.is_active,  # This field doesn't exist
        }
        
        logger.info(f"✅ Student profile retrieved: {student.student_id}")
        logger.info(f"📚 Grade: {student.grade_level}, Section: {student.section}, SY: {student.school_year}")
        
        return Response({
            'success': True,
            'student': profile_data
        })
        
    except Exception as e:
        logger.error(f"❌ Error fetching student profile: {e}")
        import traceback
        traceback.print_exc()
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([AllowAny])  # Available to all users
def get_system_settings(request):
    """Get current system settings including active school year"""
    try:
        settings = SystemSettings.get_current_settings()
        
        return Response({
            'success': True,
            'settings': {
                'current_school_year': settings.current_school_year,
                'school_year_start_date': settings.school_year_start_date.isoformat() if settings.school_year_start_date else None,
                'school_year_end_date': settings.school_year_end_date.isoformat() if settings.school_year_end_date else None,
                'is_system_active': settings.is_system_active,
                'system_message': settings.system_message,
                'last_updated': settings.last_updated.isoformat(),
            }
        })
    except Exception as e:
        logger.error(f"❌ Error fetching system settings: {e}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_system_settings(request):
    """Update system settings (Admin only)"""
    try:
        # Check if user is admin
        if not request.user.is_staff and not request.user.is_superuser:
            return Response({
                'success': False,
                'error': 'Only administrators can update system settings'
            }, status=status.HTTP_403_FORBIDDEN)
        
        settings = SystemSettings.get_current_settings()
        
        # Update fields
        if 'current_school_year' in request.data:
            settings.current_school_year = request.data['current_school_year']
        
        if 'school_year_start_date' in request.data:
            settings.school_year_start_date = request.data['school_year_start_date']
        
        if 'school_year_end_date' in request.data:
            settings.school_year_end_date = request.data['school_year_end_date']
        
        if 'is_system_active' in request.data:
            settings.is_system_active = request.data['is_system_active']
        
        if 'system_message' in request.data:
            settings.system_message = request.data['system_message']
        
        settings.updated_by = request.user
        settings.save()
        
        logger.info(f"✅ System settings updated by {request.user.username}")
        logger.info(f"   Current S.Y.: {settings.current_school_year}")
        logger.info(f"   System Active: {settings.is_system_active}")
        
        return Response({
            'success': True,
            'message': 'System settings updated successfully',
            'settings': {
                'current_school_year': settings.current_school_year,
                'is_system_active': settings.is_system_active,
                'system_message': settings.system_message,
            }
        })
        
    except Exception as e:
        logger.error(f"❌ Error updating system settings: {e}")
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def counselor_available_school_years(request):
    """
    Get list of available school years from student records
    Used by counselors to filter data by school year
    """
    try:
        # Verify user is a counselor
        if not hasattr(request.user, 'counselor'):
            return Response({
                'success': False,
                'error': 'Only counselors can access this endpoint'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get distinct school years from students
        school_years = Student.objects.values_list('school_year', flat=True).distinct().order_by('-school_year')
        
        # Convert to list and filter out None values
        school_years_list = [sy for sy in school_years if sy]
        
        logger.info(f"📅 Available school years: {school_years_list}")
        
        return Response({
            'success': True,
            'school_years': school_years_list,
            'count': len(school_years_list)
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        logger.error(f"❌ Error fetching school years: {str(e)}")
        return Response({
            'success': False,
            'error': f'Failed to fetch school years: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
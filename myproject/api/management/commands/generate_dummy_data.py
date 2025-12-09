from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
import random
from faker import Faker
from api.models import (
    Student, Teacher, Counselor, ViolationType, StudentReport, TeacherReport,
    ViolationHistory, CounselingSession, CounselorAction, Notification,
    StudentViolationRecord, StudentViolationTally, SystemSettings,
    LoginAttempt, StudentSchoolYearHistory
)

class Command(BaseCommand):
    help = 'Generate comprehensive dummy data for testing and analytics'

    def add_arguments(self, parser):
        parser.add_argument(
            '--students',
            type=int,
            default=50,
            help='Number of students to create (default: 50)'
        )
        parser.add_argument(
            '--teachers',
            type=int,
            default=10,
            help='Number of teachers to create (default: 10)'
        )
        parser.add_argument(
            '--reports',
            type=int,
            default=100,
            help='Number of reports to create (default: 100)'
        )
        parser.add_argument(
            '--clear',
            action='store_true',
            help='Clear existing dummy data before generating new data'
        )

    def handle(self, *args, **options):
        fake = Faker()
        
        if options['clear']:
            self.stdout.write(self.style.WARNING('🗑️  Clearing existing dummy data...'))
            self._clear_dummy_data()
        
        self.stdout.write(self.style.SUCCESS('\n🎯 Starting dummy data generation...\n'))
        
        # Get system settings
        settings = SystemSettings.get_current_settings()
        current_school_year = settings.current_school_year
        
        # ✅ Get existing counselors (don't create new ones)
        counselors = list(Counselor.objects.all())
        if not counselors:
            self.stdout.write(self.style.ERROR('❌ No counselors found in the system!'))
            self.stdout.write(self.style.WARNING('Please create at least one counselor account first.'))
            return
        
        self.stdout.write(self.style.SUCCESS(f'✅ Using {len(counselors)} existing counselor(s)'))
        
        # Create teachers
        teachers = self._create_teachers(fake, options['teachers'])
        
        # Create students
        students = self._create_students(fake, options['students'], teachers, current_school_year)
        
        # Create violation types if not exists
        violation_types = list(ViolationType.objects.all())
        if not violation_types:
            self.stdout.write(self.style.WARNING('⚠️  No violation types found. Run: python manage.py seed_violation_types'))
            return
        
        # Create reports and violations
        self._create_reports_and_violations(
            fake, 
            students, 
            teachers, 
            counselors, 
            violation_types, 
            options['reports'],
            current_school_year
        )
        
        # Create counseling sessions
        self._create_counseling_sessions(fake, counselors, students)
        
        # Create login attempts
        self._create_login_attempts(fake, students, teachers)
        
        # Update violation tallies
        self._update_violation_tallies(students)
        
        self.stdout.write(self.style.SUCCESS('\n✅ Dummy data generation completed!'))
        self._print_summary(students, teachers, counselors)

    def _clear_dummy_data(self):
        """Clear existing dummy data"""
        # Delete users that are test data (you can identify them by username pattern)
        User.objects.filter(username__startswith='test_').delete()
        User.objects.filter(username__startswith='student_').delete()
        User.objects.filter(username__startswith='teacher_').delete()
        # ❌ DON'T delete counselors
        
        self.stdout.write(self.style.SUCCESS('✅ Cleared existing dummy data (kept counselors)'))

    def _create_teachers(self, fake, count):
        """Create teacher accounts"""
        self.stdout.write(self.style.SUCCESS(f'👨‍🏫 Creating {count} teachers...'))
        teachers = []
        
        departments = ['English', 'Math', 'Science', 'Filipino', 'MAPEH', 'TLE', 'Araling Panlipunan']
        grade_levels = ['7', '8', '9', '10', '11', '12']
        sections = ['A', 'B', 'C', 'D', 'E']
        strands = ['STEM', 'ABM', 'HUMSS', 'ICT', 'HOME_ECONOMICS']
        
        for i in range(count):
            username = f'teacher_{i+1}'
            user, created = User.objects.get_or_create(
                username=username,
                defaults={
                    'first_name': fake.first_name(),
                    'last_name': fake.last_name(),
                    'email': f'{username}@school.edu',
                }
            )
            if created:
                user.set_password('password123')
                user.save()
            
            grade = random.choice(grade_levels)
            section = random.choice(sections)
            
            teacher, _ = Teacher.objects.get_or_create(
                user=user,
                defaults={
                    'employee_id': f'TEACH{2000 + i}',
                    'department': random.choice(departments),
                    'specialization': random.choice(departments),
                    'advising_grade': grade,
                    'advising_strand': random.choice(strands) if grade in ['11', '12'] else None,
                    'advising_section': section,
                    'is_approved': True,
                    'approval_status': 'approved',
                    'approved_at': timezone.now() - timedelta(days=random.randint(1, 30))
                }
            )
            teachers.append(teacher)
            
        self.stdout.write(self.style.SUCCESS(f'✅ Created {len(teachers)} teachers'))
        return teachers

    def _create_students(self, fake, count, teachers, current_school_year):
        """Create student accounts"""
        self.stdout.write(self.style.SUCCESS(f'🎓 Creating {count} students...'))
        students = []
        
        grade_levels = ['7', '8', '9', '10', '11', '12']
        sections = ['A', 'B', 'C', 'D', 'E']
        strands = ['STEM', 'ABM', 'HUMSS', 'ICT', 'HOME_ECONOMICS', 'PBM']
        
        for i in range(count):
            username = f'student_{i+1}'
            user, created = User.objects.get_or_create(
                username=username,
                defaults={
                    'first_name': fake.first_name(),
                    'last_name': fake.last_name(),
                    'email': f'{username}@school.edu',
                }
            )
            if created:
                user.set_password('password123')
                user.save()
            
            grade = random.choice(grade_levels)
            section = random.choice(sections)
            
            # Generate unique LRN
            lrn = f'{random.randint(100000000000, 999999999999)}'
            
            student, _ = Student.objects.get_or_create(
                user=user,
                defaults={
                    'student_id': f'STU{3000 + i}',
                    'lrn': lrn,
                    'grade_level': grade,
                    'strand': random.choice(strands) if grade in ['11', '12'] else None,
                    'section': section,
                    'contact_number': fake.phone_number()[:15],
                    'guardian_name': fake.name(),
                    'guardian_contact': fake.phone_number()[:15],
                    'school_year': current_school_year,
                    'is_archived': random.random() < 0.1  # 10% archived
                }
            )
            
            # Create school year history
            StudentSchoolYearHistory.objects.get_or_create(
                student=student,
                school_year=current_school_year,
                defaults={
                    'grade_level': grade,
                    'section': section,
                    'strand': student.strand,
                    'adviser': random.choice(teachers) if teachers else None,
                    'is_active': True
                }
            )
            
            students.append(student)
            
        self.stdout.write(self.style.SUCCESS(f'✅ Created {len(students)} students'))
        return students

    def _create_reports_and_violations(self, fake, students, teachers, counselors, violation_types, count, school_year):
        """Create student and teacher reports with violations"""
        self.stdout.write(self.style.SUCCESS(f'📋 Creating {count} reports and violations...'))
        
        statuses = ['pending', 'under_review', 'under_investigation', 'verified', 'resolved']
        severities = ['low', 'medium', 'high', 'critical']
        locations = ['Classroom', 'Hallway', 'Cafeteria', 'Library', 'Playground', 'Gym', 'Computer Lab']
        
        student_reports_count = 0
        teacher_reports_count = 0
        violations_count = 0
        
        for i in range(count):
            # 60% teacher reports, 40% student reports
            is_teacher_report = random.random() < 0.6
            
            reporter_student = random.choice(students)
            reported_student = random.choice([s for s in students if s != reporter_student])
            violation_type = random.choice(violation_types)
            counselor = random.choice(counselors)
            
            incident_date = timezone.now() - timedelta(days=random.randint(1, 180))
            
            if is_teacher_report:
                # Create teacher report
                teacher = random.choice(teachers)
                report = TeacherReport.objects.create(
                    title=f"{violation_type.name} Incident",
                    description=fake.paragraph(nb_sentences=3),
                    reporter_teacher=teacher,
                    reported_student=reported_student,
                    violation_type=violation_type,
                    severity=random.choice(severities),
                    status=random.choice(statuses),
                    assigned_counselor=counselor,
                    incident_date=incident_date,
                    location=random.choice(locations),
                    school_year=school_year,
                    requires_counseling=random.random() < 0.8,
                    is_reviewed=random.random() < 0.7,
                    verified_by=counselor.user if random.random() < 0.6 else None,
                    verified_at=incident_date + timedelta(days=random.randint(1, 7)) if random.random() < 0.6 else None,
                )
                teacher_reports_count += 1
            else:
                # Create student report
                # 30% self-reports, 70% reporting another student
                is_self_report = random.random() < 0.3
                
                report = StudentReport.objects.create(
                    title=f"{violation_type.name} Incident",
                    description=fake.paragraph(nb_sentences=3),
                    reporter_student=reporter_student,
                    reported_student=None if is_self_report else reported_student,
                    violation_type=violation_type,
                    severity=random.choice(severities),
                    status=random.choice(statuses),
                    assigned_counselor=counselor,
                    incident_date=incident_date,
                    location=random.choice(locations),
                    school_year=school_year,
                    requires_counseling=random.random() < 0.8,
                    is_reviewed=random.random() < 0.7,
                    verified_by=counselor.user if random.random() < 0.6 else None,
                    verified_at=incident_date + timedelta(days=random.randint(1, 7)) if random.random() < 0.6 else None,
                )
                student_reports_count += 1
            
            # Create violation record if verified
            if report.status in ['verified', 'resolved']:
                StudentViolationRecord.objects.create(
                    student=reported_student,
                    violation_type=violation_type,
                    counselor=counselor,
                    related_student_report=report if not is_teacher_report else None,
                    related_teacher_report=report if is_teacher_report else None,
                    incident_date=incident_date,
                    description=report.description,
                    location=report.location,
                    status='resolved' if report.status == 'resolved' else 'active',
                    school_year=school_year,
                    action_taken=fake.sentence() if random.random() < 0.5 else None
                )
                violations_count += 1
            
            # Create counselor action
            if random.random() < 0.6:
                action_types = [
                    'counseling', 'group_session', 'parent_meeting', 'warning',
                    'detention', 'community_service', 'follow_up'
                ]
                
                CounselorAction.objects.create(
                    student_report=report if not is_teacher_report else None,
                    teacher_report=report if is_teacher_report else None,
                    counselor=counselor,
                    action_type=random.choice(action_types),
                    description=fake.paragraph(nb_sentences=2),
                    scheduled_date=incident_date + timedelta(days=random.randint(1, 14)),
                    is_completed=random.random() < 0.7
                )
        
        self.stdout.write(self.style.SUCCESS(
            f'✅ Created {student_reports_count} student reports, '
            f'{teacher_reports_count} teacher reports, '
            f'{violations_count} violation records'
        ))

    def _create_counseling_sessions(self, fake, counselors, students):
        """Create counseling sessions"""
        self.stdout.write(self.style.SUCCESS('🗓️  Creating counseling sessions...'))
        
        statuses = ['scheduled', 'completed', 'cancelled', 'no_show']
        sessions_count = 0
        
        # Get reports that require counseling
        student_reports = list(StudentReport.objects.filter(requires_counseling=True)[:30])
        teacher_reports = list(TeacherReport.objects.filter(requires_counseling=True)[:30])
        
        for report in student_reports:
            scheduled_date = report.incident_date + timedelta(days=random.randint(1, 14))
            status = random.choice(statuses)
            
            CounselingSession.objects.create(
                student_report=report,
                counselor=random.choice(counselors),
                reporter_student=report.reporter_student if not report.is_self_report() else None,
                reported_student=report.reported_student or report.reporter_student,
                scheduled_date=scheduled_date,
                actual_date=scheduled_date if status == 'completed' else None,
                status=status,
                reporter_attended=random.random() < 0.8 if not report.is_self_report() else False,
                reported_attended=random.random() < 0.8,
                session_notes=fake.paragraph(nb_sentences=3) if status == 'completed' else '',
                case_verified=status == 'completed' and random.random() < 0.7,
                summons_sent=True,
                session_duration_minutes=random.randint(30, 90) if status == 'completed' else None
            )
            sessions_count += 1
        
        for report in teacher_reports:
            scheduled_date = report.incident_date + timedelta(days=random.randint(1, 14))
            status = random.choice(statuses)
            
            CounselingSession.objects.create(
                teacher_report=report,
                counselor=random.choice(counselors),
                reported_student=report.reported_student,
                scheduled_date=scheduled_date,
                actual_date=scheduled_date if status == 'completed' else None,
                status=status,
                reported_attended=random.random() < 0.8,
                session_notes=fake.paragraph(nb_sentences=3) if status == 'completed' else '',
                case_verified=status == 'completed' and random.random() < 0.7,
                summons_sent=True,
                session_duration_minutes=random.randint(30, 90) if status == 'completed' else None
            )
            sessions_count += 1
        
        self.stdout.write(self.style.SUCCESS(f'✅ Created {sessions_count} counseling sessions'))

    def _create_login_attempts(self, fake, students, teachers):
        """Create login attempt records"""
        self.stdout.write(self.style.SUCCESS('🔐 Creating login attempts...'))
        
        attempts_count = 0
        users = []
        
        # Get some users
        for student in random.sample(list(students), min(20, len(students))):
            users.append(student.user)
        for teacher in random.sample(list(teachers), min(10, len(teachers))):
            users.append(teacher.user)
        
        for user in users:
            # Create 5-20 login attempts per user
            for _ in range(random.randint(5, 20)):
                LoginAttempt.objects.create(
                    username=user.username,
                    ip_address=fake.ipv4(),
                    attempt_time=timezone.now() - timedelta(days=random.randint(0, 30)),
                    success=random.random() < 0.9  # 90% success rate
                )
                attempts_count += 1
        
        self.stdout.write(self.style.SUCCESS(f'✅ Created {attempts_count} login attempts'))

    def _update_violation_tallies(self, students):
        """Update violation tallies for all students"""
        self.stdout.write(self.style.SUCCESS('📊 Updating violation tallies...'))
        
        updated_count = 0
        for student in students:
            tally, created = StudentViolationTally.objects.get_or_create(student=student)
            tally.update_counts()
            updated_count += 1
        
        self.stdout.write(self.style.SUCCESS(f'✅ Updated {updated_count} violation tallies'))

    def _print_summary(self, students, teachers, counselors):
        """Print summary of generated data"""
        total_students = len(students)
        total_teachers = len(teachers)
        total_counselors = len(counselors)
        total_student_reports = StudentReport.objects.count()
        total_teacher_reports = TeacherReport.objects.count()
        total_violations = StudentViolationRecord.objects.count()
        total_sessions = CounselingSession.objects.count()
        
        self.stdout.write(self.style.SUCCESS('\n' + '='*60))
        self.stdout.write(self.style.SUCCESS('📊 DUMMY DATA GENERATION SUMMARY'))
        self.stdout.write(self.style.SUCCESS('='*60))
        self.stdout.write(self.style.SUCCESS(f'👥 Users:'))
        self.stdout.write(self.style.SUCCESS(f'   • Students: {total_students} (created)'))
        self.stdout.write(self.style.SUCCESS(f'   • Teachers: {total_teachers} (created)'))
        self.stdout.write(self.style.SUCCESS(f'   • Counselors: {total_counselors} (existing, not created)'))
        self.stdout.write(self.style.SUCCESS(f'\n📋 Reports:'))
        self.stdout.write(self.style.SUCCESS(f'   • Student Reports: {total_student_reports}'))
        self.stdout.write(self.style.SUCCESS(f'   • Teacher Reports: {total_teacher_reports}'))
        self.stdout.write(self.style.SUCCESS(f'   • Total Reports: {total_student_reports + total_teacher_reports}'))
        self.stdout.write(self.style.SUCCESS(f'\n📊 Other Data:'))
        self.stdout.write(self.style.SUCCESS(f'   • Violation Records: {total_violations}'))
        self.stdout.write(self.style.SUCCESS(f'   • Counseling Sessions: {total_sessions}'))
        self.stdout.write(self.style.SUCCESS('='*60))
        self.stdout.write(self.style.SUCCESS('\n💡 Test Login Credentials:'))
        self.stdout.write(self.style.SUCCESS('   Student: student_1 / password123'))
        self.stdout.write(self.style.SUCCESS('   Teacher: teacher_1 / password123'))
        self.stdout.write(self.style.SUCCESS('   Counselor: (use your existing account)'))
        self.stdout.write(self.style.SUCCESS('='*60 + '\n'))
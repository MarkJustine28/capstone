from django.core.management.base import BaseCommand
from api.models import Student, StudentSchoolYearHistory, Teacher
from datetime import datetime
from django.db import transaction

class Command(BaseCommand):
    help = 'Roll over students to new school year (keeps violation history)'

    def add_arguments(self, parser):
        parser.add_argument(
            '--new-year',
            type=str,
            help='New school year (e.g., 2025-2026)',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Preview changes without applying them',
        )

    def handle(self, *args, **options):
        dry_run = options.get('dry_run', False)
        new_year = options.get('new_year')
        
        if not new_year:
            current_year = datetime.now().year
            current_month = datetime.now().month
            new_year = f"{current_year}-{current_year + 1}" if current_month >= 6 else f"{current_year - 1}-{current_year}"
        
        self.stdout.write(f"\n{'🔍 DRY RUN MODE' if dry_run else '🚀 EXECUTING'}: School Year Rollover to {new_year}\n")
        self.stdout.write("=" * 70)
        
        students = Student.objects.select_related('user').all()
        total_students = students.count()
        
        self.stdout.write(f"\n📊 Total students: {total_students}")
        
        if dry_run:
            self.stdout.write(f"\n{'⚠️ DRY RUN - No changes will be made'}\n")
        
        updated_count = 0
        history_created = 0
        
        with transaction.atomic():
            for student in students:
                old_year = student.school_year
                old_grade = student.grade_level
                old_section = student.section
                
                # Save current year to history
                history, created = StudentSchoolYearHistory.objects.get_or_create(
                    student=student,
                    school_year=old_year,
                    defaults={
                        'grade_level': old_grade,
                        'section': old_section,
                        'strand': student.strand,
                        'is_active': False,
                    }
                )
                
                if created:
                    history_created += 1
                    self.stdout.write(f"  📝 Archived: {student.user.get_full_name()} - {old_year} ({old_grade} {old_section})")
                
                # Update student to new school year
                if not dry_run:
                    # Promote grade level (if not Grade 12)
                    if old_grade.isdigit():
                        new_grade = str(int(old_grade) + 1) if int(old_grade) < 12 else old_grade
                    else:
                        new_grade = old_grade
                    
                    student.school_year = new_year
                    student.grade_level = new_grade
                    # Note: Section will be updated by advisers later
                    student.save()
                    
                    # Create new history entry for new year
                    StudentSchoolYearHistory.objects.create(
                        student=student,
                        school_year=new_year,
                        grade_level=new_grade,
                        section=old_section,  # Temporary, adviser will update
                        strand=student.strand,
                        is_active=True,
                    )
                    
                    updated_count += 1
                    self.stdout.write(
                        f"  ✅ Updated: {student.user.get_full_name()} - "
                        f"{old_grade} → {new_grade} (School Year: {new_year})"
                    )
            
            if dry_run:
                self.stdout.write(f"\n⚠️ DRY RUN COMPLETE - No changes were made")
                raise Exception("Dry run - rolling back transaction")
        
        self.stdout.write("\n" + "=" * 70)
        self.stdout.write(self.style.SUCCESS(f"\n✅ Rollover Complete!"))
        self.stdout.write(f"  📚 School Year History Records Created: {history_created}")
        self.stdout.write(f"  👥 Students Updated to {new_year}: {updated_count}")
        self.stdout.write(f"\n⚠️ Note: Advisers should now update student sections for their advisory classes\n")
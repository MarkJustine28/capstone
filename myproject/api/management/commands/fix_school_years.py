from django.core.management.base import BaseCommand
from api.models import Student, StudentViolationRecord
from datetime import datetime

class Command(BaseCommand):
    help = 'Fix school_year for existing students and violations'

    def handle(self, *args, **options):
        # Calculate current school year
        current_year = datetime.now().year
        current_month = datetime.now().month
        current_sy = f"{current_year}-{current_year + 1}" if current_month >= 6 else f"{current_year - 1}-{current_year}"
        
        self.stdout.write(f"🎓 Current school year: {current_sy}")
        
        # Update students without school_year
        students_null = Student.objects.filter(school_year__isnull=True)
        students_empty = Student.objects.filter(school_year='')
        
        count_null = students_null.count()
        count_empty = students_empty.count()
        
        self.stdout.write(f"📊 Found {count_null} students with NULL school_year")
        self.stdout.write(f"📊 Found {count_empty} students with empty school_year")
        
        # Update them
        students_null.update(school_year=current_sy)
        students_empty.update(school_year=current_sy)
        
        total_students = count_null + count_empty
        
        self.stdout.write(
            self.style.SUCCESS(f"✅ Updated {total_students} students to {current_sy}")
        )
        
        # Show sample
        sample_students = Student.objects.all()[:5]
        self.stdout.write("\n📋 Sample students after update:")
        for student in sample_students:
            self.stdout.write(
                f"  - {student.user.first_name} {student.user.last_name}: '{student.school_year}'"
            )
        
        # Count by school year
        self.stdout.write("\n📊 Students by school year:")
        from django.db.models import Count
        sy_counts = Student.objects.values('school_year').annotate(count=Count('id')).order_by('-school_year')
        for sy in sy_counts:
            self.stdout.write(f"  - {sy['school_year']}: {sy['count']} students")
        
        self.stdout.write(self.style.SUCCESS("\n✅ School year fix completed!"))

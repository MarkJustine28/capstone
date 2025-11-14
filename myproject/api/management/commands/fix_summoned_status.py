from django.core.management.base import BaseCommand
from api.models import StudentReport, TeacherReport

class Command(BaseCommand):
    help = 'Update summons_sent status to summoned'

    def handle(self, *args, **options):
        # Update StudentReports
        student_reports_updated = StudentReport.objects.filter(
            status='summons_sent'
        ).update(status='summoned')
        
        # Update TeacherReports
        teacher_reports_updated = TeacherReport.objects.filter(
            status='summons_sent'
        ).update(status='summoned')
        
        self.stdout.write(
            self.style.SUCCESS(
                f'✅ Updated {student_reports_updated} student reports and '
                f'{teacher_reports_updated} teacher reports from summons_sent to summoned'
            )
        )
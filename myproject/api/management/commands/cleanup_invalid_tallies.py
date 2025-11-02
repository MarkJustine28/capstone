from django.core.management.base import BaseCommand
from api.models import StudentViolationRecord, Report

class Command(BaseCommand):
    help = 'Remove violation records for reports that were not reviewed'

    def handle(self, *args, **kwargs):
        # Find all violations with related reports that are not 'reviewed' or 'resolved'
        invalid_violations = StudentViolationRecord.objects.filter(
            related_report__isnull=False
        ).exclude(
            related_report__status__in=['reviewed', 'resolved']
        )
        
        count = invalid_violations.count()
        
        if count > 0:
            self.stdout.write(self.style.WARNING(f'Found {count} invalid tallied violations'))
            
            for violation in invalid_violations:
                report = violation.related_report
                self.stdout.write(
                    f'  - Violation ID {violation.id} for report "{report.title}" (Status: {report.status})'
                )
            
            confirm = input('Do you want to delete these invalid violations? (yes/no): ')
            
            if confirm.lower() == 'yes':
                invalid_violations.delete()
                self.stdout.write(self.style.SUCCESS(f'✅ Deleted {count} invalid violations'))
            else:
                self.stdout.write(self.style.WARNING('❌ Cancelled'))
        else:
            self.stdout.write(self.style.SUCCESS('✅ No invalid violations found'))
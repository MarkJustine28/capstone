from django.core.management.base import BaseCommand
from api.models import ViolationType

class Command(BaseCommand):
    help = 'Populate violation types'

    def handle(self, *args, **options):
        violations = [
            {'name': 'Tardiness', 'category': 'Attendance', 'severity_level': 'Low'},
            {'name': 'Using Vape/Cigarette', 'category': 'Substance', 'severity_level': 'High'},
            {'name': 'Misbehavior', 'category': 'Behavioral', 'severity_level': 'Medium'},
            {'name': 'Bullying - Physical', 'category': 'Bullying', 'severity_level': 'Critical'},
            {'name': 'Bullying - Verbal/Emotional', 'category': 'Bullying', 'severity_level': 'High'},
            {'name': 'Bullying - Cyberbullying', 'category': 'Bullying', 'severity_level': 'High'},
            {'name': 'Bullying - Sexual', 'category': 'Bullying', 'severity_level': 'Critical'},
            {'name': 'Bullying - Racism', 'category': 'Bullying', 'severity_level': 'Critical'},
            {'name': 'Gambling', 'category': 'Behavioral', 'severity_level': 'Medium'},
            {'name': 'Hair Cut', 'category': 'Dress Code', 'severity_level': 'Low'},
            {'name': 'Not Wearing Proper Uniform/ID', 'category': 'Dress Code', 'severity_level': 'Low'},
            {'name': 'Cheating', 'category': 'Academic', 'severity_level': 'High'},
            {'name': 'Cutting Classes', 'category': 'Attendance', 'severity_level': 'Medium'},
            {'name': 'Absenteeism', 'category': 'Attendance', 'severity_level': 'Medium'},
        ]

        self.stdout.write(self.style.SUCCESS('🚀 Starting to populate violation types...'))
        
        created_count = 0
        existing_count = 0
        
        for violation_data in violations:
            violation, created = ViolationType.objects.get_or_create(
                name=violation_data['name'],
                defaults=violation_data
            )
            if created:
                self.stdout.write(self.style.SUCCESS(f"✅ Created: {violation.name}"))
                created_count += 1
            else:
                self.stdout.write(self.style.WARNING(f"⚠️  Already exists: {violation.name}"))
                existing_count += 1

        self.stdout.write(
            self.style.SUCCESS(
                f'\n🎉 Successfully completed!\n'
                f'📊 Summary:\n'
                f'   • Created: {created_count} new violation types\n'
                f'   • Existing: {existing_count} violation types\n'
                f'   • Total: {created_count + existing_count} violation types'
            )
        )
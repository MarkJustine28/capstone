from django.core.management.base import BaseCommand
from api.models import ViolationType  # ✅ Changed from reports.models to api.models

class Command(BaseCommand):
    help = "Seed initial violation types"

    def handle(self, *args, **kwargs):
        # Clear existing first
        ViolationType.objects.all().delete()
        self.stdout.write(self.style.WARNING('🗑️  Cleared existing violation types'))
        
        violation_data = [
            {'id': 1, 'name': 'Tardiness', 'category': 'Attendance', 'severity_level': 'Low'},
            {'id': 2, 'name': 'Absenteeism', 'category': 'Attendance', 'severity_level': 'Medium'},
            {'id': 3, 'name': 'Cutting Classes', 'category': 'Attendance', 'severity_level': 'Medium'},
            {'id': 4, 'name': 'Misbehavior', 'category': 'Behavioral', 'severity_level': 'Medium'},
            {'id': 5, 'name': 'Gambling', 'category': 'Behavioral', 'severity_level': 'Medium'},
            {'id': 6, 'name': 'Bullying - Physical', 'category': 'Bullying', 'severity_level': 'Critical'},
            {'id': 7, 'name': 'Bullying - Verbal/Emotional', 'category': 'Bullying', 'severity_level': 'High'},
            {'id': 8, 'name': 'Bullying - Cyberbullying', 'category': 'Bullying', 'severity_level': 'High'},
            {'id': 9, 'name': 'Bullying - Sexual', 'category': 'Bullying', 'severity_level': 'Critical'},
            {'id': 10, 'name': 'Bullying - Racism', 'category': 'Bullying', 'severity_level': 'Critical'},
            {'id': 11, 'name': 'Cheating', 'category': 'Academic', 'severity_level': 'High'},
            {'id': 12, 'name': 'Hair Cut', 'category': 'Dress Code', 'severity_level': 'Low'},
            {'id': 13, 'name': 'Not Wearing Proper Uniform/ID', 'category': 'Dress Code', 'severity_level': 'Low'},
            {'id': 14, 'name': 'Using Vape/Cigarette', 'category': 'Substance', 'severity_level': 'High'},
        ]

        created_count = 0
        for data in violation_data:
            vt = ViolationType.objects.create(
                id=data['id'],
                name=data['name'],
                category=data['category'],
                severity_level=data['severity_level'],
                description=f"Default description for {data['name']}"
            )
            self.stdout.write(self.style.SUCCESS(f"✅ Created: ID {vt.id:2d} - {vt.name}"))
            created_count += 1

        self.stdout.write(self.style.SUCCESS(f'\n🎉 Successfully seeded {created_count} violation types!'))

import os
from django.core.management.base import BaseCommand
from api.models import ViolationType

class Command(BaseCommand):
    help = 'Populate violation types with default data'

    def handle(self, *args, **options):
        violation_types_data = [
            # Tardiness
            {'name': 'Tardiness', 'category': 'Tardiness', 'severity_level': 'Low', 'description': 'Arriving late to class'},

            # Using Vape/Cigarette
            {'name': 'Using Vape/Cigarette', 'category': 'Using Vape/Cigarette', 'severity_level': 'High', 'description': 'Using vaping devices or cigarettes on school grounds'},

            # Misbehavior
            {'name': 'Misbehavior', 'category': 'Misbehavior', 'severity_level': 'Medium', 'description': 'General disruptive behavior'},

            # Bullying
            {'name': 'Bullying - Physical, Verbal/Emotional, Cyberbullying, Sexual, Racism', 'category': 'Bullying', 'severity_level': 'High', 'description': 'Any form of bullying including physical, verbal, emotional, cyber, sexual, or racial harassment'},

            # Gambling
            {'name': 'Gambling', 'category': 'Gambling', 'severity_level': 'Medium', 'description': 'Gambling activities on school grounds'},

            # Haircut
            {'name': 'Haircut', 'category': 'Haircut', 'severity_level': 'Low', 'description': 'Inappropriate hairstyle'},

            # Not Wearing Proper Uniform/ID
            {'name': 'Not Wearing Proper Uniform/ID', 'category': 'Not Wearing Proper Uniform/ID', 'severity_level': 'Low', 'description': 'Not wearing required school uniform or identification'},

            # Cheating
            {'name': 'Cheating', 'category': 'Cheating', 'severity_level': 'High', 'description': 'Dishonesty in examinations or assignments'},

            # Cutting Classes
            {'name': 'Cutting Classes', 'category': 'Cutting Classes', 'severity_level': 'Medium', 'description': 'Skipping classes without permission'},

            # Absenteeism
            {'name': 'Absenteeism', 'category': 'Absenteeism', 'severity_level': 'Medium', 'description': 'Frequent unexcused absences'},

            # Others
            {'name': 'Others', 'category': 'Others', 'severity_level': 'Medium', 'description': 'Other violations not listed above'},
        ]

        created_count = 0
        updated_count = 0

        for violation_data in violation_types_data:
            violation_type, created = ViolationType.objects.get_or_create(
                name=violation_data['name'],
                defaults=violation_data
            )
            
            if created:
                created_count += 1
                self.stdout.write(
                    self.style.SUCCESS(f'✅ Created: {violation_type.name}')
                )
            else:
                # Update existing record
                for key, value in violation_data.items():
                    setattr(violation_type, key, value)
                violation_type.save()
                updated_count += 1
                self.stdout.write(
                    self.style.WARNING(f'🔄 Updated: {violation_type.name}')
                )

        self.stdout.write(
            self.style.SUCCESS(
                f'\n🎉 Successfully processed {len(violation_types_data)} violation types:'
                f'\n   📝 Created: {created_count}'
                f'\n   🔄 Updated: {updated_count}'
            )
        )
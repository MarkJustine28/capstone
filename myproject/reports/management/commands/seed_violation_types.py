from django.core.management.base import BaseCommand
from api.models import ViolationType

class Command(BaseCommand):
    help = "Seed initial violation types (only if empty)"

    def handle(self, *args, **kwargs):
        # ✅ Check --force flag FIRST
        force = kwargs.get('force', False)
        
        if force:
            ViolationType.objects.all().delete()
            self.stdout.write(self.style.WARNING('🗑️  Cleared existing violation types (--force used)'))
        
        # ✅ REMOVED the "elif ViolationType.objects.exists()" check
        # Now it always attempts to seed, creating only missing violations
        
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
            # ✅ NEW: Using Mobile Phones
            {'id': 15, 'name': 'Using Mobile Phones', 'category': 'Behavioral', 'severity_level': 'Low'},
        ]

        created_count = 0
        skipped_count = 0
        
        for data in violation_data:
            vt, created = ViolationType.objects.get_or_create(
                id=data['id'],
                defaults={
                    'name': data['name'],
                    'category': data['category'],
                    'severity_level': data['severity_level'],
                    'description': f"Default description for {data['name']}"
                }
            )
            if created:
                self.stdout.write(self.style.SUCCESS(f"✅ Created: ID {vt.id:2d} - {vt.name}"))
                created_count += 1
            else:
                self.stdout.write(self.style.WARNING(f"⏭️  Skipped: ID {vt.id:2d} - {vt.name} (already exists)"))
                skipped_count += 1

        # ✅ Better summary
        self.stdout.write(self.style.SUCCESS('\n' + '='*60))
        if created_count > 0:
            self.stdout.write(self.style.SUCCESS(f'🎉 Successfully created {created_count} new violation type(s)!'))
        if skipped_count > 0:
            self.stdout.write(self.style.WARNING(f'⏭️  Skipped {skipped_count} existing violation type(s)'))
        
        total = ViolationType.objects.count()
        self.stdout.write(self.style.SUCCESS(f'📊 Total violation types in database: {total}'))
        self.stdout.write(self.style.SUCCESS('='*60 + '\n'))

    def add_arguments(self, parser):
        parser.add_argument(
            '--force',
            action='store_true',
            help='Force reset: delete existing violation types and recreate',
        )
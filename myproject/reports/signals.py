from django.db.models.signals import post_migrate
from django.dispatch import receiver
from api.models import ViolationType

@receiver(post_migrate)
def populate_violation_types(sender, **kwargs):
    """
    Automatically populate violation types after migrations.
    Prevents duplicates using get_or_create().
    """
    # Prevent running multiple times for unrelated apps
    if sender.name != "api":
        return  

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

    created_count = 0
    existing_count = 0

    for data in violations:
        obj, created = ViolationType.objects.get_or_create(
            name=data['name'],
            defaults=data
        )
        if created:
            created_count += 1
        else:
            existing_count += 1

    print(f"🚀 Violation Types Seeded → Created: {created_count}, Existing: {existing_count}")

# reports/signals.py
from django.db.models.signals import post_migrate
from django.dispatch import receiver
from reports.models import ViolationType

@receiver(post_migrate)
def create_violation_types(sender, **kwargs):
    """
    Automatically seed default violation types after migrations.
    Safe to run multiple times.
    """
    # Only run for the 'reports' app
    if sender.name != 'reports':
        return

    violation_names = [
        "Absenteeism",
        "Bullying - Physical, Verbal/Emotional, Cyberbullying, Sexual, Racism",
        "Cheating",
        "Cutting Classes",
        "Gambling",
        "Haircut",
        "Misbehavior",
        "Not Wearing Proper Uniform/ID",
        "Others",
        "Tardiness",
        "Using Vape/Cigarette",
    ]

    for name in violation_names:
        ViolationType.objects.get_or_create(name=name)

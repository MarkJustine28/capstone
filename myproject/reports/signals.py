# reports/signals.py
from django.db.models.signals import post_migrate
from django.dispatch import receiver
from django.db import connection
from reports.models import ViolationType

def table_exists(table_name):
    """Check if a table exists in the database."""
    return table_name in connection.introspection.table_names()

@receiver(post_migrate)
def create_violation_types(sender, **kwargs):
    if sender.name != 'reports':
        return

    # Only proceed if the table exists
    if not table_exists('reports_violationtype'):
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

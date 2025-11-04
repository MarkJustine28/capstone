from django.core.management.base import BaseCommand
from reports.models import ViolationType

class Command(BaseCommand):
    help = "Seed initial violation types"

    def handle(self, *args, **kwargs):
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
            obj, created = ViolationType.objects.get_or_create(name=name)
            if created:
                self.stdout.write(self.style.SUCCESS(f"Added violation type: {name}"))
            else:
                self.stdout.write(self.style.WARNING(f"Already exists: {name}"))

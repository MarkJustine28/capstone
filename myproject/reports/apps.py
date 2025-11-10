from django.apps import AppConfig

class ReportsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'reports'

    def ready(self):
        pass  # ✅ Remove or comment out the signals import
        # import reports.signals  # ❌ Comment this out

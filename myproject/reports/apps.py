from django.apps import AppConfig

class ReportConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'reports'

    def ready(self):
        import reports.signals  # 👈 Ensures signals are registered

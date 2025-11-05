from django.apps import AppConfig

class ReportConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'reports'

    def ready(self):
        import report.signals  # 👈 Ensures signals are registered

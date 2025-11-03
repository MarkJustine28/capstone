from django.contrib import admin
from django.urls import path, include
from django.http import HttpResponse
from django.core.management import call_command

def run_migrations(request):
    call_command('migrate')
    return HttpResponse("✅ Migrations applied successfully!")

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),
    path("run-migrations/", run_migrations),

    # Root endpoint (for testing)
    path('', lambda request: HttpResponse("🚀 Guidance Tracker API is running")),
]

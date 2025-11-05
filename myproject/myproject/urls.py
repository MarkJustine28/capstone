from django.contrib import admin
from django.urls import path, include
from django.http import HttpResponse
from django.core.management import call_command
from django.contrib.auth import get_user_model


def run_migrations(request):
    call_command('migrate')
    return HttpResponse("✅ Migrations applied successfully!")


def create_admin(request):
    User = get_user_model()
    username = "admin"
    email = "admin@example.com"
    password = "admin123"

    if not User.objects.filter(username=username).exists():
        User.objects.create_superuser(username=username, email=email, password=password)
        return HttpResponse("✅ Superuser created successfully!")
    else:
        return HttpResponse("⚠️ Superuser already exists.")


urlpatterns = [
    path('admin/', admin.site.urls),
    
    # Include your app routes
    path('api/', include('api.urls')),       # Existing API routes
    path('api/', include('reports.urls')),   # Add reports routes here

    path("run-migrations/", run_migrations),
    path("create-admin/", create_admin),

    # Root endpoint
    path('', lambda request: HttpResponse("🚀 Guidance Tracker API is running")),
]

from django.contrib import admin
from django.urls import path, include
from django.http import HttpResponse

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),

    # Root endpoint (for testing)
    path('', lambda request: HttpResponse("🚀 Guidance Tracker API is running")),
]

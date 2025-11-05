# reports/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('violation-types/', views.ViolationTypeListView.as_view(), name='violation-types'),
]

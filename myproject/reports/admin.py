from django.contrib import admin
from .models import ViolationType

@admin.register(ViolationType)
class ViolationTypeAdmin(admin.ModelAdmin):
    list_display = ("name",)

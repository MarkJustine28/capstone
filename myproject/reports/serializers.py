# reports/serializers.py
from rest_framework import serializers
from .models import ViolationType

class ViolationTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = ViolationType
        fields = ['id', 'name']

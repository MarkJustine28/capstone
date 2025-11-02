from rest_framework import serializers
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token
from django.contrib.auth.models import User
from .models import Student, Teacher, Counselor, Report, Notification, ViolationType

User = get_user_model()

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'role']

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            role=validated_data.get('role', 'student'),
        )
        Token.objects.create(user=user)  # auto create auth token
        return user

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name']

class StudentSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    
    class Meta:
        model = Student
        fields = ['id', 'user', 'grade_level', 'section']

class TeacherSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    
    class Meta:
        model = Teacher
        fields = ['id', 'user', 'department']

class CounselorSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    
    class Meta:
        model = Counselor
        fields = ['id', 'user', 'office']

class ViolationTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = ViolationType
        fields = ['id', 'name', 'category', 'severity_level', 'description']

class ReportSerializer(serializers.ModelSerializer):
    student = StudentSerializer(read_only=True)
    teacher = TeacherSerializer(read_only=True)
    assigned_counselor = CounselorSerializer(read_only=True)
    violation_type = ViolationTypeSerializer(read_only=True)
    reported_by = UserSerializer(read_only=True)
    created_at_formatted = serializers.SerializerMethodField()
    
    class Meta:
        model = Report
        fields = [
            'id', 'title', 'content', 'status', 'report_type',
            'student', 'teacher', 'assigned_counselor', 'reported_by',
            'violation_type', 'custom_violation', 'severity_assessment',
            'incident_date', 'location', 'witnesses', 'follow_up_required',
            'parent_notified', 'disciplinary_action', 'created_at',
            'updated_at', 'resolved_at', 'created_at_formatted'
        ]
    
    def get_created_at_formatted(self, obj):
        return obj.created_at.strftime('%Y-%m-%d %H:%M:%S') if obj.created_at else None

class ReportCreateSerializer(serializers.ModelSerializer):
    violation_type_id = serializers.IntegerField(required=False, allow_null=True)
    
    class Meta:
        model = Report
        fields = [
            'title', 'content', 'violation_type_id', 'custom_violation',
            'severity_assessment', 'incident_date', 'location', 'witnesses'
        ]

class NotificationSerializer(serializers.ModelSerializer):
    created_at_formatted = serializers.SerializerMethodField()
    
    class Meta:
        model = Notification
        fields = [
            'id', 'title', 'message', 'notification_type',
            'is_read', 'created_at', 'created_at_formatted',
            'related_report'
        ]
    
    def get_created_at_formatted(self, obj):
        return obj.created_at.strftime('%Y-%m-%d %H:%M:%S') if obj.created_at else None

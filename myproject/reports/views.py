# reports/views.py
from rest_framework import generics
from .models import ViolationType
from .serializers import ViolationTypeSerializer

class ViolationTypeListView(generics.ListAPIView):
    queryset = ViolationType.objects.all()
    serializer_class = ViolationTypeSerializer

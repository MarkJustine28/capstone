from django.http import JsonResponse
from django.utils.deprecation import MiddlewareMixin
from .models import SystemSettings
import logging

logger = logging.getLogger(__name__)


class SystemStatusMiddleware(MiddlewareMixin):
    """
    Middleware to check if system is active before allowing access.
    Admins and superusers can always access.
    """
    
    # Endpoints that should always be accessible (even when frozen)
    ALLOWED_ENDPOINTS = [
        '/api/login/',
        '/api/logout/',
        '/api/system/settings/',
        '/admin/',
        '/static/',
        '/media/',
    ]
    
    def process_request(self, request):
        """Check system status before processing request"""
        
        # Allow certain endpoints regardless of system status
        for allowed_path in self.ALLOWED_ENDPOINTS:
            if request.path.startswith(allowed_path):
                return None
        
        # Allow admin/superuser access always
        if request.user.is_authenticated and (request.user.is_staff or request.user.is_superuser):
            return None
        
        # Check system status
        try:
            settings = SystemSettings.get_current_settings()
            
            if not settings.is_system_active:
                logger.warning(f"🔒 System frozen - blocking access to: {request.path}")
                
                return JsonResponse({
                    'success': False,
                    'error': 'system_frozen',
                    'message': settings.system_message or 
                              'The Guidance Tracking System is currently unavailable. '
                              'The system will be reactivated when the new school year begins.',
                    'current_school_year': settings.current_school_year,
                    'is_system_active': False,
                }, status=503)  # 503 Service Unavailable
                
        except Exception as e:
            logger.error(f"❌ Error checking system status: {e}")
            # If error checking status, allow request to proceed
            return None
        
        return None
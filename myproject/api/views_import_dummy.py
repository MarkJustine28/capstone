import json
import os
from django.http import JsonResponse, HttpResponseForbidden
from django.core.serializers import deserialize
from django.views.decorators.csrf import csrf_exempt
from django.conf import settings

@csrf_exempt
def import_dummy_reports(request):
    SECRET_TOKEN = os.environ.get("DUMMY_IMPORT_TOKEN")

    # security check
    token = request.GET.get("token")
    if token != SECRET_TOKEN:
        return HttpResponseForbidden("Invalid or missing token.")

    file_path = os.path.join(settings.BASE_DIR, "dummy_new_reports.json")

    if not os.path.exists(file_path):
        return JsonResponse({"status": "error", "message": "Fixture not found."})

    try:
        with open(file_path, "r") as f:
            objects = deserialize("json", f)
            for obj in objects:
                obj.save()

        return JsonResponse({"status": "success", "message": "Dummy reports successfully imported!"})

    except Exception as e:
        return JsonResponse({"status": "error", "message": str(e)})

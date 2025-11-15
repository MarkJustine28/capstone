"""
Django settings for myproject project.
"""

import os
import dj_database_url
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# =============================================================================
# SECRET KEY & DEBUG
# =============================================================================

SECRET_KEY = os.getenv(
    "SECRET_KEY",
    "django-insecure-*phz0rid)(r32^w--9c7(b=p&l*a@4oi)y5u(t27byeymw!_ny"
)

DEBUG = os.getenv("DEBUG", "False").lower() == "true"

ALLOWED_HOSTS = os.getenv("ALLOWED_HOSTS", "*").split(",")

# =============================================================================
# INSTALLED APPS
# =============================================================================

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'reports',
    'rest_framework',
    'rest_framework.authtoken',
    'corsheaders',

    'api',
    'guidance_tracker',
]

ADMIN_SITE_HEADER = "Guidance Tracker Administration"
ADMIN_SITE_TITLE = "Guidance Tracker Admin"
ADMIN_INDEX_TITLE = "Welcome to Guidance Tracker Administration"

# =============================================================================
# REST FRAMEWORK
# =============================================================================

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ],
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
    'DEFAULT_PARSER_CLASSES': [
        'rest_framework.parsers.JSONParser',
    ],
}

# =============================================================================
# MIDDLEWARE
# =============================================================================

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',

    # whitenoise for static files (Render)
    'whitenoise.middleware.WhiteNoiseMiddleware',

    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'myproject.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'myproject.wsgi.application'

# =============================================================================
# DATABASE CONFIG (FULLY FIXED)
# =============================================================================

DATABASE_URL = os.getenv("DATABASE_URL")

DATABASES = {}

if DATABASE_URL:
    # Render Deployment (Use PostgreSQL)
    DATABASES["default"] = dj_database_url.config(
        default=DATABASE_URL,
        conn_max_age=600,
        ssl_require=True
    )
else:
    # Local Development (Use SQLite)
    DATABASES["default"] = {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }

# =============================================================================
# PASSWORD VALIDATION
# =============================================================================

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# =============================================================================
# INTERNATIONALIZATION
# =============================================================================

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# =============================================================================
# STATIC FILES (FIXED FOR RENDER)
# =============================================================================

STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"

# =============================================================================
# CORS
# =============================================================================

CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True

CORS_ALLOWED_HEADERS = [
    'authorization',
    'content-type',
    'x-csrftoken',
    'x-requested-with',
]

# =============================================================================
# LOGGING
# =============================================================================

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'console': {'class': 'logging.StreamHandler'},
    },
    'loggers': {
        'django': {'handlers': ['console'], 'level': 'INFO'},
        'api': {'handlers': ['console'], 'level': 'DEBUG'},
    },
}

# =============================================================================
# DEFAULT AUTO FIELD
# =============================================================================

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

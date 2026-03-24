import firebase_admin
from firebase_admin import credentials

from app.core.config import get_settings

settings = get_settings()

_firebase_app = None


def get_firebase_app():
    global _firebase_app

    if _firebase_app is None:
        cred = credentials.Certificate(settings.firebase_credentials_path)
        _firebase_app = firebase_admin.initialize_app(cred)

    return _firebase_app
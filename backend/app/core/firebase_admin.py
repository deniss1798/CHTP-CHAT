import json

import firebase_admin
from firebase_admin import credentials

from app.core.config import get_settings

settings = get_settings()
_firebase_app = None


def get_firebase_app():
    global _firebase_app

    if _firebase_app is not None:
        return _firebase_app

    firebase_json = getattr(settings, "firebase_service_account_json", None)

    if not firebase_json:
        raise RuntimeError("FIREBASE_SERVICE_ACCOUNT_JSON is not set")

    cred_dict = json.loads(firebase_json)
    cred = credentials.Certificate(cred_dict)
    _firebase_app = firebase_admin.initialize_app(cred)

    return _firebase_app
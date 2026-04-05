import json
from pathlib import Path

import firebase_admin
from firebase_admin import credentials

from app.core.config import get_settings

settings = get_settings()
_firebase_app = None


def get_firebase_app():
    global _firebase_app

    if _firebase_app is not None:
        return _firebase_app

    firebase_file = settings.firebase_service_account_file
    firebase_json = settings.firebase_service_account_json

    cred = None

    if firebase_file:
        firebase_path = Path(firebase_file)
        if firebase_path.exists():
            cred = credentials.Certificate(str(firebase_path))

    if cred is None and firebase_json:
        cred_dict = json.loads(firebase_json)
        cred = credentials.Certificate(cred_dict)

    if cred is None:
        raise RuntimeError(
            "Firebase credentials are not set. "
            "Use FIREBASE_SERVICE_ACCOUNT_FILE or FIREBASE_SERVICE_ACCOUNT_JSON"
        )

    _firebase_app = firebase_admin.initialize_app(cred)
    return _firebase_app
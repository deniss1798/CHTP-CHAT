import firebase_admin
from firebase_admin import credentials

_firebase_app = None


def get_firebase_app():
    global _firebase_app

    if _firebase_app is None:
        cred = credentials.Certificate("app/core/firebase-service-account.json")
        _firebase_app = firebase_admin.initialize_app(cred)

    return _firebase_app
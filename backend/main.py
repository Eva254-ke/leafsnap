from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any, Optional

import firebase_admin
import httpx
from fastapi import FastAPI, File, Form, Header, HTTPException, UploadFile
from firebase_admin import auth, credentials, firestore
from google.oauth2 import service_account
from googleapiclient.discovery import build
from pydantic import BaseModel, Field

app = FastAPI(title='LeafSnap API', version='1.1.0')


class VerifyGooglePlayRequest(BaseModel):
    package_name: str = Field(..., alias='packageName')
    purchase_token: str = Field(..., alias='purchaseToken')
    product_id: Optional[str] = Field(default=None, alias='productId')


class VerifyGooglePlayResponse(BaseModel):
    active: bool
    product_id: Optional[str] = Field(default=None, alias='productId')
    expires_at: Optional[str] = Field(default=None, alias='expiresAt')


class EntitlementResponse(BaseModel):
    active: bool
    product_id: Optional[str] = Field(default=None, alias='productId')
    expires_at: Optional[str] = Field(default=None, alias='expiresAt')
    updated_at: Optional[str] = Field(default=None, alias='updatedAt')


class EntitlementDocument(BaseModel):
    active: bool = False
    product_id: Optional[str] = None
    package_name: Optional[str] = None
    purchase_token: Optional[str] = None
    subscription_state: Optional[str] = None
    expires_at: Optional[datetime] = None
    source: str = 'googleplay'

    def firestore_payload(self) -> dict[str, Any]:
        payload: dict[str, Any] = {
            'active': self.active,
            'source': self.source,
        }
        if self.product_id is not None:
            payload['productId'] = self.product_id
        if self.package_name is not None:
            payload['packageName'] = self.package_name
        if self.purchase_token is not None:
            payload['purchaseToken'] = self.purchase_token
        if self.subscription_state is not None:
            payload['subscriptionState'] = self.subscription_state
        if self.expires_at is not None:
            payload['expiresAt'] = self.expires_at
        payload['updatedAt'] = firestore.SERVER_TIMESTAMP
        return payload


firebase_app = None


@app.on_event('startup')
def startup() -> None:
    _init_firebase()


@app.get('/health')
def health() -> dict[str, bool]:
    return {'ok': True}


@app.post('/v1/identify/plant')
async def identify_plant(
    images: list[UploadFile] = File(...),
    organs: list[str] = Form(...),
    language: Optional[str] = Form(default='en'),
    project: str = Form(default='all'),
    include_related_images: bool = Form(default=False, alias='includeRelatedImages'),
) -> dict[str, Any]:
    if not images or len(images) > 5:
        raise HTTPException(status_code=400, detail='images must contain 1 to 5 files.')
    if len(images) != len(organs):
        raise HTTPException(status_code=400, detail='images and organs must have the same length.')

    api_key = _require_env('PLANTNET_API_KEY')
    params = {
        'api-key': api_key,
        'include-related-images': str(include_related_images).lower(),
        'no-reject': 'true',
        'nb-results': '3',
    }
    if language:
        params['lang'] = language

    multipart: list[tuple[str, tuple[Optional[str], bytes | str, Optional[str]]]] = []
    for organ in organs:
        multipart.append(('organs', (None, organ, None)))
    for image in images:
        content = await image.read()
        multipart.append(
            (
                'images',
                (
                    image.filename or 'plant.jpg',
                    content,
                    image.content_type or 'image/jpeg',
                ),
            )
        )

    url = f'https://my-api.plantnet.org/v2/identify/{project}'
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(25.0, connect=8.0)) as client:
            response = await client.post(url, params=params, files=multipart)
    except httpx.TimeoutException as exc:
        raise HTTPException(status_code=504, detail='LeafSnap identification timed out.') from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail='LeafSnap identification gateway failed.') from exc

    if response.status_code == 429:
        raise HTTPException(status_code=429, detail='LeafSnap identification is busy.')
    if response.status_code < 200 or response.status_code >= 300:
        raise HTTPException(
            status_code=502,
            detail='LeafSnap identification provider failed.',
        )

    payload = response.json()
    if not isinstance(payload, dict):
        raise HTTPException(status_code=502, detail='LeafSnap identification returned invalid data.')
    return payload


@app.get('/v1/entitlements/me', response_model=EntitlementResponse)
def get_entitlement(
    authorization: Optional[str] = Header(default=None, alias='Authorization'),
) -> EntitlementResponse:
    uid = _verify_user(authorization)
    doc = _firestore().collection('entitlements').document(uid).get()
    if not doc.exists:
        return EntitlementResponse(active=False)

    data = doc.to_dict() or {}
    return EntitlementResponse(
        active=bool(data.get('active', False)),
        productId=data.get('productId'),
        expiresAt=_format_datetime(data.get('expiresAt')),
        updatedAt=_format_datetime(data.get('updatedAt')),
    )


@app.post('/v1/iap/googleplay/verify', response_model=VerifyGooglePlayResponse)
def verify_google_play(
    payload: VerifyGooglePlayRequest,
    authorization: Optional[str] = Header(default=None, alias='Authorization'),
) -> VerifyGooglePlayResponse:
    uid = _verify_user(authorization)
    client = _publisher_client()

    try:
        result = (
            client.purchases()
            .subscriptionsv2()
            .get(packageName=payload.package_name, token=payload.purchase_token)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail='Google Play verification failed.') from exc

    entitlement = _build_entitlement(payload, result)
    _firestore().collection('entitlements').document(uid).set(
        entitlement.firestore_payload(),
        merge=True,
    )

    return VerifyGooglePlayResponse(
        active=entitlement.active,
        productId=entitlement.product_id,
        expiresAt=_format_datetime(entitlement.expires_at),
    )


def _init_firebase() -> None:
    global firebase_app
    if firebase_admin._apps:
        firebase_app = firebase_admin.get_app()
        return

    service_account_path = os.getenv('GOOGLE_APPLICATION_CREDENTIALS', '').strip()
    if not service_account_path:
        return
    firebase_app = firebase_admin.initialize_app(
        credentials.Certificate(service_account_path),
    )


def _firestore():
    if firebase_app is None:
        _init_firebase()
    if firebase_app is None:
        raise RuntimeError('Firebase is not configured.')
    return firestore.client(app=firebase_app)


def _publisher_client():
    service_account_path = _require_env('GOOGLE_APPLICATION_CREDENTIALS')
    creds = service_account.Credentials.from_service_account_file(
        service_account_path,
        scopes=['https://www.googleapis.com/auth/androidpublisher'],
    )
    return build('androidpublisher', 'v3', credentials=creds, cache_discovery=False)


def _verify_user(authorization: Optional[str]) -> str:
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail='Missing auth token.')

    token = authorization.replace('Bearer ', '', 1).strip()
    try:
        decoded = auth.verify_id_token(token)
        uid = decoded.get('uid')
        if not uid:
            raise ValueError('Missing uid')
        return uid
    except Exception as exc:
        raise HTTPException(status_code=401, detail='Invalid auth token.') from exc


def _build_entitlement(
    payload: VerifyGooglePlayRequest,
    result: dict[str, Any],
) -> EntitlementDocument:
    state = result.get('subscriptionState')
    line_items = result.get('lineItems') or []
    first_item = line_items[0] if line_items else {}
    product_id = first_item.get('productId') or payload.product_id
    expires_at = _parse_expiry(first_item.get('expiryTime'))

    active_states = {
        'SUBSCRIPTION_STATE_ACTIVE',
        'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    }
    active = state in active_states

    return EntitlementDocument(
        active=active,
        product_id=product_id,
        package_name=payload.package_name,
        purchase_token=payload.purchase_token,
        subscription_state=state,
        expires_at=expires_at,
    )


def _parse_expiry(expiry_raw: Optional[str]) -> Optional[datetime]:
    if not expiry_raw:
        return None
    try:
        return datetime.fromisoformat(expiry_raw.replace('Z', '+00:00'))
    except ValueError:
        return None


def _format_datetime(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).isoformat()
    if hasattr(value, 'isoformat'):
        return value.isoformat()
    return str(value)


def _require_env(name: str) -> str:
    value = os.getenv(name, '').strip()
    if not value:
        raise RuntimeError(f'Missing required env var: {name}')
    return value

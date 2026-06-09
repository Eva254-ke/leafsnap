# LeafSnap API

FastAPI service for server-side plant identification, Google Play subscription verification, and Firestore entitlement writes.

## Responsibilities

- Proxies plant identification through the LeafSnap backend so mobile clients do not depend on direct provider reachability
- Keeps provider API keys off the mobile client
- Verifies Firebase Auth ID tokens
- Verifies Google Play subscription purchase tokens with the Android Publisher API
- Writes the entitlement document to Firestore as the source of truth
- Exposes the current entitlement for debugging and support

## Environment

Set `GOOGLE_APPLICATION_CREDENTIALS` to a Firebase / Google service-account JSON with:

- Firebase Admin access
- Android Publisher API access
- Firestore access

Set `PLANTNET_API_KEY` for server-side plant identification.

## Install

```bash
pip install -r requirements.txt
```

## Run

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

## Endpoints

- `GET /health`
- `POST /v1/identify/plant`
- `GET /v1/entitlements/me`
- `POST /v1/iap/googleplay/verify`

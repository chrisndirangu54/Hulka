# Hulka research inference adapter

A deliberately **fail-closed** FastAPI adapter matching the Firebase clinician-copilot contract. It authenticates the bearer token and validates input, but returns 503 until a licensed MedGemma runtime, privacy controls and independent clinical evaluation are installed. It does not claim to provide medical diagnoses. Do not enable public access. The actual pretrained weights, GPU inference, model-version pinning, PHI safeguards and clinical validation are **not implemented** here.

Development only: `pip install -r requirements.txt && uvicorn app:app --host 127.0.0.1 --port 8080`. Provide `HULKA_MEDICAL_MODEL_TOKEN` through a secure secret store.

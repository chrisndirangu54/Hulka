import os
from fastapi.testclient import TestClient
from app import app

client=TestClient(app)
payload={"modelId":"medgemma-1.5-4b","task":"questions","question":"Which missing history matters?","evidence":[],"system":"For clinician review only","maxOutputTokens":500}

def test_unauthenticated_rejected():
    assert client.post("/v1/clinical-assist",json=payload).status_code == 401

def test_fails_closed_even_with_token():
    os.environ["HULKA_MEDICAL_MODEL_TOKEN"]="test-secret"
    response=client.post("/v1/clinical-assist",json=payload,headers={"authorization":"Bearer test-secret"})
    assert response.status_code == 503

def test_invalid_task_rejected():
    os.environ["HULKA_MEDICAL_MODEL_TOKEN"]="test-secret"
    wrong=dict(payload,task="diagnose")
    assert client.post("/v1/clinical-assist",json=wrong,headers={"authorization":"Bearer test-secret"}).status_code == 422

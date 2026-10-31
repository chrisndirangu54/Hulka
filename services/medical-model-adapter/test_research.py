import importlib.util
from pathlib import Path
from unittest.mock import patch
import pytest
from fastapi.testclient import TestClient
from app import app

client=TestClient(app)
def test_pubmed_auth_required():
    assert client.post("/v1/research/pubmed",json={"topic":"malaria epidemiology"}).status_code==401

def test_pubmed_does_not_allow_pii():
    with patch.dict("os.environ",{"HULKA_MEDICAL_MODEL_TOKEN":"test-token"}):
        result=client.post("/v1/research/pubmed",json={"topic":"patient ID: 12345 fever"},
            headers={"Authorization":"Bearer test-token"})
        assert result.status_code==422

def test_medgemma_is_disabled_by_default():
    from inference import load_model
    with patch.dict("os.environ",{"HULKA_RESEARCH_INFERENCE_ENABLED":"false",
                                  "HULKA_MODEL_REVISION":""}):
        load_model.cache_clear()
        with pytest.raises(RuntimeError):
            load_model("medgemma-1.5-4b")

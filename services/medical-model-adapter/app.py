"""Hulka private inference gateway. Research mode only, no clinical approval.

Explicitly restrict network and deployment; use a service-to-service bearer secret.
No PHI persistence, no blockchain, no hospital-local training.
"""
import os
import secrets
from typing import Literal
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="Hulka Research Model Adapter", docs_url=None, redoc_url=None)
Model = Literal["medgemma-1.5-4b", "medgemma-27b"]
Task = Literal["summary", "questions", "differential_review", "lab_review", "evidence_review"]

class Reference(BaseModel):
    title: str = Field(min_length=1, max_length=150)
    url: str = Field(pattern=r"^https://", max_length=500)

class Input(BaseModel):
    modelId: Model
    task: Task
    question: str = Field(min_length=1, max_length=2000)
    evidence: list[Reference] = Field(default_factory=list, max_length=8)
    system: str = Field(max_length=1500)
    maxOutputTokens: int = Field(ge=100, le=1400)

@app.post("/v1/clinical-assist")
async def assist(payload: Input, authorization: str | None = Header(default=None)):
    configured = os.environ.get("HULKA_MEDICAL_MODEL_TOKEN", "")
    if not configured or not authorization or not secrets.compare_digest(
        authorization, "Bearer " + configured
    ):
        raise HTTPException(401, "Unauthorized")
    if os.environ.get("HULKA_RESEARCH_INFERENCE_ENABLED") != "true":
        raise HTTPException(503, "Research model runtime not enabled")
    if os.environ.get("HULKA_SYNTHETIC_ONLY") != "true":
        raise HTTPException(503, "Synthetic-only safeguard not enabled")
    try:
        from inference import research_assist
        result = research_assist(payload.modelId, payload.task,
                                 payload.question, [r.model_dump() for r in payload.evidence],
                                 payload.maxOutputTokens)
        return {"response": result, "references": [],
                "clinicalApproval": False, "researchOnly": True}
    except Exception:
        raise HTTPException(503, "Research inference unavailable")

class LiteratureQuery(BaseModel):
    topic: str = Field(min_length=3, max_length=140)

@app.post("/v1/research/pubmed")
async def pubmed_search(payload: LiteratureQuery, authorization: str | None = Header(default=None)):
    configured = os.environ.get("HULKA_MEDICAL_MODEL_TOKEN", "")
    if not configured or not authorization or not secrets.compare_digest(
        authorization, "Bearer " + configured
    ):
        raise HTTPException(401, "Unauthorized")
    # This API accepts a public scientific TOPIC only; do not include PHI.
    import re
    if re.search(r"@|\\b(?:\\+?254|0)[17]\\d{8}\\b|(?:patient|nhif|passport)\\s*(?:id|number)\\s*[:#]",payload.topic,re.I):
        raise HTTPException(422, "Personal identifiers are not allowed in PubMed searches")
    try:
        from pubmed import find_papers
        return {"results":find_papers(payload.topic),"source":"NCBI PubMed",
                "reviewStatus":"discovered_not_clinically_approved"}
    except ValueError as error:
        raise HTTPException(422, str(error))
    except Exception:
        raise HTTPException(503, "Literature search temporarily unavailable")

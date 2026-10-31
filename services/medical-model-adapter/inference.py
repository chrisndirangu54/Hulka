"""Research-only MedGemma engine; no clinical use or automatic deployment.
Enable on a private GPU with licensed weights after accepting Google's HAI-DEF terms.
Only synthetic/de-identified evaluation inputs are permitted in this runtime.
"""
import os
from functools import lru_cache

MODEL_IDS = {
    "medgemma-1.5-4b": "google/medgemma-1.5-4b-it",
    "medgemma-27b": "google/medgemma-27b-text-it",
}

@lru_cache(maxsize=1)
def load_model(model_id: str):
    if model_id not in MODEL_IDS:
        raise ValueError("Unsupported model")
    approved = os.environ.get("HULKA_MODEL_REVISION", "")
    if not approved or os.environ.get("HULKA_RESEARCH_INFERENCE_ENABLED") != "true":
        raise RuntimeError("Explicitly pinned research model revision and flag required")
    import torch
    from transformers import pipeline
    # Use gated model weights from a licensed Hugging Face/Model Garden account.
    return pipeline(
        task="image-text-to-text" if model_id == "medgemma-1.5-4b" else "text-generation",
        model=MODEL_IDS[model_id], revision=approved,
        device_map="auto", torch_dtype=torch.bfloat16,
        trust_remote_code=False,
    )

def research_assist(model_id: str, task: str, question: str, evidence: list[dict], max_tokens: int):
    engine = load_model(model_id)
    sources = "\n".join(f"[{i+1}] {r['title']} — {r['url']}" for i, r in enumerate(evidence))
    prompt = (
        "You are an experimental clinician research assistant, not a diagnostic system. "
        "Never state a definitive diagnosis or treatment plan. "
        "Offer differential considerations, information gaps, uncertainty and independent review. "
        "Only cite these supplied references; if none exist state there are no verified citations.\n"
        f"Task: {task}\nEvidence:\n{sources}\nQuestion:\n{question}"
    )
    if model_id == "medgemma-1.5-4b":
        messages = [{"role":"user","content":[{"type":"text","text":prompt}]}]
    else:
        messages = [{"role":"user","content":prompt}]
    result = engine(text=messages, max_new_tokens=max_tokens, do_sample=False)
    value = result[0].get("generated_text", "")
    if isinstance(value, list):
        value = value[-1].get("content","")
    return str(value)[:6000]

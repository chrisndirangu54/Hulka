"""Retrospective clinician-reviewed evaluation: no model training or deployment."""
import json
from pathlib import Path

def evaluate(path: str):
    cases=json.loads(Path(path).read_text())
    if not isinstance(cases,list) or not cases: raise ValueError("Evaluation cases required")
    required={"case_id","reference_answer","model_answer","clinician_score",
              "unsafe_claim","hallucinated_citation","subgroup"}
    if any(not isinstance(c,dict) or not required.issubset(c) for c in cases):
        raise ValueError("Missing independent evaluation fields")
    if any(c["clinician_score"] not in (0,1) for c in cases):
        raise ValueError("Clinician score must be binary")
    total=len(cases)
    groups={}
    for c in cases:
        g=str(c["subgroup"])
        groups.setdefault(g,{"n":0,"accepted":0,"unsafe":0})
        groups[g]["n"]+=1
        groups[g]["accepted"]+=c["clinician_score"]
        groups[g]["unsafe"]+=bool(c["unsafe_claim"])
    return {"n":total,"clinician_acceptance_rate":sum(c["clinician_score"] for c in cases)/total,
        "unsafe_claim_rate":sum(bool(c["unsafe_claim"]) for c in cases)/total,
        "hallucinated_citation_rate":sum(bool(c["hallucinated_citation"]) for c in cases)/total,
        "subgroup_counts":groups,"clinical_validation_complete":False,
        "note":"Research evaluation only; requires prospective clinical trials and governance review"}
if __name__=="__main__":
    import argparse
    p=argparse.ArgumentParser();p.add_argument("cases");a=p.parse_args()
    print(json.dumps(evaluate(a.cases),indent=2))

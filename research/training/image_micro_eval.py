"""Evaluation gate for microbiology and medical imaging research models.
Requires human adjudicated, independent external dataset evaluations.
No diagnosis or release control is granted by this module alone.
"""
import json
from pathlib import Path

REQUIRED_DOMAINS = {"radiology","microscopy","antimicrobial_susceptibility"}
def assess(report_file: str):
    report=json.loads(Path(report_file).read_text())
    if report.get("domain") not in REQUIRED_DOMAINS:
        raise ValueError("Unknown domain")
    required=["model_sha256","dataset_license","independent_external_site",
              "patient_overlap_excluded","clinician_adjudicated",
              "sensitivity","specificity","subgroup_results","failure_analysis"]
    if any(k not in report for k in required):
        raise ValueError("Insufficient evaluation documentation")
    if any(report[k] is not True for k in ["patient_overlap_excluded","clinician_adjudicated"]):
        raise ValueError("Leakage prevention and clinician adjudication required")
    for key in ("sensitivity","specificity"):
        value=report[key]
        if not isinstance(value,(int,float)) or not 0 <= value <= 1:
            raise ValueError("Invalid metric")
    # Performance reporting alone never constitutes clinical clearance.
    return {"evaluation_record_complete":True,"domain":report["domain"],
            "clinical_approval":False,"deploy_to_patient_care":False}

"""Read-only FHIR R4 adapter for authorized facility integrations.

Credentials and patient identifiers are supplied by an institutional integration,
never accepted from arbitrary client URL input. No write or automatic import.
"""
import os
import urllib.parse
import requests

ALLOWED_TYPES={"Patient","Encounter","Observation","DiagnosticReport","MedicationRequest","Condition"}
def fetch_fhir(resource_type: str, patient_id: str, bearer: str):
    base=os.environ.get("HULKA_APPROVED_FHIR_BASE","").rstrip("/")
    expected=os.environ.get("HULKA_FHIR_EXPECTED_HOST","")
    parsed=urllib.parse.urlsplit(base)
    if not base or parsed.scheme!="https" or parsed.hostname!=expected or not expected:
        raise RuntimeError("Approved hospital FHIR endpoint not configured")
    if resource_type not in ALLOWED_TYPES or not patient_id.isalnum() or len(patient_id)>128:
        raise ValueError("Invalid FHIR resource or patient identifier")
    if resource_type=="Patient":
        suffix="Patient/"+urllib.parse.quote(patient_id,safe="")
    else:
        suffix=resource_type+"?"+urllib.parse.urlencode({"patient":patient_id,"_count":20})
    response=requests.get(base+"/"+suffix,headers={
        "Authorization":"Bearer "+bearer,"Accept":"application/fhir+json"},
        timeout=12,allow_redirects=False)
    response.raise_for_status()
    data=response.json()
    if data.get("resourceType") not in ("Bundle",resource_type):
        raise ValueError("Unexpected FHIR resource")
    return {"resourceType":data["resourceType"],"data":data,
            "verification":"hospital_token_and_patient_consent_required"}

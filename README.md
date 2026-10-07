# Hulka

Hulka is a Flutter + Firebase digital-health platform designed for longitudinal patient records, cross-hospital telemedicine, pharmacy availability matching, wearable integration, clinician decision support, consent-aware data sharing, and privacy-preserving population analytics.

## Product surfaces

- Patient app: health timeline, appointments, telemedicine, prescriptions, pharmacy matching, wearables, labs, preventive care and AI health copilot.
- Clinician workspace: consent-gated longitudinal record retrieval, consultation queue, recent observations and prescription issuance.
- Pharmacy workspace: verified e-prescriptions, inventory matching, generic/brand mapping, pharmacist substitution review, dispensing and refill workflows.
- Care network and administration: verified organizations/providers, interoperability boundaries and aggregate quality/research metrics.
- Research/public-health workspace: de-identified cohort analytics, medicine-response and adverse-event signals, fairness checks and export-controlled research queries.
- Administration: institution onboarding, clinician verification, integrations, security policy, audit review and model configuration. Platform administrators do not automatically receive unrestricted clinical-record access.

## Safety principles

Hulka is not an autonomous doctor. Generative AI is used for explanation, retrieval, summarization and workflow assistance. Diagnosis, prescribing, medication substitution, emergency triage and other safety-critical actions remain controlled by validated rules/models and qualified clinicians.

Medication-response analytics must not treat race or ethnicity as biological causation. Demographic attributes, when lawfully and consensually collected, are primarily intended for epidemiology, health-equity/fairness analysis and detection of differential outcomes. More causally relevant variables such as age, renal function, comorbidities, dose, adherence, concomitant medicines, exposures and relevant genetics should be preferred.

## Architecture

```text
Flutter apps
   |
Firebase Auth / FCM / Realtime workflow state
   |
API + policy gateway
   |
   +-- Consent / authorization service
   +-- Clinical record service (FHIR-oriented)
   +-- Telemedicine service
   +-- Pharmacy & inventory service
   +-- Wearable ingestion / normalization
   +-- AI orchestration + medical retrieval
   +-- Safety / rules engine
   +-- Audit service
   |
Operational Firestore + durable clinical data layer + object/DICOM storage
   |
De-identified analytics / pharmacovigilance / ML
```

## Initial modules

```text
lib/
  core/
  models/
  services/
  features/
    dashboard/
    timeline/
    telemedicine/
    pharmacy/
    wearables/
    consent/
    clinical/
    analytics/
```

## Interoperability roadmap

Hulka should expose/consume FHIR where practical, HL7 connectors for legacy hospital systems, and DICOM/PACS integrations for imaging. Every imported measurement keeps provenance, source device/facility, timestamp, units and quality metadata.

## Data model principles

1. Patient-centered longitudinal timeline rather than hospital-siloed documents.
2. Explicit consent grants with scopes, purpose and expiry.
3. Role- and organization-aware access controls.
4. Every clinical read/write produces an audit event.
5. Synthetic/demo data is labeled and isolated from real clinical data.
6. AI outputs retain evidence links, confidence/limitations and human-review state.
7. Research datasets are de-identified/aggregated and never expose raw patient records by default.

## Status

Hulka now contains working application and Firebase backend workflows for patient identity, consent, longitudinal records, telemedicine appointments, clinician history retrieval and prescribing, pharmacy inventory/reservations, wearables, labs, emergency profiles, care programs, caregivers, insurance records, wellness logs, preventive-care rules and privacy-preserving analytics.

External systems such as hospital FHIR/HL7, DICOM/PACS, production video, insurer/payment networks, e-prescription certificates and production medical AI still require deployment-specific credentials and validation. Hulka fails closed rather than simulating those external services.

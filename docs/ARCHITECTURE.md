# Hulka architecture

## Bounded contexts

### Identity & organizations
Firebase Authentication establishes user identity. Application claims/records describe role, organization membership and verification status. Organization boundaries must be enforced server-side.

### Consent & authorization
Consent is explicit, purpose-bound, scope-based, revocable and optionally expiring. A patient's authorization to one hospital does not imply authorization to every institution.

### Clinical longitudinal record
The canonical record should evolve toward a FHIR-oriented service. Firestore is appropriate for client synchronization and operational workflow but should not become the only source of truth for a multi-hospital clinical platform.

### Telemedicine
Appointments, clinician availability, secure messaging, call/session tokens, referral workflows, consultation notes, orders and follow-up tasks.

### Pharmacy
Medication normalization, signed e-prescriptions, inventory, exact matches, generic candidates, price/availability, pharmacist review, dispensing and refill history. Medically significant substitution must not be automated solely by an LLM.

### Wearables and devices
Adapters ingest Apple/Google/Samsung/Garmin/device data into canonical observations with original source, timestamp, unit, quality metadata and ingestion version.

### AI
AI services are separated from clinical authorization. They can retrieve, summarize, explain and detect candidate patterns, but safety-critical decisions pass through deterministic policy/rule layers and human review.

### Analytics and pharmacovigilance
Medication outcomes are modeled as temporal associations first. Aggregate analysis should control for confounders where possible and include uncertainty. Race/ethnicity must not be treated as a biological causal variable; use it cautiously for health-equity/fairness analysis and disparity detection.

### Audit
Clinical access, consent changes, prescribing, dispensing, exports, administrative actions and model-assisted recommendations produce immutable server-side audit events.

## Production services to add

- Cloud Functions / Cloud Run policy gateway
- FHIR server and terminology service
- DICOM/PACS integration
- video provider integration
- e-prescription signing/verification
- pharmacy inventory connectors
- wearable OAuth/device adapters
- de-identification pipeline
- analytical warehouse
- model registry, evaluation and safety gateway
- secrets/KMS integration
- backup/disaster recovery
- security monitoring and incident response

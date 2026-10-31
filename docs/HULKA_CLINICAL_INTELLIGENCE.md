# Hulka clinical intelligence: implementation and rollout

## Product decisions
- No blockchain, tokens, decentralized ledgers or on-chain medical records.
- No hospital-side model training, federated learning or sharing gradients.
- Hulka manages model training and versioning in its controlled cloud environment.
- Training uses only approved, lawfully sourced and de-identified datasets after documented governance review. Clinical records are never used for training by default.
- Human medical professionals retain responsibility for diagnosis, prescriptions, surveillance confirmation and medical decisions.

## Changes in this branch
1. `requestLabIntelligenceReview`: creates patient-linked clinician review requests for laboratory results; does not fabricate interpretation or infer pathogens/resistance.
2. `submitSurveillanceSignal`: accepts a bounded signal and evidence reference from verified clinicians/administrators; remains private pending public-health review.
3. `registerHulkaTrainingProposal`: platform-admin-only governance intake; does not start training and does not permit clinical deployment.
4. Flutter callable wrappers for the above endpoints.

## Follow-on clinical functionality
- Clinical intelligence: summarize records only after verified consent, retrieve clinician-approved guidance, and highlight critical findings for review.
- Laboratory intelligence: schema-aware results extraction, reference-range handling, quality flags, organism/culture data and antibiotic susceptibility interpretation with laboratory oversight; independent validation required for image or AST predictors.
- Preventive care: deploy clinically reviewed WHO, Kenya Ministry of Health and other source-specific rule packs with provenance, expiration and human approval; connect source-quality-tagged wearable streams.
- Public health: vetted partner feeds, deduplication, geospatial and temporal aggregation with suppression thresholds, human authorization, and approved Jumuisha AI interoperation only.
- Research: specialist-only microbiome/genomics workflows, controlled access, de-identification and approved usage policies.

## Hulka training pipeline (not yet operational)
Proposed stages: data-use authority -> consent/legal basis -> provenance -> de-identification -> licensed, quality-controlled dataset -> versioned feature pipeline -> separated training/validation/geographic or institutional holdout -> calibration/fairness/safety assessment -> clinician review -> model registry -> staged monitored release.
Maintain independent clinical evaluation and rollback. Collect no raw clinical data in telemetry. Do not enable model-assisted clinical decisions without evidence of required regulatory approvals.

## Security and verification checklist
- Verify auth, consent, tenant isolation, App Check, input bounds, and audit coverage.
- Introduce model-registry, data-retention, access control, monitoring and revocation policies.
- Add Firestore access rules for any patient-facing review UI; current new collections are server-only.
- Confirm KMPDC/other relevant clinical service requirements, Kenya Data Protection Act obligations and applicable medical-device regulation with qualified counsel/regulators.
- Deploy to staging and run Cloud Functions build/tests, emulator authorization tests and security review before production.
- Public-health signals must not be published automatically.

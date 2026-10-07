# Hulka security and clinical-safety model

## Trust boundaries

Hulka separates user-interface convenience from clinical authority.

- Patients can access and contribute to their own record.
- Clinicians, laboratories and pharmacists require verified role records.
- Cross-provider access requires explicit patient consent scopes.
- Server-side functions perform privileged prescribing, dispensing, laboratory and audit operations.
- Browser/mobile clients cannot write audit records or aggregate research data directly.
- Platform administrators do not automatically gain patient-record access.

## Consent

Consent is purpose-bound, scoped and revocable. The current Firebase implementation uses deterministic consent IDs of `patientId_granteeId` for direct lookup in rules and server functions.

## AI safety

Generative AI must not be used as the sole mechanism for:

- autonomous diagnosis,
- medication initiation/discontinuation/dose changes,
- emergency disposition,
- controlled-drug prescribing,
- high-risk clinical decision-making.

The callable AI gateway currently fails closed when no production provider is configured and includes a deterministic emergency-language guard. Production deployments should add:

1. authenticated clinical retrieval,
2. evidence references,
3. deterministic rule checks,
4. model/output validation,
5. high-risk human review,
6. model/version logging,
7. red-team and bias evaluation.

## Wearable data

Device data keeps source, time interval, recording method and a `synthetic=false` flag. Wearables are not treated as equivalent to validated clinical instruments unless the specific device/integration supports that claim.

## Analytics

Research and population analytics must operate on de-identified or aggregate datasets. Demographic attributes, including race/ethnicity where lawfully collected, should be used for fairness, health-equity and epidemiological analysis rather than treated as simplistic biological causal variables.

## External providers

FHIR, HL7, DICOM, video, payment, insurer and model providers are adapter-based. Missing credentials must produce explicit configuration errors rather than synthetic success responses.

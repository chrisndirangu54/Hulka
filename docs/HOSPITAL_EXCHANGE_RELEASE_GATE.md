# Hulka ↔ TeknTandao Workspace clinical exchange: release gate

## Implemented
- Workspace hospitalExportPatientHistory: hospital-portal-authenticated, patient-owned, bounded (100) clinical summary; logs export actor and count; excludes billing fields.
- Hulka patientRecords: explicit patient acknowledgement; manual import of exported JSON; records marked patientSuppliedExport/unverified.
- Hulka reconcileImportedHistory: verified clinician with current timeline read/write consent may mark an unverified event verified or rejected; reason and actor audited.
- Preventive packs: bundle is educationalDraft only; task engine rejects drafts and requires clinicallyApproved, reviewer, version, current approvedAt/expiresAt, matching country and HTTPS source.
- Image restoration: existing bundled local imagery, including preventive hero.

## NOT enabled / not yet verified
A patient ID is not authorization. No automatic cross-project hospital synchronization is enabled. Do not advertise one-click data exchange or use shared client-side secrets.
Before automation, provision distinct service identities for both Firebase projects, server-side short-lived signed audience-bound assertions, facility-specific patient identity linkage with two-sided verification, consent scopes and revocation checks on **both** systems, immutable import receipts, throttling/replay prevention, structured FHIR resource validation, and per-facility data-sharing agreements. Use backend-only endpoints and avoid including patient data in logs.

## Clinical governance
No rule pack is clinicallyApproved until a licensed clinician reviews every rule against current applicable Kenya MoH guidance, documents approval date, expiry date, clinician identity, protocol version, jurisdiction, citations and exceptions. WHO, CDC and Red Cross educational links are not substitutes for Kenyan clinical protocols. Pediatric, maternal, immunization and medication decisions require specific clinical sign-off.

## Test and release checklist
1. Run Flutter analyzer and tests, and TypeScript Cloud Functions build in CI.
2. Run Firestore and Storage emulator security rule tests for unauthenticated users, wrong patient, expired/revoked consent, cross-tenant reads, and clinician roles.
3. Verify photo assets on web/mobile with network disabled.
4. Integration test hospital patient register/export; upload and manually import a fixture; verify provenance and clinician reconciliation.
5. Validate duplicate imports, malformed file handling, oversized files, failures and retries.
6. Pentest endpoints, review access controls, retention/erasure policy, backups and disaster recovery.
7. Obtain facility agreements and regulatory/legal review for Kenyan health data; approve all clinical content before production.

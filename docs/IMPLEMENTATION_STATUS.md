# Hulka implementation status

## Working foundation implemented

- Flutter Material 3 application shell
- Firebase Authentication sign-in flow and patient registration service
- longitudinal patient timeline reader
- telemedicine appointment data model and workspace
- pharmacy inventory search UI
- exact/generic pharmacy matching logic with pharmacist-review boundary
- wearable observation UI and normalization service
- scoped consent model and access workspace
- clinician workspace shell
- de-identified analytics workspace shell
- Firebase Cloud Functions for appointments, prescriptions, dispensing, consent revocation and adverse-event reporting
- server-only audit-event writes
- verified-role checks for clinical/pharmacy actions
- medication-outcome temporal-signal model
- Firebase project configuration and Firestore indexes
- application startup that fails visibly when Firebase is not configured

## External provider adapters still require deployment credentials

The repository contains the application boundary for these systems, but no real third-party integration can be activated without the relevant credentials, agreements, endpoints, certificates or mobile entitlements:

- production video-call provider
- Apple Health / HealthKit
- Android Health Connect
- Garmin / Samsung partner APIs
- hospital FHIR / HL7 endpoints
- DICOM / PACS
- laboratory feeds
- pharmacy inventory APIs
- insurer eligibility / claims APIs
- M-Pesa / card payment credentials
- e-prescription signing certificates
- terminology servers
- production medical AI/model provider

Hulka must fail closed when these services are not configured. It must not manufacture patient measurements, medication availability, clinical results or provider availability.

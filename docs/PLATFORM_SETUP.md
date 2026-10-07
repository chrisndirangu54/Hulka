# Hulka mobile and provider setup

## Generate platform projects

This repository keeps generated platform projects out of source until a deployment target is selected. From the repository root:

```bash
flutter create --platforms=android,ios,web .
flutterfire configure
```

Do not commit Firebase service-account keys or provider secrets.

## Apple HealthKit

Hulka uses the `health` Flutter package for HealthKit/Health Connect.

The current plugin requires an iOS deployment target of at least iOS 15. Enable the HealthKit capability in the Runner target and add usage descriptions to `ios/Runner/Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>Hulka reads selected health data you authorize to build your longitudinal health timeline.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Hulka writes only health data you explicitly choose to share.</string>
```

Only request data types required by enabled features.

## Android Health Connect

Declare only the Health Connect permissions needed for the measurements Hulka reads. The user must explicitly grant access through Health Connect.

Hulka intentionally does not use the deprecated Google Fit path.

## Firebase

Enable:

- Authentication (email/password initially)
- Cloud Firestore
- Cloud Functions
- Cloud Messaging
- Cloud Storage where documents/imaging references are required
- App Check for production deployments

Deploy Firestore rules and functions with the Firebase CLI after reviewing environment-specific settings.

## Hospital interoperability

Configure provider adapters separately for each institution:

- FHIR base URL and OAuth client
- HL7 integration engine where required
- DICOM/PACS endpoint
- laboratory interface
- pharmacy inventory feed
- insurer eligibility/claims service

Do not put provider credentials in Flutter. Store them in Secret Manager and invoke integrations from trusted backend services.

## Telemedicine

Hulka's API creates a telemedicine-session request but deliberately returns `configured=false` until a production video provider is bound. Choose a provider suitable for the deployment's clinical/privacy obligations and issue short-lived session tokens server-side.

## Payments

Payment functions are fail-closed until M-Pesa/card credentials are configured in the backend. The mobile application must never hold payment-provider private keys.

## AI

The AI gateway remains provider-neutral. Bind a server-side model only after adding medical retrieval, evidence capture, deterministic safety checks, model/version logging and human review for high-risk outputs.

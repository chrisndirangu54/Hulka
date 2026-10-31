/**
 * Hulka-managed clinical intelligence: no blockchain and no hospital-side model training.
 * This module is a guarded integration scaffold, not a diagnostic model.
 * Patient data is never automatically included in AI training.
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const db = () => getFirestore();
const MAX_TEXT = 2000;
const safeText = (v: unknown, max = MAX_TEXT): string =>
  typeof v === "string" ? v.trim().slice(0, max) : "";

async function verified(uid: string, roles: string[]) {
  const snap = await db().collection("users").doc(uid).get();
  const u = snap.data();
  if (!u || u.verified !== true || !roles.includes(String(u.role))) {
    throw new HttpsError("permission-denied", "Verified role required");
  }
  return u;
}
function authUid(request: { auth?: { uid?: string } }): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Sign in required");
  return uid;
}
async function permitted(patientId: string, uid: string, scope: string): Promise<boolean> {
  if (uid === patientId) return true;
  const snap = await db().collection("consents").doc(patientId + "_" + uid).get();
  const c = snap.data();
  const expires = c?.expiresAt?.toDate?.();
  return !!c && !c.revokedAt && (!expires || expires.getTime() > Date.now()) &&
    Array.isArray(c.scopes) && c.scopes.includes(scope);
}
async function log(uid: string, operation: string, identifiers: Record<string, unknown>) {
  await db().collection("auditEvents").add({ actorId: uid, action: operation,
    payload: identifiers, createdAt: FieldValue.serverTimestamp() });
}

/** Patient or consented clinician can request evidence-based interpretation of existing lab reports.
 * No LLM inference or medical diagnosis is performed until a validated provider is configured.
 */
export const requestLabIntelligenceReview = onCall(async request => {
  const uid = authUid(request), patientId = safeText(request.data?.patientId, 128),
    resultId = safeText(request.data?.resultId, 128);
  if (!patientId || !resultId) throw new HttpsError("invalid-argument", "patientId and resultId required");
  if (uid !== patientId) {
    await verified(uid, ["clinician"]);
    if (!(await permitted(patientId, uid, "patient.timeline.read"))) {
      throw new HttpsError("permission-denied", "Patient authorization required");
    }
  }
  const result = await db().collection("labResults").doc(resultId).get();
  if (!result.exists || result.data()?.patientId !== patientId) {
    throw new HttpsError("not-found", "Patient laboratory result unavailable");
  }
  const ref = await db().collection("clinicalReviewRequests").add({
    patientId, resultId, requestedBy: uid, kind: "laboratory",
    status: "awaitingClinicianReview", modelInferencePerformed: false,
    diagnosisProvided: false, createdAt: FieldValue.serverTimestamp()
  });
  await log(uid, "clinical.lab.review.request", { patientId, resultId, reviewId: ref.id });
  return { reviewId: ref.id, status: "awaitingClinicianReview",
    message: "A clinician must review the laboratory finding; automated pathogen or resistance prediction is not enabled." };
});

/** Verified clinicians can submit candidate surveillance signals; no public warning is auto-published. */
export const submitSurveillanceSignal = onCall(async request => {
  const uid = authUid(request);
  const u = await verified(uid, ["clinician", "hospitalAdmin", "platformAdmin"]);
  const condition = safeText(request.data?.condition, 120);
  const region = safeText(request.data?.region, 120);
  const evidenceRef = safeText(request.data?.evidenceRef, 300);
  if (!condition || !region || !evidenceRef) {
    throw new HttpsError("invalid-argument", "Condition, region and evidence reference required");
  }
  const ref = await db().collection("surveillanceSignals").add({
    condition, region, evidenceRef, organizationId: u.organizationId ?? null,
    submittedBy: uid, status: "pendingPublicHealthReview",
    publiclyVisible: false, patientIdentifiersIncluded: false,
    createdAt: FieldValue.serverTimestamp()
  });
  await log(uid, "surveillance.signal.submit", { signalId: ref.id });
  return { signalId: ref.id, status: "pendingPublicHealthReview" };
});

/** Hulka owns training orchestration and model artifacts.
 * Never train on raw patient records automatically: require documented approvals,
 * de-identification, licensing, dataset provenance and independent evaluation.
 */
export const registerHulkaTrainingProposal = onCall(async request => {
  const uid = authUid(request);
  await verified(uid, ["platformAdmin"]);
  const modelPurpose = safeText(request.data?.modelPurpose, 200);
  const datasetReference = safeText(request.data?.datasetReference, 300);
  const governanceApprovalId = safeText(request.data?.governanceApprovalId, 150);
  if (!modelPurpose || !datasetReference || !governanceApprovalId) {
    throw new HttpsError("invalid-argument",
      "modelPurpose, datasetReference and governanceApprovalId are required");
  }
  if (["patients/", "labResults/", "gs://"].some(prefix => datasetReference.startsWith(prefix))) {
    throw new HttpsError("invalid-argument", "Raw clinical records are not training datasets");
  }
  const ref = await db().collection("hulkaTrainingProposals").add({
    modelPurpose, datasetReference, governanceApprovalId,
    owner: "Hulka", architecture: "centralized-managed",
    hospitalLocalTraining: false, blockchain: false, requestedBy: uid,
    status: "pendingGovernanceValidation", trainingStarted: false,
    clinicalDeploymentAllowed: false,
    requires: ["data-use-approval", "deidentification-assessment",
      "dataset-provenance", "independent-holdout-evaluation",
      "subgroup-validation", "clinician-signoff", "model-monitoring-plan"],
    createdAt: FieldValue.serverTimestamp()
  });
  await log(uid, "hulka.training.proposal", { proposalId: ref.id });
  return { proposalId: ref.id, status: "pendingGovernanceValidation",
    trainingStarted: false };
});

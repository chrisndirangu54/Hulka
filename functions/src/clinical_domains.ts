import { HttpsError, onCall } from "firebase-functions/v2/https";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const db = getFirestore();
function id(v: unknown): string {
  if (typeof v !== "string" || !/^[a-zA-Z0-9_-]{1,128}$/.test(v)) {
    throw new HttpsError("invalid-argument", "Invalid identifier");
  }
  return v;
}
function text(v: unknown, limit = 300): string {
  if (typeof v !== "string" || !v.trim() || v.length > limit) {
    throw new HttpsError("invalid-argument", "Invalid required text");
  }
  return v.trim();
}
function actor(req: {auth?: {uid?: string}}): string {
  if (!req.auth?.uid) throw new HttpsError("unauthenticated", "Sign-in required");
  return req.auth.uid;
}
async function role(uid: string, expected: string[]) {
  const snap = await db.collection("users").doc(uid).get();
  const user = snap.data();
  if (!user || user.verified !== true || !expected.includes(String(user.role))) {
    throw new HttpsError("permission-denied", "Verified clinical or administrative role required");
  }
  return user;
}
async function consent(patient: string, uid: string, scope: string): Promise<boolean> {
  if (patient === uid) return true;
  const c = (await db.collection("consents").doc(patient + "_" + uid).get()).data();
  if (!c || c.revokedAt || !Array.isArray(c.scopes) || !c.scopes.includes(scope)) return false;
  const expires = c.expiresAt?.toDate?.();
  return !expires || expires.getTime() > Date.now();
}
async function audit(uid: string, action: string, keys: object) {
  await db.collection("auditEvents").add({
    actorId: uid, action, payload: keys, createdAt: FieldValue.serverTimestamp()
  });
}

/** Structured review is an administrative workflow, not automatic diagnostic interpretation. */
export const submitClinicalInsight = onCall(async req => {
  const uid = actor(req);
  await role(uid, ["clinician"]);
  const patientId = id(req.data?.patientId);
  if (!(await consent(patientId, uid, "patient.timeline.read"))) {
    throw new HttpsError("permission-denied", "Explicit patient read consent required");
  }
  const domain = text(req.data?.domain, 40);
  if (!["microbiology", "genomics", "microbiome", "preventive", "wearable", "clinical"].includes(domain)) {
    throw new HttpsError("invalid-argument", "Unsupported domain");
  }
  const evidenceRef = text(req.data?.evidenceRef, 300);
  const summary = text(req.data?.summary, 1500);
  const ref = await db.collection("clinicalInsights").add({
    patientId, domain, evidenceRef, summary,
    clinicianId: uid, reviewStatus: "clinicianAuthored",
    origin: "human", automatedDiagnosis: false,
    createdAt: FieldValue.serverTimestamp()
  });
  await audit(uid, "clinical.insight.create", {patientId, insightId: ref.id});
  return {insightId: ref.id, reviewStatus: "clinicianAuthored"};
});

/** Hospital observation intake records provenance; patient data is not shared for training. */
export const registerClinicalDataset = onCall(async req => {
  const uid = actor(req);
  await role(uid, ["platformAdmin"]);
  const datasetId = id(req.data?.datasetId);
  const approvalId = text(req.data?.approvalId, 200);
  const sourceOrganization = text(req.data?.sourceOrganization, 200);
  const license = text(req.data?.license, 200);
  const purpose = text(req.data?.purpose, 200);
  const ref = db.collection("hulkaDatasets").doc(datasetId);
  if ((await ref.get()).exists) throw new HttpsError("already-exists", "Dataset registered");
  await ref.create({approvalId, sourceOrganization, license, purpose, createdBy: uid,
    state: "pendingPrivacyAndQualityReview", containsPatientData: null,
    approvedForTraining: false, createdAt: FieldValue.serverTimestamp()});
  await audit(uid, "hulka.dataset.register", {datasetId});
  return {datasetId, state: "pendingPrivacyAndQualityReview"};
});

/** Read only, restricted to patient or consented verified clinician. */
export const listClinicalInsights = onCall(async req => {
  const uid = actor(req);
  const patientId = id(req.data?.patientId);
  if (uid !== patientId) {
    await role(uid, ["clinician"]);
    if (!(await consent(patientId, uid, "patient.timeline.read"))) {
      throw new HttpsError("permission-denied", "Patient consent required");
    }
  }
  const docs = await db.collection("clinicalInsights")
    .where("patientId", "==", patientId).limit(30).get();
  await audit(uid, "clinical.insight.read", {patientId});
  return {insights: docs.docs.map(d => ({id:d.id, ...d.data()}))};
});

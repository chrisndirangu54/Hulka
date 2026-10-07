import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

initializeApp();
const db = getFirestore();

function requireAuth(auth: { uid?: string } | undefined): string {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Authentication required");
  return auth.uid;
}

async function roleOf(uid: string): Promise<string> {
  const snap = await db.collection("users").doc(uid).get();
  return String(snap.data()?.role ?? "patient");
}

async function verified(uid: string): Promise<boolean> {
  const snap = await db.collection("users").doc(uid).get();
  return snap.data()?.verified === true;
}

async function audit(actorId: string, action: string, payload: Record<string, unknown>) {
  await db.collection("auditEvents").add({
    actorId,
    action,
    payload,
    createdAt: FieldValue.serverTimestamp(),
  });
}

export const createAppointment = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const d = request.data ?? {};
  if (!d.clinicianId || !d.organizationId || !d.startsAt) {
    throw new HttpsError("invalid-argument", "clinicianId, organizationId and startsAt are required");
  }
  const ref = db.collection("appointments").doc();
  await ref.set({
    patientId: uid,
    clinicianId: d.clinicianId,
    organizationId: d.organizationId,
    startsAt: d.startsAt,
    reason: d.reason ?? null,
    status: "requested",
    createdAt: FieldValue.serverTimestamp(),
  });
  await audit(uid, "appointment.create", { appointmentId: ref.id });
  return { appointmentId: ref.id };
});

export const issuePrescription = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  if (await roleOf(uid) !== "clinician" || !(await verified(uid))) {
    throw new HttpsError("permission-denied", "Verified clinician role required");
  }
  const d = request.data ?? {};
  for (const key of ["patientId", "genericName", "strength", "form", "quantity", "instructions"]) {
    if (d[key] === undefined || d[key] === null || d[key] === "") {
      throw new HttpsError("invalid-argument", "Missing " + key);
    }
  }
  const ref = db.collection("prescriptions").doc();
  await ref.set({
    patientId: d.patientId,
    clinicianId: uid,
    organizationId: d.organizationId ?? null,
    genericName: d.genericName,
    strength: d.strength,
    form: d.form,
    quantity: d.quantity,
    instructions: d.instructions,
    repeats: d.repeats ?? 0,
    status: "active",
    issuedAt: FieldValue.serverTimestamp(),
    substitutionAllowed: d.substitutionAllowed !== false
  });
  await audit(uid, "prescription.issue", { prescriptionId: ref.id, patientId: d.patientId });
  return { prescriptionId: ref.id };
});

export const recordDispense = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  if (await roleOf(uid) !== "pharmacist" || !(await verified(uid))) {
    throw new HttpsError("permission-denied", "Verified pharmacist role required");
  }
  const d = request.data ?? {};
  if (!d.prescriptionId || !d.medicationCode || !d.quantity) {
    throw new HttpsError("invalid-argument", "prescriptionId, medicationCode and quantity are required");
  }
  const ref = db.collection("dispensingEvents").doc();
  await ref.set({
    prescriptionId: d.prescriptionId,
    medicationCode: d.medicationCode,
    genericName: d.genericName ?? null,
    brandName: d.brandName ?? null,
    quantity: d.quantity,
    pharmacistId: uid,
    pharmacyId: d.pharmacyId ?? null,
    substitution: d.substitution === true,
    substitutionReason: d.substitutionReason ?? null,
    dispensedAt: FieldValue.serverTimestamp(),
  });
  await audit(uid, "pharmacy.dispense", {
    dispensingEventId: ref.id,
    prescriptionId: d.prescriptionId
  });
  return { dispensingEventId: ref.id };
});

export const revokeConsent = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const consentId = String(request.data?.consentId ?? "");
  if (!consentId) throw new HttpsError("invalid-argument", "consentId required");
  const ref = db.collection("consents").doc(consentId);
  const snap = await ref.get();
  if (!snap.exists || snap.data()?.patientId !== uid) {
    throw new HttpsError("permission-denied", "Only the patient may revoke this consent");
  }
  await ref.update({ revokedAt: FieldValue.serverTimestamp() });
  await audit(uid, "consent.revoke", { consentId });
  return { ok: true };
});

export const recordAdverseEvent = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const d = request.data ?? {};
  if (!d.medicationCode || !d.description) {
    throw new HttpsError("invalid-argument", "medicationCode and description are required");
  }
  const ref = db.collection("adverseEvents").doc();
  await ref.set({
    patientId: uid,
    medicationCode: d.medicationCode,
    description: d.description,
    severity: d.severity ?? "unknown",
    onsetAt: d.onsetAt ?? null,
    causality: "unassessed",
    requiresClinicalReview: true,
    createdAt: FieldValue.serverTimestamp(),
  });
  await audit(uid, "medication.adverse_event.report", { adverseEventId: ref.id });
  return { adverseEventId: ref.id };
});

export const clinicalAiGateway = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const prompt = String(request.data?.prompt ?? "").trim();
  if (!prompt) throw new HttpsError("invalid-argument", "prompt required");

  await audit(uid, "ai.query", { promptLength: prompt.length });
  return {
    answer: "AI provider is not configured. Connect a secret-managed model and medical retrieval service before production use.",
    evidence: [],
    requiresClinicalReview: false,
    configured: false
  };
});

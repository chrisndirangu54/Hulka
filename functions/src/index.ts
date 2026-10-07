import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

initializeApp();
const db = getFirestore();

type Role =
  | "patient"
  | "clinician"
  | "pharmacist"
  | "laboratory"
  | "hospitalAdmin"
  | "researcher"
  | "platformAdmin";

function requireAuth(auth: { uid?: string } | undefined): string {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Authentication required");
  return auth.uid;
}

async function user(uid: string): Promise<Record<string, unknown>> {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) throw new HttpsError("permission-denied", "User profile missing");
  return snap.data() ?? {};
}

async function requireRole(uid: string, roles: Role[]) {
  const u = await user(uid);
  if (u.verified !== true || !roles.includes(String(u.role) as Role)) {
    throw new HttpsError("permission-denied", "Verified role required");
  }
  return u;
}

async function audit(actorId: string, action: string, payload: Record<string, unknown>) {
  await db.collection("auditEvents").add({
    actorId,
    action,
    payload,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function activeConsent(patientId: string, granteeId: string, requiredScopes: string[]) {
  const direct = await db.collection("consents").doc(patientId + "_" + granteeId).get();
  const d = direct.data();
  if (!direct.exists || !d || d.revokedAt) return false;

  const expiresAt = d.expiresAt?.toDate?.();
  if (expiresAt && expiresAt.getTime() <= Date.now()) return false;

  const scopes = Array.isArray(d.scopes) ? d.scopes.map(String) : [];
  return requiredScopes.every((scope) => scopes.includes(scope));
}

export const grantConsent = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const d = request.data ?? {};
  const granteeId = String(d.granteeId ?? "");
  const scopes = Array.isArray(d.scopes) ? d.scopes.map(String) : [];
  const purpose = String(d.purpose ?? "care");
  if (!granteeId || scopes.length === 0) {
    throw new HttpsError("invalid-argument", "granteeId and scopes are required");
  }
  const id = uid + "_" + granteeId;
  await db.collection("consents").doc(id).set({
    patientId: uid,
    granteeId,
    granteeType: d.granteeType ?? "user",
    scopes,
    purpose,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: d.expiresAt ?? null,
    revokedAt: null,
  }, { merge: true });
  await audit(uid, "consent.grant", { consentId: id, granteeId, scopes, purpose });
  return { consentId: id };
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

export const getPatientSummary = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const patientId = String(request.data?.patientId ?? "");
  if (!patientId) throw new HttpsError("invalid-argument", "patientId required");

  if (patientId !== uid) {
    await requireRole(uid, ["clinician", "laboratory", "pharmacist"]);
    const allowed = await activeConsent(patientId, uid, ["patient.timeline.read"]);
    if (!allowed) throw new HttpsError("permission-denied", "Patient consent required");
  }

  const patient = await db.collection("patients").doc(patientId).get();
  const timeline = await db.collection("patients").doc(patientId)
    .collection("timeline").orderBy("occurredAt", "desc").limit(20).get();
  const observations = await db.collection("patients").doc(patientId)
    .collection("observations").orderBy("recordedAt", "desc").limit(20).get();

  await audit(uid, "patient.summary.read", { patientId });

  return {
    patient: patient.data() ?? {},
    timeline: timeline.docs.map((x) => ({ id: x.id, ...x.data() })),
    observations: observations.docs.map((x) => ({ id: x.id, ...x.data() })),
  };
});

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

export const updateAppointmentStatus = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const appointmentId = String(request.data?.appointmentId ?? "");
  const status = String(request.data?.status ?? "");
  const allowedStatuses = ["confirmed", "inProgress", "completed", "cancelled"];
  if (!appointmentId || !allowedStatuses.includes(status)) {
    throw new HttpsError("invalid-argument", "Valid appointmentId and status required");
  }

  const ref = db.collection("appointments").doc(appointmentId);
  const snap = await ref.get();
  const data = snap.data();
  if (!snap.exists || !data) throw new HttpsError("not-found", "Appointment not found");

  const isPatient = data.patientId === uid;
  const isClinician = data.clinicianId === uid;
  if (!isPatient && !isClinician) throw new HttpsError("permission-denied", "Not a participant");
  if (isPatient && !["cancelled"].includes(status)) {
    throw new HttpsError("permission-denied", "Patients may only cancel appointments");
  }

  await ref.update({ status, updatedAt: FieldValue.serverTimestamp() });
  await audit(uid, "appointment.status", { appointmentId, status });
  return { ok: true };
});

export const createTelemedicineSession = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const appointmentId = String(request.data?.appointmentId ?? "");
  if (!appointmentId) throw new HttpsError("invalid-argument", "appointmentId required");
  const snap = await db.collection("appointments").doc(appointmentId).get();
  const a = snap.data();
  if (!snap.exists || !a) throw new HttpsError("not-found", "Appointment not found");
  if (a.patientId !== uid && a.clinicianId !== uid) {
    throw new HttpsError("permission-denied", "Not a participant");
  }

  await audit(uid, "telemedicine.session.request", { appointmentId });
  return {
    configured: false,
    message: "No production video provider is configured. Bind a secret-managed provider adapter before deployment."
  };
});

export const issuePrescription = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  await requireRole(uid, ["clinician"]);

  const d = request.data ?? {};
  for (const key of ["patientId", "genericName", "strength", "form", "quantity", "instructions"]) {
    if (d[key] === undefined || d[key] === null || d[key] === "") {
      throw new HttpsError("invalid-argument", "Missing " + key);
    }
  }

  if (!(await activeConsent(String(d.patientId), uid, ["patient.timeline.write"]))) {
    throw new HttpsError("permission-denied", "Patient consent required");
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
    substitutionAllowed: d.substitutionAllowed !== false,
    digitalSignatureRef: d.digitalSignatureRef ?? null,
  });

  await db.collection("patients").doc(String(d.patientId)).collection("timeline").add({
    type: "prescription",
    title: "Prescription issued",
    summary: String(d.genericName) + " " + String(d.strength),
    occurredAt: FieldValue.serverTimestamp(),
    sourceOrganizationId: d.organizationId ?? null,
    evidenceRefs: [ref.id],
    synthetic: false,
  });

  await audit(uid, "prescription.issue", { prescriptionId: ref.id, patientId: d.patientId });
  return { prescriptionId: ref.id };
});

export const upsertPharmacyInventory = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const u = await requireRole(uid, ["pharmacist"]);
  const d = request.data ?? {};
  for (const key of ["medicationCode", "genericName", "strength", "doseForm", "availableQuantity", "price", "currency"]) {
    if (d[key] === undefined || d[key] === null || d[key] === "") {
      throw new HttpsError("invalid-argument", "Missing " + key);
    }
  }
  const pharmacyId = String(d.pharmacyId ?? u.organizationId ?? "");
  if (!pharmacyId) throw new HttpsError("invalid-argument", "pharmacyId required");

  const id = pharmacyId + "_" + String(d.medicationCode);
  await db.collection("pharmacyInventory").doc(id).set({
    ...d,
    pharmacyId,
    updatedBy: uid,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await audit(uid, "pharmacy.inventory.upsert", { inventoryId: id });
  return { inventoryId: id };
});

export const recordDispense = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  await requireRole(uid, ["pharmacist"]);
  const d = request.data ?? {};
  if (!d.prescriptionId || !d.medicationCode || !d.quantity) {
    throw new HttpsError("invalid-argument", "prescriptionId, medicationCode and quantity are required");
  }

  const prescription = await db.collection("prescriptions").doc(String(d.prescriptionId)).get();
  if (!prescription.exists) throw new HttpsError("not-found", "Prescription not found");

  const ref = db.collection("dispensingEvents").doc();
  await ref.set({
    prescriptionId: d.prescriptionId,
    patientId: prescription.data()?.patientId ?? null,
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

export const recordLabResult = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  await requireRole(uid, ["laboratory"]);
  const d = request.data ?? {};
  for (const key of ["patientId", "testName", "value", "unit"]) {
    if (d[key] === undefined || d[key] === null || d[key] === "") {
      throw new HttpsError("invalid-argument", "Missing " + key);
    }
  }
  if (!(await activeConsent(String(d.patientId), uid, ["patient.timeline.write"]))) {
    throw new HttpsError("permission-denied", "Patient consent required");
  }

  const ref = db.collection("labResults").doc();
  await ref.set({
    patientId: d.patientId,
    testName: d.testName,
    code: d.code ?? null,
    value: d.value,
    unit: d.unit,
    referenceRange: d.referenceRange ?? null,
    organizationId: d.organizationId ?? null,
    collectedAt: d.collectedAt ?? FieldValue.serverTimestamp(),
    recordedBy: uid,
    synthetic: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  await db.collection("patients").doc(String(d.patientId)).collection("timeline").add({
    type: "lab_result",
    title: String(d.testName),
    summary: String(d.value) + " " + String(d.unit),
    occurredAt: FieldValue.serverTimestamp(),
    sourceOrganizationId: d.organizationId ?? null,
    evidenceRefs: [ref.id],
    synthetic: false,
  });

  await audit(uid, "lab.result.record", { labResultId: ref.id, patientId: d.patientId });
  return { labResultId: ref.id };
});

export const saveEmergencyProfile = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const d = request.data ?? {};
  const safe = {
    patientId: uid,
    bloodGroup: d.bloodGroup ?? null,
    criticalAllergies: Array.isArray(d.criticalAllergies) ? d.criticalAllergies.map(String) : [],
    majorConditions: Array.isArray(d.majorConditions) ? d.majorConditions.map(String) : [],
    currentMedications: Array.isArray(d.currentMedications) ? d.currentMedications.map(String) : [],
    emergencyContactName: d.emergencyContactName ?? null,
    emergencyContactPhone: d.emergencyContactPhone ?? null,
    implants: Array.isArray(d.implants) ? d.implants.map(String) : [],
    updatedAt: FieldValue.serverTimestamp(),
  };
  await db.collection("emergencyProfiles").doc(uid).set(safe, { merge: true });
  await audit(uid, "emergency_profile.update", {});
  return { ok: true };
});

export const linkCaregiver = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const caregiverId = String(request.data?.caregiverId ?? "");
  const scopes = Array.isArray(request.data?.scopes) ? request.data.scopes.map(String) : [];
  if (!caregiverId || scopes.length === 0) {
    throw new HttpsError("invalid-argument", "caregiverId and scopes required");
  }
  const id = uid + "_" + caregiverId;
  await db.collection("caregiverGrants").doc(id).set({
    patientId: uid,
    caregiverId,
    scopes,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: request.data?.expiresAt ?? null,
    revokedAt: null,
  }, { merge: true });
  await audit(uid, "caregiver.link", { caregiverId, scopes });
  return { caregiverGrantId: id };
});

export const enrollCareProgram = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const type = String(request.data?.type ?? "");
  if (!type) throw new HttpsError("invalid-argument", "Care program type required");
  const ref = db.collection("carePrograms").doc();
  await ref.set({
    patientId: uid,
    type,
    startedAt: FieldValue.serverTimestamp(),
    active: true,
    goals: Array.isArray(request.data?.goals) ? request.data.goals.map(String) : [],
    clinicianId: request.data?.clinicianId ?? null,
    organizationId: request.data?.organizationId ?? null,
  });
  await audit(uid, "care_program.enroll", { careProgramId: ref.id, type });
  return { careProgramId: ref.id };
});

export const saveInsuranceCoverage = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const d = request.data ?? {};
  if (!d.insurerId || !d.planName || !d.memberReference) {
    throw new HttpsError("invalid-argument", "insurerId, planName and memberReference required");
  }
  const ref = db.collection("insuranceCoverage").doc();
  await ref.set({
    patientId: uid,
    insurerId: d.insurerId,
    planName: d.planName,
    memberReference: d.memberReference,
    active: true,
    createdAt: FieldValue.serverTimestamp(),
  });
  await audit(uid, "insurance.coverage.add", { coverageId: ref.id });
  return { coverageId: ref.id };
});

export const insuranceEligibility = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  await audit(uid, "insurance.eligibility.request", {});
  return {
    configured: false,
    covered: null,
    message: "No insurer connector is configured for this deployment."
  };
});

export const createPayment = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  const d = request.data ?? {};
  if (!d.amount || !d.currency || !d.reference) {
    throw new HttpsError("invalid-argument", "amount, currency and reference required");
  }
  await audit(uid, "payment.request", {
    amount: d.amount,
    currency: d.currency,
    reference: d.reference
  });
  return {
    configured: false,
    message: "No payment provider is configured. Bind M-Pesa/card credentials server-side."
  };
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

  const lower = prompt.toLowerCase();
  const emergencyTerms = [
    "chest pain",
    "cannot breathe",
    "can't breathe",
    "stroke",
    "unconscious",
    "severe bleeding",
    "suicide",
    "kill myself",
  ];
  if (emergencyTerms.some((x) => lower.includes(x))) {
    await audit(uid, "ai.emergency_guard", { promptLength: prompt.length });
    return {
      answer: "This may describe an emergency. Seek immediate in-person emergency care or contact local emergency services. Hulka should not continue an ordinary AI consultation for this situation.",
      evidence: [],
      requiresClinicalReview: true,
      emergency: true,
      configured: true
    };
  }

  await audit(uid, "ai.query", { promptLength: prompt.length });
  return {
    answer: "AI provider is not configured. Connect a secret-managed model, medical retrieval service and output-safety validator before production use.",
    evidence: [],
    requiresClinicalReview: false,
    configured: false
  };
});

export const getPopulationMetric = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  await requireRole(uid, ["researcher", "hospitalAdmin"]);
  const metric = String(request.data?.metric ?? "");
  if (!metric) throw new HttpsError("invalid-argument", "metric required");

  const snap = await db.collection("analyticsAggregates").doc(metric).get();
  await audit(uid, "analytics.metric.read", { metric });
  if (!snap.exists) return { metric, available: false };
  return { metric, available: true, ...snap.data() };
});


function ageBand(dateOfBirth: unknown): string {
  const value = dateOfBirth as { toDate?: () => Date } | string | undefined;
  let dob: Date | null = null;
  if (value && typeof value === "object" && typeof value.toDate === "function") dob = value.toDate();
  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) dob = parsed;
  }
  if (!dob) return "unknown";
  const now = new Date();
  let age = now.getUTCFullYear() - dob.getUTCFullYear();
  const beforeBirthday =
    now.getUTCMonth() < dob.getUTCMonth() ||
    (now.getUTCMonth() === dob.getUTCMonth() && now.getUTCDate() < dob.getUTCDate());
  if (beforeBirthday) age -= 1;
  if (age < 18) return "under_18";
  if (age < 30) return "18_29";
  if (age < 45) return "30_44";
  if (age < 60) return "45_59";
  if (age < 75) return "60_74";
  return "75_plus";
}

export const rebuildMedicationReactionAggregate = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  await requireRole(uid, ["researcher", "hospitalAdmin"]);
  const medicationCode = String(request.data?.medicationCode ?? "").trim();
  if (!medicationCode) throw new HttpsError("invalid-argument", "medicationCode required");

  const events = await db.collection("adverseEvents")
    .where("medicationCode", "==", medicationCode)
    .limit(5000)
    .get();

  const groups = new Map<string, number>();
  for (const event of events.docs) {
    const patientId = String(event.data().patientId ?? "");
    if (!patientId) continue;
    const patient = await db.collection("patients").doc(patientId).get();
    const p = patient.data() ?? {};
    const age = ageBand(p.dateOfBirth);
    const sex = String(p.sex ?? "unknown");
    const demographic = String(p.ethnicityOrRace ?? "not_provided");
    const key = JSON.stringify({ ageBand: age, sex, demographic });
    groups.set(key, (groups.get(key) ?? 0) + 1);
  }

  const minimumCohort = 10;
  const cohorts = [...groups.entries()]
    .filter(([, count]) => count >= minimumCohort)
    .map(([key, count]) => ({ ...JSON.parse(key), adverseEventCount: count }));

  const aggregate = {
    medicationCode,
    eventCount: events.size,
    minimumCohort,
    cohorts,
    interpretation:
      "Descriptive pharmacovigilance counts only. Demographic association does not establish biological causation or treatment effect.",
    rebuiltAt: FieldValue.serverTimestamp(),
  };

  await db.collection("analyticsAggregates").doc("medication_" + medicationCode).set(aggregate);
  await audit(uid, "analytics.medication_reaction.rebuild", {
    medicationCode,
    sourceEventCount: events.size,
    publishedCohorts: cohorts.length,
  });

  return {
    medicationCode,
    eventCount: events.size,
    minimumCohort,
    publishedCohorts: cohorts.length,
  };
});


export const upsertHealthcareOrganization = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  await requireRole(uid, ["platformAdmin"]);
  const d = request.data ?? {};
  const name = String(d.name ?? "").trim();
  const type = String(d.type ?? "").trim();
  const countryCode = String(d.countryCode ?? "").trim();
  if (!name || !type || !countryCode) {
    throw new HttpsError("invalid-argument", "name, type and countryCode required");
  }

  const ref = d.organizationId
    ? db.collection("organizations").doc(String(d.organizationId))
    : db.collection("organizations").doc();

  await ref.set({
    name,
    type,
    countryCode,
    facilityCode: d.facilityCode ?? null,
    verified: d.verified === true,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await audit(uid, "organization.upsert", { organizationId: ref.id, type });
  return { organizationId: ref.id };
});

export const verifyProviderAccount = onCall(async (request) => {
  const uid = requireAuth(request.auth);
  await requireRole(uid, ["platformAdmin"]);

  const providerUid = String(request.data?.providerUid ?? "");
  const role = String(request.data?.role ?? "") as Role;
  const organizationId = String(request.data?.organizationId ?? "");
  const providerRoles: Role[] = ["clinician", "pharmacist", "laboratory", "hospitalAdmin", "researcher"];

  if (!providerUid || !providerRoles.includes(role) || !organizationId) {
    throw new HttpsError("invalid-argument", "providerUid, approved provider role and organizationId required");
  }

  const org = await db.collection("organizations").doc(organizationId).get();
  if (!org.exists || org.data()?.verified !== true) {
    throw new HttpsError("failed-precondition", "Provider organization must be verified first");
  }

  await db.collection("users").doc(providerUid).set({
    role,
    organizationId,
    verified: true,
    providerVerifiedAt: FieldValue.serverTimestamp(),
    providerVerifiedBy: uid,
  }, { merge: true });

  await audit(uid, "provider.verify", { providerUid, role, organizationId });
  return { ok: true };
});

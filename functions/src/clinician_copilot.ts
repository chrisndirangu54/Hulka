import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const endpoint = defineSecret("HULKA_MEDICAL_MODEL_ENDPOINT");
const token = defineSecret("HULKA_MEDICAL_MODEL_TOKEN");
const db = () => getFirestore();
const MODELS = {
  "medgemma-1.5-4b": {
    displayName: "Google MedGemma 1.5 4B",
    source: "https://developers.google.com/health-ai-developer-foundations/medgemma/model-card",
    intendedUse: "Medical text and image research development",
    clinicalApproval: false,
  },
  "medgemma-27b": {
    displayName: "Google MedGemma 27B",
    source: "https://developers.google.com/health-ai-developer-foundations/medgemma/model-card-v1",
    intendedUse: "Medical-language research development",
    clinicalApproval: false,
  },
} as const;
type ModelId = keyof typeof MODELS;
const allowedTypes = ["summary", "questions", "differential_review", "lab_review", "evidence_review"];
function bounded(value: unknown, max: number): string {
  if (typeof value !== "string" || !value.trim() || value.length > max) {
    throw new HttpsError("invalid-argument", "Missing or oversized input");
  }
  return value.trim();
}
function uid(auth: {uid?: string}|undefined): string {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Sign in required");
  return auth.uid;
}
async function clinician(userId: string) {
  const user = (await db().collection("users").doc(userId).get()).data();
  if (!user || user.role !== "clinician" || user.verified !== true) {
    throw new HttpsError("permission-denied", "Verified clinician role required");
  }
  return user;
}
async function consent(patientId: string, clinicianId: string): Promise<boolean> {
  const c = (await db().collection("consents").doc(patientId + "_" + clinicianId).get()).data();
  if (!c || c.revokedAt || !Array.isArray(c.scopes) ||
      !c.scopes.includes("patient.timeline.read")) return false;
  const exp = c.expiresAt?.toDate?.();
  return !exp || exp.getTime() > Date.now();
}
function isSafeEndpoint(raw: string): boolean {
  try {
    const url = new URL(raw);
    if (url.protocol !== "https:" || url.username || url.password ||
        url.port || url.search || url.hash || url.pathname !== "/v1/clinical-assist") return false;
    const hosts = (process.env.HULKA_APPROVED_MODEL_HOSTS ?? "")
      .split(",").map(x => x.trim().toLowerCase()).filter(Boolean);
    return hosts.length > 0 && hosts.includes(url.hostname.toLowerCase());
  } catch { return false; }
}
function checkOutput(raw: unknown): {response: string; references: Array<{title:string;url:string}>} {
  if (!raw || typeof raw !== "object") throw new Error("Bad model output");
  const obj = raw as Record<string,unknown>;
  const response = typeof obj.response === "string" ? obj.response.slice(0,6000) : "";
  if (!response.trim()) throw new Error("Model returned no answer");
  const references = Array.isArray(obj.references) ? obj.references.slice(0,10)
    .filter((r): r is {title:string;url:string} => !!r && typeof r === "object" &&
      typeof r.title === "string" && typeof r.url === "string" &&
      /^https:\/\//.test(r.url)).map(r => ({title:r.title.slice(0,150),url:r.url.slice(0,500)})) : [];
  return {response,references};
}

/** An explicitly gated clinical-assistance endpoint.
 * Evidence is supplied from a separately approved corpus; model-generated URLs are
 * not treated as validated literature. No autonomous clinical action is taken.
 */
export const clinicianCopilot = onCall({secrets:[endpoint,token], timeoutSeconds:60},
async request => {
  const userId = uid(request.auth);
  await clinician(userId);
  const patientId = bounded(request.data?.patientId,128);
  const task = bounded(request.data?.task,40);
  const modelId = bounded(request.data?.modelId,40) as ModelId;
  const question = bounded(request.data?.question,2000);
  if (!allowedTypes.includes(task) || !Object.prototype.hasOwnProperty.call(MODELS,modelId)) {
    throw new HttpsError("invalid-argument","Unsupported task or model");
  }
  if (!(await consent(patientId,userId))) {
    throw new HttpsError("permission-denied","Patient consent required");
  }
  // Trust only server-validated, independently approved evidence records.
  const evidenceIds = request.data?.evidenceIds ?? [];
  if (!Array.isArray(evidenceIds) || evidenceIds.length > 8 ||
      evidenceIds.some((e: unknown) => typeof e !== "string" ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(e))) {
    throw new HttpsError("invalid-argument","Valid reviewed evidence identifiers required");
  }
  const evidence: Array<{title:string;url:string}> = [];
  for (const evidenceId of evidenceIds) {
    const record = (await db().collection("reviewedEvidence").doc(evidenceId).get()).data();
    if (!record || record.clinicalApproved !== true ||
        record.sourceVerified !== true || typeof record.title !== "string" ||
        typeof record.url !== "string" || !record.url.startsWith("https://")) {
      throw new HttpsError("failed-precondition","Evidence not independently approved");
    }
    evidence.push({title:record.title.slice(0,150),url:record.url.slice(0,500)});
  }
  // Prevent raw personal identifiers from being sent to a research gateway.
  // This is a conservative blocklist, not a substitute for privacy review.
  const unsafeMarkers = [
    /\\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}\\b/i,
    /\\b(?:\\+?254|0)[17]\\d{8}\\b/,
    /\\b(?:national\\s+id|passport\\s+number|nhif\\s+number|patient\\s+id)\\s*[:#-]\\s*[A-Za-z0-9-]+/i
  ];
  if (unsafeMarkers.some(pattern => pattern.test(question))) {
    throw new HttpsError("invalid-argument",
      "Remove direct patient identifiers before requesting research assistance");
  }
  // Clinical evidence is required for assertions that purport to review published findings.
  if (task === "evidence_review" && evidence.length === 0) {
    throw new HttpsError("failed-precondition",
      "Select at least one independently approved reference");
  }
  // Per-clinician fixed-window quota: prevents accidental bulk inference and
  // excessive requests. This is not a substitute for service-wide cost limits.
  const windowStart = Math.floor(Date.now() / 3600000);
  const quotaRef = db().collection("clinicalAiQuotas").doc(userId + "_" + windowStart);
  await db().runTransaction(async tx => {
    const snap = await tx.get(quotaRef);
    const count = Number(snap.data()?.count ?? 0);
    if (count >= 20) {
      throw new HttpsError("resource-exhausted",
        "Clinical research assistance limit reached for this hour");
    }
    tx.set(quotaRef, {userId, windowStart, count: count + 1,
      expiresAt: new Date((windowStart + 2) * 3600000)}, {merge:true});
  });
  const modelUrl = endpoint.value();
  const apiToken = token.value();
  if (!modelUrl || !apiToken || !isSafeEndpoint(modelUrl)) {
    return {configured:false, clinicianReviewRequired:true, model:MODELS[modelId],
      message:"No approved Hulka model gateway configured. No inference performed."};
  }
  // Never send the entire patient chart. Do not include patient name, address or identifiers.
  // Clinician question may still contain PHI: gateway approval and lawful data transfer required.
  const payload = {
    modelId, task, question, evidence,
    system: "You are Hulka's research-grade clinician assistant. Support, never replace, licensed clinical judgment. Organize clinical evidence, provide questions to consider, possible alternatives and gaps, never assert a final diagnosis or prescribe. State uncertainty. Cite only supplied, verified references. Do not invent citations.",
    maxOutputTokens: 1400
  };
  let outcome;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 45000);
    try {
      const res = await fetch(modelUrl,{method:"POST",signal:controller.signal,
        headers:{"content-type":"application/json","authorization":"Bearer "+apiToken},
        body:JSON.stringify(payload)});
      if (!res.ok) throw new Error("Model provider unavailable");
      outcome = checkOutput(await res.json());
    } finally { clearTimeout(timer); }
  } catch {
    throw new HttpsError("unavailable","Clinical assistance temporarily unavailable");
  }
  // Returned model references are excluded: only caller-supplied, human-reviewed sources appear.
  await db().collection("auditEvents").add({
    actorId:userId, action:"clinician.copilot.invoke",
    payload:{patientId,modelId,task,evidenceCount:evidence.length},
    createdAt:FieldValue.serverTimestamp()
  });
  return {configured:true, reviewStatus:"notClinicallyValidated",
    clinicianReviewRequired:true, modelId, model:MODELS[modelId],
    response:outcome.response,
    evidence: evidence.map((e:any) => ({title:String(e.title).slice(0,150),url:String(e.url).slice(0,500)})),
    notice:"Unvalidated AI research assistance. Verify independently. Not a diagnosis."};
});

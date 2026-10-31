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
  // Accept only reviewed, explicitly supplied evidence references, never invented papers.
  const evidence = Array.isArray(request.data?.evidence) ? request.data.evidence : [];
  if (evidence.length > 8 || evidence.some((e: unknown) =>
    !e || typeof e !== "object" || typeof (e as any).title !== "string" ||
    typeof (e as any).url !== "string" ||
    !(e as any).url.startsWith("https://"))) {
    throw new HttpsError("invalid-argument","Only verified evidence references allowed");
  }
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

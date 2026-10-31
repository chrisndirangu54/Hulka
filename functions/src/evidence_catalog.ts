import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const db = () => getFirestore();
const accepted = new Set(["WHO","Kenya MoH","CDC","Peer reviewed publication","Hospital protocol"]);
const toText = (v: unknown, max: number) =>
  typeof v === "string" && v.trim().length && v.length <= max ? v.trim() : "";
async function requireIdentity(auth: {uid?: string}|undefined, allowed: string[]) {
  if (!auth?.uid) throw new HttpsError("unauthenticated","Authentication required");
  const u=(await db().collection("users").doc(auth.uid).get()).data();
  if (!u || u.verified !== true || !allowed.includes(String(u.role))) {
    throw new HttpsError("permission-denied","Verified role required");
  }
  return auth.uid;
}
/** Admin-reviewed evidence catalogue: references only, no downloaded content or scraped PHI. */
export const registerReviewedEvidence = onCall(async request => {
  const uid=await requireIdentity(request.auth,["platformAdmin"]);
  const d=request.data ?? {};
  const title=toText(d.title,180), url=toText(d.url,500);
  const publisher=toText(d.publisher,80), version=toText(d.version,90);
  if(!title || !url || !version || !accepted.has(publisher)) {
    throw new HttpsError("invalid-argument","Evidence metadata required");
  }
  try { const u=new URL(url); if(u.protocol!=="https:" || u.username || u.password)
    throw new Error("Invalid"); } catch {
    throw new HttpsError("invalid-argument","HTTPS reference required");
  }
  const ref=await db().collection("reviewedEvidence").add({
    title,url,publisher,version,sourceVerified:false,clinicalApproved:false,
    approvalStatus:"pendingIndependentReview",addedBy:uid,
    createdAt:FieldValue.serverTimestamp()
  });
  await db().collection("auditEvents").add({actorId:uid,
    action:"evidence.submit",payload:{evidenceId:ref.id},
    createdAt:FieldValue.serverTimestamp()});
  return {evidenceId:ref.id,status:"pendingIndependentReview"};
});
/** Published only after a verified, independent review step outside this API. */
export const searchReviewedEvidence = onCall(async request => {
  await requireIdentity(request.auth,["clinician","platformAdmin"]);
  const term=toText(request.data?.query,120).toLowerCase();
  if(term.length<3) throw new HttpsError("invalid-argument","Query must contain at least 3 characters");
  const snapshot=await db().collection("reviewedEvidence")
    .where("clinicalApproved","==",true).limit(100).get();
  const matches=snapshot.docs.map(d=>({id:d.id,...d.data()}))
    .filter((d:any)=>String(d.title).toLowerCase().includes(term) ||
      String(d.publisher).toLowerCase().includes(term)).slice(0,15);
  return {references:matches,verifiedOnly:true};
});

/** Two-person review: a second verified platform administrator can approve
 * source provenance only after independently checking the publication.
 * This is not clinical guideline endorsement or model accreditation.
 */
export const verifyEvidenceSource = onCall(async request => {
  const uid = await requireIdentity(request.auth, ["platformAdmin"]);
  const evidenceId = toText(request.data?.evidenceId, 128);
  if (!/^[A-Za-z0-9_-]+$/.test(evidenceId)) {
    throw new HttpsError("invalid-argument", "Invalid evidence ID");
  }
  const ref = db().collection("reviewedEvidence").doc(evidenceId);
  await db().runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    const data = snapshot.data();
    if (!data) throw new HttpsError("not-found", "Reference not found");
    if (data.addedBy === uid) throw new HttpsError("permission-denied", "Independent reviewer required");
    if (data.clinicalApproved === true) throw new HttpsError("failed-precondition", "Already approved");
    tx.update(ref, {
      sourceVerified: true, provenanceReviewerId: uid,
      sourceVerifiedAt: FieldValue.serverTimestamp(),
      approvalStatus: "pendingClinicalReview"
    });
  });
  await db().collection("auditEvents").add({
    actorId: uid, action: "evidence.source.verify",
    payload: {evidenceId}, createdAt: FieldValue.serverTimestamp()
  });
  return {evidenceId, status: "pendingClinicalReview"};
});

/** Clinical review is separate from authorship and source verification. */
export const approveClinicalEvidence = onCall(async request => {
  const uid = await requireIdentity(request.auth, ["clinician"]);
  const evidenceId = toText(request.data?.evidenceId, 128);
  if (!/^[A-Za-z0-9_-]+$/.test(evidenceId)) {
    throw new HttpsError("invalid-argument", "Invalid evidence ID");
  }
  const ref = db().collection("reviewedEvidence").doc(evidenceId);
  await db().runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    const data = snapshot.data();
    if (!data) throw new HttpsError("not-found", "Reference not found");
    if (data.sourceVerified !== true) {
      throw new HttpsError("failed-precondition", "Independent source review required");
    }
    if (data.addedBy === uid || data.provenanceReviewerId === uid) {
      throw new HttpsError("permission-denied", "Independent clinical reviewer required");
    }
    tx.update(ref, {clinicalApproved: true, clinicalReviewerId: uid,
      approvalStatus: "approved", clinicalReviewedAt: FieldValue.serverTimestamp()});
  });
  await db().collection("auditEvents").add({actorId: uid,
    action: "evidence.clinical.approve", payload: {evidenceId},
    createdAt: FieldValue.serverTimestamp()});
  return {evidenceId, status:"approved"};
});

/** Emergency evidence withdrawal, preventing reuse by the copilot. */
export const revokeClinicalEvidence = onCall(async request => {
  const uid = await requireIdentity(request.auth, ["platformAdmin"]);
  const evidenceId = toText(request.data?.evidenceId, 128);
  const reason = toText(request.data?.reason, 400);
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(evidenceId) || !reason) {
    throw new HttpsError("invalid-argument", "Evidence ID and withdrawal reason required");
  }
  const ref = db().collection("reviewedEvidence").doc(evidenceId);
  await db().runTransaction(async tx => {
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) throw new HttpsError("not-found", "Reference not found");
    tx.update(ref, {
      clinicalApproved: false, sourceVerified: false,
      approvalStatus: "withdrawn", withdrawalReason: reason,
      withdrawnBy: uid, withdrawnAt: FieldValue.serverTimestamp()
    });
  });
  await db().collection("auditEvents").add({
    actorId: uid, action: "evidence.withdraw", payload: {evidenceId, reason},
    createdAt: FieldValue.serverTimestamp()
  });
  return {evidenceId, status: "withdrawn"};
});

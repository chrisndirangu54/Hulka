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

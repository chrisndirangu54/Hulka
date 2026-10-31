import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const db = () => getFirestore();
const sources = new Set(["WHO","Kenya MoH","CDC","Red Cross","Authorized clinical laboratory","Verified hospital"]);
const allowedConditions = ["infectious-disease","foodborne-illness","vector-borne-disease","respiratory-illness","other"];
async function admin(uid?:string) {
 if(!uid) throw new HttpsError("unauthenticated","Sign in required");
 const u=(await db().collection("users").doc(uid).get()).data();
 if(!u || u.verified!==true || u.role!=="platformAdmin")
   throw new HttpsError("permission-denied","Verified Hulka administrator required");
 return uid;
}
function string(v:unknown,max:number):string {
 if(typeof v!=="string" || v.trim().length===0 || v.length>max)
   throw new HttpsError("invalid-argument","Invalid field");
 return v.trim();
}
/** Human-curated public health bulletin; no arbitrary website scraping or public auto-approval. */
export const registerPublicHealthBulletin = onCall(async request=>{
 const uid=await admin(request.auth?.uid);
 const d=request.data??{};
 const source=string(d.source,80);
 const condition=string(d.condition,80);
 const county=string(d.county,120);
 const bulletinUrl=string(d.bulletinUrl,500);
 const publishedDate=string(d.publishedDate,20);
 const summary=string(d.summary,1200);
 if(!sources.has(source) || !allowedConditions.includes(condition))
   throw new HttpsError("invalid-argument","Unrecognized source or condition");
 try {const u=new URL(bulletinUrl);if(u.protocol!=="https:" || u.username || u.password)
   throw new Error();}catch{throw new HttpsError("invalid-argument","HTTPS source URL required");}
 if(!/^\d{4}-\d{2}-\d{2}$/.test(publishedDate))
   throw new HttpsError("invalid-argument","ISO date required");
 const ref=await db().collection("hulkaPublicHealthBulletins").add({
   source,condition,county,bulletinUrl,publishedDate,summary,
   submittedBy:uid,status:"pendingPublicHealthReview",
   approvedForPublication:false,createdAt:FieldValue.serverTimestamp()
 });
 await db().collection("auditEvents").add({
   actorId:uid,action:"publicHealth.bulletin.submit",
   payload:{bulletinId:ref.id},createdAt:FieldValue.serverTimestamp()
 });
 return {bulletinId:ref.id,status:"pendingPublicHealthReview"};
});
/** Read only independent, explicitly approved bulletins; no connection to Regen Insight. */
export const listApprovedPublicHealthBulletins = onCall(async request=>{
 if(!request.auth?.uid)throw new HttpsError("unauthenticated","Sign in required");
 const snap=await db().collection("hulkaPublicHealthBulletins")
   .where("approvedForPublication","==",true).limit(30).get();
 return {bulletins:snap.docs.map(d=>({id:d.id,...d.data()})),dataSource:"Hulka independently approved sources"};
});

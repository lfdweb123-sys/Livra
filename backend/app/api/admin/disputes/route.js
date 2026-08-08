import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';

export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);
  const snap = await db.collection('disputes').orderBy('createdAt', 'desc').limit(50).get();

  // BUG CORRIGE: la page admin des litiges n'affichait jamais aucune
  // information sur la personne signalée (ni sur qui a signalé) — juste
  // des uid bruts illisibles. On enrichit chaque litige avec le profil
  // complet des deux parties pour permettre une vraie identification.
  const items = await Promise.all(
    snap.docs.map(async (d) => {
      const dispute = d.data();
      const [raisedBySnap, againstSnap] = await Promise.all([
        db.collection('users').doc(dispute.raisedBy).get(),
        db.collection('users').doc(dispute.against).get(),
      ]);
      return {
        id: d.id,
        ...dispute,
        raisedByProfile: raisedBySnap.exists
          ? { name: raisedBySnap.data().name, phone: raisedBySnap.data().phone, email: raisedBySnap.data().email, role: raisedBySnap.data().role }
          : null,
        againstProfile: againstSnap.exists
          ? { name: againstSnap.data().name, phone: againstSnap.data().phone, email: againstSnap.data().email, role: againstSnap.data().role }
          : null,
      };
    })
  );

  return Response.json({ items });
}

// PATCH { id, status, resolution }
export async function PATCH(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);
  const { id, status, resolution } = await req.json();
  await db.collection('disputes').doc(id).update({
    status,
    resolution: resolution || null,
    resolvedAt: FieldValue.serverTimestamp(),
  });
  return Response.json({ ok: true });
}

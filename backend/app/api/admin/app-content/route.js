import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';

export async function PATCH(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);

  const body = await req.json();
  const update = { updatedAt: FieldValue.serverTimestamp() };
  ['bannersEnabled', 'banners', 'onboardingEnabled', 'onboardingSlides', 'supportEmail', 'supportPhone', 'supportWhatsapp'].forEach((k) => {
    if (body[k] !== undefined) update[k] = body[k];
  });

  await db.collection('app_content').doc('config').set(update, { merge: true });
  return Response.json({ ok: true });
}

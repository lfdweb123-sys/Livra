import { db, FieldValue } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';

// POST { campaignId, type: 'impression' | 'click' }
// Appelé côté client à l'affichage réel (pas à la génération de la liste)
// et au tap sur un produit sponsorisé.
export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { campaignId, type } = await req.json();
  if (!campaignId || !['impression', 'click'].includes(type)) return jsonError('invalid_params', 400);

  const field = type === 'impression' ? 'impressions' : 'clicks';
  await db.collection('ad_campaigns').doc(campaignId).update({ [field]: FieldValue.increment(1) }).catch(() => {});
  return Response.json({ ok: true });
}

import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';
import { toGeoPoint } from '../../../lib/geo';

// POST — un client candidate comme vendeur (statut pending, activé par l'admin)
export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const body = await req.json();
  const existing = await db.collection('vendors').where('ownerId', '==', auth.uid).limit(1).get();
  if (!existing.empty) return jsonError('already_applied', 400);

  const ref = await db.collection('vendors').add({
    ownerId: auth.uid,
    businessName: body.businessName,
    category: body.category,
    status: 'pending',
    commission: 15,
    position: toGeoPoint(body.lat, body.lng),
    address: body.address || '',
    coverImageUrl: body.coverImageUrl || null,
    logoUrl: body.logoUrl || null,
    documents: body.documents || {},
    rating: 0,
    ratingCount: 0,
    isOpen: false,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return Response.json({ id: ref.id, status: 'pending' });
}

// GET — liste publique des vendeurs actifs (browse client), ou tous pour admin
export async function GET(req) {
  const { searchParams } = new URL(req.url);
  const status = searchParams.get('status') || 'active';
  const category = searchParams.get('category');
  const limit = Math.min(parseInt(searchParams.get('limit') || '20', 10), 50);

  let query = db.collection('vendors').where('status', '==', status);
  if (category) query = query.where('category', '==', category);
  query = query.orderBy('createdAt', 'desc').limit(limit);
  const snap = await query.get();
  return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
}

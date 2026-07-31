import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';

export async function GET(req, { params }) {
  const snap = await db.collection(`vendors/${params.id}/products`).where('isAvailable', '==', true).get();
  return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
}

export async function POST(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  const vendorSnap = await db.collection('vendors').doc(params.id).get();
  if (!vendorSnap.exists || vendorSnap.data().ownerId !== auth.uid) return jsonError('forbidden', 403);

  const body = await req.json();
  const ref = await db.collection(`vendors/${params.id}/products`).add({
    name: body.name,
    description: body.description || '',
    price: body.price,
    imageUrl: body.imageUrl || null,
    category: body.category || '',
    isAvailable: true,
    stock: body.stock ?? null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return Response.json({ id: ref.id });
}

import { db, FieldValue } from '../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../lib/auth';

export async function GET(req, { params }) {
  const snap = await db.collection(`vendors/${params.id}/products`).where('isAvailable', '==', true).get();
  return Response.json({ items: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
}

const MAX_PRODUCTS_PER_VENDOR = 50;

export async function POST(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  const vendorSnap = await db.collection('vendors').doc(params.id).get();
  if (!vendorSnap.exists || vendorSnap.data().ownerId !== auth.uid) return jsonError('forbidden', 403);

  const countSnap = await db.collection(`vendors/${params.id}/products`).count().get();
  if (countSnap.data().count >= MAX_PRODUCTS_PER_VENDOR) {
    return jsonError(`max_products_reached:${MAX_PRODUCTS_PER_VENDOR}`, 400);
  }

  const body = await req.json();
  const ref = await db.collection(`vendors/${params.id}/products`).add({
    // vendorId dupliqué ici (en plus du chemin de la sous-collection) car les
    // requêtes de découverte (collectionGroup) ont besoin de le lire sans
    // avoir à reconstituer le vendeur à partir du chemin Firestore.
    vendorId: params.id,
    name: body.name,
    description: body.description || '',
    price: body.price,
    imageUrl: body.imageUrl || null,
    category: body.category || '',
    isAvailable: true,
    pinned: false,
    stock: body.stock ?? null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return Response.json({ id: ref.id });
}

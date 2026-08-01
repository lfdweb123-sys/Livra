import { db, FieldValue } from '../../../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../../../lib/auth';

async function assertOwner(vendorId, uid) {
  const vendorSnap = await db.collection('vendors').doc(vendorId).get();
  return vendorSnap.exists && vendorSnap.data().ownerId === uid;
}

export async function PATCH(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (!(await assertOwner(params.id, auth.uid))) return jsonError('forbidden', 403);

  const body = await req.json();
  const update = { updatedAt: FieldValue.serverTimestamp() };
  ['name', 'description', 'price', 'imageUrl', 'category', 'isAvailable', 'stock', 'pinned'].forEach((k) => {
    if (body[k] !== undefined) update[k] = body[k];
  });
  await db.doc(`vendors/${params.id}/products/${params.productId}`).update(update);
  return Response.json({ ok: true });
}

export async function DELETE(req, { params }) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin' && !(await assertOwner(params.id, auth.uid))) return jsonError('forbidden', 403);
  await db.doc(`vendors/${params.id}/products/${params.productId}`).delete();
  return Response.json({ ok: true });
}

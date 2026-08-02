import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';
import { computeOrderBreakdown, computeDeliveryFee } from '../../../lib/pricing';
import { toGeoPoint } from '../../../lib/geo';
import { logActivity } from '../../../lib/activityLog';

// POST /api/orders — crée une commande, prix toujours recalculé serveur
export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'client') return jsonError('forbidden', 403);

  const body = await req.json();
  const { vendorId, type, items, deliveryAddress, pickupAddress } = body;

  if (type === 'nourriture' && !vendorId) return jsonError('vendorId_required', 400);
  if (type === 'colis' && !pickupAddress?.geopoint) return jsonError('pickupAddress_required', 400);
  if (!deliveryAddress?.geopoint) return jsonError('deliveryAddress_required', 400);

  let vendorCommissionPercent = 0;
  let vendorGeopoint = pickupAddress?.geopoint;
  let vendorDeliveryFee = null;

  if (type === 'nourriture') {
    const vendorSnap = await db.collection('vendors').doc(vendorId).get();
    if (!vendorSnap.exists || vendorSnap.data().status !== 'active') {
      return jsonError('vendor_unavailable', 400);
    }
    vendorCommissionPercent = vendorSnap.data().commission || 0;
    vendorGeopoint = vendorSnap.data().position.geopoint;
    vendorDeliveryFee = vendorSnap.data().deliveryFee;

    // recalcule les prix produits depuis Firestore, jamais depuis le payload client
    const productsSnap = await db.collection(`vendors/${vendorId}/products`).get();
    const catalog = {};
    productsSnap.forEach((d) => (catalog[d.id] = d.data()));
    for (const item of items) {
      const p = catalog[item.productId];
      if (!p || !p.isAvailable) return jsonError(`product_unavailable:${item.productId}`, 400);
      item.price = p.price;
      item.name = p.name;
    }
  }

  // Nourriture : le vendeur peut fixer son propre frais de livraison (voir
  // profil boutique) — sinon on retombe sur le calcul à la distance comme
  // pour un colis. Un colis, lui, reste TOUJOURS calculé à la distance.
  const deliveryFee =
    type === 'nourriture' && typeof vendorDeliveryFee === 'number' && vendorDeliveryFee >= 0
      ? vendorDeliveryFee
      : computeDeliveryFee('coursier', vendorGeopoint, deliveryAddress.geopoint);
  const priceBreakdown =
    type === 'nourriture'
      ? computeOrderBreakdown({ items, vendorCommissionPercent, deliveryFee })
      : { subtotal: 0, deliveryFee, commission: 0, total: deliveryFee };

  // matchPosition = point de collecte (vendeur pour nourriture, pickupAddress pour colis).
  // C'est ce champ que le driver_home_screen interroge en géo-requête (geoflutterfire2)
  // pour proposer les commandes à proximité, sans avoir à lire chaque doc vendor/order.
  const matchPosition = toGeoPoint(vendorGeopoint.latitude, vendorGeopoint.longitude);

  // readyForPickup = le champ que les livreurs interrogent (avec la géo-requête)
  // pour voir les commandes disponibles. Un colis est prêt immédiatement (pas
  // d'étape de préparation) ; une commande nourriture ne l'est qu'une fois le
  // vendeur passé en "picked_up" (plat prêt) — voir PATCH orders/[id].
  const readyForPickup = type === 'colis';

  const orderRef = await db.collection('orders').add({
    clientId: auth.uid,
    vendorId: vendorId || null,
    driverId: null,
    type,
    items: items || [],
    priceBreakdown,
    status: 'pending',
    readyForPickup,
    paymentMethod: body.paymentMethod || null,
    paymentStatus: 'pending',
    deliveryAddress,
    pickupAddress: pickupAddress || null,
    matchPosition,
    statusHistory: [{ status: 'pending', at: new Date().toISOString(), by: auth.uid }],
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  // Notification vendeur/livreurs déplacée volontairement APRÈS paiement
  // confirmé (voir notifyOrderPaid dans lib/matching.js, appelée depuis le
  // webhook de paiement, le paiement wallet, ou le choix "espèces") — pour
  // ne jamais faire préparer/livrer une commande jamais réellement payée.

  await logActivity('order_created', `Commande ${type} créée — ${priceBreakdown.total} XOF`, { orderId: orderRef.id, clientId: auth.uid });

  // Conversion pub : si un des produits commandés est sous campagne active,
  // ça compte comme conversion — best-effort, ne doit jamais faire échouer
  // la commande.
  if (type === 'nourriture' && items?.length) {
    try {
      const productIds = items.map((i) => i.productId);
      const adsSnap = await db
        .collection('ad_campaigns')
        .where('vendorId', '==', vendorId)
        .where('status', '==', 'active')
        .get();
      for (const doc of adsSnap.docs) {
        if (productIds.includes(doc.data().productId)) {
          await doc.ref.update({ conversions: FieldValue.increment(1) });
        }
      }
    } catch (e) {
      console.error('[AD_CONVERSION_TRACKING_ERROR]', e.message);
    }
  }

  return Response.json({ id: orderRef.id, priceBreakdown, status: 'pending' });
}

// GET /api/orders?role=client|vendor|driver&status=pending&cursor=...&limit=20
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const status = searchParams.get('status');
  const cursor = searchParams.get('cursor');
  const limit = Math.min(parseInt(searchParams.get('limit') || '20', 10), 50);

  let query = db.collection('orders');
  if (auth.role === 'client') query = query.where('clientId', '==', auth.uid);
  else if (auth.role === 'vendor') {
    const vendorSnap = await db.collection('vendors').where('ownerId', '==', auth.uid).limit(1).get();
    if (vendorSnap.empty) return Response.json({ items: [], nextCursor: null });
    query = query.where('vendorId', '==', vendorSnap.docs[0].id);
  } else if (auth.role === 'driver') {
    const driverSnap = await db.collection('drivers').where('ownerId', '==', auth.uid).limit(1).get();
    if (driverSnap.empty) return Response.json({ items: [], nextCursor: null });
    query = query.where('driverId', '==', driverSnap.docs[0].id);
  } else if (auth.role !== 'admin') {
    return jsonError('forbidden', 403);
  }

  if (status) query = query.where('status', '==', status);
  query = query.orderBy('createdAt', 'desc').limit(limit);
  if (cursor) {
    const cursorDoc = await db.collection('orders').doc(cursor).get();
    if (cursorDoc.exists) query = query.startAfter(cursorDoc);
  }

  const snap = await query.get();
  const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const nextCursor = items.length === limit ? items[items.length - 1].id : null;
  return Response.json({ items, nextCursor });
}

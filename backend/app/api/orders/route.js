import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';
import { computeOrderBreakdown, computeDeliveryFee, computeServiceFee, SERVICE_FEE_PERCENT } from '../../../lib/pricing';
import { toGeoPoint } from '../../../lib/geo';
import { logActivity } from '../../../lib/activityLog';
import { logOffPlatformDelivery } from '../../../lib/offPlatform';

// POST /api/orders — crée une commande, prix toujours recalculé serveur
export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'client') return jsonError('forbidden', 403);

  const body = await req.json();
  const { vendorId, type, items, deliveryAddress, pickupAddress, preferredDriverId, offPlatformDriverPhone } = body;

  if (type === 'nourriture' && !vendorId) return jsonError('vendorId_required', 400);
  if (type === 'colis' && !pickupAddress?.geopoint) return jsonError('pickupAddress_required', 400);
  if (!deliveryAddress?.geopoint) return jsonError('deliveryAddress_required', 400);

  let vendorCommissionPercent = 0;
  let vendorGeopoint = pickupAddress?.geopoint;
  let vendorDeliveryFee = null;
  let vendorSnap = null;

  if (type === 'nourriture') {
    vendorSnap = await db.collection('vendors').doc(vendorId).get();
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

  // Le client peut choisir un livreur actif précis pour un colis (le
  // choix pour une commande "nourriture" se fait plutôt côté vendeur, au
  // moment de marquer le plat prêt — voir PATCH orders/[id]). On vérifie
  // que le livreur existe et est bien actif+en ligne avant d'accepter le
  // choix, jamais fait confiance au client pour cet id.
  let validatedPreferredDriverId = null;
  let preferredDriverPricingConfig = null;
  if (preferredDriverId) {
    const driverSnap = await db.collection('drivers').doc(preferredDriverId).get();
    if (driverSnap.exists && driverSnap.data().status === 'active' && driverSnap.data().isOnline) {
      validatedPreferredDriverId = preferredDriverId;
      preferredDriverPricingConfig = driverSnap.data().pricingConfig || null;
    }
  }

  // Nourriture : le vendeur peut fixer son propre frais de livraison (voir
  // profil boutique) — sinon on retombe sur le calcul à la distance comme
  // pour un colis. Un colis, lui, reste TOUJOURS calculé à la distance —
  // mais avec le tarif PERSONNALISÉ du livreur choisi si le client en a
  // sélectionné un précis (voir "configurer mes tarifs" côté livreur).
  const deliveryFee =
    type === 'nourriture' && typeof vendorDeliveryFee === 'number' && vendorDeliveryFee >= 0
      ? vendorDeliveryFee
      : computeDeliveryFee('coursier', vendorGeopoint, deliveryAddress.geopoint, preferredDriverPricingConfig);
  const priceBreakdown =
    type === 'nourriture'
      ? computeOrderBreakdown({ items, vendorCommissionPercent, deliveryFee })
      : (() => {
          // Colis: pas de vendeur, mais le frais de service de 5% s'applique
          // quand même côté livreur, sur le frais de livraison.
          const serviceFee = computeServiceFee(deliveryFee);
          return { subtotal: 0, deliveryFee, commission: 0, serviceFee, serviceFeePercent: SERVICE_FEE_PERCENT, total: deliveryFee + serviceFee };
        })();

  // matchPosition = point de collecte (vendeur pour nourriture, pickupAddress pour colis).
  // C'est ce champ que le driver_home_screen interroge en géo-requête (geoflutterfire2)
  // pour proposer les commandes à proximité, sans avoir à lire chaque doc vendor/order.
  const matchPosition = toGeoPoint(vendorGeopoint.latitude, vendorGeopoint.longitude);

  // BUG CORRIGE: pour une commande nourriture, pickupAddress restait TOUJOURS
  // null (le client n'en envoie pas, seul le colis en a un) — le livreur
  // n'avait alors AUCUNE adresse de collecte ni itinéraire tracé jusqu'au
  // vendeur (driver_navigation_screen.dart s'appuie sur ce champ). On le
  // construit maintenant depuis la fiche vendeur elle-même.
  const finalPickupAddress =
    type === 'nourriture'
      ? { geopoint: vendorGeopoint, label: vendorSnap?.data()?.address || vendorSnap?.data()?.businessName || 'Adresse du vendeur' }
      : pickupAddress || null;

  // readyForPickup = le champ que les livreurs interrogent (avec la géo-requête)
  // pour voir les commandes disponibles. Un colis est prêt immédiatement (pas
  // d'étape de préparation) ; une commande nourriture ne l'est qu'une fois le
  // vendeur passé en "picked_up" (plat prêt) — voir PATCH orders/[id]. Un
  // colis confié à un livreur HORS application ne doit jamais être proposé
  // aux livreurs Livra.
  const readyForPickup = type === 'colis' && !offPlatformDriverPhone;

  const orderRef = await db.collection('orders').add({
    clientId: auth.uid,
    vendorId: vendorId || null,
    driverId: null,
    preferredDriverId: validatedPreferredDriverId,
    // Numéro d'un livreur HORS application, saisi par le client — transmis
    // à l'admin pour suivi (voir page admin dédiée). N'engage jamais la
    // responsabilité de Livra (voir CGU).
    offPlatformDriverPhone: offPlatformDriverPhone || null,
    type,
    items: items || [],
    priceBreakdown,
    status: 'pending',
    readyForPickup,
    paymentMethod: body.paymentMethod || null,
    paymentStatus: 'pending',
    deliveryAddress,
    pickupAddress: finalPickupAddress,
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
  if (offPlatformDriverPhone) {
    await logOffPlatformDelivery({ phone: offPlatformDriverPhone, declaredBy: auth.uid, role: 'client', orderId: orderRef.id });
  }

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

  // IMPORTANT: une requête Firestore combinant where(...) + orderBy() sur un
  // champ différent EXIGE un index composite. Sans lui, .get() lève une
  // exception (FAILED_PRECONDITION) — sans ce try/catch, cette route
  // plantait silencieusement côté client (l'app affichait juste "aucune
  // commande" sans aucune erreur visible). Le message d'erreur Firestore
  // contient normalement un lien direct pour créer l'index en un clic —
  // voir les logs Vercel si cette erreur apparaît.
  try {
    const snap = await query.get();
    const items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    const nextCursor = items.length === limit ? items[items.length - 1].id : null;
    return Response.json({ items, nextCursor });
  } catch (e) {
    console.error('[ORDERS_GET_QUERY_ERROR]', { role: auth.role, uid: auth.uid, status, message: e.message, code: e.code });
    return jsonError('orders_query_failed', 500);
  }
}

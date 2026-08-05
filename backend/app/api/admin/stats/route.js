import { db } from '../../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../../lib/auth';

export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);
  if (auth.role !== 'admin') return jsonError('forbidden', 403);

  const [ordersSnap, ridesSnap, vendorsPending, driversPending, disputesOpen] = await Promise.all([
    db.collection('orders').orderBy('createdAt', 'desc').limit(200).get(),
    db.collection('rides').orderBy('createdAt', 'desc').limit(200).get(),
    db.collection('vendors').where('status', '==', 'pending').get(),
    db.collection('drivers').where('status', '==', 'pending').get(),
    db.collection('disputes').where('status', '==', 'open').get(),
  ]);

  const orders = ordersSnap.docs.map((d) => d.data());
  const rides = ridesSnap.docs.map((d) => d.data());

  const revenueByDay = {};
  [...orders, ...rides].forEach((o) => {
    if (o.paymentStatus !== 'paid') return;
    const day = o.createdAt?.toDate ? o.createdAt.toDate().toISOString().slice(0, 10) : 'unknown';
    // Revenu plateforme = frais de service de 5% réellement facturé à
    // l'acheteur (voir lib/pricing.js) — pas l'ancien champ "commission"
    // qui n'a jamais été prélevé nulle part.
    const amount = o.priceBreakdown ? o.priceBreakdown.serviceFee || 0 : o.serviceFee || 0;
    revenueByDay[day] = (revenueByDay[day] || 0) + amount;
  });

  return Response.json({
    ordersCount: orders.length,
    ridesCount: rides.length,
    vendorsPendingCount: vendorsPending.size,
    driversPendingCount: driversPending.size,
    disputesOpenCount: disputesOpen.size,
    revenueByDay: Object.entries(revenueByDay)
      .map(([date, revenue]) => ({ date, revenue }))
      .sort((a, b) => (a.date > b.date ? 1 : -1)),
  });
}

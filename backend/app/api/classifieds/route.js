import { db, FieldValue } from '../../../lib/firebaseAdmin';
import { requireAuth, jsonError } from '../../../lib/auth';
import { logActivity } from '../../../lib/activityLog';
import { notifyAdminByEmail } from '../../../lib/adminNotify';

// Modération stricte, sans exception : aucun contenu à caractère sexuel,
// même partiellement déguisé/reformulé — la revue humaine par l'admin
// (statut "pending" systématique) reste le vrai rempart, cette liste n'est
// qu'un premier filtre automatique qui bloque la soumission d'entrée.
const BLOCKED_KEYWORDS = [
  'sexe', 'sexuel', 'sexuelle', 'porno', 'pornographie', 'escort', 'call girl',
  'massage érotique', 'erotique', 'nude', 'nue', 'nu ', 'charme discret',
  'rencontre coquine', 'plaisir intime', 'compagnie masculine', 'compagnie féminine',
];

function containsBlockedContent(text) {
  const normalized = (text || '').toLowerCase();
  return BLOCKED_KEYWORDS.some((kw) => normalized.includes(kw));
}

// POST — créer une annonce (petite annonce personnelle, distincte du
// catalogue vendeur). Première annonce : exige un document d'identité et
// un contact, vérifiés par l'admin avant publication (voir statut
// "pending"). Les annonces suivantes du même utilisateur n'exigent plus
// de redéposer le document une fois déjà vérifié.
export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const body = await req.json();
  const { title, description, price, category, imageUrl, contactPhone, identityDocUrl } = body;

  if (!title || !description || !price || !contactPhone) return jsonError('missing_fields', 400);
  if (containsBlockedContent(title) || containsBlockedContent(description)) {
    return jsonError('content_not_allowed', 400);
  }

  const userSnap = await db.collection('users').doc(auth.uid).get();
  const userData = userSnap.exists ? userSnap.data() : {};
  const alreadyVerified = userData.classifiedsIdentityStatus === 'verified';

  if (!alreadyVerified && !identityDocUrl) {
    return jsonError('identity_document_required', 400);
  }

  // Premier dépôt de document : enregistre le statut de vérification sur
  // le profil (une seule fois suffit, pas à chaque annonce).
  if (!alreadyVerified && identityDocUrl) {
    await db.collection('users').doc(auth.uid).update({
      classifiedsIdentityDocUrl: identityDocUrl,
      classifiedsIdentityStatus: 'pending',
    });
  }

  const ref = await db.collection('classified_listings').add({
    ownerId: auth.uid,
    title,
    description,
    price: Number(price),
    category: category || 'Autre',
    imageUrl: imageUrl || null,
    contactPhone,
    contactName: userData.name || null,
    country: userData.country || null,
    // Toujours en attente de revue admin — jamais publié automatiquement,
    // que l'identité soit déjà vérifiée ou non pour ce compte.
    status: 'pending',
    boostTier: null,
    boostedUntil: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await logActivity('classified_submitted', `Nouvelle annonce en attente de vérification : ${title}`, {
    listingId: ref.id,
    ownerId: auth.uid,
  });
  await notifyAdminByEmail({
    subject: 'Nouvelle annonce à vérifier',
    htmlContent: `<p>Nouvelle annonce : <strong>${title}</strong> — ${price} XOF.</p><p>Ouvrez le tableau de bord admin, section Annonces, pour vérifier l'identité du vendeur et le contenu avant publication.</p>`,
  });

  return Response.json({ id: ref.id, status: 'pending' });
}

// GET — liste publique des annonces actives (filtrage par pays du
// demandeur, sauf admin — même principe que vendors/drivers).
export async function GET(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const { searchParams } = new URL(req.url);
  const status = searchParams.get('status') || 'active';
  const category = searchParams.get('category');
  const mine = searchParams.get('mine');
  const limit = Math.min(parseInt(searchParams.get('limit') || '30', 10), 200);

  let query = db.collection('classified_listings');
  if (mine === '1') {
    query = query.where('ownerId', '==', auth.uid);
  } else {
    query = query.where('status', '==', status);
    if (category) query = query.where('category', '==', category);
  }
  query = query.orderBy('createdAt', 'desc').limit(limit);

  try {
    const snap = await query.get();
    let items = snap.docs.map((d) => ({ id: d.id, ...d.data() }));

    if (mine !== '1' && auth.role !== 'admin') {
      items = items.filter((l) => !l.country || l.country === auth.user.country);
    }

    // Boostées en premier, selon le palier de budget dépensé — même
    // principe que pour les boosts de profil vendeur/livreur.
    const now = new Date();
    items.sort((a, b) => {
      const aBoosted = a.boostTier && a.boostedUntil && a.boostedUntil.toDate?.() > now;
      const bBoosted = b.boostTier && b.boostedUntil && b.boostedUntil.toDate?.() > now;
      const tierWeight = { gold: 3, silver: 2, bronze: 1 };
      const aWeight = aBoosted ? tierWeight[a.boostTier] || 0 : 0;
      const bWeight = bBoosted ? tierWeight[b.boostTier] || 0 : 0;
      return bWeight - aWeight;
    });

    return Response.json({ items });
  } catch (e) {
    console.error('[CLASSIFIEDS_GET_QUERY_ERROR]', { message: e.message, code: e.code });
    return jsonError('classifieds_query_failed', 500);
  }
}

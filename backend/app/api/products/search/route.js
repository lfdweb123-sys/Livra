import { db } from '../../../../lib/firebaseAdmin';

// Recherche produits (nourriture/articles) tous vendeurs confondus.
// Sans texte de recherche, renvoie un échantillon de produits disponibles
// (pour que la barre de recherche affiche déjà du contenu avant même que
// l'utilisateur ne tape). Filtrage en mémoire (pas de moteur full-text
// dédié) — suffisant à l'échelle actuelle.
export const dynamic = 'force-dynamic';

export async function GET(req) {
  const { searchParams } = new URL(req.url);
  const q = (searchParams.get('q') || '').trim().toLowerCase();

  const pool = await db.collectionGroup('products').where('isAvailable', '==', true).limit(300).get();
  let items = pool.docs.map((d) => ({ id: d.id, ...d.data() }));

  if (q) {
    items = items.filter((p) => (p.name || '').toLowerCase().includes(q) || (p.description || '').toLowerCase().includes(q));
  } else {
    // pas de recherche : mélange aléatoire pour varier ce qui est montré
    for (let i = items.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [items[i], items[j]] = [items[j], items[i]];
    }
  }

  return Response.json({ items: items.slice(0, 30) });
}

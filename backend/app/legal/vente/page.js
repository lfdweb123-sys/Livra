export const metadata = { title: 'Conditions de vente — Livra' };

export default function SalesPage() {
  return (
    <>
      <h1>Conditions générales de vente</h1>
      <p><em>Dernière mise à jour : {new Date().toLocaleDateString('fr-FR')}</em></p>

      <h2>1. Champ d'application</h2>
      <p>
        Les présentes conditions régissent la vente de produits et repas par les vendeurs, restaurants
        et boutiques référencés sur Livra, ainsi que la prestation de services de livraison et de
        transport (course) par les livreurs, coursiers, chauffeurs et taxi-motos référencés sur Livra.
      </p>

      <h2>2. Prix et frais</h2>
      <p>
        Le prix affiché pour chaque produit ou service est fixé librement par le vendeur ou le
        livreur/chauffeur. Un frais de service de 5% est ajouté au montant payé par l'acheteur sur
        chaque commande (vendeur/restaurant/boutique) et chaque course (livreur/chauffeur/taxi-moto),
        clairement indiqué avant validation du paiement. Les retraits de fonds vers un compte
        Mobile Money sont gratuits.
      </p>

      <h2>3. Commande et paiement</h2>
      <p>
        La commande est confirmée après validation du paiement (Mobile Money, carte bancaire,
        portefeuille Livra) ou choix du paiement en espèces à la livraison. Le client peut choisir un
        livreur actif proposé par l'application, ou ne pas en choisir et faire appel à son propre
        livreur en dehors de la Plateforme.
      </p>

      <h2>4. Annulation</h2>
      <p>
        Une commande ou course peut être annulée par le client tant qu'elle est au statut « en
        attente », avant acceptation par le vendeur ou le livreur. Passé ce stade, l'annulation est
        soumise à l'accord du vendeur/livreur concerné.
      </p>

      <h2>5. Livraison hors Plateforme</h2>
      <p>
        Lorsqu'un client ou un vendeur fait appel à un livreur en dehors de la Plateforme, la
        transaction et la livraison ne sont pas couvertes par les présentes conditions de vente ni
        par la garantie ou le support de Livra.
      </p>

      <h2>6. Réclamations</h2>
      <p>
        En cas de non-réception d'une commande, de produit non conforme ou de tout autre litige avec
        un vendeur, un restaurant, une boutique ou un livreur, le client est invité à signaler
        l'incident directement depuis sa page de profil dans l'application, puis, en l'absence de
        solution satisfaisante, à contacter le support client via les coordonnées indiquées sur cette
        même page.
      </p>

      <h2>7. Responsabilité</h2>
      <p>
        Livra agit en tant qu'intermédiaire technique. La responsabilité de la conformité, de la
        qualité et de la livraison effective d'un produit ou service incombe au vendeur ou au
        livreur/chauffeur ayant accepté la commande ou la course.
      </p>
    </>
  );
}

export const metadata = { title: 'Politique de confidentialité — Livra' };

export default function PrivacyPage() {
  return (
    <>
      <h1>Politique de confidentialité</h1>
      <p><em>Dernière mise à jour : {new Date().toLocaleDateString('fr-FR')}</em></p>

      <h2>1. Données collectées</h2>
      <p>Selon votre profil (client, vendeur, restaurant, boutique, livreur, coursier, chauffeur, taxi-moto), Livra collecte :</p>
      <ul>
        <li>Identité : nom, numéro de téléphone, email, photo de profil ;</li>
        <li>Documents de vérification : pièce d'identité, permis de conduire, assurance, photo du véhicule
          (selon le type de véhicule) — pour les vendeurs et livreurs uniquement ;</li>
        <li>Localisation : position GPS, nécessaire à la mise en relation et au suivi des livraisons/courses ;</li>
        <li>Transactions : historique de commandes, courses, paiements et retraits ;</li>
        <li>Contenu généré : avis, notes, photos de produits, messages liés à une commande.</li>
      </ul>

      <h2>2. Finalités du traitement</h2>
      <ul>
        <li>Mise en relation entre clients, vendeurs et livreurs ;</li>
        <li>Traitement des paiements et versements ;</li>
        <li>Vérification d'identité des vendeurs et livreurs avant activation de leur compte ;</li>
        <li>Sécurité, prévention de la fraude et traitement des signalements ;</li>
        <li>Amélioration du service et support client.</li>
      </ul>

      <h2>3. Partage des données</h2>
      <p>
        Les données strictement nécessaires (nom, position, statut de la commande) sont partagées entre
        les parties concernées par une même commande ou course (client, vendeur, livreur) pour permettre
        son exécution. Les données de paiement sont transmises à nos prestataires de paiement
        (Feexpay, Verzapay) uniquement pour le traitement des transactions. Livra ne vend aucune donnée
        personnelle à des tiers.
      </p>

      <h2>4. Conservation</h2>
      <p>
        Les données sont conservées pendant la durée nécessaire aux finalités décrites ci-dessus, et
        au minimum pendant la durée légale de conservation des documents commerciaux et comptables
        applicable au Bénin.
      </p>

      <h2>5. Vos droits</h2>
      <p>
        Conformément à la réglementation applicable, vous disposez d'un droit d'accès, de rectification
        et de suppression de vos données personnelles. Vous pouvez exercer ces droits en contactant le
        support depuis votre page de profil dans l'application.
      </p>

      <h2>6. Sécurité</h2>
      <p>
        Livra met en œuvre des mesures techniques et organisationnelles raisonnables pour protéger vos
        données contre l'accès non autorisé, la perte ou l'altération.
      </p>
    </>
  );
}

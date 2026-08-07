export const metadata = { title: 'Mentions légales — Livra' };

export default function LegalNoticePage() {
  return (
    <>
      <h1>Mentions légales</h1>
      <p><em>Dernière mise à jour : {new Date().toLocaleDateString('fr-FR')}</em></p>

      <h2>Éditeur</h2>
      <p>
        L'application et le site Livra sont édités par <strong>La Faveur Infinie de Dieu</strong>,
        représentée par son dirigeant, Sononkpon Gérard.
      </p>
      <ul>
        <li>Forme juridique : [À COMPLÉTER]</li>
        <li>Numéro RCCM : [À COMPLÉTER]</li>
        <li>Numéro IFU : [À COMPLÉTER]</li>
        <li>Siège social : [À COMPLÉTER — adresse complète, Bénin]</li>
        <li>Email de contact : [À COMPLÉTER]</li>
        <li>Téléphone : [À COMPLÉTER]</li>
      </ul>

      <h2>Hébergement</h2>
      <p>
        L'application et le site sont hébergés par Vercel Inc. (backend et pages web) et Google
        Firebase (données et fichiers).
      </p>

      <h2>Propriété intellectuelle</h2>
      <p>
        L'ensemble des éléments composant l'application et le site Livra (textes, logos, interface,
        code) est protégé par le droit de la propriété intellectuelle et demeure la propriété
        exclusive de La Faveur Infinie de Dieu, sauf mention contraire.
      </p>

      <h2>Signalement et poursuites</h2>
      <p>
        Tout Utilisateur — client, vendeur, restaurant, boutique, livreur, coursier, chauffeur ou
        taxi-moto — qui enfreint les règles de la Plateforme (voir les Conditions générales
        d'utilisation) s'expose aux mêmes sanctions, sans exception de profil : avertissement,
        suspension, bannissement définitif du compte, et le cas échéant signalement aux autorités
        compétentes ainsi que des poursuites judiciaires conformément aux lois de la République du
        Bénin.
      </p>

      <h2>Contact</h2>
      <p>
        Pour toute question, réclamation, signalement ou demande relative à vos données personnelles,
        contactez le support directement depuis votre page de profil dans l'application Livra.
      </p>
    </>
  );
}

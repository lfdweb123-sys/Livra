import Image from 'next/image';
import Link from 'next/link';

export default function SiteFooter() {
  return (
    <footer className="border-t border-livra-divider/60 bg-livra-surface">
      <div className="max-w-6xl mx-auto px-6 py-14 grid gap-10 md:grid-cols-4">
        <div>
          <div className="flex items-center gap-2 mb-3">
            <Image src="/livra_logo_full.png" alt="Livra" width={32} height={33} />
            <span className="text-lg font-semibold">Livra</span>
          </div>
          <p className="text-sm text-livra-textSecondary leading-relaxed">
            Livraison, courses et boutiques en ligne, partout en Afrique de l'Ouest.
          </p>
        </div>

        <div>
          <div className="text-sm font-semibold text-livra-textPrimary mb-3">Application</div>
          <ul className="space-y-2 text-sm text-livra-textSecondary">
            <li><a href="/#services" className="hover:text-livra-gold transition-colors">Services</a></li>
            <li><a href="/#telecharger" className="hover:text-livra-gold transition-colors">Télécharger</a></li>
            <li><a href="/#partenaires" className="hover:text-livra-gold transition-colors">Devenir partenaire</a></li>
          </ul>
        </div>

        <div>
          <div className="text-sm font-semibold text-livra-textPrimary mb-3">Informations légales</div>
          <ul className="space-y-2 text-sm text-livra-textSecondary">
            <li><Link href="/legal/cgu" className="hover:text-livra-gold transition-colors">Conditions d'utilisation</Link></li>
            <li><Link href="/legal/confidentialite" className="hover:text-livra-gold transition-colors">Confidentialité</Link></li>
            <li><Link href="/legal/vente" className="hover:text-livra-gold transition-colors">Conditions de vente</Link></li>
            <li><Link href="/legal/mentions" className="hover:text-livra-gold transition-colors">Mentions légales</Link></li>
          </ul>
        </div>

        <div>
          <div className="text-sm font-semibold text-livra-textPrimary mb-3">Contact</div>
          <p className="text-sm text-livra-textSecondary leading-relaxed">
            Le support est accessible directement depuis votre page de profil dans l'application.
          </p>
        </div>
      </div>

      <div className="border-t border-livra-divider/60">
        <div className="max-w-6xl mx-auto px-6 py-5 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-livra-textSecondary">
          <span>© {new Date().getFullYear()} La Faveur Infinie de Dieu — Livra. Tous droits réservés.</span>
          <span>Fait avec soin en Afrique de l'Ouest.</span>
        </div>
      </div>
    </footer>
  );
}

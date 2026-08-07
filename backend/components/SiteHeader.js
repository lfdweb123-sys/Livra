import Image from 'next/image';
import Link from 'next/link';

export default function SiteHeader() {
  return (
    <header className="sticky top-0 z-50 border-b border-livra-divider/60 bg-livra-bg/80 backdrop-blur-md">
      <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        <Link href="/" className="flex items-center gap-2 shrink-0">
          <Image src="/livra_logo_full.png" alt="Livra" width={36} height={37} priority />
          <span className="text-lg font-semibold tracking-tight">Livra</span>
        </Link>

        <nav className="hidden md:flex items-center gap-8 text-sm text-livra-textSecondary">
          <a href="/#comment-ca-marche" className="hover:text-livra-textPrimary transition-colors">
            Comment ça marche
          </a>
          <a href="/#services" className="hover:text-livra-textPrimary transition-colors">
            Services
          </a>
          <a href="/#telecharger" className="hover:text-livra-textPrimary transition-colors">
            Télécharger
          </a>
          <Link href="/legal/cgu" className="hover:text-livra-textPrimary transition-colors">
            À propos
          </Link>
        </nav>

        <a
          href="/#telecharger"
          className="inline-flex items-center rounded-full bg-livra-gold px-5 py-2 text-sm font-semibold text-livra-bg hover:bg-livra-goldSoft transition-colors"
        >
          Télécharger l'app
        </a>
      </div>
    </header>
  );
}

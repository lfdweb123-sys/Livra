'use client';
import { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import Image from 'next/image';
import { auth, db } from '../../lib/firebaseClient';

const NAV_SECTIONS = [
  {
    label: 'Vue d\'ensemble',
    items: [
      { href: '/dashboard', label: 'Dashboard' },
      { href: '/activity', label: "Journal d'activité" },
    ],
  },
  {
    label: 'Marketplace',
    items: [
      { href: '/vendors', label: 'Vendeurs' },
      { href: '/products', label: 'Produits' },
      { href: '/orders', label: 'Commandes' },
    ],
  },
  {
    label: 'Mobilité',
    items: [
      { href: '/drivers', label: 'Chauffeurs' },
      { href: '/rides', label: 'Courses' },
    ],
  },
  {
    label: 'Confiance & sécurité',
    items: [
      { href: '/users', label: 'Utilisateurs' },
      { href: '/disputes', label: 'Litiges' },
      { href: '/off-platform', label: 'Livraisons hors app.' },
    ],
  },
  {
    label: 'Configuration',
    items: [
      { href: '/content', label: 'Visuels' },
      { href: '/commission', label: 'Commission' },
    ],
  },
];

function SidebarContent({ pathname, onNavigate }) {
  return (
    <>
      <div className="flex items-center gap-2 px-5 h-16 border-b border-livra-divider shrink-0">
        <Image src="/livra_icon_full.png" alt="Livra" width={36} height={36} />
        <span className="font-semibold text-livra-textPrimary">Admin</span>
      </div>

      <nav className="flex-1 overflow-y-auto px-3 py-5 space-y-6">
        {NAV_SECTIONS.map((section) => (
          <div key={section.label}>
            <div className="px-3 mb-1.5 text-[11px] font-semibold uppercase tracking-wide text-livra-textSecondary/70">
              {section.label}
            </div>
            <div className="flex flex-col gap-0.5">
              {section.items.map((n) => {
                const active = pathname === n.href;
                return (
                  <a
                    key={n.href}
                    href={n.href}
                    onClick={onNavigate}
                    className={
                      'px-3 py-2 rounded-lg text-sm transition-colors border-l-2 ' +
                      (active
                        ? 'bg-livra-gold/10 text-livra-textPrimary border-livra-gold font-medium'
                        : 'text-livra-textSecondary border-transparent hover:bg-livra-surfaceElevated hover:text-livra-textPrimary')
                    }
                  >
                    {n.label}
                  </a>
                );
              })}
            </div>
          </div>
        ))}
      </nav>

      <div className="p-3 border-t border-livra-divider shrink-0">
        <button
          onClick={() => signOut(auth)}
          className="w-full px-3 py-2 rounded-lg text-sm text-livra-textSecondary hover:bg-livra-surfaceElevated hover:text-livra-danger transition-colors text-left"
        >
          Déconnexion
        </button>
      </div>
    </>
  );
}

export default function AdminLayout({ children }) {
  const [status, setStatus] = useState('loading'); // loading | ok | denied
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const pathname = usePathname();
  const router = useRouter();

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (pathname === '/login') { setStatus('ok'); return; }
      if (!user) { router.replace('/login'); return; }
      const snap = await getDoc(doc(db, 'users', user.uid));
      if (snap.exists() && snap.data().role === 'admin') setStatus('ok');
      else { setStatus('denied'); router.replace('/login'); }
    });
    return () => unsub();
  }, [pathname, router]);

  // Ferme le menu mobile à chaque changement de page.
  useEffect(() => { setMobileNavOpen(false); }, [pathname]);

  if (pathname === '/login') return children;
  if (status !== 'ok') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-livra-bg text-livra-textSecondary text-sm">
        Chargement…
      </div>
    );
  }

  return (
    <div className="min-h-screen flex bg-livra-bg">
      {/* Sidebar desktop — masquée sur mobile, largeur fixe à partir de md */}
      <aside className="hidden md:flex w-64 shrink-0 border-r border-livra-divider flex-col bg-livra-surface">
        <SidebarContent pathname={pathname} onNavigate={() => {}} />
      </aside>

      {/* Sidebar mobile — panneau coulissant plein écran depuis la DROITE,
          ouvert via le hamburger (lui-même placé à droite de la barre) */}
      {mobileNavOpen && (
        <div className="md:hidden fixed inset-0 z-50 flex">
          <button
            aria-label="Fermer le menu"
            className="flex-1 bg-black/40"
            onClick={() => setMobileNavOpen(false)}
          />
          <div className="w-72 max-w-[80vw] bg-livra-surface flex flex-col border-l border-livra-divider">
            <SidebarContent pathname={pathname} onNavigate={() => setMobileNavOpen(false)} />
          </div>
        </div>
      )}

      <div className="flex-1 min-w-0 flex flex-col">
        {/* Barre supérieure mobile uniquement — bouton hamburger à DROITE */}
        <div className="md:hidden flex items-center gap-3 h-14 px-4 border-b border-livra-divider bg-livra-surface shrink-0">
          <Image src="/livra_icon_full.png" alt="Livra" width={30} height={30} />
          <span className="font-semibold text-livra-textPrimary text-sm flex-1">Admin</span>
          <button
            aria-label="Ouvrir le menu"
            onClick={() => setMobileNavOpen(true)}
            className="p-2 -mr-2 rounded-lg hover:bg-livra-surfaceElevated"
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
              <line x1="3" y1="6" x2="21" y2="6" /><line x1="3" y1="12" x2="21" y2="12" /><line x1="3" y1="18" x2="21" y2="18" />
            </svg>
          </button>
        </div>

        <main className="flex-1 min-w-0 p-4 sm:p-6 md:p-8 max-w-[1400px] overflow-x-hidden">{children}</main>
      </div>
    </div>
  );
}

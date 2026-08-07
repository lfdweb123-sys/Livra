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

export default function AdminLayout({ children }) {
  const [status, setStatus] = useState('loading'); // loading | ok | denied
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

  if (pathname === '/login') return children;
  if (status !== 'ok') {
    return (
      <div className="min-h-screen flex items-center justify-center text-livra-textSecondary text-sm">
        Chargement…
      </div>
    );
  }

  return (
    <div className="min-h-screen flex bg-livra-bg">
      <aside className="w-64 shrink-0 border-r border-livra-divider flex flex-col">
        <div className="flex items-center gap-2 px-5 h-16 border-b border-livra-divider">
          <Image src="/livra_logo_full.png" alt="Livra" width={28} height={29} />
          <span className="font-semibold text-livra-textPrimary">Livra Admin</span>
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
                      className={
                        'px-3 py-2 rounded-lg text-sm transition-colors border-l-2 ' +
                        (active
                          ? 'bg-livra-gold/10 text-livra-textPrimary border-livra-gold font-medium'
                          : 'text-livra-textSecondary border-transparent hover:bg-livra-surface hover:text-livra-textPrimary')
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

        <div className="p-3 border-t border-livra-divider">
          <button
            onClick={() => signOut(auth)}
            className="w-full px-3 py-2 rounded-lg text-sm text-livra-textSecondary hover:bg-livra-surface hover:text-livra-danger transition-colors text-left"
          >
            Déconnexion
          </button>
        </div>
      </aside>
      <main className="flex-1 p-8 max-w-[1400px]">{children}</main>
    </div>
  );
}

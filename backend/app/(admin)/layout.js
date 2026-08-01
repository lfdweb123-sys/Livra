'use client';
import { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../../lib/firebaseClient';

const NAV = [
  { href: '/dashboard', label: 'Dashboard' },
  { href: '/activity', label: "Journal d'activité" },
  { href: '/content', label: 'Visuels' },
  { href: '/users', label: 'Utilisateurs' },
  { href: '/products', label: 'Produits' },
  { href: '/vendors', label: 'Vendeurs' },
  { href: '/drivers', label: 'Chauffeurs' },
  { href: '/orders', label: 'Commandes' },
  { href: '/rides', label: 'Courses' },
  { href: '/disputes', label: 'Litiges' },
  { href: '/commission', label: 'Commission' },
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
    return <div className="min-h-screen flex items-center justify-center text-neutral-400">Chargement…</div>;
  }

  return (
    <div className="min-h-screen flex">
      <aside className="w-60 shrink-0 border-r border-neutral-800 p-5">
        <div className="text-xl font-bold mb-8" style={{ color: 'var(--livra-gold)' }}>Livra Admin</div>
        <nav className="flex flex-col gap-1">
          {NAV.map((n) => (
            <a
              key={n.href}
              href={n.href}
              className={`px-3 py-2 rounded-lg text-sm ${pathname === n.href ? 'bg-neutral-800 text-white' : 'text-neutral-400 hover:bg-neutral-900'}`}
            >
              {n.label}
            </a>
          ))}
        </nav>
      </aside>
      <main className="flex-1 p-8">{children}</main>
    </div>
  );
}

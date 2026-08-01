'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

export default function UsersPage() {
  const [items, setItems] = useState(null);

  async function load() {
    const data = await apiFetch('/api/admin/users?limit=100');
    setItems(data.items);
  }
  useEffect(() => { load(); }, []);

  async function toggleActive(uid, isActive) {
    if (!isActive && !confirm('Désactiver ce compte ? Il ne pourra plus se connecter utilement.')) return;
    await apiFetch(`/api/admin/users/${uid}`, { method: 'PATCH', body: JSON.stringify({ isActive }) });
    load();
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">Utilisateurs</h1>
      <p className="text-neutral-500 text-sm mb-4">Tous les comptes (clients, vendeurs, livreurs, admins).</p>
      <div className="grid gap-2">
        {items === null && <div className="text-neutral-500">Chargement…</div>}
        {items?.map((u) => (
          <div key={u.id} className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 flex justify-between items-center">
            <div>
              <div className="font-semibold">{u.name || '(sans nom)'} <span className="text-neutral-500 font-normal text-sm">— {u.role}</span></div>
              <div className="text-neutral-400 text-sm">{u.email} {u.phone ? `— ${u.phone}` : ''}</div>
            </div>
            <div className="flex items-center gap-3 shrink-0">
              <span className={`text-xs px-2 py-0.5 rounded-full ${u.isActive !== false ? 'bg-green-800' : 'bg-red-900'}`}>
                {u.isActive !== false ? 'actif' : 'désactivé'}
              </span>
              <button
                onClick={() => toggleActive(u.id, u.isActive === false)}
                className={`px-3 py-1 rounded-lg text-sm ${u.isActive !== false ? 'bg-yellow-600' : 'bg-green-600'}`}
              >
                {u.isActive !== false ? 'Désactiver' : 'Réactiver'}
              </button>
            </div>
          </div>
        ))}
        {items?.length === 0 && <div className="text-neutral-500">Aucun utilisateur.</div>}
      </div>
    </div>
  );
}

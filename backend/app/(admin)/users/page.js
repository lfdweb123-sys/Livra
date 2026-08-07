'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

const ROLE_LABELS = { client: 'Client', vendor: 'Vendeur', driver: 'Livreur/Chauffeur', admin: 'Admin' };

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
      <h1 className="text-2xl font-bold mb-1 text-livra-textPrimary">Utilisateurs</h1>
      <p className="text-livra-textSecondary text-sm mb-4">Tous les comptes (clients, vendeurs, livreurs, admins).</p>
      <div className="grid gap-2">
        {items === null && <div className="text-livra-textSecondary">Chargement…</div>}
        {items?.map((u) => (
          <div key={u.id} className="bg-livra-surface border border-livra-divider rounded-xl p-4 flex flex-wrap justify-between items-center gap-2">
            <div>
              <div className="font-semibold text-livra-textPrimary">{u.name || '(sans nom)'} <span className="text-livra-textSecondary font-normal text-sm">— {ROLE_LABELS[u.role] || u.role}</span></div>
              <div className="text-livra-textSecondary text-sm">{u.email} {u.phone ? `— ${u.phone}` : ''}</div>
            </div>
            <div className="flex items-center gap-3 shrink-0">
              <span className={`text-xs px-2 py-0.5 rounded-full text-white ${u.isActive !== false ? 'bg-livra-success' : 'bg-livra-danger'}`}>
                {u.isActive !== false ? 'Actif' : 'Désactivé'}
              </span>
              <button
                onClick={() => toggleActive(u.id, u.isActive === false)}
                className={`px-3 py-1 rounded-lg text-sm text-white ${u.isActive !== false ? 'bg-livra-warning' : 'bg-livra-success'}`}
              >
                {u.isActive !== false ? 'Désactiver' : 'Réactiver'}
              </button>
            </div>
          </div>
        ))}
        {items?.length === 0 && <div className="text-livra-textSecondary">Aucun utilisateur.</div>}
      </div>
    </div>
  );
}

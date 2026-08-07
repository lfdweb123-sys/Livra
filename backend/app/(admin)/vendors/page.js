'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

const STATUS_LABELS = { pending: 'En attente', active: 'Actifs', suspended: 'Suspendus', rejected: 'Rejetés' };

// L'admin vérifie l'identité (documents) avant d'approuver — pas
// d'activation automatique. Voir le Journal d'activité pour l'historique
// des décisions.
export default function VendorsPage() {
  const [items, setItems] = useState([]);
  const [filter, setFilter] = useState('pending');

  async function load() {
    const data = await apiFetch(`/api/vendors?status=${filter}&limit=50`);
    setItems(data.items);
  }
  useEffect(() => { load(); }, [filter]);

  async function updateStatus(id, status) {
    let rejectionReason;
    if (status === 'rejected') {
      rejectionReason = prompt('Motif du rejet (visible par le vendeur) ?') || '';
    }
    await apiFetch(`/api/vendors/${id}`, { method: 'PATCH', body: JSON.stringify({ status, rejectionReason }) });
    load();
  }

  async function remove(v) {
    if (!confirm(`Supprimer définitivement "${v.businessName}" et tout son catalogue ? Action irréversible (non-respect des règles).`)) return;
    await apiFetch(`/api/vendors/${v.id}`, { method: 'DELETE' });
    load();
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1 text-livra-textPrimary">Vendeurs</h1>
      <p className="text-livra-textSecondary text-sm mb-4">Vérifie l'identité (documents) avant d'approuver une candidature.</p>
      <div className="flex gap-2 mb-4 flex-wrap">
        {['pending', 'active', 'suspended', 'rejected'].map((s) => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`px-3 py-1 rounded-full text-sm ${filter === s ? 'bg-livra-gold text-white font-medium' : 'bg-livra-surfaceElevated text-livra-textPrimary'}`}
          >
            {STATUS_LABELS[s]}
          </button>
        ))}
      </div>
      <div className="grid gap-3">
        {items.map((v) => (
          <div key={v.id} className="bg-livra-surface border border-livra-divider rounded-xl p-4">
            <div className="flex justify-between items-start gap-4">
              <div>
                <div className="font-semibold">{v.businessName}</div>
                <div className="text-livra-textSecondary text-sm">{v.category} — {v.address}</div>
              </div>
              <div className="flex gap-2 shrink-0">
                {v.status === 'pending' && (
                  <>
                    <button onClick={() => updateStatus(v.id, 'active')} className="px-3 py-1 rounded-lg bg-green-600 text-sm text-white">Approuver</button>
                    <button onClick={() => updateStatus(v.id, 'rejected')} className="px-3 py-1 rounded-lg bg-red-600 text-sm text-white">Rejeter</button>
                  </>
                )}
                {v.status === 'active' && (
                  <button onClick={() => updateStatus(v.id, 'suspended')} className="px-3 py-1 rounded-lg bg-livra-warning text-sm text-white">Suspendre</button>
                )}
                {v.status === 'suspended' && (
                  <button onClick={() => updateStatus(v.id, 'active')} className="px-3 py-1 rounded-lg bg-green-600 text-sm text-white">Réactiver</button>
                )}
                <button onClick={() => remove(v)} className="px-3 py-1 rounded-lg bg-red-800 text-sm text-white">Supprimer</button>
              </div>
            </div>
            {v.documents && Object.keys(v.documents).length > 0 && (
              <div className="mt-3 pt-3 border-t border-livra-divider flex flex-wrap gap-3">
                {Object.entries(v.documents).map(([key, url]) => (
                  <a key={key} href={url} target="_blank" rel="noreferrer" className="text-xs text-livra-gold underline font-medium">
                    Voir : {key}
                  </a>
                ))}
              </div>
            )}
            {(!v.documents || Object.keys(v.documents).length === 0) && v.status === 'pending' && (
              <div className="mt-3 pt-3 border-t border-livra-divider text-xs text-livra-warning font-medium">
                ⚠ Aucun document d'identité fourni — vérifie avant d'approuver.
              </div>
            )}
          </div>
        ))}
        {items.length === 0 && <div className="text-livra-textSecondary">Aucun vendeur dans ce filtre.</div>}
      </div>
    </div>
  );
}

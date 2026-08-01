'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

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

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">Vendeurs</h1>
      <p className="text-neutral-500 text-sm mb-4">Vérifie l'identité (documents) avant d'approuver une candidature.</p>
      <div className="flex gap-2 mb-4">
        {['pending', 'active', 'suspended', 'rejected'].map((s) => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`px-3 py-1 rounded-full text-sm ${filter === s ? 'bg-white text-black' : 'bg-neutral-800 text-neutral-300'}`}
          >
            {s}
          </button>
        ))}
      </div>
      <div className="grid gap-3">
        {items.map((v) => (
          <div key={v.id} className="bg-neutral-900 border border-neutral-800 rounded-xl p-4">
            <div className="flex justify-between items-start gap-4">
              <div>
                <div className="font-semibold">{v.businessName}</div>
                <div className="text-neutral-400 text-sm">{v.category} — {v.address}</div>
              </div>
              <div className="flex gap-2 shrink-0">
                {v.status === 'pending' && (
                  <>
                    <button onClick={() => updateStatus(v.id, 'active')} className="px-3 py-1 rounded-lg bg-green-600 text-sm">Approuver</button>
                    <button onClick={() => updateStatus(v.id, 'rejected')} className="px-3 py-1 rounded-lg bg-red-600 text-sm">Rejeter</button>
                  </>
                )}
                {v.status === 'active' && (
                  <button onClick={() => updateStatus(v.id, 'suspended')} className="px-3 py-1 rounded-lg bg-yellow-600 text-sm">Suspendre</button>
                )}
                {v.status === 'suspended' && (
                  <button onClick={() => updateStatus(v.id, 'active')} className="px-3 py-1 rounded-lg bg-green-600 text-sm">Réactiver</button>
                )}
              </div>
            </div>
            {v.documents && Object.keys(v.documents).length > 0 && (
              <div className="mt-3 pt-3 border-t border-neutral-800 flex flex-wrap gap-3">
                {Object.entries(v.documents).map(([key, url]) => (
                  <a key={key} href={url} target="_blank" rel="noreferrer" className="text-xs text-blue-400 underline">
                    Voir : {key}
                  </a>
                ))}
              </div>
            )}
            {(!v.documents || Object.keys(v.documents).length === 0) && v.status === 'pending' && (
              <div className="mt-3 pt-3 border-t border-neutral-800 text-xs text-yellow-500">
                ⚠ Aucun document d'identité fourni — vérifie avant d'approuver.
              </div>
            )}
          </div>
        ))}
        {items.length === 0 && <div className="text-neutral-500">Aucun vendeur dans ce filtre.</div>}
      </div>
    </div>
  );
}

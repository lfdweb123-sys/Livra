'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

// Tout est automatisé : un vendeur est actif dès sa candidature (voir
// vendors/route.js). Cette page sert uniquement à consulter et, en cas
// d'abus signalé, suspendre — pas à valider chaque candidature au quotidien.
export default function VendorsPage() {
  const [items, setItems] = useState([]);
  const [filter, setFilter] = useState('active');

  async function load() {
    const data = await apiFetch(`/api/vendors?status=${filter}&limit=50`);
    setItems(data.items);
  }
  useEffect(() => { load(); }, [filter]);

  async function updateStatus(id, status) {
    await apiFetch(`/api/vendors/${id}`, { method: 'PATCH', body: JSON.stringify({ status }) });
    load();
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">Vendeurs</h1>
      <p className="text-neutral-500 text-sm mb-4">Activation automatique à la candidature. Suspends uniquement en cas d'abus signalé.</p>
      <div className="flex gap-2 mb-4">
        {['active', 'suspended'].map((s) => (
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
          <div key={v.id} className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 flex justify-between items-center">
            <div>
              <div className="font-semibold">{v.businessName}</div>
              <div className="text-neutral-400 text-sm">{v.category} — {v.address}</div>
            </div>
            {v.status === 'active' && (
              <button onClick={() => updateStatus(v.id, 'suspended')} className="px-3 py-1 rounded-lg bg-yellow-600 text-sm">Suspendre (abus)</button>
            )}
            {v.status === 'suspended' && (
              <button onClick={() => updateStatus(v.id, 'active')} className="px-3 py-1 rounded-lg bg-green-600 text-sm">Réactiver</button>
            )}
          </div>
        ))}
        {items.length === 0 && <div className="text-neutral-500">Aucun vendeur dans ce filtre.</div>}
      </div>
    </div>
  );
}

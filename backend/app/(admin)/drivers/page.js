'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

// Même logique que vendors : activation automatique, l'admin ne fait que
// consulter et suspendre en cas d'abus.
export default function DriversPage() {
  const [items, setItems] = useState([]);
  const [filter, setFilter] = useState('active');

  async function load() {
    const data = await apiFetch(`/api/drivers?status=${filter}`);
    setItems(data.items);
  }
  useEffect(() => { load(); }, [filter]);

  async function updateStatus(id, status) {
    await apiFetch(`/api/drivers/${id}`, { method: 'PATCH', body: JSON.stringify({ status }) });
    load();
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">Chauffeurs / Livreurs</h1>
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
        {items.map((d) => (
          <div key={d.id} className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 flex justify-between items-center">
            <div>
              <div className="font-semibold">{d.vehicleType}</div>
              <div className="text-neutral-400 text-sm">Documents: {Object.keys(d.documentsR2 || {}).length} fichier(s)</div>
            </div>
            {d.status === 'active' && (
              <button onClick={() => updateStatus(d.id, 'suspended')} className="px-3 py-1 rounded-lg bg-yellow-600 text-sm">Suspendre (abus)</button>
            )}
            {d.status === 'suspended' && (
              <button onClick={() => updateStatus(d.id, 'active')} className="px-3 py-1 rounded-lg bg-green-600 text-sm">Réactiver</button>
            )}
          </div>
        ))}
        {items.length === 0 && <div className="text-neutral-500">Aucun chauffeur dans ce filtre.</div>}
      </div>
    </div>
  );
}

'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

export default function DriversPage() {
  const [items, setItems] = useState([]);
  const [filter, setFilter] = useState('pending');

  async function load() {
    const data = await apiFetch(`/api/drivers?status=${filter}`);
    setItems(data.items);
  }
  useEffect(() => { load(); }, [filter]);

  async function updateStatus(id, status) {
    let rejectionReason;
    if (status === 'rejected') {
      rejectionReason = prompt('Motif du rejet (visible par le livreur) ?') || '';
    }
    await apiFetch(`/api/drivers/${id}`, { method: 'PATCH', body: JSON.stringify({ status, rejectionReason }) });
    load();
  }

  async function remove(d) {
    if (!confirm('Supprimer définitivement ce compte livreur ? Action irréversible (non-respect des règles).')) return;
    await apiFetch(`/api/drivers/${d.id}`, { method: 'DELETE' });
    load();
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">Chauffeurs / Livreurs</h1>
      <p className="text-neutral-500 text-sm mb-4">Vérifie CNI, permis, assurance et photo du véhicule avant d'approuver.</p>
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
        {items.map((d) => (
          <div key={d.id} className="bg-neutral-900 border border-neutral-800 rounded-xl p-4">
            <div className="flex justify-between items-start gap-4">
              <div>
                <div className="font-semibold">{d.vehicleType}</div>
                <div className="text-neutral-400 text-sm">{Object.keys(d.documentsR2 || {}).length} document(s) fourni(s)</div>
              </div>
              <div className="flex gap-2 shrink-0">
                {d.status === 'pending' && (
                  <>
                    <button onClick={() => updateStatus(d.id, 'active')} className="px-3 py-1 rounded-lg bg-green-600 text-sm">Approuver</button>
                    <button onClick={() => updateStatus(d.id, 'rejected')} className="px-3 py-1 rounded-lg bg-red-600 text-sm">Rejeter</button>
                  </>
                )}
                {d.status === 'active' && (
                  <button onClick={() => updateStatus(d.id, 'suspended')} className="px-3 py-1 rounded-lg bg-yellow-600 text-sm">Suspendre</button>
                )}
                {d.status === 'suspended' && (
                  <button onClick={() => updateStatus(d.id, 'active')} className="px-3 py-1 rounded-lg bg-green-600 text-sm">Réactiver</button>
                )}
              </div>
            </div>
            {d.documentsR2 && Object.keys(d.documentsR2).length > 0 && (
              <div className="mt-3 pt-3 border-t border-neutral-800 flex flex-wrap gap-3">
                {Object.entries(d.documentsR2).map(([key, url]) => (
                  <a key={key} href={url} target="_blank" rel="noreferrer" className="text-xs text-blue-400 underline">
                    Voir : {key}
                  </a>
                ))}
              </div>
            )}
            {(!d.documentsR2 || Object.keys(d.documentsR2).length === 0) && d.status === 'pending' && (
              <div className="mt-3 pt-3 border-t border-neutral-800 text-xs text-yellow-500">
                ⚠ Aucun document fourni — vérifie avant d'approuver.
              </div>
            )}
          </div>
        ))}
        {items.length === 0 && <div className="text-neutral-500">Aucun chauffeur dans ce filtre.</div>}
      </div>
    </div>
  );
}

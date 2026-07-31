'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

export default function DisputesPage() {
  const [items, setItems] = useState([]);
  async function load() {
    const d = await apiFetch('/api/admin/disputes');
    setItems(d.items);
  }
  useEffect(() => { load(); }, []);

  async function resolve(id, status) {
    const resolution = status === 'resolved' ? prompt('Résolution ?') : null;
    await apiFetch('/api/admin/disputes', { method: 'PATCH', body: JSON.stringify({ id, status, resolution }) });
    load();
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">Litiges</h1>
      <div className="grid gap-3">
        {items.map((d) => (
          <div key={d.id} className="bg-neutral-900 border border-neutral-800 rounded-xl p-4">
            <div className="text-sm mb-2">{d.reason}</div>
            <div className="text-neutral-500 text-xs mb-3">Statut: {d.status}</div>
            {d.status === 'open' && (
              <div className="flex gap-2">
                <button onClick={() => resolve(d.id, 'resolved')} className="px-3 py-1 rounded-lg bg-green-600 text-sm">Résoudre</button>
                <button onClick={() => resolve(d.id, 'rejected')} className="px-3 py-1 rounded-lg bg-red-600 text-sm">Rejeter</button>
              </div>
            )}
          </div>
        ))}
        {items.length === 0 && <div className="text-neutral-500">Aucun litige.</div>}
      </div>
    </div>
  );
}

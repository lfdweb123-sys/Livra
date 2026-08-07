'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

const REASON_LABELS = {
  not_received: 'Commande/course non reçue',
  bad_product: 'Produit non conforme / endommagé',
  abuse: 'Comportement abusif ou irrespectueux',
  fraud: "Fraude ou tentative d'arnaque",
  other: 'Autre',
};
const STATUS_LABELS = { open: 'Ouvert', resolved: 'Résolu', rejected: 'Rejeté' };

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
      <h1 className="text-2xl font-bold mb-4 text-livra-textPrimary">Litiges</h1>
      <div className="grid gap-3">
        {items.map((d) => (
          <div key={d.id} className="bg-livra-surface border border-livra-divider rounded-xl p-4">
            <div className="text-sm mb-1 font-medium text-livra-textPrimary">{REASON_LABELS[d.reason] || d.reason}</div>
            {d.description && <div className="text-sm text-livra-textSecondary mb-2">{d.description}</div>}
            <div className="text-livra-textSecondary text-xs mb-3">Statut : {STATUS_LABELS[d.status] || d.status}</div>
            {d.status === 'open' && (
              <div className="flex gap-2">
                <button onClick={() => resolve(d.id, 'resolved')} className="px-3 py-1 rounded-lg bg-livra-success text-sm text-white">Résoudre</button>
                <button onClick={() => resolve(d.id, 'rejected')} className="px-3 py-1 rounded-lg bg-livra-danger text-sm text-white">Rejeter</button>
              </div>
            )}
          </div>
        ))}
        {items.length === 0 && <div className="text-livra-textSecondary">Aucun litige.</div>}
      </div>
    </div>
  );
}

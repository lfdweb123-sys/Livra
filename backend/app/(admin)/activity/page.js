'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

const TYPE_COLOR = {
  vendor_activated: 'bg-green-700',
  driver_activated: 'bg-green-700',
  order_created: 'bg-blue-700',
  payment_confirmed: 'bg-emerald-700',
  dispute_opened: 'bg-red-800',
};

export default function ActivityPage() {
  const [items, setItems] = useState(null);

  useEffect(() => {
    apiFetch('/api/admin/activity?limit=100').then((d) => setItems(d.items));
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">Journal d'activité</h1>
      <p className="text-neutral-500 text-sm mb-4">
        Trace de toutes les actions automatiques de la plateforme (candidatures, paiements...). Rien ici n'attend une validation — c'est un historique de consultation.
      </p>
      <div className="grid gap-2">
        {items === null && <div className="text-neutral-500">Chargement…</div>}
        {items?.map((log) => (
          <div key={log.id} className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 flex items-start gap-3">
            <span className={`px-2 py-0.5 rounded-full text-xs shrink-0 ${TYPE_COLOR[log.type] || 'bg-neutral-700'}`}>{log.type}</span>
            <div className="text-sm">{log.message}</div>
          </div>
        ))}
        {items?.length === 0 && <div className="text-neutral-500">Aucune activité pour le moment.</div>}
      </div>
    </div>
  );
}

'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

const STATUS_COLOR = {
  pending: 'bg-neutral-700', accepted: 'bg-blue-700', preparing: 'bg-blue-600',
  picked_up: 'bg-purple-700', delivering: 'bg-purple-600', delivered: 'bg-green-700', cancelled: 'bg-red-800',
};

export default function OrdersPage() {
  const [items, setItems] = useState([]);

  useEffect(() => {
    apiFetch('/api/orders?limit=50').then((d) => setItems(d.items)).catch(() => {});
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">Commandes</h1>
      <div className="grid gap-2">
        {items.map((o) => (
          <div key={o.id} className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 flex justify-between items-center">
            <div>
              <div className="font-mono text-xs text-neutral-500">{o.id}</div>
              <div className="text-sm">{o.type} — {o.priceBreakdown?.total} XOF — paiement: {o.paymentStatus}</div>
            </div>
            <span className={`px-3 py-1 rounded-full text-xs ${STATUS_COLOR[o.status] || 'bg-neutral-700'}`}>{o.status}</span>
          </div>
        ))}
        {items.length === 0 && <div className="text-neutral-500">Aucune commande.</div>}
      </div>
    </div>
  );
}

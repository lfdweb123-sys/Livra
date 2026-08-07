'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';
import { orderStatusFr, ORDER_TYPE_LABELS_FR, PAYMENT_STATUS_LABELS_FR } from '../../../lib/statusLabels';

const STATUS_COLOR = {
  pending: 'bg-livra-surfaceElevated text-livra-textPrimary', accepted: 'bg-blue-600 text-white', preparing: 'bg-blue-500 text-white',
  picked_up: 'bg-purple-600 text-white', delivering: 'bg-purple-500 text-white', delivered: 'bg-livra-success text-white', cancelled: 'bg-livra-danger text-white',
};

export default function OrdersPage() {
  const [items, setItems] = useState([]);

  useEffect(() => {
    apiFetch('/api/orders?limit=50').then((d) => setItems(d.items)).catch(() => {});
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4 text-livra-textPrimary">Commandes</h1>
      <div className="grid gap-2">
        {items.map((o) => (
          <div key={o.id} className="bg-livra-surface border border-livra-divider rounded-xl p-4 flex flex-wrap justify-between items-center gap-2">
            <div>
              <div className="font-mono text-xs text-livra-textSecondary">{o.id}</div>
              <div className="text-sm text-livra-textPrimary">
                {ORDER_TYPE_LABELS_FR[o.type] || o.type} — {o.priceBreakdown?.total} XOF — paiement : {PAYMENT_STATUS_LABELS_FR[o.paymentStatus] || o.paymentStatus}
              </div>
            </div>
            <span className={`px-3 py-1 rounded-full text-xs shrink-0 ${STATUS_COLOR[o.status] || 'bg-livra-surfaceElevated text-livra-textPrimary'}`}>
              {orderStatusFr(o.status)}
            </span>
          </div>
        ))}
        {items.length === 0 && <div className="text-livra-textSecondary">Aucune commande.</div>}
      </div>
    </div>
  );
}

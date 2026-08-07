'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

const ROLE_LABELS = { client: 'Client', vendor: 'Vendeur' };

export default function OffPlatformPage() {
  const [items, setItems] = useState(null);

  async function load() {
    const d = await apiFetch('/api/admin/off-platform-deliveries');
    setItems(d.items);
  }
  useEffect(() => { load(); }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">Livraisons hors application</h1>
      <p className="text-livra-textSecondary text-sm mb-6">
        Numéros de livreurs/chauffeurs déclarés par des clients ou des vendeurs pour des trajets
        réalisés en dehors de la plateforme — ne relèvent pas de la responsabilité de Livra
        (voir CGU), suivi à titre informatif uniquement.
      </p>
      {items === null ? (
        <div className="text-livra-textSecondary">Chargement…</div>
      ) : items.length === 0 ? (
        <div className="text-livra-textSecondary">Aucune déclaration pour le moment.</div>
      ) : (
        <div className="grid gap-3">
          {items.map((d) => (
            <div key={d.id} className="bg-livra-surface border border-livra-divider rounded-xl p-4">
              <div className="flex items-center justify-between mb-2">
                <span className="font-mono text-sm">{d.phone}</span>
                <span className="text-xs px-2 py-1 rounded-full bg-livra-surfaceElevated">
                  {ROLE_LABELS[d.role] || d.role}
                </span>
              </div>
              <div className="text-livra-textSecondary text-xs">
                Déclaré par : {d.declaredByName || d.declaredBy}
              </div>
              {d.orderId && <div className="text-livra-textSecondary text-xs">Commande : {d.orderId}</div>}
              {d.rideId && <div className="text-livra-textSecondary text-xs">Course : {d.rideId}</div>}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

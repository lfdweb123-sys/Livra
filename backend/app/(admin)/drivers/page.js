'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

const STATUS_LABELS = { pending: 'En attente', active: 'Actifs', suspended: 'Suspendus', rejected: 'Rejetés' };
const VEHICLE_LABELS = { moto: 'Taxi-moto', voiture: 'Chauffeur voiture', coursier: 'Coursier' };

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
      <h1 className="text-2xl font-bold mb-1 text-livra-textPrimary">Chauffeurs / Livreurs</h1>
      <p className="text-livra-textSecondary text-sm mb-4">Vérifie CNI, permis, assurance et photo du véhicule avant d'approuver.</p>
      <div className="flex gap-2 mb-4 flex-wrap">
        {['pending', 'active', 'suspended', 'rejected'].map((s) => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`px-3 py-1 rounded-full text-sm ${filter === s ? 'bg-livra-gold text-white font-medium' : 'bg-livra-surfaceElevated text-livra-textPrimary'}`}
          >
            {STATUS_LABELS[s]}
          </button>
        ))}
      </div>
      <div className="grid gap-3">
        {items.map((d) => (
          <div key={d.id} className="bg-livra-surface border border-livra-divider rounded-xl p-4">
            <div className="flex justify-between items-start gap-4">
              <div>
                <div className="font-semibold text-livra-textPrimary">{VEHICLE_LABELS[d.vehicleType] || d.vehicleType}</div>
                <div className="text-livra-textSecondary text-sm">{Object.keys(d.documentsR2 || {}).length} document(s) fourni(s)</div>
              </div>
              <div className="flex gap-2 shrink-0">
                {d.status === 'pending' && (
                  <>
                    <button onClick={() => updateStatus(d.id, 'active')} className="px-3 py-1 rounded-lg bg-livra-success text-sm text-white">Approuver</button>
                    <button onClick={() => updateStatus(d.id, 'rejected')} className="px-3 py-1 rounded-lg bg-livra-danger text-sm text-white">Rejeter</button>
                  </>
                )}
                {d.status === 'active' && (
                  <button onClick={() => updateStatus(d.id, 'suspended')} className="px-3 py-1 rounded-lg bg-livra-warning text-sm text-white">Suspendre</button>
                )}
                {d.status === 'suspended' && (
                  <button onClick={() => updateStatus(d.id, 'active')} className="px-3 py-1 rounded-lg bg-livra-success text-sm text-white">Réactiver</button>
                )}
                <button onClick={() => remove(d)} className="px-3 py-1 rounded-lg bg-livra-danger/80 text-sm text-white">Supprimer</button>
              </div>
            </div>
            {d.documentsR2 && Object.keys(d.documentsR2).length > 0 && (
              <div className="mt-3 pt-3 border-t border-livra-divider flex flex-wrap gap-3">
                {Object.entries(d.documentsR2).map(([key, url]) => (
                  <a key={key} href={url} target="_blank" rel="noreferrer" className="text-xs text-livra-gold underline font-medium">
                    Voir : {key}
                  </a>
                ))}
              </div>
            )}
            {(!d.documentsR2 || Object.keys(d.documentsR2).length === 0) && d.status === 'pending' && (
              <div className="mt-3 pt-3 border-t border-livra-divider text-xs text-livra-warning font-medium">
                ⚠ Aucun document fourni — vérifie avant d'approuver.
              </div>
            )}
          </div>
        ))}
        {items.length === 0 && <div className="text-livra-textSecondary">Aucun chauffeur dans ce filtre.</div>}
      </div>
    </div>
  );
}

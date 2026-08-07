'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';
import { rideStatusFr } from '../../../lib/statusLabels';

const VEHICLE_LABELS = { moto: 'Taxi-moto', voiture: 'Voiture', coursier: 'Coursier' };
const STATUS_COLOR = {
  pending: 'bg-livra-surfaceElevated text-livra-textPrimary', accepted: 'bg-blue-600 text-white',
  arriving: 'bg-blue-500 text-white', in_progress: 'bg-purple-600 text-white',
  completed: 'bg-livra-success text-white', cancelled: 'bg-livra-danger text-white',
};

export default function RidesPage() {
  const [items, setItems] = useState([]);
  useEffect(() => {
    apiFetch('/api/rides?limit=50').then((d) => setItems(d.items)).catch(() => {});
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4 text-livra-textPrimary">Courses</h1>
      <div className="grid gap-2">
        {items.map((r) => (
          <div key={r.id} className="bg-livra-surface border border-livra-divider rounded-xl p-4 flex flex-wrap justify-between items-center gap-2">
            <div>
              <div className="font-mono text-xs text-livra-textSecondary">{r.id}</div>
              <div className="text-sm text-livra-textPrimary">{VEHICLE_LABELS[r.vehicleType] || r.vehicleType} — {r.price} XOF — {r.distanceKm} km</div>
            </div>
            <span className={`px-3 py-1 rounded-full text-xs shrink-0 ${STATUS_COLOR[r.status] || 'bg-livra-surfaceElevated text-livra-textPrimary'}`}>
              {rideStatusFr(r.status)}
            </span>
          </div>
        ))}
        {items.length === 0 && <div className="text-livra-textSecondary">Aucune course.</div>}
      </div>
    </div>
  );
}

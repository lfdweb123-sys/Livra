'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

export default function RidesPage() {
  const [items, setItems] = useState([]);
  useEffect(() => {
    apiFetch('/api/rides?limit=50').then((d) => setItems(d.items)).catch(() => {});
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">Courses</h1>
      <div className="grid gap-2">
        {items.map((r) => (
          <div key={r.id} className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 flex justify-between items-center">
            <div>
              <div className="font-mono text-xs text-neutral-500">{r.id}</div>
              <div className="text-sm">{r.vehicleType} — {r.price} XOF — {r.distanceKm} km</div>
            </div>
            <span className="px-3 py-1 rounded-full text-xs bg-neutral-700">{r.status}</span>
          </div>
        ))}
        {items.length === 0 && <div className="text-neutral-500">Aucune course.</div>}
      </div>
    </div>
  );
}

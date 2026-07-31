'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

export default function CommissionPage() {
  const [percent, setPercent] = useState(15);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    apiFetch('/api/admin/commission').then((d) => setPercent(d.defaultCommissionPercent ?? 15));
  }, []);

  async function save() {
    await apiFetch('/api/admin/commission', { method: 'PATCH', body: JSON.stringify({ defaultCommissionPercent: Number(percent) }) });
    setSaved(true);
    setTimeout(() => setSaved(false), 1500);
  }

  return (
    <div className="max-w-sm">
      <h1 className="text-2xl font-bold mb-4">Commission par défaut</h1>
      <div className="flex items-center gap-3">
        <input
          type="number"
          value={percent}
          onChange={(e) => setPercent(e.target.value)}
          className="w-24 px-3 py-2 rounded-lg bg-neutral-800 border border-neutral-700"
        />
        <span>%</span>
      </div>
      <button onClick={save} className="mt-4 px-4 py-2 rounded-lg font-semibold text-black" style={{ backgroundColor: 'var(--livra-gold)' }}>
        {saved ? 'Enregistré ✓' : 'Enregistrer'}
      </button>
      <p className="text-neutral-500 text-sm mt-3">Ce taux sert de valeur par défaut pour les nouveaux vendeurs ; chaque vendeur peut ensuite être ajusté individuellement dans sa fiche.</p>
    </div>
  );
}

'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

export default function ProductsPage() {
  const [items, setItems] = useState(null);

  async function load() {
    const data = await apiFetch('/api/admin/products');
    setItems(data.items);
  }
  useEffect(() => { load(); }, []);

  async function remove(product) {
    if (!confirm(`Supprimer "${product.name}" ? Action définitive.`)) return;
    await apiFetch(`/api/vendors/${product.vendorId}/products/${product.id}`, { method: 'DELETE' });
    load();
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">Produits</h1>
      <p className="text-neutral-500 text-sm mb-4">Tous les produits, tous vendeurs confondus.</p>
      <div className="grid gap-2">
        {items === null && <div className="text-neutral-500">Chargement…</div>}
        {items?.map((p) => (
          <div key={p.id} className="bg-neutral-900 border border-neutral-800 rounded-xl p-4 flex justify-between items-center gap-3">
            <div className="flex items-center gap-3">
              {p.imageUrl && <img src={p.imageUrl} alt="" className="w-12 h-12 object-cover rounded-lg" />}
              <div>
                <div className="font-semibold">{p.name}</div>
                <div className="text-neutral-400 text-sm">{p.price} XOF {p.pinned ? '· épinglé' : ''} {!p.isAvailable ? '· masqué' : ''}</div>
              </div>
            </div>
            <button onClick={() => remove(p)} className="px-3 py-1 rounded-lg bg-red-600 text-sm shrink-0">Supprimer</button>
          </div>
        ))}
        {items?.length === 0 && <div className="text-neutral-500">Aucun produit.</div>}
      </div>
    </div>
  );
}

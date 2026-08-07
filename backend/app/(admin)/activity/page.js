'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';

// Traduction complète de chaque type d'activité — jamais le code brut
// affiché à l'écran (ex: "order_created"). Liste exhaustive des types
// réellement produits par le backend (voir logActivity() dans tout le
// projet).
const TYPE_INFO = {
  order_created: { label: 'Commande créée', color: 'bg-livra-gold', icon: '🛒' },
  vendor_applied: { label: 'Candidature vendeur', color: 'bg-livra-textSecondary', icon: '🏪' },
  vendor_approved: { label: 'Vendeur approuvé', color: 'bg-livra-success', icon: '✅' },
  vendor_rejected: { label: 'Vendeur rejeté', color: 'bg-livra-danger', icon: '⛔' },
  vendor_deleted: { label: 'Vendeur supprimé', color: 'bg-livra-danger', icon: '🗑️' },
  driver_applied: { label: 'Candidature livreur/chauffeur', color: 'bg-livra-textSecondary', icon: '🛵' },
  driver_approved: { label: 'Livreur/chauffeur approuvé', color: 'bg-livra-success', icon: '✅' },
  driver_rejected: { label: 'Livreur/chauffeur rejeté', color: 'bg-livra-danger', icon: '⛔' },
  driver_deleted: { label: 'Livreur/chauffeur supprimé', color: 'bg-livra-danger', icon: '🗑️' },
  review_created: { label: 'Avis publié', color: 'bg-livra-warning', icon: '⭐' },
  user_reactivated: { label: 'Compte réactivé', color: 'bg-livra-success', icon: '🔓' },
  user_deactivated: { label: 'Compte désactivé', color: 'bg-livra-danger', icon: '🔒' },
};

const FALLBACK = { label: 'Activité', color: 'bg-livra-textSecondary', icon: '•' };

export default function ActivityPage() {
  const [items, setItems] = useState(null);

  useEffect(() => {
    apiFetch('/api/admin/activity?limit=100').then((d) => setItems(d.items));
  }, []);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1 text-livra-textPrimary">Journal d'activité</h1>
      <p className="text-livra-textSecondary text-sm mb-6">
        Trace de toutes les actions automatiques de la plateforme (candidatures, paiements...). Rien ici n'attend une validation — c'est un historique de consultation.
      </p>
      <div className="grid gap-2.5">
        {items === null && <div className="text-livra-textSecondary text-sm">Chargement…</div>}
        {items?.map((log) => {
          const info = TYPE_INFO[log.type] || FALLBACK;
          return (
            <div key={log.id} className="bg-livra-surface border border-livra-divider rounded-xl p-4 flex items-start gap-3 shadow-sm">
              <span className={`h-8 w-8 shrink-0 rounded-full flex items-center justify-center text-sm ${info.color} text-white`}>
                {info.icon}
              </span>
              <div className="min-w-0">
                <div className="text-xs font-semibold text-livra-textSecondary uppercase tracking-wide mb-0.5">{info.label}</div>
                <div className="text-sm text-livra-textPrimary">{log.message}</div>
              </div>
            </div>
          );
        })}
        {items?.length === 0 && <div className="text-livra-textSecondary text-sm">Aucune activité pour le moment.</div>}
      </div>
    </div>
  );
}

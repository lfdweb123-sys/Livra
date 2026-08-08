'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';
import { orderStatusFr, ORDER_TYPE_LABELS_FR, PAYMENT_STATUS_LABELS_FR } from '../../../lib/statusLabels';
import { useSearchPagination, SearchBar, PaginationBar } from '../../../lib/adminSearchPagination';

const STATUS_COLOR = {
  pending: 'bg-livra-surfaceElevated text-livra-textPrimary', accepted: 'bg-blue-600 text-white', preparing: 'bg-blue-500 text-white',
  picked_up: 'bg-purple-600 text-white', delivering: 'bg-purple-500 text-white', delivered: 'bg-livra-success text-white', cancelled: 'bg-livra-danger text-white',
};

const PAYMENT_METHOD_LABELS = {
  cash: 'Espèces à la livraison', wallet: 'Portefeuille Livra',
  feexpay: 'Mobile Money (Feexpay)', verzapay: 'Carte bancaire / International (Verzapay)',
};

function DetailRow({ label, value }) {
  if (value === undefined || value === null || value === '') return null;
  return (
    <div className="flex justify-between gap-4 py-1 text-sm">
      <span className="text-livra-textSecondary">{label}</span>
      <span className="text-livra-textPrimary text-right">{value}</span>
    </div>
  );
}

function OrderDetailModal({ orderId, onClose }) {
  const [detail, setDetail] = useState(null);
  useEffect(() => {
    apiFetch(`/api/orders/${orderId}`).then(setDetail).catch(() => setDetail({ error: true }));
  }, [orderId]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div
        className="bg-livra-surface rounded-2xl max-w-lg w-full max-h-[85vh] overflow-y-auto p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex justify-between items-start mb-4">
          <h2 className="text-lg font-bold text-livra-textPrimary">Détail de la commande</h2>
          <button onClick={onClose} className="text-livra-textSecondary text-xl leading-none">×</button>
        </div>
        {!detail ? (
          <div className="text-livra-textSecondary text-sm">Chargement…</div>
        ) : detail.error ? (
          <div className="text-livra-danger text-sm">Impossible de charger le détail.</div>
        ) : (
          <div className="space-y-4">
            <DetailRow label="N° de commande" value={detail.id} />
            <DetailRow label="Type" value={ORDER_TYPE_LABELS_FR[detail.type] || detail.type} />
            <DetailRow label="Statut" value={orderStatusFr(detail.status)} />
            {detail.items?.length > 0 && (
              <div>
                <div className="text-xs uppercase text-livra-textSecondary font-semibold mb-1">Articles</div>
                {detail.items.map((it, i) => (
                  <DetailRow key={i} label={`${it.qty || it.quantity || 1}x ${it.name}`} value={`${it.price} XOF`} />
                ))}
              </div>
            )}
            <div>
              <div className="text-xs uppercase text-livra-textSecondary font-semibold mb-1">Paiement</div>
              <DetailRow label="Sous-total" value={`${detail.priceBreakdown?.subtotal ?? 0} XOF`} />
              <DetailRow label="Frais de livraison" value={detail.priceBreakdown?.deliveryFee ? `${detail.priceBreakdown.deliveryFee} XOF` : null} />
              <DetailRow label="Frais de service" value={`${detail.priceBreakdown?.serviceFee ?? 0} XOF`} />
              <DetailRow label="Total" value={`${detail.priceBreakdown?.total ?? 0} XOF`} />
              <DetailRow label="Moyen de paiement" value={PAYMENT_METHOD_LABELS[detail.paymentMethod] || detail.paymentMethod} />
              <DetailRow label="Statut du paiement" value={PAYMENT_STATUS_LABELS_FR[detail.paymentStatus] || detail.paymentStatus} />
            </div>
            <div>
              <div className="text-xs uppercase text-livra-textSecondary font-semibold mb-1">Adresses</div>
              <DetailRow label="Collecte" value={detail.pickupAddress?.label} />
              <DetailRow label="Livraison" value={detail.deliveryAddress?.label} />
            </div>
            <div>
              <div className="text-xs uppercase text-livra-textSecondary font-semibold mb-1">Contacts</div>
              <DetailRow label="Vendeur" value={detail.vendorInfo ? `${detail.vendorInfo.businessName || '—'}${detail.vendorInfo.phone ? ' — ' + detail.vendorInfo.phone : ''}` : null} />
              <DetailRow label="Client" value={detail.clientInfo ? `${detail.clientInfo.name || '—'}${detail.clientInfo.phone ? ' — ' + detail.clientInfo.phone : ''}` : null} />
              <DetailRow label="Livreur" value={detail.driverInfo ? `${detail.driverInfo.name || '—'}${detail.driverInfo.phone ? ' — ' + detail.driverInfo.phone : ''}` : null} />
              <DetailRow label="Livreur hors application" value={detail.offPlatformDriverPhone} />
            </div>
            {detail.statusHistory?.length > 0 && (
              <div>
                <div className="text-xs uppercase text-livra-textSecondary font-semibold mb-1">Historique</div>
                {detail.statusHistory.map((h, i) => (
                  <DetailRow key={i} label={orderStatusFr(h.status)} value={h.at ? new Date(h.at).toLocaleString('fr-FR') : null} />
                ))}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

export default function OrdersPage() {
  const [items, setItems] = useState([]);
  const [selectedId, setSelectedId] = useState(null);

  useEffect(() => {
    apiFetch('/api/orders?limit=200').then((d) => setItems(d.items)).catch(() => {});
  }, []);

  const { query, setQuery, page, setPage, pageCount, paginated, totalCount } =
    useSearchPagination(items, ['id', 'type', 'status']);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4 text-livra-textPrimary">Commandes</h1>
      <SearchBar value={query} onChange={setQuery} placeholder="Rechercher par n° de commande, type, statut…" />
      <div className="grid gap-2">
        {paginated.map((o) => (
          <button
            key={o.id}
            onClick={() => setSelectedId(o.id)}
            className="text-left bg-livra-surface border border-livra-divider rounded-xl p-4 flex flex-wrap justify-between items-center gap-2 hover:border-livra-gold/50 transition-colors"
          >
            <div>
              <div className="font-mono text-xs text-livra-textSecondary">{o.id}</div>
              <div className="text-sm text-livra-textPrimary">
                {ORDER_TYPE_LABELS_FR[o.type] || o.type} — {o.priceBreakdown?.total} XOF — paiement : {PAYMENT_STATUS_LABELS_FR[o.paymentStatus] || o.paymentStatus}
              </div>
            </div>
            <span className={`px-3 py-1 rounded-full text-xs shrink-0 ${STATUS_COLOR[o.status] || 'bg-livra-surfaceElevated text-livra-textPrimary'}`}>
              {orderStatusFr(o.status)}
            </span>
          </button>
        ))}
        {paginated.length === 0 && <div className="text-livra-textSecondary">Aucune commande.</div>}
      </div>
      <PaginationBar page={page} pageCount={pageCount} setPage={setPage} totalCount={totalCount} shownCount={paginated.length} />
      {selectedId && <OrderDetailModal orderId={selectedId} onClose={() => setSelectedId(null)} />}
    </div>
  );
}

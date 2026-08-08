'use client';
import { useEffect, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';
import { rideStatusFr } from '../../../lib/statusLabels';
import { useSearchPagination, SearchBar, PaginationBar } from '../../../lib/adminSearchPagination';

const VEHICLE_LABELS = { moto: 'Taxi-moto', voiture: 'Voiture', coursier: 'Coursier' };
const STATUS_COLOR = {
  pending: 'bg-livra-surfaceElevated text-livra-textPrimary', accepted: 'bg-blue-600 text-white',
  arriving: 'bg-blue-500 text-white', in_progress: 'bg-purple-600 text-white',
  completed: 'bg-livra-success text-white', cancelled: 'bg-livra-danger text-white',
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

function RideDetailModal({ rideId, onClose }) {
  const [detail, setDetail] = useState(null);
  useEffect(() => {
    apiFetch(`/api/rides/${rideId}`).then(setDetail).catch(() => setDetail({ error: true }));
  }, [rideId]);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div className="bg-livra-surface rounded-2xl max-w-lg w-full max-h-[85vh] overflow-y-auto p-6" onClick={(e) => e.stopPropagation()}>
        <div className="flex justify-between items-start mb-4">
          <h2 className="text-lg font-bold text-livra-textPrimary">Détail de la course</h2>
          <button onClick={onClose} className="text-livra-textSecondary text-xl leading-none">×</button>
        </div>
        {!detail ? (
          <div className="text-livra-textSecondary text-sm">Chargement…</div>
        ) : detail.error ? (
          <div className="text-livra-danger text-sm">Impossible de charger le détail.</div>
        ) : (
          <div className="space-y-4">
            <DetailRow label="N° de course" value={detail.id} />
            <DetailRow label="Véhicule" value={VEHICLE_LABELS[detail.vehicleType] || detail.vehicleType} />
            <DetailRow label="Statut" value={rideStatusFr(detail.status)} />
            <DetailRow label="Distance" value={detail.distanceKm ? `${detail.distanceKm} km` : null} />
            <div>
              <div className="text-xs uppercase text-livra-textSecondary font-semibold mb-1">Paiement</div>
              <DetailRow label="Prix de base" value={`${detail.basePrice ?? 0} XOF`} />
              <DetailRow label="Frais de service" value={`${detail.serviceFee ?? 0} XOF`} />
              <DetailRow label="Total" value={`${detail.price ?? 0} XOF`} />
              <DetailRow label="Moyen de paiement" value={PAYMENT_METHOD_LABELS[detail.paymentMethod] || detail.paymentMethod} />
            </div>
            <div>
              <div className="text-xs uppercase text-livra-textSecondary font-semibold mb-1">Trajet</div>
              <DetailRow label="Départ" value={detail.pickupLocation?.label} />
              <DetailRow label="Destination" value={detail.dropoffLocation?.label} />
            </div>
            <div>
              <div className="text-xs uppercase text-livra-textSecondary font-semibold mb-1">Contacts</div>
              <DetailRow label="Client" value={detail.clientInfo ? `${detail.clientInfo.name || '—'}${detail.clientInfo.phone ? ' — ' + detail.clientInfo.phone : ''}` : null} />
              <DetailRow label="Chauffeur" value={detail.driverInfo ? `${detail.driverInfo.name || '—'}${detail.driverInfo.phone ? ' — ' + detail.driverInfo.phone : ''}` : null} />
              <DetailRow label="Chauffeur hors application" value={detail.offPlatformDriverPhone} />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default function RidesPage() {
  const [items, setItems] = useState([]);
  const [selectedId, setSelectedId] = useState(null);
  useEffect(() => {
    apiFetch('/api/rides?limit=200').then((d) => setItems(d.items)).catch(() => {});
  }, []);

  const { query, setQuery, page, setPage, pageCount, paginated, totalCount } =
    useSearchPagination(items, ['id', 'vehicleType', 'status']);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4 text-livra-textPrimary">Courses</h1>
      <SearchBar value={query} onChange={setQuery} placeholder="Rechercher par n° de course, véhicule, statut…" />
      <div className="grid gap-2">
        {paginated.map((r) => (
          <button
            key={r.id}
            onClick={() => setSelectedId(r.id)}
            className="text-left bg-livra-surface border border-livra-divider rounded-xl p-4 flex flex-wrap justify-between items-center gap-2 hover:border-livra-gold/50 transition-colors"
          >
            <div>
              <div className="font-mono text-xs text-livra-textSecondary">{r.id}</div>
              <div className="text-sm text-livra-textPrimary">{VEHICLE_LABELS[r.vehicleType] || r.vehicleType} — {r.price} XOF — {r.distanceKm} km</div>
            </div>
            <span className={`px-3 py-1 rounded-full text-xs shrink-0 ${STATUS_COLOR[r.status] || 'bg-livra-surfaceElevated text-livra-textPrimary'}`}>
              {rideStatusFr(r.status)}
            </span>
          </button>
        ))}
        {paginated.length === 0 && <div className="text-livra-textSecondary">Aucune course.</div>}
      </div>
      <PaginationBar page={page} pageCount={pageCount} setPage={setPage} totalCount={totalCount} shownCount={paginated.length} />
      {selectedId && <RideDetailModal rideId={selectedId} onClose={() => setSelectedId(null)} />}
    </div>
  );
}

'use client';
import { useEffect, useState } from 'react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { apiFetch } from '../../../lib/apiClient';

function StatCard({ label, value }) {
  return (
    <div className="bg-neutral-900 border border-neutral-800 rounded-2xl p-5">
      <div className="text-neutral-400 text-sm">{label}</div>
      <div className="text-3xl font-bold mt-1">{value}</div>
    </div>
  );
}

export default function DashboardPage() {
  const [stats, setStats] = useState(null);

  useEffect(() => {
    apiFetch('/api/admin/stats').then(setStats).catch(() => {});
  }, []);

  if (!stats) return <div className="text-neutral-400">Chargement des statistiques…</div>;

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Vue d'ensemble</h1>
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4 mb-8">
        <StatCard label="Commandes (200 récentes)" value={stats.ordersCount} />
        <StatCard label="Courses (200 récentes)" value={stats.ridesCount} />
        <StatCard label="Vendeurs en attente" value={stats.vendorsPendingCount} />
        <StatCard label="Chauffeurs en attente" value={stats.driversPendingCount} />
        <StatCard label="Litiges ouverts" value={stats.disputesOpenCount} />
      </div>
      <div className="bg-neutral-900 border border-neutral-800 rounded-2xl p-5 h-80">
        <div className="text-neutral-400 text-sm mb-4">Revenus commission par jour (XOF)</div>
        <ResponsiveContainer width="100%" height="90%">
          <LineChart data={stats.revenueByDay}>
            <CartesianGrid strokeDasharray="3 3" stroke="#262626" />
            <XAxis dataKey="date" stroke="#737373" fontSize={12} />
            <YAxis stroke="#737373" fontSize={12} />
            <Tooltip contentStyle={{ background: '#171717', border: '1px solid #404040' }} />
            <Line type="monotone" dataKey="revenue" stroke="#D4AF37" strokeWidth={2} dot={false} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}

'use client';
import { useMemo, useState } from 'react';

const PAGE_SIZE = 15;

/// Recherche texte (sur les champs indiques) + pagination cote client,
/// reutilise sur toutes les pages admin. items est deja charge depuis
/// l'API (limit large cote serveur) - le filtrage/la pagination se font
/// ensuite localement, suffisant a l'echelle actuelle sans avoir a
/// reecrire chaque route backend en pagination par curseur.
export function useSearchPagination(items, searchFields) {
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(0);

  const filtered = useMemo(() => {
    if (!query.trim()) return items;
    const q = query.trim().toLowerCase();
    return items.filter((item) =>
      searchFields.some((field) => {
        const value = field.split('.').reduce((o, k) => o?.[k], item);
        return value != null && String(value).toLowerCase().includes(q);
      })
    );
  }, [items, query, searchFields]);

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const safePage = Math.min(page, pageCount - 1);
  const paginated = filtered.slice(safePage * PAGE_SIZE, safePage * PAGE_SIZE + PAGE_SIZE);

  return {
    query,
    setQuery: (v) => { setQuery(v); setPage(0); },
    page: safePage,
    setPage,
    pageCount,
    filtered,
    paginated,
    totalCount: items.length,
  };
}

export function SearchBar({ value, onChange, placeholder = 'Rechercher…' }) {
  return (
    <input
      type="text"
      value={value}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      className="w-full mb-4 px-4 py-2.5 rounded-xl bg-livra-surfaceElevated border border-livra-divider text-livra-textPrimary placeholder:text-livra-textSecondary outline-none focus:border-livra-gold transition-colors text-sm"
    />
  );
}

export function PaginationBar({ page, pageCount, setPage, totalCount, shownCount }) {
  if (totalCount === 0) return null;
  return (
    <div className="flex items-center justify-between mt-4 text-sm">
      <span className="text-livra-textSecondary">{shownCount} / {totalCount}</span>
      <div className="flex items-center gap-2">
        <button
          onClick={() => setPage(Math.max(0, page - 1))}
          disabled={page === 0}
          className="px-3 py-1.5 rounded-lg bg-livra-surfaceElevated text-livra-textPrimary disabled:opacity-40 disabled:cursor-not-allowed"
        >
          ← Précédent
        </button>
        <span className="text-livra-textSecondary px-2">Page {page + 1} / {pageCount}</span>
        <button
          onClick={() => setPage(Math.min(pageCount - 1, page + 1))}
          disabled={page >= pageCount - 1}
          className="px-3 py-1.5 rounded-lg bg-livra-surfaceElevated text-livra-textPrimary disabled:opacity-40 disabled:cursor-not-allowed"
        >
          Suivant →
        </button>
      </div>
    </div>
  );
}

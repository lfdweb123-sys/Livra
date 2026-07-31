import { auth } from './firebaseClient';

export async function apiFetch(path, options = {}) {
  const token = await auth.currentUser?.getIdToken();
  const res = await fetch(path, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(options.headers || {}),
    },
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || `http_${res.status}`);
  }
  return res.json();
}

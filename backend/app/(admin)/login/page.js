'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../../../lib/firebaseClient';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const router = useRouter();

  async function handleSubmit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const cred = await signInWithEmailAndPassword(auth, email, password);
      const snap = await getDoc(doc(db, 'users', cred.user.uid));
      if (!snap.exists() || snap.data().role !== 'admin') {
        setError('Accès réservé aux administrateurs.');
        await auth.signOut();
        return;
      }
      router.replace('/dashboard');
    } catch (e) {
      setError('Identifiants invalides.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      <form onSubmit={handleSubmit} className="w-80 bg-neutral-900 p-8 rounded-2xl border border-neutral-800">
        <div className="text-2xl font-bold mb-6" style={{ color: 'var(--livra-gold)' }}>Livra Admin</div>
        <input
          className="w-full mb-3 px-3 py-2 rounded-lg bg-neutral-800 border border-neutral-700 outline-none"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <input
          className="w-full mb-4 px-3 py-2 rounded-lg bg-neutral-800 border border-neutral-700 outline-none"
          placeholder="Mot de passe"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        {error && <div className="text-red-400 text-sm mb-3">{error}</div>}
        <button
          type="submit"
          disabled={loading}
          className="w-full py-2 rounded-lg font-semibold text-black"
          style={{ backgroundColor: 'var(--livra-gold)' }}
        >
          {loading ? '...' : 'Se connecter'}
        </button>
      </form>
    </div>
  );
}

'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import Image from 'next/image';
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
    <div className="min-h-screen flex items-center justify-center bg-livra-bg px-6">
      <form onSubmit={handleSubmit} className="w-full max-w-sm bg-livra-surface p-8 rounded-2xl border border-livra-divider">
        <div className="flex items-center gap-2.5 mb-8">
          <Image src="/livra_icon_full.png" alt="Livra" width={40} height={40} />
          <span className="text-xl font-semibold">Admin</span>
        </div>
        <label className="block text-xs text-livra-textSecondary mb-1.5">Email</label>
        <input
          className="w-full mb-4 px-3.5 py-2.5 rounded-lg bg-livra-surfaceElevated border border-livra-divider outline-none focus:border-livra-gold transition-colors text-sm"
          placeholder="admin@livra.app"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
        <label className="block text-xs text-livra-textSecondary mb-1.5">Mot de passe</label>
        <input
          className="w-full mb-5 px-3.5 py-2.5 rounded-lg bg-livra-surfaceElevated border border-livra-divider outline-none focus:border-livra-gold transition-colors text-sm"
          placeholder="••••••••"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
        />
        {error && <div className="text-livra-danger text-sm mb-4">{error}</div>}
        <button
          type="submit"
          disabled={loading}
          className="w-full py-2.5 rounded-lg font-semibold text-livra-bg bg-livra-gold hover:bg-livra-goldSoft transition-colors disabled:opacity-60"
        >
          {loading ? 'Connexion…' : 'Se connecter'}
        </button>
      </form>
    </div>
  );
}

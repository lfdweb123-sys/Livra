'use client';
import { useEffect, useRef, useState } from 'react';
import { apiFetch } from '../../../lib/apiClient';
import { uploadFileToR2 } from '../../../lib/apiUpload';

export default function ContentPage() {
  const [config, setConfig] = useState(null);
  const [uploading, setUploading] = useState(false);
  const bannerInputRef = useRef(null);
  const onboardingInputRef = useRef(null);
  const [onboardingSlotIndex, setOnboardingSlotIndex] = useState(null);

  async function load() {
    const data = await apiFetch('/api/app-content');
    setConfig(data);
  }
  useEffect(() => { load(); }, []);

  async function save(patch) {
    await apiFetch('/api/admin/app-content', { method: 'PATCH', body: JSON.stringify(patch) });
    load();
  }

  async function addBanner(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      const url = await uploadFileToR2(file, 'app-content/banners');
      await save({ banners: [...(config.banners || []), url] });
    } finally {
      setUploading(false);
      e.target.value = '';
    }
  }

  async function removeBanner(url) {
    await save({ banners: config.banners.filter((b) => b !== url) });
  }

  function pickOnboardingSlot(i) {
    setOnboardingSlotIndex(i);
    onboardingInputRef.current?.click();
  }

  async function setOnboardingSlide(e) {
    const file = e.target.files?.[0];
    if (!file || onboardingSlotIndex === null) return;
    setUploading(true);
    try {
      const url = await uploadFileToR2(file, 'app-content/onboarding');
      const slides = [...(config.onboardingSlides || [])];
      while (slides.length < 4) slides.push(null);
      slides[onboardingSlotIndex] = url;
      await save({ onboardingSlides: slides });
    } finally {
      setUploading(false);
      e.target.value = '';
      setOnboardingSlotIndex(null);
    }
  }

  if (!config) return <div className="text-neutral-500">Chargement…</div>;

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">Visuels de l'application</h1>
      <p className="text-neutral-500 text-sm mb-6">Bannières de l'accueil et images des slides d'onboarding, gérées ici — aucune mise à jour d'app nécessaire.</p>

      <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-5 mb-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <div className="font-semibold">Carrousel bannières (accueil)</div>
            <div className="text-neutral-500 text-xs">Défile automatiquement toutes les 4s sur l'accueil client.</div>
          </div>
          <label className="flex items-center gap-2 text-sm cursor-pointer">
            <input type="checkbox" checked={config.bannersEnabled} onChange={(e) => save({ bannersEnabled: e.target.checked })} />
            Activé
          </label>
        </div>
        <div className="flex flex-wrap gap-3 mb-3">
          {(config.banners || []).map((url) => (
            <div key={url} className="relative">
              <img src={url} alt="" className="w-40 h-20 object-cover rounded-lg border border-neutral-800" />
              <button onClick={() => removeBanner(url)} className="absolute -top-2 -right-2 bg-red-600 rounded-full w-6 h-6 text-xs">✕</button>
            </div>
          ))}
        </div>
        <input ref={bannerInputRef} type="file" accept="image/*" className="hidden" onChange={addBanner} />
        <button onClick={() => bannerInputRef.current?.click()} disabled={uploading} className="px-3 py-2 rounded-lg bg-neutral-800 text-sm">
          {uploading ? 'Envoi…' : '+ Ajouter une bannière'}
        </button>
      </div>

      <div className="bg-neutral-900 border border-neutral-800 rounded-xl p-5">
        <div className="flex items-center justify-between mb-4">
          <div>
            <div className="font-semibold">Slides d'onboarding (4 écrans au premier lancement)</div>
            <div className="text-neutral-500 text-xs">Laisse une image vide pour garder l'illustration par défaut de l'app.</div>
          </div>
          <label className="flex items-center gap-2 text-sm cursor-pointer">
            <input type="checkbox" checked={config.onboardingEnabled} onChange={(e) => save({ onboardingEnabled: e.target.checked })} />
            Activé
          </label>
        </div>
        <div className="flex flex-wrap gap-3">
          {[0, 1, 2, 3].map((i) => {
            const url = config.onboardingSlides?.[i];
            return (
              <div key={i} className="w-32">
                <div
                  onClick={() => pickOnboardingSlot(i)}
                  className="w-32 h-32 rounded-lg border border-neutral-800 bg-neutral-800 flex items-center justify-center cursor-pointer overflow-hidden"
                >
                  {url ? <img src={url} alt="" className="w-full h-full object-cover" /> : <span className="text-neutral-500 text-xs">Slide {i + 1}</span>}
                </div>
              </div>
            );
          })}
        </div>
        <input ref={onboardingInputRef} type="file" accept="image/*" className="hidden" onChange={setOnboardingSlide} />
        {uploading && <div className="text-neutral-500 text-xs mt-2">Envoi en cours…</div>}
      </div>
    </div>
  );
}

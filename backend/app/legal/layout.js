export default function LegalLayout({ children }) {
  return (
    <div className="min-h-screen bg-neutral-950">
      <header className="border-b border-neutral-800 px-6 py-4">
        <span className="text-xl font-bold text-amber-500">Livra</span>
      </header>
      <main className="max-w-3xl mx-auto px-6 py-10 text-neutral-200 leading-relaxed [&_h1]:text-3xl [&_h1]:font-bold [&_h1]:text-amber-500 [&_h1]:mb-6 [&_h2]:text-xl [&_h2]:font-bold [&_h2]:text-amber-500 [&_h2]:mt-8 [&_h2]:mb-3 [&_p]:mb-4 [&_ul]:list-disc [&_ul]:pl-6 [&_ul]:mb-4 [&_li]:mb-1.5 [&_strong]:text-neutral-50">
        {children}
      </main>
      <footer className="border-t border-neutral-800 px-6 py-6 mt-10 text-center text-neutral-500 text-sm">
        <a href="/legal/cgu" className="hover:text-amber-500 mx-2">Conditions d'utilisation</a>
        <a href="/legal/confidentialite" className="hover:text-amber-500 mx-2">Confidentialité</a>
        <a href="/legal/vente" className="hover:text-amber-500 mx-2">Conditions de vente</a>
        <a href="/legal/mentions" className="hover:text-amber-500 mx-2">Mentions légales</a>
      </footer>
    </div>
  );
}

import SiteHeader from '../../components/SiteHeader';
import SiteFooter from '../../components/SiteFooter';

export default function LegalLayout({ children }) {
  return (
    <div className="min-h-screen flex flex-col">
      <SiteHeader />
      <main className="flex-1 max-w-3xl mx-auto px-6 py-14 leading-relaxed [&_h1]:text-3xl [&_h1]:font-bold [&_h1]:text-livra-gold [&_h1]:mb-6 [&_h2]:text-xl [&_h2]:font-bold [&_h2]:text-livra-gold [&_h2]:mt-8 [&_h2]:mb-3 [&_p]:mb-4 [&_p]:text-livra-textSecondary [&_ul]:list-disc [&_ul]:pl-6 [&_ul]:mb-4 [&_li]:mb-1.5 [&_li]:text-livra-textSecondary [&_strong]:text-livra-textPrimary">
        {children}
      </main>
      <SiteFooter />
    </div>
  );
}

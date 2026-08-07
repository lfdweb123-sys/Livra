import SiteHeader from '../components/SiteHeader';
import SiteFooter from '../components/SiteFooter';
import DownloadButtons from '../components/DownloadButtons';

const SERVICES = [
  { icon: '🍽️', title: 'Nourriture', desc: 'Commandez chez vos restaurants préférés, livré chaud en un tap.' },
  { icon: '📦', title: 'Colis', desc: "Faites livrer un colis n'importe où en ville, rapidement et en sécurité." },
  { icon: '🛵', title: 'Taxi-moto', desc: 'Un chauffeur à proximité pour vos trajets courts en ville.' },
  { icon: '🚗', title: 'Voiture', desc: 'Réservez une voiture pour vos trajets, avec suivi en temps réel.' },
  { icon: '🛍️', title: 'Boutiques', desc: "Vêtements, électronique, cosmétiques… toutes les boutiques en un endroit." },
];

const STEPS = [
  { n: '01', title: 'Choisissez', desc: "Un plat, un colis, une course ou un produit — parcourez ce qui est disponible près de vous." },
  { n: '02', title: 'Commandez', desc: 'Payez par Mobile Money, carte bancaire, portefeuille Livra ou en espèces à la livraison.' },
  { n: '03', title: 'Suivez', desc: "Suivez votre livreur ou chauffeur en temps réel jusqu'à votre porte." },
];

export default function LandingPage() {
  return (
    <div>
      <SiteHeader />

      <section className="relative overflow-hidden">
        <div
          className="pointer-events-none absolute -top-40 right-0 h-[32rem] w-[32rem] rounded-full opacity-20 blur-3xl"
          style={{ background: 'radial-gradient(circle, #F2660B, transparent 70%)' }}
        />
        <div className="max-w-6xl mx-auto px-6 pt-20 pb-24 grid md:grid-cols-2 gap-14 items-center relative">
          <div>
            <span className="inline-block rounded-full border border-livra-gold/40 bg-livra-gold/10 px-4 py-1.5 text-xs font-medium text-livra-goldSoft mb-6">
              Livraison, courses &amp; boutiques
            </span>
            <h1 className="text-4xl sm:text-5xl font-bold leading-[1.1] tracking-tight mb-6">
              Tout ce dont vous avez besoin,{' '}
              <span className="text-livra-gold">livré en un tap</span>
            </h1>
            <p className="text-livra-textSecondary text-lg leading-relaxed mb-8 max-w-md">
              Repas, colis, courses en taxi-moto ou voiture, et boutiques en ligne — Livra connecte
              clients, vendeurs et livreurs partout en Afrique de l&apos;Ouest.
            </p>
            <DownloadButtons />
          </div>

          <div className="flex justify-center md:justify-end">
            <div className="w-[280px] rounded-[2.5rem] border-4 border-livra-surfaceElevated bg-livra-surface p-3 shadow-2xl shadow-black/40">
              <div className="rounded-[1.8rem] bg-livra-bg overflow-hidden">
                <div className="h-6 flex items-center justify-center">
                  <div className="h-1.5 w-16 rounded-full bg-livra-surfaceElevated" />
                </div>
                <div className="px-4 pb-6 pt-2">
                  <div className="flex items-center justify-between mb-5">
                    <div className="h-3 w-20 rounded-full bg-livra-surfaceElevated" />
                    <div className="h-6 w-6 rounded-full bg-livra-gold" />
                  </div>
                  <div className="grid grid-cols-4 gap-2 mb-5">
                    {SERVICES.slice(0, 4).map((s) => (
                      <div key={s.title} className="flex flex-col items-center gap-1.5 rounded-xl bg-livra-surface py-3">
                        <span className="text-lg">{s.icon}</span>
                        <div className="h-1 w-6 rounded-full bg-livra-surfaceElevated" />
                      </div>
                    ))}
                  </div>
                  {[1, 2, 3].map((i) => (
                    <div key={i} className="flex items-center gap-3 rounded-xl bg-livra-surface p-3 mb-2.5">
                      <div className="h-10 w-10 shrink-0 rounded-lg bg-livra-surfaceElevated" />
                      <div className="flex-1 space-y-1.5">
                        <div className="h-2 w-24 rounded-full bg-livra-surfaceElevated" />
                        <div className="h-2 w-16 rounded-full bg-livra-surfaceElevated/60" />
                      </div>
                      <div className="h-2 w-8 rounded-full bg-livra-gold/60" />
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="services" className="border-t border-livra-divider/60 bg-livra-surface/40">
        <div className="max-w-6xl mx-auto px-6 py-20">
          <h2 className="text-2xl sm:text-3xl font-bold mb-3">Tout Livra, en un seul endroit</h2>
          <p className="text-livra-textSecondary mb-12 max-w-xl">
            Une seule application pour se faire livrer, se déplacer, et acheter — sans restriction de
            catégorie pour les boutiques.
          </p>
          <div className="grid sm:grid-cols-2 md:grid-cols-3 gap-5">
            {SERVICES.map((s) => (
              <div
                key={s.title}
                className="rounded-2xl border border-livra-divider bg-livra-surface p-6 hover:border-livra-gold/50 transition-colors"
              >
                <div className="text-3xl mb-4">{s.icon}</div>
                <h3 className="font-semibold text-lg mb-2">{s.title}</h3>
                <p className="text-sm text-livra-textSecondary leading-relaxed">{s.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section id="comment-ca-marche" className="border-t border-livra-divider/60">
        <div className="max-w-6xl mx-auto px-6 py-20">
          <h2 className="text-2xl sm:text-3xl font-bold mb-12">Comment ça marche</h2>
          <div className="grid md:grid-cols-3 gap-10">
            {STEPS.map((s) => (
              <div key={s.n}>
                <div className="text-livra-gold text-sm font-bold mb-3">{s.n}</div>
                <h3 className="font-semibold text-lg mb-2">{s.title}</h3>
                <p className="text-sm text-livra-textSecondary leading-relaxed">{s.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section id="partenaires" className="border-t border-livra-divider/60 bg-livra-surface/40">
        <div className="max-w-6xl mx-auto px-6 py-20 grid md:grid-cols-2 gap-12 items-center">
          <div>
            <h2 className="text-2xl sm:text-3xl font-bold mb-4">Devenez partenaire Livra</h2>
            <p className="text-livra-textSecondary leading-relaxed mb-6">
              Restaurant, boutique, livreur, coursier, chauffeur ou taxi-moto — postulez directement
              depuis l&apos;application, vérification d&apos;identité en quelques minutes, et commencez à
              gagner.
            </p>
            <DownloadButtons />
          </div>
          <div className="grid grid-cols-2 gap-4">
            {[
              { label: 'Restaurant / Boutique', icon: '🏪' },
              { label: 'Livreur / Coursier', icon: '📦' },
              { label: 'Taxi-moto', icon: '🛵' },
              { label: 'Chauffeur voiture', icon: '🚗' },
            ].map((p) => (
              <div key={p.label} className="rounded-2xl border border-livra-divider bg-livra-surface p-5">
                <div className="text-2xl mb-3">{p.icon}</div>
                <div className="text-sm font-medium">{p.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="border-t border-livra-divider/60">
        <div className="max-w-6xl mx-auto px-6 py-24 text-center">
          <h2 className="text-3xl sm:text-4xl font-bold mb-4">Prêt à essayer Livra ?</h2>
          <p className="text-livra-textSecondary mb-10 max-w-md mx-auto">
            Téléchargez l&apos;application et commandez en quelques secondes.
          </p>
          <div className="flex justify-center">
            <DownloadButtons />
          </div>
        </div>
      </section>

      <SiteFooter />
    </div>
  );
}

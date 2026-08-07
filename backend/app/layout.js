import './globals.css';

export const metadata = {
  title: 'Livra — Livraison, courses et boutiques en un tap',
  description:
    "Livra connecte clients, restaurants, boutiques et livreurs partout en Afrique de l'Ouest. Commandez, vendez, livrez.",
};

export default function RootLayout({ children }) {
  return (
    <html lang="fr">
      <body className="bg-livra-bg text-livra-textPrimary font-sans antialiased">{children}</body>
    </html>
  );
}

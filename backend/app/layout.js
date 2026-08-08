import './globals.css';

export const metadata = {
  title: 'Livra — Livraison, courses et boutiques en un tap',
  description:
    "Livra connecte clients, restaurants, boutiques et livreurs partout en Afrique de l'Ouest. Commandez, vendez, livrez.",
  icons: {
    icon: [
      { url: '/favicon-16x16.png', sizes: '16x16', type: 'image/png' },
      { url: '/favicon-32x32.png', sizes: '32x32', type: 'image/png' },
      { url: '/favicon.ico' },
    ],
    apple: '/apple-touch-icon.png',
  },
};

export default function RootLayout({ children }) {
  return (
    <html lang="fr">
      <body className="bg-livra-bg text-livra-textPrimary font-sans antialiased">{children}</body>
    </html>
  );
}

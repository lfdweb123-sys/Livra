import './globals.css';

export const metadata = { title: 'Livra Admin', description: 'Dashboard admin Livra' };

export default function RootLayout({ children }) {
  return (
    <html lang="fr">
      <body className="bg-neutral-950 text-neutral-100">{children}</body>
    </html>
  );
}

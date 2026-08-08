// URL publique du site web de l'application (panneau + pages publiques:
// CGU, confidentialité, mentions légales...). Définir NEXT_PUBLIC_SITE_URL
// sur Vercel — cette variable doit être la même partout dans le projet
// (backend ET mobile) pour ne jamais désynchroniser un lien en dur.
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || 'https://livras.vercel.app';

// Liens de téléchargement de l'application — tant que Livra n'est pas
// encore publiée sur le Play Store / App Store (ou qu'un APK n'est pas
// encore hébergé quelque part), ces variables restent vides et les
// boutons de la landing page affichent "Bientôt disponible" au lieu d'un
// lien mort. À définir sur Vercel dès que les liens réels existent :
// NEXT_PUBLIC_PLAY_STORE_URL, NEXT_PUBLIC_APP_STORE_URL, NEXT_PUBLIC_APK_URL.
export const PLAY_STORE_URL = process.env.NEXT_PUBLIC_PLAY_STORE_URL || null;
export const APP_STORE_URL = process.env.NEXT_PUBLIC_APP_STORE_URL || null;
export const APK_DOWNLOAD_URL = process.env.NEXT_PUBLIC_APK_URL || null;

// Email admin qui reçoit les alertes importantes (nouvelle candidature
// vendeur/livreur, nouveau litige...) — à définir sur Vercel via
// ADMIN_NOTIFICATION_EMAIL. Si absent, ces alertes sont simplement
// ignorées (aucune erreur), rien ne casse tant que ce n'est pas configuré.
export const ADMIN_NOTIFICATION_EMAIL = process.env.ADMIN_NOTIFICATION_EMAIL || null;

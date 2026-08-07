// URL publique du site web de l'application (panneau + pages publiques:
// CGU, confidentialité, mentions légales...). Définir NEXT_PUBLIC_SITE_URL
// sur Vercel — cette variable doit être la même partout dans le projet
// (backend ET mobile) pour ne jamais désynchroniser un lien en dur.
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || 'https://livras.vercel.app';

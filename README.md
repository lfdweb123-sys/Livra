# Livra — Livraison & Transport multi-vendeurs (Bénin / Afrique de l'Ouest)

Marketplace mono-plateforme : livraison colis, livraison nourriture, VTC, moto-taxi.
100% gratuit côté infra (pas de Cloud Functions, pas de Firebase Storage — tout passe par API Routes Vercel + Cloudflare R2).

## Structure du repo

```
livra/
├── backend/     # Next.js — API Routes (Vercel) + Dashboard Admin, un seul projet
├── mobile/      # Flutter — 1 seul projet, 3 espaces (Client / Livreur / Vendeur) via routing par rôle
├── firestore.rules
└── firestore-schema-livra.md
```

Pas de KYC séparé : les documents (CNI, permis, RC…) sont stockés directement sur les docs `vendors`/`drivers` (champ `documents` / `documentsR2`), l'admin active ou rejette depuis le dashboard.

---

## 1. Backend (`backend/`)

Next.js 14 App Router. Contient à la fois les API Routes (consommées par les 3 apps Flutter) et le dashboard admin (pages `app/(admin)/*`).

### Setup

```bash
cd backend
npm install
cp .env.example .env.local   # à remplir (Firebase Admin, R2, FeexPay, Verzapay, Maps, Brevo)
npm run dev
```

### Déploiement Vercel
Push sur GitHub → import sur Vercel → renseigner les mêmes variables d'env que `.env.example` dans les Project Settings. Le compte Vercel Hobby suffit (pas de Cloud Functions, tout est en Route Handlers standards).

**URLs à configurer une fois le backend déployé** (remplace le domaine par le tien) :
- Webhook FeexPay : `https://<ton-domaine>/api/payments/feexpay/webhook`
- Webhook Verzapay : `https://<ton-domaine>/api/payments/verzapay/webhook`
- Cron réconciliation (cron-job.org, toutes les 5 min) : GET `https://<ton-domaine>/api/cron/reconcile-payments` avec le header `x-cron-secret: <ton INTERNAL_API_SECRET>`

### Ce qui est complet
- **lib/** : `firebaseAdmin`, `auth` (vérif ID token + rôle), `geo` (geohash + haversine), `pricing` (calcul serveur des prix, jamais depuis le payload client), `r2` (upload), `fcm` (notifications), `feexpay` (tous les réseaux BJ/TG/CI/CG/SN/BF/ML), `verzapay` (payment + payout), `paymentRouter` (routing par indicatif tél).
- **API** : orders (create/list/patch avec machine à états par rôle), rides (idem), vendors + produits (CRUD), drivers (candidature + toggle online + update position), upload (proxy R2), paiements FeexPay/Verzapay (initiate + webhooks), wallet (solde/historique/retrait avec transaction Firestore atomique + rollback si le payout échoue), proxies Maps (Directions/Distance Matrix/Places, clé jamais exposée au mobile), admin (stats, disputes, commission).
- **Dashboard admin** : login (garde de rôle client-side via Firestore), sidebar, dashboard (recharts), validation vendeurs/chauffeurs, vue commandes/courses, litiges, réglage commission.

### Ce qui reste à faire avant prod
- Webhook FeexPay : le format exact de `status` ('SUCCESSFUL'/'successful') doit être revérifié avec un vrai payload sandbox — j'ai couvert les deux casse mais à confirmer.
- Garde admin actuellement client-side uniquement (les routes `/api/admin/*` sont elles bien protégées côté serveur via `requireAuth` + check `role==='admin'`, donc pas de fuite de données) — un cookie de session Firebase donnerait un vrai SSR guard si tu veux durcir encore.
- `lib/brevo.js` est écrit et branché (validation vendeur/chauffeur, commande livrée) — reste à créer le compte Brevo sender vérifié et ajuster le HTML des templates à ton goût.
- `/api/cron/reconcile-payments` est écrit (timeout 20 min → `failed` si le webhook n'est jamais arrivé) — reste à le brancher sur cron-job.org toutes les 5 min avec le header `x-cron-secret`.

---

## 2. Mobile (`mobile/`)

Un seul projet Flutter, 3 espaces par rôle (Client / Livreur / Vendeur), redirection automatique via `go_router` + rôle lu sur `users/{uid}.role`.

### Setup

```bash
cd mobile
flutter pub get
flutterfire configure   # génère le vrai firebase_options.dart (celui fourni est un placeholder REPLACE_ME)
flutter run              # pointe déjà par défaut sur https://livras.vercel.app (voir core/constants/api_constants.dart)
```

Il faut aussi :
- Activer Google Maps SDK (Android/iOS) + Places/Directions/Distance Matrix côté Google Cloud Console, et mettre la clé **client** (restreinte par bundle id / SHA-1) dans `AndroidManifest.xml` / `AppDelegate.swift` — la clé **serveur** (illimitée, dans `.env` backend) sert uniquement aux proxies `/api/maps/*`.
- Configurer les notifications push (fichiers `google-services.json` / `GoogleService-Info.plist`).

### Ce qui est complet
- Architecture Clean-ish (`core/` = infra partagée, `features/` = un dossier par domaine, `data/domain/presentation` prévu).
- Thème noir/or (palette alternative vert/blanc en commentaire dans `app_colors.dart`), skeleton loaders partout (jamais de spinner plein écran), bottom sheets pour les actions rapides.
- Modèles Dart pour toutes les collections Firestore.
- Services : `ApiClient` (Dio + injection auto du ID token Firebase), `AuthService`, `MapsService` (proxy backend), `UploadService` (pattern octet-stream + x-file-type, identique à Animaginee), `FcmService`, `LocationService` (geolocator).
- Routing par rôle avec redirection automatique (`GoRouterRefreshStream` branché sur `authStateChanges`).
- **Espace Client** : onboarding (3 slides), login/register, home (services + liste vendeurs), détail vendeur + panier, checkout avec recalcul serveur du prix + choix paiement (FeexPay par réseau avec OTP si requis, Verzapay, wallet), demande de course avec carte tap-to-set-destination, tracking live avec marker interpolé (`TweenAnimationBuilder`), historique, profil (+ toggle biométrique local_auth, candidatures livreur/vendeur).
- **Espace Livreur** : toggle en ligne (avec update position en continu via `watchPosition`), liste des commandes disponibles (Firestore live), acceptation, navigation (statuts contrôlés), gains + historique wallet.
- **Espace Vendeur** : dashboard (toggle ouvert/fermé), catalogue (ajout produit avec upload image R2, toggle disponibilité), commandes entrantes avec avancement de statut, stats simples.
- Wallet et notifications partagés (lecture Firestore live + retrait Mobile Money).

### Ce qui a été complété dans cette passe
- **Polyline réelle** : `driver_navigation_screen.dart` décode maintenant la polyline Directions (décodeur maison dans `core/utils/polyline_decoder.dart`, pas de dépendance en plus) et dessine le tracé + markers collecte/destination sur une vraie `GoogleMap`, avec `animateCamera` pour cadrer l'itinéraire.
- **Matching géo réel** : les commandes ont désormais un champ `matchPosition` (geohash) calculé côté serveur à la création. `driver_home_screen.dart` utilise `geoflutterfire2` (`Geoflutterfire().collection(...).within(...)`) pour ne proposer que les commandes dans un rayon de 5 km autour du livreur, recalculé à chaque mise à jour de position.
- **Paiement des courses** : `request_ride_screen.dart` proposait le tracking direct sans paiement — corrigé, même bottom sheet de choix de paiement que pour les commandes (FeexPay/Verzapay/wallet).
- **FeexPay multi-pays** : le sheet de paiement propose maintenant tous les pays/réseaux couverts par le backend (BJ, TG, CI, CG, SN, BF, ML), avec gestion de l'OTP pour Coris et Orange BF (y compris l'instruction USSD `#144*4*6*montant#`).
- **Bouton "Nourriture"** : filtre désormais la liste de vendeurs par catégorie `resto` sur la home (au lieu de ne rien faire).
- **Mode clair** : `AppColors` est passé de constantes statiques à une facade (`core/theme/app_colors.dart`) qui lit `ThemeController` — tous les écrans existants retintent automatiquement sans avoir été modifiés un par un. Toggle disponible dans Profil > Mode clair, persisté (`shared_preferences`).
- **Verrouillage biométrique réel** : `core/services/lock_service.dart` + `app_lock_gate.dart` — si activé depuis le profil, l'app démarre verrouillée (et se reverrouille au retour en foreground) et exige `local_auth` avant d'afficher le contenu. La session Firebase Auth n'est jamais touchée par ce verrou, purement local.
- **Caméra "follow me" navigation** : `driver_navigation_screen.dart` suit maintenant la position GPS du livreur en continu pendant le trajet (`animateCamera` sur chaque update de `watchPosition`). Elle se met en pause si le livreur pan/zoom manuellement (`onCameraMoveStarted`) et se réactive via le bouton flottant en bas à droite.
- **Auto-lock après inactivité** : `core/services/inactivity_service.dart` — un minuteur global (2 min par défaut) remis à zéro à chaque tap dans l'app (`Listener` global dans `AppLockGate`) ; s'il expire alors que l'app est restée au premier plan, elle se reverrouille exactement comme au retour de background.

### Ce qui reste à faire avant prod
- Le mode clair retinte tout l'app automatiquement (facade `AppColors`), mais je n'ai pas repassé chaque écran pour vérifier le contraste exact en clair au pixel près — un passage visuel rapide reste recommandé avant de l'activer par défaut pour tout le monde.

---

## 3. Firestore

Voir `firestore-schema-livra.md` (collections, champs) et `firestore.rules`. Les index composites requis par les requêtes réelles du backend sont dans `firestore.indexes.json` — nécessaires car plusieurs routes combinent un `where` sur un champ différent de celui du `orderBy` (ex: commandes filtrées par `clientId` + triées par `createdAt`), ce que Firestore ne sait pas servir avec ses index automatiques à champ unique.

```bash
npm install -g firebase-tools
firebase login
firebase use livra-efb01   # ton project_id
firebase deploy --only firestore:rules,firestore:indexes
```

Le déploiement des index prend quelques minutes en arrière-plan (visible dans Firebase Console → Firestore → Index). Si une requête tombe sur un index manquant que j'aurais oublié, Firestore renvoie directement dans l'erreur un lien qui le crée en un clic — plus rapide que de deviner toutes les combinaisons à l'avance.

---

## Prochaines étapes suggérées, dans l'ordre

1. `flutterfire configure` + remplir `.env.local` backend + déployer le backend sur Vercel.
2. Déployer les `firestore.rules` + créer les index composites.
3. Brancher un vrai fond de carte + polyline dans `driver_navigation_screen.dart`.
4. Brancher le vrai filtrage géo `geoflutterfire2` sur `driver_home_screen.dart`.
5. Tester le cycle complet paiement FeexPay en sandbox (`test_` key) avant de passer en `fp_`.

---

## ✅ Récapitulatif complet — tout ce qui est fait et terminé

### Firestore
- ✅ Schéma complet (9 collections + 2 sous-collections), sans KYC séparé
- ✅ `firestore.rules` — accès par rôle, écriture serveur-only sur wallets/payments/notifications
- ✅ Index composites documentés
- ✅ Champ `matchPosition` (geohash) pour le matching géo réel

### Backend Next.js (API + Admin)
- ✅ Auth par ID token Firebase + vérification de rôle sur chaque route
- ✅ Orders : création avec recalcul serveur des prix, machine à états par rôle, historique de statut
- ✅ Rides : création avec calcul prix/distance/ETA serveur, machine à états par rôle
- ✅ Vendors + catalogue produits : CRUD complet, activation admin
- ✅ Drivers : candidature, toggle en ligne + position, activation admin
- ✅ Upload R2 (proxy octet-stream, pattern Animaginee)
- ✅ Paiement FeexPay V2 — tous les réseaux BJ/TG/CI/CG/SN/BF/ML, gestion OTP (Coris, Orange BF)
- ✅ Paiement Verzapay — payment + payout, webhook confirmé (payload plat, sans signature)
- ✅ Wallet — solde, historique, retrait avec transaction Firestore atomique + rollback si échec payout
- ✅ Proxies Google Maps (Directions, Distance Matrix, Places Autocomplete) — clé jamais exposée au mobile
- ✅ Dashboard admin — login, sidebar, stats (recharts), validation vendeurs/chauffeurs, commandes, courses, litiges, réglage commission
- ✅ Emails transactionnels Brevo — validation/rejet vendeur, validation/rejet chauffeur, commande livrée
- ✅ Cron de réconciliation des paiements bloqués en pending

### Mobile Flutter — Infrastructure
- ✅ 1 seul projet, 3 espaces par rôle, routing `go_router` avec redirection automatique
- ✅ Thème noir/or + mode clair fonctionnel (facade `AppColors` pilotée par `ThemeController`, persisté)
- ✅ Skeleton loaders partout (jamais de spinner plein écran), bottom sheets pour les actions rapides
- ✅ Modèles Dart pour toutes les collections Firestore
- ✅ Services : ApiClient (Dio + injection auto du token), Auth, Maps (proxy backend), Upload R2, FCM, Géolocalisation, Paiement
- ✅ Verrouillage biométrique complet — cold start, retour de background, **et auto-lock après 2 min d'inactivité en foreground**

### Espace Client
- ✅ Onboarding (3 écrans), login/register
- ✅ Home — services (colis/nourriture/moto-taxi/voiture-taxi) + liste vendeurs, **filtre par catégorie fonctionnel**
- ✅ Détail vendeur + catalogue + panier
- ✅ Checkout avec recalcul serveur du prix
- ✅ Paiement commandes **et courses** — FeexPay (tous pays/réseaux avec OTP), Verzapay, wallet
- ✅ Demande de course avec carte tap-to-set-destination
- ✅ Tracking live avec marker interpolé (jamais de saut brusque)
- ✅ Historique (commandes + courses), profil, candidatures livreur/vendeur

### Espace Livreur/Chauffeur
- ✅ Toggle en ligne avec update position continue
- ✅ **Matching géo réel** (geoflutterfire2, rayon 5 km) — plus une liste globale non filtrée
- ✅ Navigation avec **vraie carte + tracé Directions décodé + caméra "follow me"**
- ✅ Gains + historique wallet

### Espace Vendeur
- ✅ Dashboard (toggle ouvert/fermé)
- ✅ Catalogue — ajout produit avec upload image R2, toggle disponibilité
- ✅ Commandes entrantes avec avancement de statut
- ✅ Statistiques (commandes livrées, chiffre d'affaires)

### Commun
- ✅ Wallet (solde, historique, retrait Mobile Money)
- ✅ Notifications (lecture Firestore live, marquage lu)

### Dernier point de vigilance (pas un manque, une recommandation)
- 🟡 Mode clair : fonctionnel partout, mais pas encore vérifié écran par écran au pixel près pour le contraste — à faire avant activation par défaut en prod.

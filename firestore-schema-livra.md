# Schéma Firestore — Livra

Étape 2 du build (après structure Flutter + pubspec). Toute écriture "sensible" (paiements, wallets, notifications, validation KYC) passe par les API Routes Vercel via Firebase Admin SDK — les security rules ci-dessous bloquent donc ces écritures côté client, sans gêner le backend (l'Admin SDK ignore les rules).

---

## Collections racine

### `users/{uid}`
| Champ | Type | Note |
|---|---|---|
| uid | string | = id du doc |
| role | string | `client`\|`driver`\|`vendor`\|`admin` |
| phone | string | E.164, ex `+22996000000` |
| name | string | |
| email | string | |
| fcmToken | string\|null | mis à jour à chaque login/refresh |
| photoUrl | string\|null | URL R2 |
| isActive | boolean | false = compte banni |
| createdAt / updatedAt | timestamp | |

### `vendors/{vendorId}`
| Champ | Type | Note |
|---|---|---|
| ownerId | string | ref `users` |
| businessName | string | |
| category | string | `resto`\|`shop` |
| status | string | `pending`\|`active`\|`suspended`\|`rejected` |
| commission | number | % prélevé par transaction |
| position | map | `{ geohash: string, geopoint: GeoPoint }` — format **geoflutterfire2**, pas un GeoPoint brut |
| address | string | |
| coverImageUrl / logoUrl | string | R2 |
| documents | map | `{rcOrIfu?, photoLocal?, ...}` URLs R2, informatif — pas de flux de validation séparé |
| rejectionReason | string\|null | rempli par l'admin si `status=rejected` |
| rating / ratingCount | number | |
| isOpen | boolean | |
| createdAt / updatedAt | timestamp | |

**Sous-collection** `vendors/{vendorId}/products/{productId}` : `name, description, price, imageUrl, category, isAvailable, stock?, createdAt, updatedAt`

### `drivers/{driverId}`
| Champ | Type | Note |
|---|---|---|
| ownerId | string | ref `users` |
| vehicleType | string | `moto`\|`voiture`\|`coursier` |
| status | string | `pending`\|`active`\|`suspended`\|`rejected` |
| isOnline | boolean | toggle in-app |
| position | map | `{ geohash, geopoint }` (geoflutterfire2) |
| rating / ratingCount | number | |
| documentsR2 | map | `{ cni, permis, assurance, photoVehicule }` (URLs R2) |
| rejectionReason | string\|null | rempli par l'admin si `status=rejected` |
| createdAt / updatedAt | timestamp | |

### `orders/{orderId}`
| Champ | Type | Note |
|---|---|---|
| clientId / vendorId | string | |
| driverId | string\|null | null tant que non assigné |
| type | string | `colis`\|`nourriture` |
| items | array | `[{productId, name, price, qty}]` (vide si colis) |
| priceBreakdown | map | `{subtotal, deliveryFee, commission, total}` — **toujours recalculé serveur** |
| status | string | `pending→accepted→preparing→picked_up→delivering→delivered` ou `cancelled` |
| paymentMethod | string | `feexpay`\|`verzapay`\|`wallet` |
| paymentStatus | string | `pending`\|`paid`\|`failed`\|`refunded` |
| deliveryAddress | map | `{geohash, geopoint, label}` |
| pickupAddress | map\|null | requis si `type=colis` |
| matchPosition | map | `{geohash, geopoint}` — position de collecte (vendeur ou pickupAddress), calculée serveur à la création. C'est ce champ que `geoflutterfire2` interroge côté livreur pour proposer les commandes à proximité. |
| statusHistory | array | `[{status, at, by}]` pour l'admin |
| createdAt / updatedAt | timestamp | |

### `rides/{rideId}`
| Champ | Type | Note |
|---|---|---|
| clientId / driverId | string | |
| pickupLocation / dropoffLocation | map | `{geohash, geopoint}` |
| vehicleType | string | `moto`\|`voiture` |
| status | string | `pending→accepted→arriving→in_progress→completed` ou `cancelled` |
| price / distanceKm / etaMinutes | number | |
| paymentMethod / paymentStatus | string | idem orders |
| createdAt / updatedAt | timestamp | |

### `wallets/{userId}`
`balance` (number), `currency` (`XOF`), `updatedAt`. **Écriture client interdite** — uniquement via API Vercel (crédit/débit atomique avec `FieldValue.increment`).

**Sous-collection** `wallets/{userId}/transactions/{txId}` : `type: credit|debit, amount, reason, relatedOrderId?, relatedRideId?, createdAt`

### `payments/{paymentId}`
`orderId?, rideId?` (un seul des deux), `userId, provider: feexpay|verzapay, providerReference, status: pending|successful|failed, amount, currency, createdAt, updatedAt`. Écrit uniquement par les webhooks `/api/webhook/[provider]`.

### `notifications/{notificationId}`
`userId, title, body, type, relatedId, read: boolean, createdAt`. Créées uniquement côté serveur (Admin SDK + FCM), le client peut juste marquer `read=true`.

### `disputes/{disputeId}` (litiges — vue admin)
`orderId?, rideId?, raisedBy, against, reason, status: open|resolved|rejected, resolution?, createdAt, resolvedAt?`

### `commission_config/{configId}`
`category, defaultCommissionPercent, updatedAt` — lu par toutes les apps, modifiable par admin uniquement.

---

## Index composites à créer (Firestore Console ou `firestore.indexes.json`)

- `orders`: `(vendorId, status)`, `(driverId, status)`, `(clientId, createdAt DESC)`, `(status, createdAt DESC)`
- `rides`: `(driverId, status)`, `(clientId, createdAt DESC)`, `(status, createdAt DESC)`
- `payments`: `(userId, createdAt DESC)`, `(status, createdAt DESC)`
- `vendors`: `(status, createdAt DESC)`, `(category, status)`
- `drivers`: `(status, createdAt DESC)`, `(isOnline, vehicleType)`

Pagination stricte 20/page partout via curseur `startAfter(lastVisibleDoc)` (pattern déjà utilisé sur AdminUsersPage).

## Note geoflutterfire2

Pas de requête géo composée nativement par Firestore : `geoflutterfire2` fait des range queries sur `geohash` puis un filtre de distance exact côté client. Pour combiner "chauffeurs en ligne à proximité", il faut : requête géo (range sur geohash) → filtrer `isOnline==true` et `status=='active'` en mémoire côté Flutter (pas de `where` composé possible avec le range geohash dans la même requête).

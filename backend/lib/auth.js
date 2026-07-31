// Vérifie le ID token Firebase envoyé par les apps Flutter / dashboard admin
// Header attendu: Authorization: Bearer <idToken>
import { adminAuth, db } from './firebaseAdmin';

export async function requireAuth(req) {
  const header = req.headers.get('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return { error: 'missing_token', status: 401 };
  }
  try {
    const decoded = await adminAuth.verifyIdToken(token);
    const userSnap = await db.collection('users').doc(decoded.uid).get();
    if (!userSnap.exists) return { error: 'user_not_found', status: 404 };
    const userData = userSnap.data();
    if (userData.isActive === false) return { error: 'account_disabled', status: 403 };
    return { uid: decoded.uid, role: userData.role, user: userData };
  } catch (e) {
    return { error: 'invalid_token', status: 401 };
  }
}

export function requireRole(authResult, roles) {
  if (!authResult || authResult.error) return false;
  return roles.includes(authResult.role);
}

export function jsonError(message, status = 400) {
  return Response.json({ error: message }, { status });
}

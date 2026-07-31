// Proxy upload — pattern déjà validé (Animaginee) : le client envoie
// application/octet-stream + header x-file-type, on écrit dans R2 côté serveur.
import { requireAuth, jsonError } from '../../../lib/auth';
import { uploadToR2 } from '../../../lib/r2';

export const runtime = 'nodejs';

export async function POST(req) {
  const auth = await requireAuth(req);
  if (auth.error) return jsonError(auth.error, auth.status);

  const fileType = req.headers.get('x-file-type') || 'application/octet-stream';
  const folder = req.headers.get('x-folder') || 'misc'; // ex: kyc, avatars, products, covers
  const ext = fileType.split('/')[1] || 'bin';

  const arrayBuffer = await req.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);
  if (buffer.length > 8 * 1024 * 1024) return jsonError('file_too_large', 413);

  const key = `${folder}/${auth.uid}/${Date.now()}.${ext}`;
  const url = await uploadToR2(buffer, key, fileType);
  return Response.json({ url });
}

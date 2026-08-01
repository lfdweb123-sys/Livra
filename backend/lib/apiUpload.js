import { auth } from './firebaseClient';

// Upload depuis le dashboard admin (navigateur) — même route /api/upload
// que le mobile, format octet-stream + headers x-file-type/x-folder.
export async function uploadFileToR2(file, folder) {
  const token = await auth.currentUser?.getIdToken();
  const buffer = await file.arrayBuffer();
  const res = await fetch('/api/upload', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': file.type || 'application/octet-stream',
      'x-file-type': file.type || 'image/jpeg',
      'x-folder': folder,
    },
    body: buffer,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || `http_${res.status}`);
  }
  const data = await res.json();
  return data.url;
}

// Endpoint interne (appelé serveur à serveur, ex: cron, ou depuis une autre route)
import { jsonError } from '../../../lib/auth';
import { sendNotification } from '../../../lib/fcm';

export async function POST(req) {
  const secret = req.headers.get('x-internal-secret');
  if (secret !== process.env.INTERNAL_API_SECRET) return jsonError('forbidden', 403);

  const body = await req.json();
  const result = await sendNotification(body);
  return Response.json(result);
}

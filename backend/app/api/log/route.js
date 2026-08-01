// Endpoint de logs client -> visible dans Vercel (Deployments > Functions > Logs).
// Le mobile poste ici ses erreurs (auth, réseau...) pour qu'on puisse les
// diagnostiquer sans avoir accès physique au téléphone de l'utilisateur.
export async function POST(req) {
  try {
    const body = await req.json();
    // console.error apparaît dans les Function Logs Vercel en temps réel
    console.error('[CLIENT_LOG]', JSON.stringify({
      context: body.context || 'unknown',
      message: body.message || '',
      code: body.code || null,
      stack: body.stack || null,
      uid: body.uid || null,
      platform: body.platform || null,
      at: new Date().toISOString(),
    }));
  } catch (e) {
    console.error('[CLIENT_LOG] payload invalide', e.message);
  }
  // Toujours 200 : un souci de logging ne doit jamais bloquer l'app.
  return Response.json({ ok: true });
}

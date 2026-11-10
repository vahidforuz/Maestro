// The caller's JWT is passed to the existing checked invitation RPC. No Auth
// admin API or service-role credential is needed to create an invitation.
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('', { headers: cors });
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405, headers: cors });
  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) throw new Error('Sign in to send invitations.');
    const body = await request.json();
    const kind = body.kind === 'parent' ? 'parent' : body.kind === 'student' ? 'student' : null;
    const studentId = Number(body.studentId);
    const email = String(body.email ?? '').trim().toLowerCase();
    if (!kind || !Number.isSafeInteger(studentId) || studentId < 1 || !email) {
      throw new Error('Invalid invitation request.');
    }
    const base = Deno.env.get('MAESTRO_APP_URL');
    const apiKey = Deno.env.get('RESEND_API_KEY');
    const from = Deno.env.get('MAESTRO_FROM_EMAIL');
    if (!base || !apiKey || !from) throw new Error('Invitation email is not configured.');
    const url = new URL(base);
    const client = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authorization } } },
    );
    const { data, error } = await client.rpc(
      kind === 'student' ? 'maestro_invite_student' : 'maestro_invite_parent',
      kind === 'student'
        ? { p_student_app_id: studentId, p_email: email }
        : { p_student_app_id: studentId, p_email: email, p_name: String(body.name ?? '').trim(),
            p_relationship: String(body.relationship ?? 'Other') },
    );
    if (error) throw new Error(error.message);
    url.searchParams.set(kind === 'student' ? 'invite' : 'parent_invite', data.token);
    const result = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from, to: [email],
        subject: kind === 'student' ? 'Activate your Maestro student account' : 'Activate your Maestro parent account',
        text: `You have been invited to Maestro. Open this link to activate your account: ${url.toString()}\n\nThis invitation expires in 7 days.`,
      }),
    });
    if (!result.ok) throw new Error('The activation email could not be sent.');
    return new Response(JSON.stringify({ ...data, link: url.toString(), delivered: true }), { headers: cors });
  } catch (error) {
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Invitation failed.' }), {
      status: 400, headers: cors,
    });
  }
});

import { createServerClient } from '@supabase/ssr';
import { NextResponse } from 'next/server';
import { type NextRequest } from 'next/server';

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get('code');

  // Capture the intended post-auth destination forwarded via ?next=.
  // This preserves booking intent (e.g. /book-ride?route=<id>) through the Google OAuth flow.
  const nextParam = searchParams.get('next');

  // Always use NEXT_PUBLIC_SITE_URL as the base for redirects so that
  // server-side redirects go to the correct custom domain even when the
  // request arrives via a proxy or CDN that rewrites the Host header.
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || new URL(request.url).origin;

  if (!code) {
    console.error('[auth/callback] No code parameter received');
    return NextResponse.redirect(`${siteUrl}/sign-up-login-screen?error=auth_callback_failed`);
  }

  // Collect all cookies that Supabase wants to set during this request
  const cookiesToWrite: Array<{ name: string; value: string; options: Record<string, unknown> }> = [];

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(incoming) {
          // Collect cookies — we'll apply them to the final response below
          incoming.forEach(({ name, value, options }) => {
            cookiesToWrite.push({ name, value, options: options ?? {} });
          });
        },
      },
    }
  );

  // Step 1: Exchange the authorization code for a session
  const { data: sessionData, error: sessionError } = await supabase.auth.exchangeCodeForSession(code);

  if (sessionError || !sessionData?.user) {
    console.error('[auth/callback] exchangeCodeForSession error:', sessionError?.message);
    return NextResponse.redirect(`${siteUrl}/sign-up-login-screen?error=auth_callback_failed`);
  }

  const user = sessionData.user;
  console.log('[auth/callback] PROFILE_LOAD_START user=' + user.id);

  // Step 2: Check if profile exists — NEVER overwrite an existing profile.
  // Use maybeSingle() so that:
  //   - "no row found" → data=null, error=null  (new user)
  //   - "query error"  → data=null, error=<err> (fail closed — do NOT default to passenger)
  //   - "row found"    → data=<profile>, error=null
  const { data: existingProfile, error: profileQueryError } = await supabase
    .from('profiles')
    .select('id, role, status')
    .eq('id', user.id)
    .maybeSingle();

  if (profileQueryError) {
    // A real database/RLS error — do NOT silently default to passenger.
    // Fail closed: send user back to login so they can retry.
    console.error('[auth/callback] PROFILE_LOAD_ERROR', profileQueryError.message, 'code:', profileQueryError.code);
    return NextResponse.redirect(`${siteUrl}/sign-up-login-screen?error=profile_load_failed`);
  }

  let role: string;

  if (!existingProfile) {
    // Confirmed: no profile row exists (maybeSingle returned null with no error).
    // New user — create a default passenger profile.
    console.log('[auth/callback] PROFILE_LOAD_RESPONSE — no profile found, creating new passenger profile for user=' + user.id);
    const name =
      user.user_metadata?.full_name ||
      user.user_metadata?.name ||
      user.email?.split('@')[0] ||
      'Raahi User';

    const { error: insertError } = await supabase.from('profiles').insert({
      id: user.id,
      name,
      email: user.email ?? null,
      phone: user.phone ?? null,
      avatar_url: user.user_metadata?.avatar_url ?? null,
      role: 'passenger',
      status: 'active',
    });

    if (insertError) {
      console.error('[auth/callback] profile insert error:', insertError.message);
      // Insert failed — fail closed rather than routing with unknown role
      return NextResponse.redirect(`${siteUrl}/sign-up-login-screen?error=profile_create_failed`);
    }

    role = 'passenger';
  } else {
    // Existing profile — use the role from DB, never overwrite
    console.log('[auth/callback] PROFILE_LOAD_RESPONSE — existing profile found');
    console.log('[auth/callback] PROFILE_ROLE=' + existingProfile.role);
    role = existingProfile.role;
  }

  // Step 3: Determine destination based on role
  const roleMap: Record<string, string> = {
    passenger: '/available-routes',
    driver: '/driver-home',
    admin: '/admin-dashboard',
  };

  const destination = roleMap[role];
  console.log('[auth/callback] ROLE_REDIRECT_TARGET=' + (destination ?? 'unknown'));

  if (!destination) {
    console.error('[auth/callback] unknown role:', role, 'for user', user.id);
    return NextResponse.redirect(`${siteUrl}/sign-up-login-screen?error=unknown_role`);
  }

  // If a safe ?next= destination was provided and the user is a passenger,
  // redirect there instead of the default role landing page.
  // Only honour passenger-safe paths to prevent open-redirect abuse.
  let finalDestination = destination;
  if (nextParam && role === 'passenger') {
    const isRelative = nextParam.startsWith('/') && !nextParam.startsWith('//');
    const isSafe = isRelative &&
      !nextParam.startsWith('/admin') &&
      !nextParam.startsWith('/driver-home');
    if (isSafe) {
      finalDestination = nextParam;
    }
  }

  // Step 4: Build the final redirect and apply all collected session cookies
  const response = NextResponse.redirect(`${siteUrl}${finalDestination}`);

  cookiesToWrite.forEach(({ name, value, options }) => {
    response.cookies.set(name, value, {
      ...(options as any),
      sameSite: 'lax',
      secure: true,
      path: '/',
    });
  });

  return response;
}

import { createServerClient } from '@supabase/ssr';
import { NextResponse } from 'next/server';
import { type NextRequest } from 'next/server';

// This route is used by the OTP flow (verifyOtp → router.push('/auth/role-redirect'))
// Google OAuth now goes directly through /auth/callback without hitting this route.
export async function GET(request: NextRequest) {
  // Always use NEXT_PUBLIC_SITE_URL as the base for redirects
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || new URL(request.url).origin;

  // Capture the intended post-auth destination forwarded by AuthScreen (?next=).
  // This preserves booking intent (e.g. /book-ride?route=<id>) through the OTP flow.
  const { searchParams } = new URL(request.url);
  const nextParam = searchParams.get('next');

  // Collect cookies to write onto the final redirect response
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
          incoming.forEach(({ name, value, options }) => {
            cookiesToWrite.push({ name, value, options: options ?? {} });
          });
        },
      },
    }
  );

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  const applyAndRedirect = (path: string) => {
    const redirectResponse = NextResponse.redirect(`${siteUrl}${path}`);
    cookiesToWrite.forEach(({ name, value, options }) => {
      redirectResponse.cookies.set(name, value, {
        ...(options as any),
        sameSite: 'lax',
        secure: true,
        path: '/',
      });
    });
    return redirectResponse;
  };

  if (userError || !user) {
    console.error('[role-redirect] getUser failed:', userError?.message);
    return applyAndRedirect('/sign-up-login-screen');
  }

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('role, status')
    .eq('id', user.id)
    .single();

  if (profileError || !profile) {
    console.log('[role-redirect] no profile found for user', user.id, '— creating passenger profile');
    const name =
      user.user_metadata?.full_name ||
      user.user_metadata?.name ||
      user.phone ||
      user.email?.split('@')[0] ||
      'Raahi User';

    await supabase.from('profiles').insert({
      id: user.id,
      name,
      email: user.email ?? null,
      phone: user.phone ?? null,
      avatar_url: user.user_metadata?.avatar_url ?? null,
      role: 'passenger',
      status: 'active',
    });

    return applyAndRedirect('/available-routes');
  }

  const roleMap: Record<string, string> = {
    passenger: '/available-routes',
    driver: '/driver-home',
    admin: '/admin-dashboard',
  };

  const destination = roleMap[profile.role];

  if (!destination) {
    console.error('[role-redirect] unknown role:', profile.role, 'for user', user.id);
    return applyAndRedirect('/sign-up-login-screen?error=unknown_role');
  }

  // If a safe ?next= destination was provided and the user is a passenger,
  // redirect there instead of the default role landing page.
  // Only honour passenger-safe paths to prevent open-redirect abuse.
  if (nextParam && profile.role === 'passenger') {
    // Validate: must be a relative path starting with / and not pointing to admin/driver areas.
    const isRelative = nextParam.startsWith('/') && !nextParam.startsWith('//');
    const isSafe = isRelative &&
      !nextParam.startsWith('/admin') &&
      !nextParam.startsWith('/driver-home');
    if (isSafe) {
      return applyAndRedirect(nextParam);
    }
  }

  return applyAndRedirect(destination);
}

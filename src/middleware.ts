import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function middleware(request: NextRequest) {
  const { pathname, searchParams } = request.nextUrl;

  // ── OAuth code rescue ──────────────────────────────────────────────────────
  // If an OAuth authorization code lands on any page other than /auth/callback,
  // redirect it there immediately. This handles the case where Supabase is
  // misconfigured to redirect to /available-routes?code=... instead of
  // /auth/callback?code=...
  const code = searchParams.get('code');
  if (code && !pathname.startsWith('/auth/')) {
    const callbackUrl = new URL(`${request.nextUrl.origin}/auth/callback`);
    callbackUrl.searchParams.set('code', code);
    return NextResponse.redirect(callbackUrl);
  }

  // Create a mutable response — must be updated inside setAll to propagate refreshed cookies
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          // Step 1: set on request so downstream reads see the refreshed token
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          // Step 2: rebuild supabaseResponse with the updated request
          supabaseResponse = NextResponse.next({ request });
          // Step 3: set on response so the browser receives the refreshed cookie
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, {
              ...options,
              sameSite: 'lax',
              secure: true,
              path: '/',
            })
          );
        },
      },
    }
  );

  // IMPORTANT: Always call getUser() — this validates the JWT with Supabase Auth server.
  // Never use getSession() for server-side authorization — it only reads the local cookie.
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  // ── Public paths — always allow ────────────────────────────────────────────
  const isPublicPath =
    pathname === '/' ||
    pathname === '/landing-home'|| pathname.startsWith('/sign-up-login-screen') ||
    pathname.startsWith('/auth/');

  if (isPublicPath) {
    return supabaseResponse;
  }

  // ── Unauthenticated — FAIL CLOSED ──────────────────────────────────────────
  if (userError || !user) {
    const url = request.nextUrl.clone();
    url.pathname = '/sign-up-login-screen';
    url.search = '';
    url.searchParams.set('next', pathname);
    const redirectResponse = NextResponse.redirect(url);
    // Propagate any session cookies set during getUser()
    supabaseResponse.cookies.getAll().forEach((cookie) => {
      redirectResponse.cookies.set(cookie.name, cookie.value, { path: '/' });
    });
    return redirectResponse;
  }

  // ── Role-protected routes ──────────────────────────────────────────────────
  const isAdminRoute = pathname.startsWith('/admin-');
  const isDriverRoute = pathname === '/driver-home' || pathname.startsWith('/driver-home/');

  if (isAdminRoute || isDriverRoute) {
    // FAIL CLOSED: any error → deny
    let role: string | null = null;

    try {
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

      if (profileError || !profile || !profile.role) {
        // Profile missing or role null — redirect to login
        const url = request.nextUrl.clone();
        url.pathname = '/sign-up-login-screen';
        url.search = '';
        return NextResponse.redirect(url);
      }

      const validRoles = ['passenger', 'driver', 'admin'];
      if (!validRoles.includes(profile.role)) {
        // Unknown role — FAIL CLOSED
        const url = request.nextUrl.clone();
        url.pathname = '/sign-up-login-screen';
        url.search = '';
        return NextResponse.redirect(url);
      }

      role = profile.role;
    } catch {
      // Any unexpected error — FAIL CLOSED
      const url = request.nextUrl.clone();
      url.pathname = '/sign-up-login-screen';
      url.search = '';
      return NextResponse.redirect(url);
    }

    // ── Admin routes: ONLY role='admin' ─────────────────────────────────────
    if (isAdminRoute) {
      if (role !== 'admin') {
        const url = request.nextUrl.clone();
        url.pathname = role === 'driver' ? '/driver-home' : '/available-routes';
        url.search = '';
        return NextResponse.redirect(url);
      }
      return supabaseResponse;
    }

    // ── Driver routes: ONLY role='driver' ───────────────────────────────────
    if (isDriverRoute) {
      if (role === 'admin') {
        const url = request.nextUrl.clone();
        url.pathname = '/admin-dashboard';
        url.search = '';
        return NextResponse.redirect(url);
      }
      if (role !== 'driver') {
        // passenger or any non-driver role — deny
        const url = request.nextUrl.clone();
        url.pathname = '/available-routes';
        url.search = '';
        return NextResponse.redirect(url);
      }
      return supabaseResponse;
    }
  }

  return supabaseResponse;
}

export const config = {
  matcher: [
    /*
     * Run middleware on ALL routes EXCEPT:
     * - _next/static  (static assets)
     * - _next/image   (image optimization)
     * - favicon.ico
     * - Static file extensions
     *
     * This ensures /admin-* and /driver-home are always intercepted,
     * including on the custom domain raahitest.referralhub.co.in
     */
    '/((?!_next/static|_next/image|favicon\\.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp|ico|css|js)$).*)',
  ],
};

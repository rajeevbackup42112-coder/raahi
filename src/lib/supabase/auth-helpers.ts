/**
 * Server-side authorization helpers — FAIL CLOSED on every error.
 *
 * These must be called from Server Components / Route Handlers only.
 * They independently verify the authenticated user's role from the database,
 * never trusting any client-supplied value.
 */

import { redirect } from 'next/navigation';
import { createClient } from './server';

export type UserRole = 'passenger' | 'driver' | 'admin';

export interface AuthorizedUser {
  id: string;
  email: string | null;
  role: UserRole;
  name: string | null;
  avatar_url: string | null;
}

/**
 * Core authorization function.
 * 1. Creates server Supabase client (reads real session cookies)
 * 2. Calls auth.getUser() — never getSession()
 * 3. Queries public.profiles using auth.uid()
 * 4. Returns the authorized user or redirects (never throws to caller)
 *
 * FAIL CLOSED: any error, missing profile, null role → redirect to login
 */
export async function getAuthorizedUser(): Promise<AuthorizedUser | null> {
  try {
    const supabase = await createClient();

    // Always use getUser() — verifies the JWT with Supabase Auth server
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return null;
    }

    // Query profile using the verified auth.uid()
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('id, role, name, email, avatar_url')
      .eq('id', user.id)
      .single();

    if (profileError || !profile || !profile.role) {
      // Profile missing or role null — FAIL CLOSED
      return null;
    }

    const validRoles: UserRole[] = ['passenger', 'driver', 'admin'];
    if (!validRoles.includes(profile.role as UserRole)) {
      // Unknown role — FAIL CLOSED
      return null;
    }

    return {
      id: user.id,
      email: user.email ?? null,
      role: profile.role as UserRole,
      name: profile.name ?? null,
      avatar_url: profile.avatar_url ?? null,
    };
  } catch {
    // Any unexpected error — FAIL CLOSED
    return null;
  }
}

/**
 * Require admin role. Redirects on failure — never renders admin UI.
 *
 * NO SESSION          → /sign-up-login-screen
 * PASSENGER           → /available-routes
 * DRIVER              → /driver-home
 * ADMIN               → returns AuthorizedUser
 */
export async function requireAdmin(): Promise<AuthorizedUser> {
  const authorizedUser = await getAuthorizedUser();

  if (!authorizedUser) {
    redirect('/sign-up-login-screen');
  }

  if (authorizedUser.role !== 'admin') {
    if (authorizedUser.role === 'driver') {
      redirect('/driver-home');
    }
    // passenger or any other role
    redirect('/available-routes');
  }

  return authorizedUser;
}

/**
 * Require driver role. Redirects on failure.
 *
 * NO SESSION          → /sign-up-login-screen
 * PASSENGER           → /available-routes
 * ADMIN               → /admin-dashboard
 * DRIVER              → returns AuthorizedUser
 */
export async function requireDriver(): Promise<AuthorizedUser> {
  const authorizedUser = await getAuthorizedUser();

  if (!authorizedUser) {
    redirect('/sign-up-login-screen');
  }

  if (authorizedUser.role === 'admin') {
    redirect('/admin-dashboard');
  }

  if (authorizedUser.role !== 'driver') {
    // passenger or unknown — redirect to passenger home
    redirect('/available-routes');
  }

  return authorizedUser;
}

/**
 * Require any authenticated user (passenger, driver, or admin).
 * Redirects to login if no valid session.
 */
export async function requireAuth(): Promise<AuthorizedUser> {
  const authorizedUser = await getAuthorizedUser();

  if (!authorizedUser) {
    redirect('/sign-up-login-screen');
  }

  return authorizedUser;
}

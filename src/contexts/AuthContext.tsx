'use client';

import { createContext, useContext, useEffect, useState, useCallback, useRef } from 'react';
import { createClient } from '@/lib/supabase/client';
import { useRouter } from 'next/navigation';

interface Profile {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  role: 'passenger' | 'driver' | 'admin';
  avatar_url: string | null;
  status: 'active' | 'suspended' | 'pending';
  created_at: string;
  updated_at: string;
}

interface AuthContextType {
  user: any;
  session: any;
  profile: Profile | null;
  loading: boolean;
  signUp: (email: string, password: string, metadata?: any) => Promise<any>;
  signIn: (email: string, password: string) => Promise<any>;
  signInWithGoogle: () => Promise<any>;
  signInWithPhone: (phone: string) => Promise<any>;
  verifyOtp: (phone: string, token: string) => Promise<any>;
  signOut: () => Promise<void>;
  getCurrentUser: () => Promise<any>;
  isEmailVerified: () => boolean;
  getUserProfile: () => Promise<Profile | null>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({} as AuthContextType);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }: { children: React.ReactNode }) => {
  const [user, setUser] = useState<any>(null);
  const [session, setSession] = useState<any>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [loading, setLoading] = useState(true);
  // Track whether we need to load a profile (set by onAuthStateChange, consumed by effect)
  const pendingProfileUserId = useRef<string | null>(null);
  const supabase = createClient();
  const router = useRouter();

  // ─── loadProfile ────────────────────────────────────────────────────────────
  // IMPORTANT: This function must NOT be called directly inside onAuthStateChange.
  // Supabase documents that awaiting another Supabase call inside onAuthStateChange
  // can cause a deadlock in the auth state machine. Instead we set a ref and load
  // the profile in a separate useEffect.
  const loadProfile = useCallback(async (userId: string): Promise<Profile | null> => {
    console.log('[AuthContext] PROFILE_LOAD_START user=' + userId);
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle(); // maybeSingle: returns null (not error) when row not found

      if (error) {
        console.error('[AuthContext] PROFILE_LOAD_ERROR', error.message, 'code:', error.code);
        return null;
      }

      if (!data) {
        console.warn('[AuthContext] PROFILE_LOAD_RESPONSE — no profile row found for user=' + userId);
        return null;
      }

      console.log('[AuthContext] PROFILE_LOAD_RESPONSE — success');
      console.log('[AuthContext] PROFILE_ROLE=' + data.role);
      setProfile(data as Profile);
      return data as Profile;
    } catch (err: any) {
      console.error('[AuthContext] PROFILE_LOAD_ERROR (exception):', err?.message ?? err);
      return null;
    }
  }, [supabase]);

  // ─── Auth state listener ─────────────────────────────────────────────────────
  // KEY RULE: Do NOT await any Supabase calls inside this callback.
  // Doing so deadlocks the Supabase auth state machine.
  // We only set React state here; profile loading happens in a separate effect.
  useEffect(() => {
    console.log('[AuthContext] AUTH_INIT — passive initialization, no getSession()');

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      console.log('[AuthContext] onAuthStateChange event:', event);

      if (event === 'TOKEN_REFRESHED' && !session) {
        console.log('[AuthContext] TOKEN_REFRESHED with no session — clearing stale local state');
        // Use setTimeout to avoid calling Supabase inside the callback (deadlock risk)
        setTimeout(() => {
          supabase.auth.signOut({ scope: 'local' });
        }, 0);
        setSession(null);
        setUser(null);
        setProfile(null);
        pendingProfileUserId.current = null;
        setLoading(false);
        return;
      }

      if (event === 'SIGNED_OUT') {
        console.log('[AuthContext] AUTH_SIGNED_OUT');
        setSession(null);
        setUser(null);
        setProfile(null);
        pendingProfileUserId.current = null;
        setLoading(false);
        return;
      }

      if (event === 'SIGNED_IN' || event === 'INITIAL_SESSION') {
        if (session?.user) {
          console.log('[AuthContext] AUTH_SIGNED_IN — scheduling profile load for user=' + session.user.id);
          setSession(session);
          setUser(session.user);
          // Signal the profile-loading effect — do NOT await here
          pendingProfileUserId.current = session.user.id;
          // loading stays true until profile effect completes
          return;
        }
        // INITIAL_SESSION with no session = clean signed-out state
        console.log('[AuthContext] AUTH_SIGNED_OUT (no session on INITIAL_SESSION)');
        setSession(null);
        setUser(null);
        setProfile(null);
        pendingProfileUserId.current = null;
        setLoading(false);
        return;
      }

      if (event === 'TOKEN_REFRESHED' && session) {
        console.log('[AuthContext] TOKEN_REFRESHED — session valid');
        setSession(session);
        setUser(session.user);
        return;
      }

      // Fallback for any other events
      setSession(session);
      setUser(session?.user ?? null);
      if (!session?.user) {
        setProfile(null);
        pendingProfileUserId.current = null;
        setLoading(false);
      }
    });

    return () => subscription.unsubscribe();
  }, [supabase]);

  // ─── Profile loading effect ──────────────────────────────────────────────────
  // Runs OUTSIDE onAuthStateChange — safe to await Supabase calls here.
  // Triggered when user state changes (set by onAuthStateChange above).
  useEffect(() => {
    if (!user?.id) return;

    let cancelled = false;

    const doLoadProfile = async () => {
      const loadedProfile = await loadProfile(user.id);

      if (cancelled) return;

      if (loadedProfile) {
        const roleMap: Record<string, string> = {
          passenger: '/available-routes',
          driver: '/driver-home',
          admin: '/admin-dashboard',
        };
        const target = roleMap[loadedProfile.role];
        console.log('[AuthContext] ROLE_REDIRECT_TARGET=' + (target ?? 'unknown'));

        if (target) {
          // Only redirect if we're currently on the login page
          // (avoid redirecting on every token refresh or page navigation)
          if (typeof window !== 'undefined' &&
              window.location.pathname === '/sign-up-login-screen') {
            console.log('[AuthContext] Redirecting to', target);
            router.push(target);
          }
        } else {
          console.error('[AuthContext] Unknown role — staying on current page');
        }
      } else {
        console.warn('[AuthContext] Profile not loaded — staying on current page');
      }

      setLoading(false);
    };

    doLoadProfile();

    return () => { cancelled = true; };
  }, [user, loadProfile, router]);

  // Email/Password Sign Up
  const signUp = async (email: string, password: string, metadata = {}) => {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: (metadata as any)?.fullName || '',
          avatar_url: (metadata as any)?.avatarUrl || '',
        },
        emailRedirectTo: `${typeof window !== 'undefined' ? window.location.origin : process.env.NEXT_PUBLIC_SITE_URL}/auth/callback`,
      },
    });
    if (error) throw error;
    return data;
  };

  // Email/Password Sign In — role routing handled server-side at /auth/role-redirect
  const signIn = async (email: string, password: string) => {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    // Route to role-redirect so server determines correct destination
    router.push('/auth/role-redirect');
    return data;
  };

  // Google Sign-In
  const signInWithGoogle = async () => {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    console.log('[AuthContext] signInWithGoogle called');
    console.log('[AuthContext] NEXT_PUBLIC_SUPABASE_URL defined:', !!supabaseUrl);
    console.log('[AuthContext] NEXT_PUBLIC_SUPABASE_ANON_KEY defined:', !!supabaseKey);

    if (!supabaseUrl || !supabaseKey) {
      const msg = 'Supabase client is not configured. Missing environment variables.';
      console.error('[AuthContext]', msg);
      throw new Error(msg);
    }

    const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || (typeof window !== 'undefined' ? window.location.origin : '');

    // Thread the ?next= destination through the OAuth flow so the callback
    // can redirect the passenger to their intended booking page after login.
    let redirectTo = `${siteUrl}/auth/callback`;
    if (typeof window !== 'undefined') {
      const currentParams = new URLSearchParams(window.location.search);
      const nextParam = currentParams.get('next');
      if (nextParam) {
        redirectTo = `${siteUrl}/auth/callback?next=${encodeURIComponent(nextParam)}`;
      }
    }

    console.log('[AuthContext] signInWithOAuth_called with redirectTo:', redirectTo);

    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo,
        skipBrowserRedirect: true,
      },
    });

    if (error) {
      console.error('[AuthContext] signInWithOAuth error:', error.message);
      throw error;
    }

    console.log('[AuthContext] signInWithOAuth data.url exists:', !!data?.url);
    if (data?.url) {
      console.log('[AuthContext] OAuth URL domain:', new URL(data.url).hostname);
      window.location.assign(data.url);
    } else {
      throw new Error('Google OAuth URL was not generated');
    }

    return data;
  };

  // Phone OTP — send OTP
  const signInWithPhone = async (phone: string) => {
    const normalized = phone.startsWith('+') ? phone : `+91${phone}`;
    const { data, error } = await supabase.auth.signInWithOtp({
      phone: normalized,
    });
    if (error) throw error;
    return data;
  };

  // Phone OTP — verify
  const verifyOtp = async (phone: string, token: string) => {
    const normalized = phone.startsWith('+') ? phone : `+91${phone}`;
    const { data, error } = await supabase.auth.verifyOtp({
      phone: normalized,
      token,
      type: 'sms',
    });
    if (error) throw error;
    if (data.user) {
      await loadProfile(data.user.id);
    }
    return data;
  };

  // Sign Out
  const signOut = async () => {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
    setProfile(null);
    router.push('/sign-up-login-screen');
  };

  // Get Current User
  const getCurrentUser = async () => {
    const { data: { user }, error } = await supabase.auth.getUser();
    if (error) throw error;
    return user;
  };

  // Check if Email is Verified
  const isEmailVerified = () => {
    return user?.email_confirmed_at !== null;
  };

  // Get User Profile from Database
  const getUserProfile = async (): Promise<Profile | null> => {
    if (!user) return null;
    return await loadProfile(user.id);
  };

  // Refresh profile
  const refreshProfile = async () => {
    if (user) {
      await loadProfile(user.id);
    }
  };

  const value: AuthContextType = {
    user,
    session,
    profile,
    loading,
    signUp,
    signIn,
    signInWithGoogle,
    signInWithPhone,
    verifyOtp,
    signOut,
    getCurrentUser,
    isEmailVerified,
    getUserProfile,
    refreshProfile,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

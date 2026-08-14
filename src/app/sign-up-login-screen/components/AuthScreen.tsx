'use client';
import React, { useState, useEffect, useRef } from 'react';
import AppLogo from '@/components/ui/AppLogo';
import { useAuth } from '@/contexts/AuthContext';
import { useRouter } from 'next/navigation';

export default function AuthScreen() {
  const { signInWithGoogle } = useAuth();
  const router = useRouter();

  const [loading, setLoading] = useState(false);
  const [googleError, setGoogleError] = useState<string | null>(null);

  // Capture the intended post-auth destination from ?next= on first mount only.
  const nextDestination = useRef<string | null>(null);

  // Guard: read URL params exactly ONCE on mount.
  const didReadParams = useRef(false);

  useEffect(() => {
    if (didReadParams.current) return;
    didReadParams.current = true;

    // Read from window.location.search (the real URL) rather than Next.js
    // useSearchParams — the router can cache stale values across soft navigations.
    const realSearch = typeof window !== 'undefined' ? window.location.search : '';
    const realParams = new URLSearchParams(realSearch);

    const errorParam = realParams.get('error');
    const nextParam = realParams.get('next');

    if (nextParam) {
      nextDestination.current = nextParam;
    }

    if (errorParam) {
      // Remove error param from URL immediately so refresh/back-nav doesn't re-show it.
      const url = new URL(window.location.href);
      url.searchParams.delete('error');
      window.history.replaceState({}, '', url.toString());

      if (
        errorParam === 'auth_callback_failed' ||
        errorParam === 'profile_load_failed' ||
        errorParam === 'profile_create_failed' ||
        errorParam === 'unknown_role'
      ) {
        setGoogleError('Sign-in failed. Please try again.');
      }
    } else {
      // Clean mount — ensure no stale error is shown.
      setGoogleError(null);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleGoogleSignIn = async () => {
    setGoogleError(null);
    setLoading(true);
    try {
      await signInWithGoogle();
    } catch (err: any) {
      const msg = err?.message || 'Google sign-in failed. Please try again.';
      setGoogleError(msg);
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background flex flex-col items-center justify-center px-4 py-12">
      <div className="w-full max-w-sm">
        {/* Brand */}
        <div className="flex flex-col items-center mb-10">
          <div className="flex items-center gap-3 mb-4">
            <AppLogo size={48} />
            <span className="font-extrabold text-3xl text-primary tracking-tight">Raahi</span>
          </div>
          <p className="text-base font-semibold text-foreground text-center">Shared rides. Simple journeys.</p>
          <p className="text-sm text-muted-foreground text-center mt-1 max-w-xs">
            Join the queue for your route. Get matched automatically.
          </p>
        </div>

        <div className="flex flex-col gap-3">
          {/* Error — only shown for genuine auth failures */}
          {googleError && (
            <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700" role="alert">
              {googleError}
            </div>
          )}

          <button
            onClick={handleGoogleSignIn}
            className="btn-secondary w-full gap-3 py-3.5 justify-center"
            disabled={loading}
            type="button"
          >
            {loading ? (
              <span className="w-4 h-4 border-2 border-muted-foreground/40 border-t-foreground rounded-full animate-spin" />
            ) : (
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
                <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/>
                <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
              </svg>
            )}
            Continue with Google
          </button>

          <p className="text-xs text-muted-foreground text-center mt-2">
            By continuing, you agree to Raahi's terms of service.
          </p>
        </div>
      </div>
    </div>
  );
}
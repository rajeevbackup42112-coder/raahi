import React from 'react';
import AppLogo from '@/components/ui/AppLogo';
import Link from 'next/link';

export default function PublicFooter() {
  return (
    <footer className="border-t bg-card mt-16">
      <div className="max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          <div>
            <div className="flex items-center gap-2 mb-3">
              <AppLogo size={32} />
              <span className="font-extrabold text-lg text-primary">Raahi</span>
            </div>
            <p className="text-sm text-muted-foreground leading-relaxed">
              Shared rides on fixed routes. Simple, affordable daily commuting between Gomoh and Dhanbad.
            </p>
          </div>
          <div>
            <p className="section-label mb-3">Quick Links</p>
            <div className="flex flex-col gap-2">
              <Link href="/" className="text-sm text-muted-foreground hover:text-foreground transition-colors">Home</Link>
              <Link href="/route-selection" className="text-sm text-muted-foreground hover:text-foreground transition-colors">View Routes</Link>
              <Link href="/sign-up-login-screen" className="text-sm text-muted-foreground hover:text-foreground transition-colors">Sign In</Link>
            </div>
          </div>
          <div>
            <p className="section-label mb-3">Support</p>
            <div className="flex flex-col gap-2">
              <span className="text-sm text-muted-foreground">help@raahi.in</span>
              <span className="text-sm text-muted-foreground">Gomoh, Jharkhand</span>
              <span className="text-sm text-muted-foreground">Mon–Sat, 6 AM – 8 PM</span>
            </div>
          </div>
        </div>
        <div className="border-t mt-8 pt-6 flex flex-col sm:flex-row items-center justify-between gap-2">
          <p className="text-xs text-muted-foreground">© 2026 Raahi. All rights reserved.</p>
          <p className="text-xs text-muted-foreground">Shared rides. Simple journeys.</p>
        </div>
      </div>
    </footer>
  );
}
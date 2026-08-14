'use client';
import React, { useState } from 'react';
import AppLogo from '@/components/ui/AppLogo';
import Link from 'next/link';
import { Menu, X } from 'lucide-react';

export default function PublicHeader() {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 w-full border-b bg-card/95 backdrop-blur-sm" style={{ borderColor: 'var(--border)' }}>
      <div className="max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-8 flex items-center justify-between h-16">
        <Link href="/" className="flex items-center gap-2">
          <AppLogo size={36} />
          <span className="font-extrabold text-xl tracking-tight text-primary">Raahi</span>
        </Link>

        <nav className="hidden md:flex items-center gap-1">
          <Link href="/" className="nav-item text-sm">Home</Link>
          <Link href="/route-selection" className="nav-item text-sm">Routes</Link>
          <Link href="/sign-up-login-screen" className="nav-item text-sm">Login</Link>
        </nav>

        <div className="hidden md:flex items-center gap-3">
          <Link href="/sign-up-login-screen" className="btn-secondary text-sm px-4 py-2">Sign In</Link>
          <Link href="/sign-up-login-screen" className="btn-primary text-sm px-4 py-2">Book a Seat</Link>
        </div>

        <button
          onClick={() => setMenuOpen(!menuOpen)}
          className="md:hidden p-2 rounded-lg hover:bg-muted transition-colors"
          aria-label="Toggle menu"
        >
          {menuOpen ? <X size={20} /> : <Menu size={20} />}
        </button>
      </div>

      {menuOpen && (
        <div className="md:hidden border-t bg-card px-4 py-4 flex flex-col gap-2 animate-fade-in">
          <Link href="/" className="nav-item" onClick={() => setMenuOpen(false)}>Home</Link>
          <Link href="/route-selection" className="nav-item" onClick={() => setMenuOpen(false)}>Routes</Link>
          <Link href="/sign-up-login-screen" className="nav-item" onClick={() => setMenuOpen(false)}>Login</Link>
          <div className="pt-2 border-t flex flex-col gap-2">
            <Link href="/sign-up-login-screen" className="btn-secondary w-full justify-center" onClick={() => setMenuOpen(false)}>Sign In</Link>
            <Link href="/sign-up-login-screen" className="btn-primary w-full justify-center" onClick={() => setMenuOpen(false)}>Book a Seat</Link>
          </div>
        </div>
      )}
    </header>
  );
}
'use client';
import React, { useState } from 'react';
import AppLogo from '@/components/ui/AppLogo';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, Map, User, Bell, LogOut, Menu, X } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { toast } from 'sonner';

const navItems = [
  { href: '/available-routes', label: 'Routes', icon: Map },
  { href: '/my-bookings', label: 'My Bookings', icon: Home },
  { href: '/passenger-profile', label: 'Profile', icon: User },
];

export default function PassengerHeader() {
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);
  const { profile, signOut, loading } = useAuth();

  const handleSignOut = async () => {
    try {
      await signOut();
    } catch {
      toast.error('Sign out failed. Please try again.');
    }
  };

  // While profile is loading, show a neutral placeholder — never show a role label
  const displayName = loading ? '' : (profile?.name || '');
  const initial = displayName ? displayName.charAt(0).toUpperCase() : '?';

  return (
    <>
      <header className="sticky top-0 z-50 w-full border-b bg-card/95 backdrop-blur-sm">
        <div className="max-w-screen-xl mx-auto px-4 sm:px-6 flex items-center justify-between h-16">
          <Link href="/available-routes" className="flex items-center gap-2">
            <AppLogo size={32} />
            <span className="font-extrabold text-lg tracking-tight text-primary">Raahi</span>
          </Link>

          <nav className="hidden sm:flex items-center gap-1">
            {navItems?.map((item) => (
              <Link
                key={`nav-${item?.label}`}
                href={item?.href}
                className={`nav-item ${pathname === item?.href ? 'active' : ''}`}
              >
                <item.icon size={16} />
                {item?.label}
              </Link>
            ))}
          </nav>

          <div className="hidden sm:flex items-center gap-2">
            <button className="relative p-2 rounded-xl hover:bg-muted transition-colors" aria-label="Notifications">
              <Bell size={18} className="text-muted-foreground" />
              <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-accent rounded-full"></span>
            </button>
            <Link href="/passenger-profile" className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-muted hover:bg-secondary transition-colors">
              <div className="w-7 h-7 rounded-full gradient-primary flex items-center justify-center text-white text-xs font-bold">
                {loading ? (
                  <span className="w-3 h-3 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                ) : initial}
              </div>
              {!loading && displayName && (
                <span className="text-sm font-medium">{displayName.split(' ')[0]}</span>
              )}
              {loading && (
                <span className="w-16 h-4 bg-muted-foreground/20 rounded animate-pulse" />
              )}
            </Link>
            <button onClick={handleSignOut} className="p-2 rounded-xl hover:bg-muted transition-colors" aria-label="Logout">
              <LogOut size={16} className="text-muted-foreground" />
            </button>
          </div>

          <button onClick={() => setMenuOpen(!menuOpen)} className="sm:hidden p-2 rounded-lg hover:bg-muted" aria-label="Menu">
            {menuOpen ? <X size={20} /> : <Menu size={20} />}
          </button>
        </div>
      </header>
      {/* Mobile bottom nav */}
      <nav className="sm:hidden fixed bottom-0 left-0 right-0 z-50 bg-card border-t flex items-center justify-around h-16">
        {navItems?.map((item) => (
          <Link
            key={`mobile-nav-${item?.label}`}
            href={item?.href}
            className={`flex flex-col items-center gap-1 px-4 py-2 rounded-xl transition-colors ${pathname === item?.href ? 'text-primary' : 'text-muted-foreground'}`}
          >
            <item.icon size={20} />
            <span className="text-xs font-medium">{item?.label}</span>
          </Link>
        ))}
      </nav>
      {menuOpen && (
        <div className="sm:hidden fixed inset-0 z-40 bg-black/40" onClick={() => setMenuOpen(false)} />
      )}
    </>
  );
}
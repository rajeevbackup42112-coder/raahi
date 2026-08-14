'use client';
import React, { useState } from 'react';
import AppLogo from '@/components/ui/AppLogo';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { LayoutDashboard, BookOpen, Users, Car, Route, Settings, FileText, ChevronLeft, ChevronRight, LogOut, FlaskConical, Activity } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { toast } from 'sonner';

const navItems = [
  { href: '/admin-dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/admin-bookings', label: 'Bookings', icon: BookOpen },
  { href: '/admin-users', label: 'Users', icon: Users },
  { href: '/admin-vehicles', label: 'Vehicles', icon: Car },
  { href: '/admin-routes', label: 'Routes', icon: Route },
  { href: '/admin-settings', label: 'Business Settings', icon: Settings },
  { href: '/admin-audit-log', label: 'Activity Log', icon: FileText },
  { href: '/admin-queue-diagnostic', label: 'Queue Diagnostic', icon: Activity },
  { href: '/admin-test-harness', label: 'Test Harness', icon: FlaskConical },
];

export default function AdminSidebar() {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);
  const { signOut } = useAuth();

  const handleSignOut = async () => {
    try {
      await signOut();
    } catch {
      toast.error('Sign out failed');
    }
  };

  return (
    <aside className={`hidden lg:flex flex-col h-screen bg-card border-r transition-all duration-300 ${collapsed ? 'w-16' : 'w-60'} shrink-0`}>
      {/* Logo */}
      <div className={`flex items-center h-16 border-b px-4 ${collapsed ? 'justify-center' : 'gap-3'}`}>
        <AppLogo size={28} />
        {!collapsed && <span className="font-extrabold text-base text-primary tracking-tight">Raahi Admin</span>}
      </div>

      {/* Nav */}
      <nav className="flex-1 overflow-y-auto py-3 px-2">
        {navItems.map((item) => {
          const isActive = pathname === item.href || pathname.startsWith(item.href + '/');
          return (
            <Link
              key={`admin-nav-${item.label}`}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-xl mb-0.5 transition-all duration-150 group ${isActive ? 'bg-secondary text-primary font-semibold' : 'text-muted-foreground hover:bg-muted hover:text-foreground'}`}
              title={collapsed ? item.label : undefined}
            >
              <item.icon size={18} className="shrink-0" />
              {!collapsed && <span className="text-sm truncate">{item.label}</span>}
            </Link>
          );
        })}
      </nav>

      {/* Footer */}
      <div className="border-t p-2">
        <button
          onClick={handleSignOut}
          className={`flex items-center gap-3 px-3 py-2.5 rounded-xl w-full text-muted-foreground hover:bg-muted hover:text-foreground transition-colors ${collapsed ? 'justify-center' : ''}`}
          title={collapsed ? 'Sign Out' : undefined}
        >
          <LogOut size={18} className="shrink-0" />
          {!collapsed && <span className="text-sm">Sign Out</span>}
        </button>
        <button
          onClick={() => setCollapsed(!collapsed)}
          className={`flex items-center gap-3 px-3 py-2.5 rounded-xl w-full text-muted-foreground hover:bg-muted transition-colors mt-0.5 ${collapsed ? 'justify-center' : ''}`}
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {collapsed ? <ChevronRight size={18} /> : <><ChevronLeft size={18} /><span className="text-sm">Collapse</span></>}
        </button>
      </div>
    </aside>
  );
}
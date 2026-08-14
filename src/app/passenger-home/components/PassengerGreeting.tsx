'use client';
import React, { useEffect, useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { Sun } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

function getGreeting() {
  const hour = new Date()?.getHours();
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

export default function PassengerGreeting() {
  const { profile } = useAuth();
  const firstName = profile?.name?.split(' ')?.[0] || 'there';
  const [activeRouteCount, setActiveRouteCount] = useState<number | null>(null);

  useEffect(() => {
    const supabase = createClient();
    supabase?.from('routes')?.select('id', { count: 'exact', head: true })?.eq('status', 'active')?.then(({ count }) => setActiveRouteCount(count ?? 0));
  }, []);

  return (
    <div className="flex items-start justify-between gap-4">
      <div>
        <div className="flex items-center gap-2 mb-1">
          <Sun size={18} className="text-accent" />
          <span className="text-sm text-muted-foreground font-medium">{getGreeting()}</span>
        </div>
        <h1 className="text-2xl font-bold text-foreground">Hello, {firstName} 👋</h1>
        <p className="text-sm text-muted-foreground mt-1">Where are you headed today?</p>
      </div>
      {activeRouteCount !== null && (
        <div className="text-right">
          <p className="text-xs text-muted-foreground">Routes active</p>
          <p className="text-xs font-semibold text-primary mt-0.5">
            {activeRouteCount > 0 ? `${activeRouteCount} route${activeRouteCount !== 1 ? 's' : ''}` : 'None yet'}
          </p>
        </div>
      )}
    </div>
  );
}
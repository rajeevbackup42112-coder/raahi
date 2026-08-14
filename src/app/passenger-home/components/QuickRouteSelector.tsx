'use client';
import React, { useState, useEffect } from 'react';
import Link from 'next/link';
import { ArrowRight, ArrowLeftRight } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

interface Route {
  id: string;
  from_location: string;
  to_location: string;
}

export default function QuickRouteSelector() {
  const [routes, setRoutes] = useState<Route[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const supabase = createClient();

  useEffect(() => {
    const loadRoutes = async () => {
      try {
        const { data, error } = await supabase
          .from('routes')
          .select('id, from_location, to_location')
          .eq('status', 'active')
          .order('from_location');
        if (!error && data) {
          setRoutes(data);
          if (data.length > 0) setSelected(data[0].id);
        }
      } catch {
        // Silently handle
      } finally {
        setLoading(false);
      }
    };
    loadRoutes();
  }, []);

  return (
    <div className="card-base p-5">
      <div className="flex items-center justify-between mb-4">
        <p className="font-semibold text-sm text-foreground">Quick book</p>
        <Link href="/route-selection" className="text-xs text-primary font-semibold hover:underline">
          All routes →
        </Link>
      </div>
      {loading ? (
        <div className="flex flex-col gap-2 mb-4">
          {[1, 2].map((i) => <div key={i} className="h-14 bg-muted rounded-xl animate-pulse" />)}
        </div>
      ) : (
        <div className="flex flex-col gap-2 mb-4">
          {routes?.map((route) => (
            <button
              key={route?.id}
              onClick={() => setSelected(route?.id)}
              className={`flex items-center justify-between p-3.5 rounded-xl border-2 transition-all duration-150 text-left ${selected === route?.id ? 'border-primary bg-secondary' : 'border-border bg-card hover:border-primary/40'}`}
            >
              <div className="flex items-center gap-2">
                <ArrowLeftRight size={14} className="text-primary" />
                <div>
                  <div className="flex items-center gap-1.5 text-sm font-semibold text-foreground">
                    <span>{route?.from_location}</span>
                    <ArrowRight size={12} className="text-muted-foreground" />
                    <span>{route?.to_location}</span>
                  </div>
                  <p className="text-xs text-muted-foreground">Loading fare...</p>
                </div>
              </div>
            </button>
          ))}
        </div>
      )}
      <Link href="/route-selection" className="btn-primary w-full justify-center">
        Continue to Booking
        <ArrowRight size={16} />
      </Link>
    </div>
  );
}
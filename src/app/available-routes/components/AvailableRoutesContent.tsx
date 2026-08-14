'use client';
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { ArrowRight, MapPin, Users, RefreshCw } from 'lucide-react';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import PassengerHeader from '@/components/PassengerHeader';

interface Route {
  id: string;
  from_location: string;
  to_location: string;
  distance_km: number;
  estimated_duration_min: number;
  fare_per_seat: number;
}

interface RouteWithQueue {
  route: Route;
  waitingPassengers: number;
  loading: boolean;
}

export default function AvailableRoutesContent() {
  const { profile } = useAuth();
  const supabase = useMemo(() => createClient(), []);
  const [routesData, setRoutesData] = useState<RouteWithQueue[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);

  const loadRoutes = useCallback(async () => {
    try {
      const { data: routes, error } = await supabase
        .from('routes')
        .select('id, from_location, to_location, distance_km, estimated_duration_min, fare_per_seat')
        .eq('status', 'active')
        .order('from_location');

      if (error || !routes) return;

      const routesWithQueues = await Promise.all(
        routes.map(async (route) => {
          try {
            const { count: waitingCount } = await supabase
              .from('passenger_queue')
              .select('id', { count: 'exact', head: true })
              .eq('route_id', route.id)
              .in('status', ['WAITING', 'MATCHING']);
            return { route, waitingPassengers: waitingCount ?? 0, loading: false };
          } catch {
            return { route, waitingPassengers: 0, loading: false };
          }
        })
      );

      setRoutesData(routesWithQueues);
    } catch {
      // Silently handle
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadRoutes();
  }, [loadRoutes]);

  useEffect(() => {
    const channel = supabase
      .channel('routes-queue-realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'passenger_queue' }, () => {
        loadRoutes();
      })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [supabase, loadRoutes]);

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadRoutes();
  };

  return (
    <div className="min-h-screen bg-background">
      <PassengerHeader />
      <div className="max-w-2xl mx-auto px-4 py-8">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h1 className="text-2xl font-bold text-foreground">Where do you want to go?</h1>
            {profile?.name && (
              <p className="text-sm text-muted-foreground mt-0.5">Hello, {profile.name.split(' ')[0]} 👋</p>
            )}
          </div>
          <button
            onClick={handleRefresh}
            disabled={refreshing}
            className="p-2 rounded-xl hover:bg-muted transition-colors"
            aria-label="Refresh routes"
          >
            <RefreshCw size={16} className={`text-muted-foreground ${refreshing ? 'animate-spin' : ''}`} />
          </button>
        </div>

        {loading ? (
          <div className="flex flex-col gap-4">
            {[1, 2].map((i) => (
              <div key={i} className="card-base p-5 animate-pulse">
                <div className="h-6 bg-muted rounded w-1/2 mb-3" />
                <div className="h-4 bg-muted rounded w-1/3 mb-2" />
                <div className="h-10 bg-muted rounded mt-4" />
              </div>
            ))}
          </div>
        ) : routesData.length === 0 ? (
          <div className="card-base p-10 text-center">
            <MapPin size={32} className="text-muted-foreground mx-auto mb-3" />
            <p className="text-muted-foreground">No routes available at the moment.</p>
          </div>
        ) : (
          <div className="flex flex-col gap-4">
            {routesData.map(({ route, waitingPassengers }) => (
              <div key={route.id} className="card-base p-5">
                {/* Route header */}
                <div className="flex items-start justify-between gap-4 mb-4">
                  <div>
                    <div className="flex items-center gap-2 text-xl font-bold text-foreground mb-1">
                      <span>{route.from_location}</span>
                      <ArrowRight size={18} className="text-primary shrink-0" />
                      <span>{route.to_location}</span>
                    </div>
                    <p className="text-base font-semibold text-primary">
                      ₹{route.fare_per_seat ?? 150} / seat
                    </p>
                  </div>
                </div>

                {/* Queue status */}
                <div className="flex items-center gap-2 p-3 bg-muted rounded-xl mb-4">
                  <div className="w-8 h-8 rounded-full gradient-primary flex items-center justify-center shrink-0">
                    <Users size={14} className="text-white" />
                  </div>
                  <div className="flex-1 min-w-0">
                    {waitingPassengers > 0 ? (
                      <>
                        <p className="text-sm font-semibold text-foreground">
                          {waitingPassengers} passenger{waitingPassengers !== 1 ? 's' : ''} waiting
                        </p>
                        <p className="text-xs text-muted-foreground">
                          Join the queue — departs when vehicle is full
                        </p>
                      </>
                    ) : (
                      <>
                        <p className="text-sm font-semibold text-foreground">Be the first to join</p>
                        <p className="text-xs text-muted-foreground">
                          No passengers waiting yet — join the queue
                        </p>
                      </>
                    )}
                  </div>
                </div>

                {/* CTA */}
                <Link
                  href={`/book-ride?route=${route.id}`}
                  className="btn-primary w-full justify-center"
                >
                  Join Queue <ArrowRight size={16} />
                </Link>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

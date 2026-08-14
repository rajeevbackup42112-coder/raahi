'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { ArrowRight, MapPin, Users } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

interface RouteWithQueue {
  id: string;
  from_location: string;
  to_location: string;
  fare_per_seat: number;
  pickup_points: string[];
  waiting_seats: number;
}

export default function RoutesPreviewSection() {
  const [routes, setRoutes] = useState<RouteWithQueue[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchRoutesWithQueue() {
      const supabase = createClient();

      // Fetch active routes
      const { data: routesData, error: routesError } = await supabase
        .from('routes')
        .select('id, from_location, to_location, fare_per_seat')
        .eq('status', 'active')
        .limit(4);

      if (routesError || !routesData) {
        setLoading(false);
        return;
      }

      // For each route, fetch pickup points and waiting passenger seat count
      const enriched = await Promise.all(
        routesData.map(async (route) => {
          // Fetch pickup points
          const { data: ppData } = await supabase
            .from('pickup_points')
            .select('name')
            .eq('route_id', route.id)
            .eq('is_active', true)
            .limit(3);

          // Count waiting seats in passenger_queue
          const { data: queueData } = await supabase
            .from('passenger_queue')
            .select('seat_count')
            .eq('route_id', route.id)
            .eq('status', 'WAITING');

          const waitingSeats = (queueData ?? []).reduce(
            (sum: number, row: { seat_count: number }) => sum + (row.seat_count ?? 0),
            0
          );

          return {
            id: route.id,
            from_location: route.from_location,
            to_location: route.to_location,
            fare_per_seat: route.fare_per_seat,
            pickup_points: (ppData ?? []).map((p: { name: string }) => p.name),
            waiting_seats: waitingSeats,
          };
        })
      );

      setRoutes(enriched);
      setLoading(false);
    }

    fetchRoutesWithQueue();
  }, []);

  return (
    <section className="py-20 bg-secondary/30">
      <div className="max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col sm:flex-row items-start sm:items-end justify-between gap-4 mb-10">
          <div>
            <p className="section-label mb-2">Available routes</p>
            <h2 className="text-hero-md text-foreground">Routes open for queue</h2>
          </div>
          <Link href="/route-selection" className="btn-primary shrink-0">
            View all routes
            <ArrowRight size={16} />
          </Link>
        </div>

        {loading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {[1, 2].map((i) => (
              <div key={i} className="card-base p-6 animate-pulse">
                <div className="h-5 bg-muted rounded w-1/2 mb-3" />
                <div className="h-4 bg-muted rounded w-1/3 mb-6" />
                <div className="h-8 bg-muted rounded w-full" />
              </div>
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {routes?.map((route) => (
              <div key={route?.id} className="card-base p-6 card-hover">
                <div className="flex items-start justify-between mb-4">
                  <div>
                    <div className="flex items-center gap-2 text-lg font-bold text-foreground">
                      <span>{route?.from_location}</span>
                      <ArrowRight size={16} className="text-primary" />
                      <span>{route?.to_location}</span>
                    </div>
                    <div className="flex items-center gap-1 mt-1 text-xs text-muted-foreground">
                      <Users size={12} />
                      {route?.waiting_seats > 0 ? (
                        <span>{route.waiting_seats} passenger{route.waiting_seats !== 1 ? 's' : ''} waiting in queue</span>
                      ) : (
                        <span>Be the first to join</span>
                      )}
                    </div>
                  </div>
                </div>

                {route?.pickup_points?.length > 0 && (
                  <div className="mb-4">
                    <p className="section-label mb-2">Pickup points</p>
                    <div className="flex flex-col gap-1.5">
                      {route?.pickup_points?.map((point) => (
                        <div key={`${route?.id}-pickup-${point}`} className="flex items-center gap-2 text-sm text-muted-foreground">
                          <MapPin size={12} className="text-primary shrink-0" />
                          {point}
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                <div className="flex items-center justify-between pt-4 border-t">
                  <div>
                    <p className="text-xs text-muted-foreground">Fare per seat</p>
                    <p className="text-lg font-bold text-foreground tabular-nums">
                      ₹{route?.fare_per_seat}
                    </p>
                  </div>
                  <Link href="/route-selection" className="btn-primary text-sm px-4 py-2">
                    Join Queue
                  </Link>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
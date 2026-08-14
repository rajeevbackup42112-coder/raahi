'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { ArrowRight, MapPin, Users, Shield } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

interface HeroRoute {
  id: string;
  from: string;
  to: string;
  fare: string;
  waitingSeats: number | null;
}

export default function HeroSection() {
  const [heroRoutes, setHeroRoutes] = useState<HeroRoute[]>([]);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    async function fetchQueueCounts() {
      const supabase = createClient();
      const { data: routes } = await supabase
        .from('routes')
        .select('id, from_location, to_location, fare_per_seat')
        .eq('status', 'active')
        .order('from_location')
        .limit(4);

      if (!routes || routes.length === 0) {
        setLoaded(true);
        return;
      }

      const updated = await Promise.all(
        routes.map(async (r) => {
          const { data: queueData } = await supabase
            .from('passenger_queue')
            .select('seat_count')
            .eq('route_id', r.id)
            .eq('status', 'WAITING');

          const waitingSeats = (queueData ?? []).reduce(
            (sum: number, row: { seat_count: number }) => sum + (row.seat_count ?? 0),
            0
          );

          return {
            id: r.id,
            from: r.from_location,
            to: r.to_location,
            fare: `₹${r.fare_per_seat}`,
            waitingSeats,
          };
        })
      );

      setHeroRoutes(updated);
      setLoaded(true);
    }

    fetchQueueCounts();
  }, []);

  return (
    <section className="relative overflow-hidden gradient-hero text-white">
      <div className="absolute inset-0 blob-accent opacity-30" />
      <div className="relative max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-8 pt-16 pb-10 md:pt-24 md:pb-14">
        {/* Above the fold — primary message */}
        <div className="max-w-xl mb-10">
          <h1 className="text-4xl sm:text-5xl font-extrabold text-white leading-tight mb-4">
            Raahi
          </h1>
          <p className="text-xl sm:text-2xl font-semibold text-white/90 mb-3">
            Shared rides. Simple journeys.
          </p>
          <p className="text-base text-white/75 mb-8 leading-relaxed">
            Choose your route. Join the queue. Get matched automatically.
          </p>

          <div className="flex flex-col sm:flex-row gap-3">
            <Link
              href="/available-routes"
              className="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-2xl font-bold text-base bg-accent text-white hover:bg-accent/90 active:scale-95 transition-all duration-150 shadow-lg"
            >
              Join the Queue
              <ArrowRight size={18} />
            </Link>
            <Link
              href="/sign-up-login-screen"
              className="inline-flex items-center justify-center gap-2 px-7 py-4 rounded-2xl font-bold text-base border border-white/30 text-white hover:bg-white/10 active:scale-95 transition-all duration-150"
            >
              Sign In
            </Link>
          </div>
        </div>

        {/* Trust badges */}
        <div className="flex flex-wrap gap-4 mb-10">
          {[
            { icon: MapPin, text: 'Fixed routes, no surprises' },
            { icon: Users, text: 'Fair queue — first in, first served' },
            { icon: Shield, text: 'Verified drivers only' },
          ].map((item) => (
            <div key={item.text} className="flex items-center gap-2 text-white/70 text-sm">
              <item.icon size={15} className="text-accent shrink-0" />
              {item.text}
            </div>
          ))}
        </div>

        {/* Live route cards */}
        {loaded && heroRoutes.length > 0 && (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 max-w-2xl">
            {heroRoutes.map((route) => (
              <Link
                key={route.id}
                href={`/book-ride?route=${route.id}`}
                className="flex flex-col gap-2 p-4 rounded-2xl bg-white/10 border border-white/20 backdrop-blur-sm hover:bg-white/15 active:scale-[0.98] transition-all duration-150"
              >
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-1.5 text-white font-semibold text-sm">
                    <span>{route.from}</span>
                    <ArrowRight size={13} className="text-accent" />
                    <span>{route.to}</span>
                  </div>
                  <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-accent/20 text-accent border border-accent/30 shrink-0">
                    {route.waitingSeats === null
                      ? '…'
                      : route.waitingSeats > 0
                      ? `${route.waitingSeats} waiting`
                      : 'Be first'}
                  </span>
                </div>
                <div className="flex items-center justify-between text-white/60 text-xs">
                  <span>{route.fare} / seat</span>
                  <span className="text-accent font-semibold">Join Queue →</span>
                </div>
              </Link>
            ))}
          </div>
        )}
        {loaded && heroRoutes.length === 0 && (
          <div className="max-w-2xl">
            <div className="p-4 rounded-2xl bg-white/10 border border-white/20 text-white/70 text-sm text-center">
              No routes available yet.
            </div>
          </div>
        )}
      </div>
    </section>
  );
}
'use client';
import React, { useEffect, useState, useCallback } from 'react';
import { BookOpen, Car, Users, TrendingUp, IndianRupee, AlertTriangle, CheckCircle, Clock, BarChart2, RefreshCw } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

interface KpiData {
  bookingsToday: number;
  activeTrips: number;
  passengerSeatsToday: number;
  expectedFareToday: number;
  fareCollectedToday: number;
  seatsWaiting: number;
  cancellationsToday: number;
  completedTripsToday: number;
  driversOnline: number;
  todayStartUtc: string | null;
  todayEndUtc: string | null;
}

// Format INR safely — no locale-dependent calls in render
function formatINR(amount: number): string {
  // Manual Indian number formatting to avoid hydration mismatch
  const str = Math.round(amount).toString();
  if (str.length <= 3) return `₹${str}`;
  const last3 = str.slice(-3);
  const rest = str.slice(0, -3);
  const formatted = rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',') + ',' + last3;
  return `₹${formatted}`;
}

export default function AdminKpiGrid() {
  const [kpis, setKpis] = useState<KpiData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastRefreshedStr, setLastRefreshedStr] = useState<string | null>(null);

  const fetchKpis = useCallback(async () => {
    const supabase = createClient();
    const { data, error: rpcError } = await supabase.rpc('get_admin_dashboard_stats');

    if (rpcError) {
      setError('Unable to load dashboard stats. Please refresh.');
      setLoading(false);
      return;
    }

    if (!data || data.success === false) {
      setError(data?.error ?? 'Unable to load dashboard stats.');
      setLoading(false);
      return;
    }

    setKpis({
      bookingsToday: data.bookings_today ?? 0,
      activeTrips: data.active_trips ?? 0,
      passengerSeatsToday: data.passenger_seats_today ?? 0,
      expectedFareToday: Number(data.expected_fare_today ?? 0),
      fareCollectedToday: Number(data.fare_collected_today ?? 0),
      seatsWaiting: data.seats_waiting ?? 0,
      cancellationsToday: data.cancellations_today ?? 0,
      completedTripsToday: data.completed_trips_today ?? 0,
      driversOnline: data.drivers_online ?? 0,
      todayStartUtc: data.today_start_utc ?? null,
      todayEndUtc: data.today_end_utc ?? null,
    });
    setError(null);
    // Store time as string to avoid hydration mismatch
    const now = new Date();
    const h = now.getHours().toString().padStart(2, '0');
    const m = now.getMinutes().toString().padStart(2, '0');
    setLastRefreshedStr(`${h}:${m}`);
    setLoading(false);
  }, []);

  useEffect(() => {
    fetchKpis();
    const interval = setInterval(fetchKpis, 60_000);
    return () => clearInterval(interval);
  }, [fetchKpis]);

  const items = kpis
    ? [
        {
          id: 'kpi-bookings',
          label: 'Bookings Today',
          value: String(kpis.bookingsToday),
          icon: BookOpen,
          color: 'text-info',
          bg: 'bg-blue-50',
          alert: false,
          hint: 'Valid bookings created today (IST)',
        },
        {
          id: 'kpi-seats',
          label: 'Passenger Seats Today',
          value: String(kpis.passengerSeatsToday),
          icon: Users,
          color: 'text-success',
          bg: 'bg-green-50',
          alert: false,
          hint: 'Total seats booked today (IST) — SUM(bookings.seats)',
        },
        {
          id: 'kpi-expected-fare',
          label: 'Expected Fare Today',
          value: formatINR(kpis.expectedFareToday),
          icon: TrendingUp,
          color: 'text-info',
          bg: 'bg-blue-50',
          alert: false,
          hint: 'Fare from valid bookings — not yet collected',
        },
        {
          id: 'kpi-fare-collected',
          label: 'Fare Collected Today',
          value: formatINR(kpis.fareCollectedToday),
          icon: IndianRupee,
          color: 'text-success',
          bg: 'bg-green-50',
          alert: false,
          hint: 'Cash/UPI confirmed by drivers today',
        },
        {
          id: 'kpi-active-trips',
          label: 'Active Trips',
          value: String(kpis.activeTrips),
          icon: Car,
          color: 'text-primary',
          bg: 'bg-secondary',
          alert: false,
          hint: 'Trips currently in service',
        },
        {
          id: 'kpi-seats-waiting',
          label: 'Seats Waiting',
          value: String(kpis.seatsWaiting),
          icon: Clock,
          color: 'text-warning',
          bg: 'bg-amber-50',
          alert: kpis.seatsWaiting > 10,
          hint: 'Passenger seats awaiting driver assignment',
        },
        {
          id: 'kpi-cancellations',
          label: 'Cancellations Today',
          value: String(kpis.cancellationsToday),
          icon: AlertTriangle,
          color: 'text-danger',
          bg: 'bg-red-50',
          alert: kpis.cancellationsToday > 5,
          hint: 'Passenger-cancelled bookings today (excl. no-shows)',
        },
        {
          id: 'kpi-completed',
          label: 'Completed Trips',
          value: String(kpis.completedTripsToday),
          icon: CheckCircle,
          color: 'text-success',
          bg: 'bg-green-50',
          alert: false,
          hint: 'Trips completed today (IST)',
        },
        {
          id: 'kpi-drivers-online',
          label: 'Drivers Online',
          value: String(kpis.driversOnline),
          icon: BarChart2,
          color: 'text-info',
          bg: 'bg-blue-50',
          alert: false,
          hint: 'Drivers currently active in queue or on trip',
        },
      ]
    : [];

  if (loading) {
    return (
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3">
        {Array.from({ length: 9 }).map((_, i) => (
          <div key={i} className="card-base p-4 animate-pulse min-h-[100px]">
            <div className="w-9 h-9 rounded-xl bg-muted mb-3" />
            <div className="h-6 bg-muted rounded w-1/2 mb-2" />
            <div className="h-3 bg-muted rounded w-3/4" />
          </div>
        ))}
      </div>
    );
  }

  if (error) {
    return (
      <div className="card-base p-5 border border-red-200 bg-red-50">
        <p className="text-sm font-medium text-danger">{error}</p>
        <button
          onClick={fetchKpis}
          className="mt-2 text-xs text-info underline"
        >
          Retry
        </button>
      </div>
    );
  }

  return (
    <div>
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-3">
        {items.map((kpi) => (
          <div key={kpi.id} className="card-base p-4 card-hover min-h-[100px]" title={kpi.hint}>
            <div className="flex items-start justify-between mb-2">
              <div className={`w-9 h-9 rounded-xl ${kpi.bg} flex items-center justify-center shrink-0`}>
                <kpi.icon size={16} className={kpi.color} />
              </div>
              {kpi.alert && (
                <span className="text-xs font-semibold px-1.5 py-0.5 rounded-full bg-red-50 text-danger">⚠</span>
              )}
            </div>
            <p className="text-xl font-bold text-foreground tabular-nums mb-0.5 break-all">{kpi.value}</p>
            <p className="text-xs text-muted-foreground leading-tight">{kpi.label}</p>
          </div>
        ))}
      </div>
      {/* Fare distinction note */}
      {kpis && (
        <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
          <span>
            <span className="font-medium text-info">Expected Fare</span> = booked, not yet collected &nbsp;·&nbsp;
            <span className="font-medium text-success">Fare Collected</span> = driver-confirmed receipts
          </span>
          {lastRefreshedStr && (
            <span className="flex items-center gap-1 ml-auto">
              <RefreshCw size={10} />
              Updated {lastRefreshedStr}
            </span>
          )}
        </div>
      )}
    </div>
  );
}
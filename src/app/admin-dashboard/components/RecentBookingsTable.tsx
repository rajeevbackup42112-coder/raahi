'use client';
import React, { useState, useEffect, useCallback } from 'react';
import { Search, RefreshCw } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

interface Booking {
  id: string;
  passenger: string;
  phone: string;
  route: string;
  pickup: string;
  seats: number;
  fare: number;
  status: string;
  time: string;
}

const statusConfig: Record<string, string> = {
  confirmed: 'status-confirmed',
  completed: 'status-active',
  cancelled: 'status-full',
  pending: 'status-waiting',
  queued: 'status-waiting',
  matching: 'bg-primary/10 text-primary',
  assigned: 'status-active',
};

export default function RecentBookingsTable() {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');

  const loadBookings = useCallback(async () => {
    const supabase = createClient();
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const { data, error } = await supabase
      .from('bookings')
      .select(`
        id,
        seats,
        total_fare,
        status,
        created_at,
        profiles!bookings_passenger_id_fkey(name, phone),
        trip:trips(route:routes(from_location, to_location)),
        pickup_points!bookings_pickup_point_id_fkey(name)
      `)
      .gte('created_at', todayStart.toISOString())
      .order('created_at', { ascending: false })
      .limit(50);

    if (error || !data) {
      setLoading(false);
      return;
    }

    const mapped: Booking[] = data.map((b: any) => ({
      id: b.id.slice(0, 8).toUpperCase(),
      passenger: b.profiles?.name ?? 'Unknown',
      phone: b.profiles?.phone ?? '—',
      route: b.trip?.route ? `${b.trip.route.from_location} → ${b.trip.route.to_location}` : '—',
      pickup: b.pickup_points?.name ?? '—',
      seats: b.seats ?? 1,
      fare: b.total_fare ?? 0,
      status: b.status ?? 'pending',
      time: new Date(b.created_at).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }),
    }));

    setBookings(mapped);
    setLoading(false);
  }, []);

  useEffect(() => { loadBookings(); }, [loadBookings]);

  const filtered = bookings.filter((b) => {
    const matchSearch = b.passenger.toLowerCase().includes(search.toLowerCase()) || b.id.toLowerCase().includes(search.toLowerCase());
    const matchStatus = statusFilter === 'all' || b.status === statusFilter;
    return matchSearch && matchStatus;
  });

  const totalFare = filtered.reduce((a, b) => a + b.fare, 0);

  return (
    <div className="card-base overflow-hidden">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 px-5 py-4 border-b">
        <div>
          <h2 className="font-semibold text-sm text-foreground">Today&apos;s Bookings</h2>
          <p className="text-xs text-muted-foreground mt-0.5">{bookings.length} total</p>
        </div>
        <div className="flex items-center gap-2 w-full sm:w-auto">
          <div className="flex items-center gap-2 px-3 py-2 rounded-xl border bg-muted text-sm flex-1 sm:flex-none sm:w-48">
            <Search size={13} className="text-muted-foreground shrink-0" />
            <input
              type="text"
              placeholder="Search passenger..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="bg-transparent text-sm outline-none w-full placeholder:text-muted-foreground"
            />
          </div>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="input-field text-xs py-2 w-28"
          >
            <option value="all">All status</option>
            <option value="confirmed">Confirmed</option>
            <option value="completed">Completed</option>
            <option value="cancelled">Cancelled</option>
            <option value="queued">Queued</option>
          </select>
          <button
            onClick={loadBookings}
            className="p-2 rounded-xl border hover:bg-muted transition-colors"
            aria-label="Refresh bookings"
          >
            <RefreshCw size={14} className="text-muted-foreground" />
          </button>
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b bg-muted/50">
              <th className="text-left px-4 py-3 section-label text-xs">Booking ID</th>
              <th className="text-left px-4 py-3 section-label text-xs">Passenger</th>
              <th className="text-left px-4 py-3 section-label text-xs hidden md:table-cell">Route</th>
              <th className="text-left px-4 py-3 section-label text-xs hidden lg:table-cell">Pickup</th>
              <th className="text-left px-4 py-3 section-label text-xs">Seats</th>
              <th className="text-left px-4 py-3 section-label text-xs">Fare</th>
              <th className="text-left px-4 py-3 section-label text-xs">Status</th>
              <th className="text-left px-4 py-3 section-label text-xs hidden sm:table-cell">Time</th>
            </tr>
          </thead>
          <tbody className="divide-y">
            {loading ? (
              Array.from({ length: 4 }).map((_, i) => (
                <tr key={i}>
                  <td colSpan={8} className="px-4 py-3">
                    <div className="h-4 bg-muted rounded animate-pulse" />
                  </td>
                </tr>
              ))
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-4 py-12 text-center text-sm text-muted-foreground">
                  {bookings.length === 0 ? 'No bookings today yet.' : 'No bookings match your search.'}
                </td>
              </tr>
            ) : (
              filtered.map((booking) => (
                <tr key={booking.id} className="hover:bg-muted/30 transition-colors">
                  <td className="px-4 py-3">
                    <span className="text-xs font-mono text-muted-foreground">{booking.id}</span>
                  </td>
                  <td className="px-4 py-3">
                    <p className="font-semibold text-foreground">{booking.passenger}</p>
                    <p className="text-xs text-muted-foreground">{booking.phone}</p>
                  </td>
                  <td className="px-4 py-3 hidden md:table-cell">
                    <span className="text-xs font-medium">{booking.route}</span>
                  </td>
                  <td className="px-4 py-3 hidden lg:table-cell">
                    <span className="text-xs text-muted-foreground">{booking.pickup}</span>
                  </td>
                  <td className="px-4 py-3">
                    <span className="font-semibold tabular-nums">{booking.seats}</span>
                  </td>
                  <td className="px-4 py-3">
                    <span className="font-semibold tabular-nums">₹{booking.fare}</span>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`text-xs font-semibold px-2 py-0.5 rounded-full capitalize ${statusConfig[booking.status] ?? 'status-waiting'}`}>
                      {booking.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 hidden sm:table-cell">
                    <span className="text-xs text-muted-foreground">{booking.time}</span>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="px-5 py-3 border-t flex items-center justify-between text-xs text-muted-foreground">
        <span>Showing {filtered.length} of {bookings.length} bookings</span>
        {totalFare > 0 && (
          <span className="font-semibold text-foreground">Total: ₹{totalFare.toLocaleString('en-IN')}</span>
        )}
      </div>
    </div>
  );
}
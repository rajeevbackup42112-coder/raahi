import React from 'react';
import Link from 'next/link';
import { ArrowRight, CheckCircle, XCircle, Clock } from 'lucide-react';

// NOTE: Fetched from Supabase `bookings` table filtered by passenger_id
const recentBookings = [
  {
    id: 'booking-0041',
    routeFrom: 'Gomoh',
    routeTo: 'Dhanbad',
    date: '09 Aug 2026',
    time: '08:15 AM',
    seats: 1,
    fare: '₹150',
    status: 'confirmed',
    pickupPoint: 'Gomoh Railway Station',
  },
  {
    id: 'booking-0038',
    routeFrom: 'Dhanbad',
    routeTo: 'Gomoh',
    date: '08 Aug 2026',
    time: '06:30 PM',
    seats: 1,
    fare: '₹150',
    status: 'completed',
    pickupPoint: 'Dhanbad Bus Stand',
  },
  {
    id: 'booking-0031',
    routeFrom: 'Gomoh',
    routeTo: 'Dhanbad',
    date: '07 Aug 2026',
    time: '08:00 AM',
    seats: 2,
    fare: '₹300',
    status: 'completed',
    pickupPoint: 'Sindri Road Crossing',
  },
  {
    id: 'booking-0025',
    routeFrom: 'Gomoh',
    routeTo: 'Dhanbad',
    date: '05 Aug 2026',
    time: '08:15 AM',
    seats: 1,
    fare: '₹150',
    status: 'cancelled',
    pickupPoint: 'Gomoh Railway Station',
  },
];

const statusConfig: Record<string, { label: string; className: string; icon: React.ElementType }> = {
  confirmed: { label: 'Confirmed', className: 'status-confirmed', icon: CheckCircle },
  completed: { label: 'Completed', className: 'status-active', icon: CheckCircle },
  cancelled: { label: 'Cancelled', className: 'status-full', icon: XCircle },
  pending: { label: 'Pending', className: 'status-waiting', icon: Clock },
};

export default function RecentBookings() {
  return (
    <div className="card-base p-5">
      <div className="flex items-center justify-between mb-4">
        <h2 className="font-semibold text-sm text-foreground">Recent bookings</h2>
        <button className="text-xs text-primary font-semibold hover:underline">View all →</button>
      </div>

      {recentBookings.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-10 gap-3">
          <div className="w-12 h-12 rounded-2xl bg-muted flex items-center justify-center">
            <Clock size={22} className="text-muted-foreground" />
          </div>
          <p className="font-semibold text-sm text-foreground">No bookings yet</p>
          <p className="text-xs text-muted-foreground text-center max-w-xs">Your booking history will appear here. Reserve your first seat to get started.</p>
          <Link href="/route-selection" className="btn-primary text-sm px-4 py-2 mt-1">Book your first seat</Link>
        </div>
      ) : (
        <div className="flex flex-col divide-y">
          {recentBookings.map((booking) => {
            const s = statusConfig[booking.status] || statusConfig.pending;
            return (
              <div key={booking.id} className="flex items-center justify-between py-3.5 gap-3">
                <div className="flex items-center gap-3 min-w-0">
                  <div className={`w-8 h-8 rounded-xl flex items-center justify-center shrink-0 ${s.className}`}>
                    <s.icon size={14} />
                  </div>
                  <div className="min-w-0">
                    <div className="flex items-center gap-1.5 text-sm font-semibold text-foreground">
                      <span className="truncate">{booking.routeFrom}</span>
                      <ArrowRight size={11} className="text-muted-foreground shrink-0" />
                      <span className="truncate">{booking.routeTo}</span>
                    </div>
                    <p className="text-xs text-muted-foreground truncate">{booking.date} · {booking.time} · {booking.pickupPoint}</p>
                  </div>
                </div>
                <div className="text-right shrink-0">
                  <p className="text-sm font-bold text-foreground tabular-nums">{booking.fare}</p>
                  <span className={`text-xs font-semibold px-1.5 py-0.5 rounded-full ${s.className}`}>{s.label}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
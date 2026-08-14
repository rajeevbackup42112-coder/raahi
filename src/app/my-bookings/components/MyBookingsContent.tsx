'use client';
import React, { useState, useEffect, useCallback } from 'react';
import { ArrowRight, CheckCircle, XCircle, Clock, AlertCircle, Phone } from 'lucide-react';
import { toast } from 'sonner';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import PassengerHeader from '@/components/PassengerHeader';
import Link from 'next/link';
import { useMemo, useRef } from 'react';

interface Booking {
  id: string;
  seats: number;
  fare_per_seat: number;
  total_fare: number;
  status: string;
  booking_status: string;
  queue_status: string;
  booked_at: string;
  pickup_name: string;
  route_from: string;
  route_to: string;
  trip_id?: string;
  trip_status: string;
  vehicle_make: string;
  vehicle_model: string;
  fare_collected: boolean;
  fare_collected_at: string | null;
}

interface DriverContact {
  found: boolean;
  driver_name?: string;
  driver_phone?: string;
  trip_id?: string;
  trip_status?: string;
  vehicle_registration?: string;
  vehicle_make?: string;
  vehicle_model?: string;
  vehicle_color?: string;
}

interface CancellationFee {
  booking_id: string;
  cancellation_fee: number;
  status: string;
}

const TERMINAL_BOOKING_STATUSES = ['completed', 'COMPLETED', 'cancelled', 'CANCELLED', 'no_show'];
const TERMINAL_TRIP_STATUSES = ['completed', 'cancelled'];

function hasActiveBookings(bookings: Booking[]): boolean {
  return bookings.some((b) => {
    const bookingTerminal = TERMINAL_BOOKING_STATUSES.includes(b.booking_status);
    const tripTerminal = b.trip_status && TERMINAL_TRIP_STATUSES.includes(b.trip_status);
    return !bookingTerminal && !tripTerminal;
  });
}

export default function MyBookingsContent() {
  const { profile } = useAuth();
  const supabase = useMemo(() => createClient(), []);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [cancellationFees, setCancellationFees] = useState<CancellationFee[]>([]);
  const [driverContact, setDriverContact] = useState<DriverContact | null>(null);
  const [loading, setLoading] = useState(true);
  const [cancellingId, setCancellingId] = useState<string | null>(null);
  const activeRef = useRef(false);

  const loadDriverContact = useCallback(async () => {
    if (!profile?.id) return;
    try {
      const { data } = await supabase.rpc('get_passenger_trip_contact');
      if (data) setDriverContact(data as DriverContact);
    } catch {
      // Silently handle
    }
  }, [profile?.id, supabase]);

  const loadBookings = useCallback(async () => {
    if (!profile?.id) return;
    try {
      const { data, error: rpcErr } = await supabase.rpc('get_my_bookings');
      if (rpcErr) { console.error('[GET_MY_BOOKINGS_ERROR]', rpcErr); return; }
      const result = data as { bookings: Booking[] };
      if (result?.bookings) {
        setBookings(result.bookings);
        activeRef.current = hasActiveBookings(result.bookings);
      }
      const { data: fees } = await supabase
        .from('cancellations')
        .select('booking_id, cancellation_fee, status')
        .eq('cancelled_by', profile.id)
        .eq('status', 'pending');
      if (fees) setCancellationFees(fees);
    } catch (err) {
      console.error('[GET_MY_BOOKINGS_EXCEPTION]', err);
    } finally {
      setLoading(false);
    }
  }, [profile?.id, supabase]);

  useEffect(() => {
    loadBookings();
    loadDriverContact();
  }, [loadBookings, loadDriverContact]);

  // Realtime subscriptions
  useEffect(() => {
    if (!profile?.id) return;
    const channel = supabase
      .channel(`pax-my-bookings-${profile.id}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings', filter: `passenger_id=eq.${profile.id}` }, () => { loadBookings(); loadDriverContact(); })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'passenger_queue', filter: `passenger_id=eq.${profile.id}` }, () => { loadBookings(); loadDriverContact(); })
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'trips' }, () => { loadBookings(); loadDriverContact(); })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [profile?.id, loadBookings, loadDriverContact, supabase]);

  // Fallback polling
  useEffect(() => {
    if (!profile?.id) return;
    const intervalId = setInterval(() => {
      if (activeRef.current) { loadBookings(); loadDriverContact(); }
    }, 12000);
    return () => { clearInterval(intervalId); };
  }, [profile?.id, loadBookings, loadDriverContact]);

  const handleCancel = async (bookingId: string) => {
    if (!profile?.id) return;
    setCancellingId(bookingId);
    try {
      const { data, error } = await supabase.rpc('cancel_booking', { p_booking_id: bookingId });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Cancellation failed'); return; }
      toast.success(result.message || 'Booking cancelled');
      await loadBookings();
    } catch (err: any) {
      toast.error(err?.message || 'Cancellation failed');
    } finally {
      setCancellingId(null);
    }
  };

  const statusConfig: Record<string, { icon: React.ElementType; color: string; label: string }> = {
    confirmed:   { icon: CheckCircle, color: 'text-success',    label: 'Seat Reserved' },
    queued:      { icon: Clock,       color: 'text-warning',    label: 'Waiting for Driver' },
    WAITING:     { icon: Clock,       color: 'text-warning',    label: 'Waiting for Driver' },
    matching:    { icon: Clock,       color: 'text-blue-500',   label: 'Waiting for Driver' },
    MATCHING:    { icon: Clock,       color: 'text-blue-500',   label: 'Waiting for Driver' },
    assigned:    { icon: CheckCircle, color: 'text-success',    label: 'Driver Assigned' },
    ASSIGNED:    { icon: CheckCircle, color: 'text-success',    label: 'Driver Assigned' },
    in_progress: { icon: CheckCircle, color: 'text-primary',    label: 'Trip in Progress' },
    cancelled:   { icon: XCircle,     color: 'text-danger',     label: 'Booking Cancelled' },
    CANCELLED:   { icon: XCircle,     color: 'text-danger',     label: 'Booking Cancelled' },
    completed:   { icon: CheckCircle, color: 'text-primary',    label: 'Trip Completed' },
    COMPLETED:   { icon: CheckCircle, color: 'text-primary',    label: 'Trip Completed' },
    no_show:     { icon: AlertCircle, color: 'text-orange-500', label: 'Marked No Show' },
    NO_SHOW:     { icon: AlertCircle, color: 'text-orange-500', label: 'Marked No Show' },
  };

  const totalOutstandingFees = cancellationFees.reduce((sum, f) => sum + f.cancellation_fee, 0);

  const canCancelBooking = (booking: Booking) => {
    const activeStatuses = ['confirmed', 'queued', 'WAITING', 'matching', 'MATCHING', 'assigned', 'ASSIGNED'];
    if (!activeStatuses.includes(booking.status)) return false;
    // KEY FIX: also block cancel if the associated trip is terminal
    // This prevents the stale "Cancel Booking" button on historical bookings
    if (booking.trip_status && ['in_progress', 'completed', 'cancelled', 'COMPLETED', 'CANCELLED'].includes(booking.trip_status)) return false;
    return true;
  };

  const isAssignedBooking = (booking: Booking) =>
    ['assigned', 'ASSIGNED'].includes(booking.status) || ['assigned', 'ASSIGNED'].includes(booking.queue_status);

  return (
    <div className="min-h-screen bg-background">
      <PassengerHeader />
      <div className="max-w-2xl mx-auto px-4 py-8">
        <h1 className="text-2xl font-bold text-foreground mb-6">My Bookings</h1>

        {/* Driver contact card — shown only when assigned to active trip */}
        {driverContact?.found && driverContact.driver_phone && (
          <div className="card-base p-4 mb-5 border-success/30 bg-green-50/50">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="text-sm font-bold text-foreground mb-0.5">Your Driver</p>
                <p className="text-sm text-muted-foreground">{driverContact.driver_name}</p>
                {driverContact.vehicle_make && (
                  <p className="text-xs text-muted-foreground mt-0.5">
                    {driverContact.vehicle_make} {driverContact.vehicle_model}
                    {driverContact.vehicle_registration ? ` · ${driverContact.vehicle_registration}` : ''}
                    {driverContact.vehicle_color ? ` · ${driverContact.vehicle_color}` : ''}
                  </p>
                )}
              </div>
              <a
                href={`tel:${driverContact.driver_phone}`}
                className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-success text-white text-sm font-semibold hover:bg-success/90 transition-colors shrink-0"
              >
                <Phone size={14} />
                Call Driver
              </a>
            </div>
          </div>
        )}

        {/* Outstanding fees */}
        {totalOutstandingFees > 0 && (
          <div className="card-base p-4 mb-5 border-warning bg-yellow-50">
            <div className="flex items-center gap-2">
              <AlertCircle size={16} className="text-warning shrink-0" />
              <p className="text-sm font-semibold text-warning">Outstanding cancellation fee: ₹{totalOutstandingFees}</p>
            </div>
            <p className="text-xs text-muted-foreground mt-1 ml-6">Please pay this fee to the driver or admin at your next ride.</p>
          </div>
        )}

        {loading ? (
          <div className="flex flex-col gap-4">
            {[1, 2, 3].map((i) => <div key={i} className="card-base p-5 h-28 animate-pulse bg-muted" />)}
          </div>
        ) : bookings.length === 0 ? (
          <div className="card-base p-10 text-center">
            <Clock size={32} className="text-muted-foreground mx-auto mb-3" />
            <p className="text-muted-foreground mb-1 font-medium">No active bookings.</p>
            <p className="text-sm text-muted-foreground mb-4">Your booking history will appear here.</p>
            <Link href="/available-routes" className="btn-primary inline-flex">Book a ride</Link>
          </div>
        ) : (
          <div className="flex flex-col gap-4">
            {bookings.map((booking) => {
              const sc = statusConfig[booking.status] || { icon: Clock, color: 'text-muted-foreground', label: booking.status };
              const StatusIcon = sc.icon;
              const canCancel = canCancelBooking(booking);
              const isAssigned = isAssignedBooking(booking);

              return (
                <div key={booking.id} className="card-base p-5">
                  <div className="flex items-start justify-between gap-3 mb-3">
                    <div>
                      <div className="flex items-center gap-1.5 text-base font-bold text-foreground">
                        <span>{booking.route_from || '—'}</span>
                        <ArrowRight size={14} className="text-primary" />
                        <span>{booking.route_to || '—'}</span>
                      </div>
                      <p className="text-xs text-muted-foreground mt-0.5">
                        {booking.vehicle_make && booking.vehicle_model ? `${booking.vehicle_make} ${booking.vehicle_model}` : ''}
                        {booking.pickup_name ? ` · ${booking.pickup_name}` : ''}
                      </p>
                    </div>
                    <div className="flex items-center gap-1.5 shrink-0">
                      <StatusIcon size={14} className={sc.color} />
                      <span className={`text-xs font-semibold ${sc.color}`}>{sc.label}</span>
                    </div>
                  </div>

                  <div className="grid grid-cols-3 gap-2 text-xs mb-3">
                    <div className="p-2 bg-muted rounded-lg">
                      <p className="text-muted-foreground">Seats</p>
                      <p className="font-semibold text-foreground tabular-nums">{booking.seats}</p>
                    </div>
                    <div className="p-2 bg-muted rounded-lg">
                      <p className="text-muted-foreground">Fare</p>
                      <p className="font-semibold text-foreground tabular-nums">₹{booking.total_fare}</p>
                    </div>
                    <div className="p-2 bg-muted rounded-lg">
                      <p className="text-muted-foreground">Pickup</p>
                      <p className="font-semibold text-foreground truncate">{booking.pickup_name || '—'}</p>
                    </div>
                  </div>

                  {/* Fare collection status */}
                  {isAssigned && (
                    <div className={`flex items-center gap-2 p-2.5 rounded-lg mb-3 text-xs ${booking.fare_collected ? 'bg-green-50 text-success' : 'bg-yellow-50 text-warning'}`}>
                      {booking.fare_collected ? (
                        <>
                          <CheckCircle size={13} />
                          <span className="font-semibold">Fare Collected ✓ — Your seat is confirmed for travel.</span>
                        </>
                      ) : (
                        <>
                          <AlertCircle size={13} />
                          <span className="font-semibold">Pay ₹{booking.total_fare} directly to the driver at your pickup point.</span>
                        </>
                      )}
                    </div>
                  )}

                  {/* Pre-assignment fare info — only for active non-terminal bookings */}
                  {!isAssigned && !['cancelled', 'CANCELLED', 'no_show', 'NO_SHOW', 'completed', 'COMPLETED'].includes(booking.booking_status) && (
                    <div className="flex items-center gap-2 p-2.5 rounded-lg mb-3 text-xs bg-blue-50 text-blue-700">
                      <AlertCircle size={13} />
                      <span>Seat Reserved — Pay ₹{booking.total_fare} directly to the driver at your pickup point.</span>
                    </div>
                  )}

                  <div className="flex items-center justify-between">
                    <p className="text-xs text-muted-foreground">
                      {new Date(booking.booked_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })}
                    </p>
                    {canCancel && (
                      <button
                        onClick={() => handleCancel(booking.id)}
                        disabled={cancellingId === booking.id}
                        className="text-xs text-danger hover:underline disabled:opacity-50"
                      >
                        {cancellingId === booking.id ? 'Cancelling…' : 'Cancel Booking'}
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

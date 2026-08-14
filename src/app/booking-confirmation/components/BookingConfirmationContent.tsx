'use client';
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { CheckCircle, ArrowRight, AlertCircle, Clock, Car, User, RefreshCw } from 'lucide-react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import PassengerHeader from '@/components/PassengerHeader';

// Status config — covers both booking_status and queue_status values
const STATUS_CONFIG: Record<string, { label: string; color: string; description: string }> = {
  queued:      { label: 'Waiting for Driver',   color: 'bg-yellow-100 text-yellow-700',  description: 'You are in the queue. A driver will be matched when capacity is reached.' },
  WAITING:     { label: 'Waiting for Driver',   color: 'bg-yellow-100 text-yellow-700',  description: 'You are in the queue. A driver will be matched when capacity is reached.' },
  matching:    { label: 'Waiting for Driver',   color: 'bg-blue-100 text-blue-700',      description: 'A driver offer is being confirmed. Your vehicle will be assigned shortly.' },
  MATCHING:    { label: 'Waiting for Driver',   color: 'bg-blue-100 text-blue-700',      description: 'A driver offer is being confirmed. Your vehicle will be assigned shortly.' },
  assigned:    { label: 'Driver Assigned',      color: 'bg-green-100 text-green-700',    description: 'Your driver has confirmed the ride. Get ready to board at your pickup point.' },
  ASSIGNED:    { label: 'Driver Assigned',      color: 'bg-green-100 text-green-700',    description: 'Your driver has confirmed the ride. Get ready to board at your pickup point.' },
  confirmed:   { label: 'Seat Reserved',        color: 'bg-green-100 text-green-700',    description: 'Your seat is reserved. Pay the fare directly to the driver at your pickup point.' },
  CONFIRMED:   { label: 'Seat Reserved',        color: 'bg-green-100 text-green-700',    description: 'Your seat is reserved. Pay the fare directly to the driver at your pickup point.' },
  in_progress: { label: 'Trip in Progress',     color: 'bg-primary/10 text-primary',     description: 'Your trip is currently in progress.' },
  completed:   { label: 'Trip Completed',       color: 'bg-muted text-muted-foreground', description: 'Your trip has been completed.' },
  COMPLETED:   { label: 'Trip Completed',       color: 'bg-muted text-muted-foreground', description: 'Your trip has been completed.' },
  cancelled:   { label: 'Booking Cancelled',    color: 'bg-red-100 text-red-700',        description: 'This booking has been cancelled.' },
  CANCELLED:   { label: 'Booking Cancelled',    color: 'bg-red-100 text-red-700',        description: 'This booking has been cancelled.' },
  no_show:     { label: 'Marked No Show',       color: 'bg-orange-100 text-orange-700',  description: 'You were marked as no-show for this trip.' },
  NO_SHOW:     { label: 'Marked No Show',       color: 'bg-orange-100 text-orange-700',  description: 'You were marked as no-show for this trip.' },
};

interface BookingData {
  found: boolean;
  error?: string;
  booking_id: string;
  seats: number;
  fare_per_seat: number;
  total_fare: number;
  booking_status: string;
  booked_at: string;
  // Route — resolved via RPC (queue route or trip route)
  route_from: string;
  route_to: string;
  // Pickup
  pickup_name: string;
  pickup_landmark: string;
  // Queue
  queue_id?: string;
  queue_status?: string;
  queue_position?: number;
  passengers_ahead?: number;
  seat_count?: number;
  // Trip / assignment
  trip_id?: string;
  trip_status?: string;
  assigned_trip_id?: string;
  // Vehicle
  vehicle_make?: string;
  vehicle_model?: string;
  vehicle_registration?: string;
  // Driver
  driver_name?: string;
  driver_phone?: string;
}

export default function BookingConfirmationContent() {
  const searchParams = useSearchParams();
  const { profile } = useAuth();
  const supabase = useMemo(() => createClient(), []);

  const bookingId = searchParams.get('booking');
  const [bookingData, setBookingData] = useState<BookingData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [errorIsRpc, setErrorIsRpc] = useState(false);

  const loadBooking = useCallback(async () => {
    if (!bookingId || !profile?.id) return;
    try {
      const { data, error: rpcErr } = await supabase.rpc('get_passenger_booking', {
        p_booking_id: bookingId,
      });

      if (rpcErr) {
        console.error('[GET_PASSENGER_BOOKING_ERROR]', rpcErr);
        setError('Failed to load booking details');
        setErrorIsRpc(true);
        return;
      }

      const result = data as BookingData;
      if (!result?.found) {
        setError(result?.error || 'Booking not found');
        setErrorIsRpc(false);
        return;
      }

      setBookingData(result);
      setError('');
      setErrorIsRpc(false);
    } catch (err) {
      console.error('[GET_PASSENGER_BOOKING_EXCEPTION]', err);
      setError('Failed to load booking details');
      setErrorIsRpc(true);
    } finally {
      setLoading(false);
    }
  }, [bookingId, profile?.id, supabase]);

  useEffect(() => {
    if (!bookingId) { setLoading(false); return; }
    loadBooking();
  }, [bookingId, loadBooking]);

  // Realtime: subscribe to bookings + passenger_queue (by booking_id) + trips (by trip_id when known)
  useEffect(() => {
    if (!bookingId || !profile?.id) return;

    const tripId = bookingData?.trip_id || bookingData?.assigned_trip_id;

    // Build a single channel with multiple listeners for stable channel naming
    const channelName = `pax-booking-${bookingId}`;
    const channel = supabase
      .channel(channelName)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'passenger_queue',
        filter: `booking_id=eq.${bookingId}`,
      }, () => { loadBooking(); })
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'bookings',
        filter: `id=eq.${bookingId}`,
      }, () => { loadBooking(); });

    // Subscribe to the specific trip if we know it; otherwise subscribe to all trips
    // (catches the case where trip_id is assigned after queue → confirmed transition)
    if (tripId) {
      channel.on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'trips',
        filter: `id=eq.${tripId}`,
      }, () => { loadBooking(); });
    } else {
      // No trip yet — subscribe broadly so we catch the moment a trip is assigned
      channel.on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'trips',
      }, () => { loadBooking(); });
    }

    channel.subscribe();

    return () => { supabase.removeChannel(channel); };
  }, [bookingId, profile?.id, bookingData?.trip_id, bookingData?.assigned_trip_id, loadBooking, supabase]);

  // Fallback polling — only while booking is in an active (non-terminal) state
  useEffect(() => {
    if (!bookingId || !profile?.id) return;

    const terminalStatuses = ['completed', 'COMPLETED', 'cancelled', 'CANCELLED'];
    const bookingStatus = bookingData?.booking_status;
    const tripStatus = bookingData?.trip_status;

    // Stop polling once terminal
    const isTerminal =
      (bookingStatus && terminalStatuses.includes(bookingStatus)) ||
      (tripStatus && ['completed', 'cancelled'].includes(tripStatus));

    if (isTerminal) return;

    // Poll every 12 seconds as resilience fallback
    const intervalId = setInterval(() => {
      loadBooking();
    }, 12000);

    return () => { clearInterval(intervalId); };
  }, [bookingId, profile?.id, bookingData?.booking_status, bookingData?.trip_status, loadBooking]);

  if (loading) {
    return (
      <div className="min-h-screen bg-background">
        <PassengerHeader />
        <div className="flex items-center justify-center py-20">
          <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      </div>
    );
  }

  if (!bookingId) {
    return (
      <div className="min-h-screen bg-background">
        <PassengerHeader />
        <div className="max-w-lg mx-auto px-4 py-16 text-center">
          <AlertCircle size={40} className="text-danger mx-auto mb-3" />
          <h2 className="font-bold text-foreground mb-2">No Booking Selected</h2>
          <p className="text-sm text-muted-foreground mb-5">Please select a booking to view details.</p>
          <Link href="/available-routes" className="btn-primary inline-flex">Back to Routes</Link>
        </div>
      </div>
    );
  }

  if (error || !bookingData) {
    return (
      <div className="min-h-screen bg-background">
        <PassengerHeader />
        <div className="max-w-lg mx-auto px-4 py-16 text-center">
          <AlertCircle size={40} className="text-danger mx-auto mb-3" />
          <h2 className="font-bold text-foreground mb-2">
            {errorIsRpc ? 'Unable to Load Booking' : 'Booking Not Found'}
          </h2>
          <p className="text-sm text-muted-foreground mb-5">{error || 'Unable to load booking details.'}</p>
          <Link href="/available-routes" className="btn-primary inline-flex">Back to Routes</Link>
        </div>
      </div>
    );
  }

  const bookingRef = bookingData.booking_id.slice(0, 8).toUpperCase();

  // Determine effective status: trip_status takes highest priority for in_progress/completed
  // queue_status takes precedence for active queue entries otherwise
  const effectiveStatus = (() => {
    const ts = bookingData.trip_status;
    const qs = bookingData.queue_status;
    const bs = bookingData.booking_status;
    // Trip in progress or completed overrides queue status
    if (ts === 'in_progress') return 'in_progress';
    if (ts === 'completed') return 'completed';
    if (qs && !['CANCELLED', 'COMPLETED', ''].includes(qs) && !['cancelled', 'completed', 'no_show'].includes(bs)) {
      return qs;
    }
    return bs;
  })();

  const statusCfg = STATUS_CONFIG[effectiveStatus] ?? {
    label: effectiveStatus,
    color: 'bg-muted text-muted-foreground',
    description: '',
  };

  const isAssigned = ['ASSIGNED', 'assigned', 'confirmed', 'CONFIRMED', 'in_progress'].includes(effectiveStatus);
  const isMatching = ['MATCHING', 'matching'].includes(effectiveStatus);
  const isCancelled = ['cancelled', 'CANCELLED'].includes(bookingData.booking_status);
  const isCompleted = ['completed', 'COMPLETED'].includes(bookingData.booking_status);
  const isNoShow = bookingData.booking_status === 'no_show';
  const isWaiting = !isAssigned && !isMatching && !isCancelled && !isCompleted && !isNoShow;

  const hasQueuePosition = (isWaiting || isMatching) && bookingData.queue_id && bookingData.queue_position != null;
  const hasVehicle = isAssigned && (bookingData.vehicle_make || bookingData.driver_name);

  return (
    <div className="min-h-screen bg-background">
      <PassengerHeader />
      <div className="max-w-lg mx-auto px-4 py-6 pb-10">

        {/* Status header */}
        <div className="flex flex-col items-center mb-6">
          <div className={`w-16 h-16 rounded-full flex items-center justify-center mb-3 ${
            isCancelled ? 'bg-red-100' : isNoShow ? 'bg-orange-100' : isCompleted ? 'bg-muted' : isAssigned ? 'bg-green-100' : 'bg-secondary'
          }`}>
            {isCancelled
              ? <AlertCircle size={36} className="text-danger" />
              : isNoShow
              ? <AlertCircle size={36} className="text-orange-500" />
              : isCompleted
              ? <CheckCircle size={36} className="text-muted-foreground" />
              : isAssigned
              ? <Car size={36} className="text-success" />
              : <Clock size={36} className="text-primary" />
            }
          </div>
          <h1 className="text-xl font-bold text-foreground mb-1">
            {isCancelled
              ? 'Booking Cancelled'
              : isNoShow
              ? 'Marked No Show'
              : isCompleted
              ? 'Trip Completed'
              : isAssigned
              ? 'Driver Assigned' :'Seat Reserved'}
          </h1>
          <span className={`text-xs font-semibold px-3 py-1 rounded-full ${statusCfg.color}`}>
            {statusCfg.label}
          </span>
          {statusCfg.description && (
            <p className="text-sm text-muted-foreground text-center mt-2 max-w-xs">{statusCfg.description}</p>
          )}
        </div>

        {/* Queue Position Card — shown when waiting and queue entry exists */}
        {isWaiting && bookingData.queue_id && (
          <div className="card-base p-5 mb-4 border-primary/20 bg-secondary/30">
            <div className="flex items-center gap-2 mb-4">
              <Clock size={15} className="text-primary" />
              <p className="font-semibold text-sm text-foreground">Queue Position</p>
              <button
                onClick={loadBooking}
                className="ml-auto p-1 rounded-lg hover:bg-muted transition-colors"
                aria-label="Refresh queue status"
              >
                <RefreshCw size={13} className="text-muted-foreground" />
              </button>
            </div>
            <div className="flex items-center justify-center py-3">
              <div className="text-center">
                <p className="text-6xl font-extrabold text-primary tabular-nums">
                  {hasQueuePosition ? `#${bookingData.queue_position}` : '—'}
                </p>
                <p className="text-sm text-muted-foreground mt-1">Your queue position</p>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-3 mt-2">
              <div className="p-3 bg-card rounded-xl text-center">
                <p className="text-2xl font-bold text-foreground tabular-nums">
                  {bookingData.passengers_ahead ?? 0}
                </p>
                <p className="text-xs text-muted-foreground mt-0.5">Passengers ahead</p>
              </div>
              <div className="p-3 bg-card rounded-xl text-center">
                <p className="text-2xl font-bold text-foreground tabular-nums">
                  {bookingData.seat_count ?? bookingData.seats}
                </p>
                <p className="text-xs text-muted-foreground mt-0.5">Your seats</p>
              </div>
            </div>
          </div>
        )}

        {/* Booking details */}
        <div className="card-base p-5 mb-4">
          <p className="section-label mb-3">Booking Details</p>
          <div className="flex flex-col gap-3">
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">Booking Ref</span>
              <span className="text-sm font-mono font-bold text-foreground">{bookingRef}</span>
            </div>
            {(bookingData.route_from || bookingData.route_to) && (
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Route</span>
                <span className="text-sm font-semibold text-foreground flex items-center gap-1">
                  {bookingData.route_from} <ArrowRight size={12} className="text-primary" /> {bookingData.route_to}
                </span>
              </div>
            )}
            {bookingData.pickup_name && (
              <div className="flex items-center justify-between">
                <span className="text-sm text-muted-foreground">Pickup</span>
                <span className="text-sm font-semibold text-foreground">{bookingData.pickup_name}</span>
              </div>
            )}
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">Seats</span>
              <span className="text-sm font-semibold text-foreground tabular-nums">{bookingData.seats}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">Total Fare</span>
              <span className="text-base font-bold text-primary tabular-nums">₹{bookingData.total_fare}</span>
            </div>
          </div>
        </div>

        {/* Driver/Vehicle info — shown when assigned */}
        {hasVehicle && (
          <div className="card-base p-5 mb-4 border-success/30 bg-green-50/50">
            <p className="section-label mb-3">Your Driver</p>
            <div className="flex flex-col gap-2">
              {bookingData.driver_name && (
                <div className="flex items-center gap-2">
                  <User size={14} className="text-muted-foreground" />
                  <span className="text-sm font-semibold text-foreground">{bookingData.driver_name}</span>
                </div>
              )}
              {bookingData.vehicle_make && (
                <div className="flex items-center gap-2">
                  <Car size={14} className="text-muted-foreground" />
                  <span className="text-sm text-foreground">
                    {bookingData.vehicle_make} {bookingData.vehicle_model}
                    {bookingData.vehicle_registration && ` · ${bookingData.vehicle_registration}`}
                  </span>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Actions */}
        <div className="flex flex-col gap-3">
          <Link href="/my-bookings" className="btn-secondary w-full justify-center">
            View All Bookings
          </Link>
          <Link href="/available-routes" className="btn-primary w-full justify-center">
            Book Another Ride
          </Link>
        </div>
      </div>
    </div>
  );
}

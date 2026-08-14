'use client';
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { ArrowRight, MapPin, Users, ChevronDown, Minus, Plus, AlertCircle, CheckCircle, Phone } from 'lucide-react';
import { useSearchParams, useRouter } from 'next/navigation';
import { toast } from 'sonner';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import PassengerHeader from '@/components/PassengerHeader';
import Link from 'next/link';

interface ActiveTripData {
  found: boolean;
  trip_id?: string;
  route_id?: string;
  from_location?: string;
  to_location?: string;
  total_seats?: number;
  booked_seats?: number;
  available_seats?: number;
  fare_per_seat?: number;
  status?: string;
  vehicle_make?: string;
  vehicle_model?: string;
  vehicle_type?: string;
  vehicle_registration?: string;
  driver_name?: string;
}

interface PickupPoint {
  id: string;
  name: string;
  landmark: string | null;
  sequence_order: number;
  direction: string;
}

interface BusinessSettings {
  max_seats_per_booking: number;
  luggage_policy: string;
}

function getBookingErrorMessage(error: string): string {
  const e = error.toLowerCase();
  if (e.includes('no active trip') || e.includes('no vehicle')) return 'No drivers are currently online for this route. You have been added to the queue.';
  // CAPACITY errors: only map when backend returns an EXPLICIT capacity signal.
  // Do NOT match generic 'seats' text — schema errors (e.g. "column seats_requested
  // does not exist") must NOT be classified as insufficient capacity.
  if (e.includes('not enough seats') || e.includes('insufficient seats') || e.includes('no seats available')) return 'Not enough seats available. Try booking fewer seats.';
  if (e.includes('already') && (e.includes('booked') || e.includes('queue'))) return 'You already have an active booking on this route.';
  if (e.includes('route') && e.includes('unavailable')) return 'This route is temporarily unavailable.';
  if (e.includes('route') && e.includes('paused')) return 'This route is temporarily unavailable.';
  if (e.includes('auth') || e.includes('not authenticated')) return 'Your session has expired. Please sign in again.';
  if (e.includes('network') || e.includes('fetch')) return 'Network error. Please check your connection and try again.';
  // Schema/RPC errors (column not found, function not found, etc.) must surface as
  // a generic booking failure — never as a false capacity error.
  if (e.includes('column') || e.includes('function') || e.includes('schema') || e.includes('relation')) return 'Booking failed due to a server error. Please try again or contact support.';
  return 'Booking failed. Please try again.';
}

function getBookingReasonMessage(reason: string, data?: any): string {
  switch (reason) {
    case 'phone_required':
      return 'Add your mobile number before booking.';
    case 'booking_cooldown': {
      const mins = data?.remaining_minutes ?? data?.cooldown_minutes;
      return mins
        ? `Booking temporarily paused after repeated cancellations. Try again in ${mins} minute${mins !== 1 ? 's' : ''}.`
        : 'Booking temporarily paused after repeated cancellations. Please try again later.';
    }
    case 'rate_limited': {
      const secs = data?.retry_after_seconds;
      return secs
        ? `Too many requests. Please wait ${secs} second${secs !== 1 ? 's' : ''} before trying again.`
        : 'Too many requests. Please wait a moment before trying again.';
    }
    case 'account_suspended':
      return 'Your account has been suspended. Please contact support.';
    case 'duplicate_booking':
      return 'You already have an active booking on this route.';
    case 'route_paused':
      return 'This route is temporarily unavailable.';
    case 'no_seats':
      return 'Not enough seats available. Try booking fewer seats.';
    default:
      return getBookingErrorMessage(reason);
  }
}

export default function BookRideContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const { profile } = useAuth();
  const supabase = useMemo(() => createClient(), []);

  const routeId = searchParams.get('route');

  const [activeTrip, setActiveTrip] = useState<ActiveTripData | null>(null);
  const [pickupPoints, setPickupPoints] = useState<PickupPoint[]>([]);
  const [settings, setSettings] = useState<BusinessSettings>({ max_seats_per_booking: 4, luggage_policy: '' });
  const [selectedPickup, setSelectedPickup] = useState<string>('');
  const [seats, setSeats] = useState(1);
  const [loading, setLoading] = useState(true);
  const [booking, setBooking] = useState(false);
  const [showPickupDropdown, setShowPickupDropdown] = useState(false);
  const [routeInfo, setRouteInfo] = useState<{ from_location: string; to_location: string; fare_per_seat: number; min_passengers: number } | null>(null);

  const loadData = useCallback(async () => {
    if (!routeId) return;
    try {
      // Load route info
      const { data: routeData } = await supabase
        .from('routes')
        .select('from_location, to_location, fare_per_seat, min_passengers')
        .eq('id', routeId)
        .eq('status', 'active')
        .single();
      if (routeData) setRouteInfo(routeData);

      // Load active trip (may not exist — queue-only mode is fine)
      const { data: tripData } = await supabase.rpc('get_active_trip_for_route', { p_route_id: routeId });
      setActiveTrip(tripData as ActiveTripData);

      // Load pickup points for this route (active only)
      const { data: pickups } = await supabase
        .from('pickup_points')
        .select('id, name, landmark, sequence_order, direction')
        .eq('route_id', routeId)
        .eq('is_active', true)
        .order('sequence_order');
      if (pickups) setPickupPoints(pickups);

      // Load settings
      const { data: settingsData } = await supabase
        .from('business_settings')
        .select('key, value')
        .in('key', ['max_seats_per_booking', 'luggage_policy']);
      if (settingsData) {
        const s: any = {};
        settingsData.forEach((row) => { s[row.key] = row.value; });
        setSettings({
          max_seats_per_booking: parseInt(s.max_seats_per_booking || '4'),
          luggage_policy: s.luggage_policy || '',
        });
      }
    } catch {
      // Silently handle
    } finally {
      setLoading(false);
    }
  }, [routeId, supabase]);

  useEffect(() => { loadData(); }, [loadData]);

  useEffect(() => {
    if (!routeId) return;
    const channel = supabase
      .channel(`book-ride-${routeId}`)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'trips' }, (payload) => {
        if (payload.new && (payload.new as any).route_id === routeId) {
          loadData();
        }
      })
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [routeId, loadData, supabase]);

  const handleBook = async () => {
    if (!profile) { toast.error('Please sign in to book'); return; }
    if (!selectedPickup) { toast.error('Please select a pickup point'); return; }

    setBooking(true);
    try {
      const { data, error } = await supabase.rpc('book_or_queue', {
        p_route_id: routeId,
        p_pickup_point_id: selectedPickup,
        p_seats: seats,
      });

      if (error) {
        console.error('[BOOK_OR_QUEUE_RAW_ERROR]', {
          message: (error as any).message,
          code: (error as any).code,
          details: (error as any).details,
          hint: (error as any).hint,
        });
        throw error;
      }

      const result = data as any;
      if (!result?.success) {
        // Phone required — redirect to profile
        if (result?.reason === 'phone_required') {
          toast.error('Add your mobile number before booking.');
          router.push('/passenger-profile');
          return;
        }
        // Structured reason codes
        if (result?.reason) {
          toast.error(getBookingReasonMessage(result.reason, result));
          return;
        }
        toast.error(getBookingErrorMessage(result?.error || ''));
        return;
      }

      if (result?.already_queued) {
        // KEY FIX (T2-BUG-01): Only show "already booked" notification when
        // the existing booking is genuinely active (non-terminal trip).
        // If is_genuinely_active=false, the stale guard fired on a historical
        // booking — navigate silently to the booking page to show canonical state.
        if (result?.is_genuinely_active !== false) {
          toast.info('You already have an active booking on this route');
        }
        router.push(`/booking-confirmation?booking=${result.booking_id}`);
        return;
      }

      router.push(`/booking-confirmation?booking=${result.booking_id}`);
    } catch (err: any) {
      toast.error(getBookingErrorMessage(err?.message || ''));
    } finally {
      setBooking(false);
    }
  };

  if (!routeId) {
    return (
      <div className="min-h-screen bg-background">
        <PassengerHeader />
        <div className="max-w-lg mx-auto px-4 py-16 text-center">
          <p className="text-muted-foreground mb-4">No route selected.</p>
          <Link href="/available-routes" className="btn-primary inline-flex">← Back to Routes</Link>
        </div>
      </div>
    );
  }

  if (!loading && !routeInfo) {
    return (
      <div className="min-h-screen bg-background">
        <PassengerHeader />
        <div className="max-w-lg mx-auto px-4 py-16 text-center">
          <AlertCircle size={32} className="text-muted-foreground mx-auto mb-3" />
          <p className="text-muted-foreground mb-4">This route is not available.</p>
          <Link href="/available-routes" className="btn-primary inline-flex">← Back to Routes</Link>
        </div>
      </div>
    );
  }

  const maxSeats = Math.min(settings.max_seats_per_booking, 4);
  const selectedPickupName = pickupPoints.find(p => p.id === selectedPickup)?.name || '';
  const farePerSeat = activeTrip?.fare_per_seat ?? routeInfo?.fare_per_seat ?? 0;
  const fromLocation = activeTrip?.from_location ?? routeInfo?.from_location ?? '';
  const toLocation = activeTrip?.to_location ?? routeInfo?.to_location ?? '';
  const hasActiveDriver = activeTrip?.found === true;

  return (
    <div className="min-h-screen bg-background">
      <PassengerHeader />
      <div className="max-w-lg mx-auto px-4 py-6 pb-10">
        <Link href="/available-routes" className="flex items-center gap-1.5 text-sm text-muted-foreground hover:text-foreground mb-5 transition-colors">
          <ArrowRight size={14} className="rotate-180" /> Back to routes
        </Link>

        {loading ? (
          <div className="flex flex-col gap-4">
            {[1, 2, 3].map((i) => <div key={i} className="card-base p-5 h-24 animate-pulse bg-muted" />)}
          </div>
        ) : (
          <div className="flex flex-col gap-4">
            {/* Route info */}
            <div className="card-base p-5">
              <p className="section-label mb-2">Route</p>
              <div className="flex items-center gap-2 text-xl font-bold text-foreground">
                <span>{fromLocation}</span>
                <ArrowRight size={18} className="text-primary shrink-0" />
                <span>{toLocation}</span>
              </div>
              <p className="text-base font-semibold text-primary mt-1">₹{farePerSeat} / seat</p>
            </div>

            {/* Queue / driver status */}
            {hasActiveDriver ? (
              <div className="card-base p-4 border-success/30 bg-green-50/50">
                <div className="flex items-start gap-3">
                  <CheckCircle size={16} className="text-success shrink-0 mt-0.5" />
                  <div>
                    <p className="font-semibold text-sm text-foreground mb-1">Driver available</p>
                    <p className="text-xs text-muted-foreground">
                      {activeTrip?.available_seats} seat{activeTrip?.available_seats !== 1 ? 's' : ''} available
                      {activeTrip?.vehicle_make ? ` · ${activeTrip.vehicle_make} ${activeTrip.vehicle_model}` : ''}
                    </p>
                  </div>
                </div>
              </div>
            ) : (
              <div className="card-base p-4 border-warning/30 bg-yellow-50/50">
                <div className="flex items-start gap-3">
                  <AlertCircle size={16} className="text-warning shrink-0 mt-0.5" />
                  <div>
                    <p className="font-semibold text-sm text-foreground mb-1">No driver currently online</p>
                    <p className="text-xs text-muted-foreground">
                      You can still join the queue. A driver will be matched automatically when one becomes available.
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* Pickup point */}
            <div className="card-base p-5">
              <p className="section-label mb-3">Pickup Point</p>
              {pickupPoints.length === 0 ? (
                <div className="p-3 bg-muted rounded-xl">
                  <p className="text-sm text-muted-foreground">No pickup points configured for this route. Contact admin.</p>
                </div>
              ) : (
                <div className="relative">
                  <button
                    onClick={() => setShowPickupDropdown(!showPickupDropdown)}
                    className={`w-full flex items-center justify-between p-3.5 rounded-xl border-2 text-left transition-all ${selectedPickup ? 'border-primary bg-secondary' : 'border-border bg-card hover:border-primary/40'}`}
                  >
                    <div className="flex items-center gap-2">
                      <MapPin size={16} className={selectedPickup ? 'text-primary' : 'text-muted-foreground'} />
                      <span className={`text-sm font-medium ${selectedPickup ? 'text-foreground' : 'text-muted-foreground'}`}>
                        {selectedPickupName || 'Select your pickup point'}
                      </span>
                    </div>
                    <ChevronDown size={16} className={`text-muted-foreground transition-transform ${showPickupDropdown ? 'rotate-180' : ''}`} />
                  </button>
                  {showPickupDropdown && (
                    <div className="absolute top-full left-0 right-0 mt-1 bg-card border border-border rounded-xl shadow-elevated z-10 overflow-hidden">
                      {pickupPoints.map((point) => (
                        <button
                          key={point.id}
                          onClick={() => { setSelectedPickup(point.id); setShowPickupDropdown(false); }}
                          className={`w-full flex items-start gap-3 p-3.5 text-left hover:bg-muted transition-colors border-b last:border-b-0 border-border ${selectedPickup === point.id ? 'bg-secondary' : ''}`}
                        >
                          <MapPin size={14} className="text-primary mt-0.5 shrink-0" />
                          <div>
                            <p className="text-sm font-semibold text-foreground">{point.name}</p>
                            {point.landmark && <p className="text-xs text-muted-foreground">{point.landmark}</p>}
                          </div>
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* Seat selection */}
            <div className="card-base p-5">
              <p className="section-label mb-3">Number of Seats</p>
              <div className="flex items-center gap-4">
                <button
                  onClick={() => setSeats(Math.max(1, seats - 1))}
                  className="w-10 h-10 rounded-full border-2 border-border flex items-center justify-center hover:border-primary transition-colors"
                >
                  <Minus size={16} />
                </button>
                <div className="flex-1 text-center">
                  <span className="text-3xl font-bold text-foreground">{seats}</span>
                  <p className="text-xs text-muted-foreground mt-0.5">seat{seats !== 1 ? 's' : ''}</p>
                </div>
                <button
                  onClick={() => setSeats(Math.min(maxSeats, seats + 1))}
                  className="w-10 h-10 rounded-full border-2 border-border flex items-center justify-center hover:border-primary transition-colors"
                >
                  <Plus size={16} />
                </button>
              </div>
              {farePerSeat > 0 && (
                <div className="mt-4 p-3 bg-muted rounded-xl flex items-center justify-between">
                  <span className="text-sm text-muted-foreground">Total fare</span>
                  <span className="text-lg font-bold text-primary">₹{farePerSeat * seats}</span>
                </div>
              )}
            </div>

            {/* Luggage policy */}
            {settings.luggage_policy && (
              <div className="card-base p-4">
                <p className="section-label mb-1">Luggage Policy</p>
                <p className="text-sm text-muted-foreground">{settings.luggage_policy}</p>
              </div>
            )}

            {/* Book button */}
            <button
              onClick={handleBook}
              disabled={booking || !selectedPickup || pickupPoints.length === 0}
              className="btn-primary w-full justify-center py-4 text-base font-bold gap-2"
            >
              {booking ? (
                <span className="w-5 h-5 border-2 border-white/40 border-t-white rounded-full animate-spin" />
              ) : (
                <Users size={18} />
              )}
              {booking ? 'Joining queue...' : 'Join Queue — Pay Driver at Pickup'}
            </button>

            <p className="text-xs text-muted-foreground text-center">
              Seat Reserved. Pay ₹{farePerSeat * seats} directly to the driver at your pickup point.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}

'use client';
import React, { useState, useEffect, useCallback, useMemo, useRef } from 'react';
import AppLogo from '@/components/ui/AppLogo';
import { Home, List, Clock, User, LogOut, Radio, Power, CheckCircle, Play, X, Check, AlertCircle, Users, Timer, ArrowRight, Phone, MapPin, IndianRupee, UserX } from 'lucide-react';
import { toast } from 'sonner';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import DriverProfileContent from './DriverProfileContent';
import DriverTripHistory from './DriverTripHistory';

type DriverTab = 'home' | 'queue' | 'trips' | 'profile';

interface DriverQueueStatus {
  found: boolean;
  queue_entry_id?: string;
  status?: string;
  queue_position?: number;
  drivers_ahead?: number;
  route_from?: string;
  route_to?: string;
  vehicle_make?: string;
  vehicle_model?: string;
  vehicle_registration?: string;
  vehicle_capacity?: number;
  offered_at?: string;
  offer_expires_at?: string;
  provisional_trip_id?: string;
  passenger_count?: number;
  fare_per_seat?: number;
  offer_timeout_seconds?: number;
  trip_id?: string;
  trip_status?: string;
  booked_seats?: number;
  total_seats?: number;
  seats_needed_to_dispatch?: number;
  waiting_passenger_seats?: number;
  ready_to_dispatch?: boolean;
  min_passengers?: number;
  can_depart?: boolean;
  is_full?: boolean;
  departure_lock_expires_at?: string;
  departure_lock_remaining_seconds?: number;
}

interface PickupPassenger {
  booking_id: string;
  passenger_name: string;
  passenger_phone: string | null;
  seats: number;
  fare_due: number;
  fare_collected: boolean;
  fare_collected_at: string | null;
  booking_status: string;
  queue_status: string;
}

interface PickupGroup {
  pickup_point_id: string;
  pickup_name: string;
  sequence_order: number;
  passenger_count: number;
  seat_count: number;
  passengers: PickupPassenger[];
}

interface FareSummary {
  expected_fare: number;
  fare_collected: number;
  fare_remaining: number;
  total_passengers: number;
  total_seats: number;
}

interface PickupPlan {
  found: boolean;
  trip_id?: string;
  trip_status?: string;
  fare_per_seat?: number;
  pickup_groups: PickupGroup[];
  summary?: FareSummary;
}

interface DriverState {
  driverId: string | null;
  status: string;
  currentRouteId: string | null;
  currentVehicleId: string | null;
  queueStatus: DriverQueueStatus | null;
  vehicleInfo: { make: string; model: string; registration_number: string; seating_capacity: number } | null;
  verificationStatus: string;
}

interface Route { id: string; from_location: string; to_location: string; }
interface Vehicle { id: string; make: string; model: string; registration_number: string; seating_capacity: number; }

export default function DriverHomeContent() {
  const [activeTab, setActiveTab] = useState<DriverTab>('home');
  const { profile, signOut } = useAuth();
  const supabase = useMemo(() => createClient(), []);

  const [driverState, setDriverState] = useState<DriverState>({
    driverId: null, status: 'offline', currentRouteId: null, currentVehicleId: null,
    queueStatus: null, vehicleInfo: null, verificationStatus: 'pending',
  });
  const [routes, setRoutes] = useState<Route[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [selectedRoute, setSelectedRoute] = useState<string>('');
  const [selectedVehicle, setSelectedVehicle] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [offerCountdown, setOfferCountdown] = useState<number | null>(null);
  const [departureLockCountdown, setDepartureLockCountdown] = useState<number | null>(null);
  const [pickupPlan, setPickupPlan] = useState<PickupPlan | null>(null);
  const [pickupPlanLoading, setPickupPlanLoading] = useState(false);

  // Guards to prevent overlapping concurrent loads
  const isLoadingRef = React.useRef(false);
  const isPickupLoadingRef = React.useRef(false);
  // Debounce timers for realtime callbacks
  const realtimeDebounceRef = React.useRef<ReturnType<typeof setTimeout> | null>(null);
  const pickupDebounceRef = React.useRef<ReturnType<typeof setTimeout> | null>(null);

  const loadPickupPlan = useCallback(async (source = 'unknown') => {
    if (!profile?.id) return;
    // Prevent overlapping pickup plan loads
    if (isPickupLoadingRef.current) {
      console.log(`[DriverHome] loadPickupPlan(${source}) skipped — already loading`, new Date().toISOString());
      return;
    }
    console.log(`[DriverHome] loadPickupPlan(${source}) START`, new Date().toISOString());
    isPickupLoadingRef.current = true;
    setPickupPlanLoading(true);
    try {
      const { data } = await supabase.rpc('driver_get_pickup_plan', {
        p_driver_profile_id: profile.id,
      });
      if (data) {
        const result = data as any;
        setPickupPlan({
          found: result.found ?? false,
          trip_id: result.trip_id,
          trip_status: result.trip_status,
          fare_per_seat: result.fare_per_seat,
          pickup_groups: result.pickup_groups ?? [],
          summary: result.summary,
        });
      }
    } catch {
      // Silently handle
    } finally {
      setPickupPlanLoading(false);
      isPickupLoadingRef.current = false;
      console.log(`[DriverHome] loadPickupPlan(${source}) DONE`, new Date().toISOString());
    }
  }, [profile?.id, supabase]);

  // Stable ref so loadDriverState can call loadPickupPlan without
  // taking it as a useCallback dependency (which would cause
  // loadDriverState to get a new identity every time loadPickupPlan
  // updates state, re-triggering the initial-load useEffect).
  const loadPickupPlanRef = React.useRef(loadPickupPlan);
  useEffect(() => { loadPickupPlanRef.current = loadPickupPlan; }, [loadPickupPlan]);

  const loadDriverState = useCallback(async (source = 'unknown') => {
    if (!profile?.id) return;
    // Prevent overlapping driver state loads
    if (isLoadingRef.current) {
      console.log(`[DriverHome] loadDriverState(${source}) skipped — already loading`, new Date().toISOString());
      return;
    }
    console.log(`[DriverHome] loadDriverState(${source}) START`, new Date().toISOString());
    isLoadingRef.current = true;
    try {
      const { data: driver } = await supabase
        .from('drivers')
        .select('id, availability_status, current_route_id, current_vehicle_id, verification_status')
        .eq('profile_id', profile.id)
        .single();

      if (!driver) { setLoading(false); return; }

      const { data: routesData } = await supabase.from('routes').select('id, from_location, to_location').eq('status', 'active');
      const { data: vehiclesData } = await supabase.from('vehicles').select('id, make, model, registration_number, seating_capacity').eq('assigned_driver_id', profile.id).eq('status', 'active');

      if (routesData) setRoutes(routesData);
      if (vehiclesData) setVehicles(vehiclesData);

      let vehicleInfo = null;
      let queueStatus: DriverQueueStatus | null = null;

      if (driver.availability_status !== 'offline' && driver.availability_status !== 'completed') {
        const { data: qsData } = await supabase.rpc('get_driver_queue_status', {
          p_driver_profile_id: profile.id,
        });
        if (qsData) queueStatus = qsData as DriverQueueStatus;

        if (driver.current_vehicle_id) {
          const { data: veh } = await supabase.from('vehicles').select('make, model, registration_number, seating_capacity').eq('id', driver.current_vehicle_id).single();
          if (veh) vehicleInfo = veh;
        }
      }

      setDriverState({
        driverId: driver.id,
        status: driver.availability_status,
        currentRouteId: driver.current_route_id,
        currentVehicleId: driver.current_vehicle_id,
        queueStatus, vehicleInfo,
        verificationStatus: driver.verification_status,
      });

      if (driver.current_route_id) setSelectedRoute(driver.current_route_id);
      if (driver.current_vehicle_id) setSelectedVehicle(driver.current_vehicle_id);

      // Load pickup plan when driver has an active trip.
      // Use the stable ref so this call does NOT create a dependency on
      // loadPickupPlan's identity — preventing the identity-change loop:
      //   loadPickupPlan updates state → loadDriverState gets new identity
      //   → initial-load useEffect fires again → infinite loop.
      const hasActiveTrip = queueStatus?.status === 'assigned' || 
        driver.availability_status === 'on_trip' || 
        driver.availability_status === 'trip_started';
      if (hasActiveTrip) {
        loadPickupPlanRef.current(`loadDriverState(${source})`);
      }
    } catch { /* Silently handle */ }
    finally {
      setLoading(false);
      isLoadingRef.current = false;
      console.log(`[DriverHome] loadDriverState(${source}) DONE`, new Date().toISOString());
    }
    // CRITICAL: loadPickupPlan is intentionally NOT in this dependency array.
    // It is accessed via loadPickupPlanRef to prevent a new loadDriverState
    // identity every time loadPickupPlan updates state.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [profile?.id, supabase]);

  useEffect(() => { loadDriverState('initial-effect'); }, [loadDriverState]);

  // Stable ref for use in countdown timers so those effects don't need
  // loadDriverState in their dependency arrays (which would recreate the
  // interval every time loadDriverState identity changes).
  const loadDriverStateRef = React.useRef(loadDriverState);
  useEffect(() => { loadDriverStateRef.current = loadDriverState; }, [loadDriverState]);

  // Offer countdown timer
  useEffect(() => {
    const expiresAtStr = driverState.queueStatus?.offer_expires_at;
    const queueStatusValue = driverState.queueStatus?.status;

    // LIFECYCLE FIX: Only run the offer countdown when the driver currently
    // has an actionable offer. offer_expires_at may remain populated as
    // historical metadata after acceptance/assignment — do NOT reactivate
    // the countdown based on the timestamp alone.
    const isOffered = queueStatusValue === 'offered';

    if (!isOffered || !expiresAtStr) {
      setOfferCountdown(null);
      return;
    }

    // One-shot guard: ensure expiry handling fires exactly once, not once
    // per timer tick while waiting for state reconciliation.
    const expiredFiredRef = { fired: false };

    const updateCountdown = () => {
      const expiresAt = new Date(expiresAtStr).getTime();
      const now = Date.now();
      const remaining = Math.max(0, Math.floor((expiresAt - now) / 1000));
      setOfferCountdown(remaining);
      if (remaining === 0 && !expiredFiredRef.fired) {
        expiredFiredRef.fired = true;
        loadDriverStateRef.current('offer-countdown-expired');
      }
    };
    updateCountdown();
    const interval = setInterval(updateCountdown, 1000);
    return () => clearInterval(interval);
    // Depends on both the expires-at string AND the queue status value.
    // loadDriverState is accessed via stable ref.
  }, [driverState.queueStatus?.offer_expires_at, driverState.queueStatus?.status]);

  // Departure lock countdown timer
  useEffect(() => {
    const lockExpiresAtStr = driverState.queueStatus?.departure_lock_expires_at;
    const queueStatusValue = driverState.queueStatus?.status;

    // LIFECYCLE FIX: Only run the departure countdown when the driver is
    // actually in a departure-pending state. departure_lock_expires_at may
    // remain populated as historical metadata after trip_started — do NOT
    // reactivate the countdown based on the timestamp alone.
    const isDeparturePending = queueStatusValue === 'departure_pending' || queueStatusValue === 'assigned';

    if (!isDeparturePending || !lockExpiresAtStr) {
      setDepartureLockCountdown(null);
      return;
    }

    // One-shot guard: ensure expiry handling fires exactly once.
    const expiredFiredRef = { fired: false };

    const updateLockCountdown = () => {
      const expiresAt = new Date(lockExpiresAtStr).getTime();
      const now = Date.now();
      const remaining = Math.max(0, Math.floor((expiresAt - now) / 1000));
      setDepartureLockCountdown(remaining);
      if (remaining === 0 && !expiredFiredRef.fired) {
        expiredFiredRef.fired = true;
        loadDriverStateRef.current('departure-lock-countdown-expired');
      }
    };
    updateLockCountdown();
    const interval = setInterval(updateLockCountdown, 1000);
    return () => clearInterval(interval);
    // Depends on both the lock timestamp AND the queue status value.
    // loadDriverState is accessed via stable ref.
  }, [driverState.queueStatus?.departure_lock_expires_at, driverState.queueStatus?.status]);

  // Keep stable refs to the latest loaders so the subscription effect
  // never needs to re-run just because loadDriverState/loadPickupPlan
  // changed identity (they are already stable via useCallback, but this
  // pattern makes the subscription dependency array explicit and safe).
  // NOTE: loadDriverStateRef is already declared above (used by countdown timers).
  // loadPickupPlanRef is already declared above (used by loadDriverState).
  // We only need to keep them updated here.

  useEffect(() => {
    if (!driverState.driverId) return;

    // Debounced wrappers — prevent a burst of DB change events from
    // firing multiple overlapping full-reload cycles.
    const debouncedLoadAll = () => {
      if (realtimeDebounceRef.current) clearTimeout(realtimeDebounceRef.current);
      realtimeDebounceRef.current = setTimeout(() => {
        loadDriverStateRef.current('realtime-driver-queue');
      }, 300);
    };

    const debouncedLoadPickup = () => {
      if (pickupDebounceRef.current) clearTimeout(pickupDebounceRef.current);
      pickupDebounceRef.current = setTimeout(() => {
        loadPickupPlanRef.current('realtime-bookings');
      }, 300);
    };

    const channel = supabase
      .channel(`driver-state-${driverState.driverId}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'trips' }, debouncedLoadAll)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'driver_queue' }, debouncedLoadAll)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'passenger_queue' }, debouncedLoadAll)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, debouncedLoadPickup)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'fare_collections' }, debouncedLoadPickup)
      .subscribe();

    return () => {
      // Clean up debounce timers on unmount / driverId change
      if (realtimeDebounceRef.current) clearTimeout(realtimeDebounceRef.current);
      if (pickupDebounceRef.current) clearTimeout(pickupDebounceRef.current);
      supabase.removeChannel(channel);
    };
    // Only re-create the subscription when the driverId changes.
    // loadDriverState/loadPickupPlan are accessed via stable refs above.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [driverState.driverId, supabase]);

  const handleGoOnline = async () => {
    if (!selectedRoute || !selectedVehicle) { toast.error('Please select a route and vehicle first'); return; }
    if (!driverState.driverId) { toast.error('Driver profile not found'); return; }
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('driver_go_online', {
        p_driver_profile_id: profile?.id,
        p_route_id: selectedRoute,
        p_vehicle_id: selectedVehicle,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Failed to go online'); return; }
      toast.success('Joined driver queue');
      await loadDriverState();
    } catch (err: any) { toast.error(err?.message || 'Failed to go online'); }
    finally { setActionLoading(false); }
  };

  const handleGoOffline = async () => {
    if (!driverState.driverId) return;
    if (!confirm('Go offline? You will leave the driver queue.')) return;
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('driver_go_offline', { p_driver_id: driverState.driverId });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Cannot leave queue right now'); return; }
      toast.success('You are now offline');
      await loadDriverState('action-go-offline');
    } catch (err: any) { toast.error(err?.message || 'Failed to go offline'); }
    finally { setActionLoading(false); }
  };

  const handleAcceptOffer = async () => {
    if (!profile?.id || !driverState.queueStatus?.queue_entry_id) return;
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('driver_accept_offer', {
        p_driver_profile_id: profile.id,
        p_queue_entry_id: driverState.queueStatus.queue_entry_id,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) {
        const reason = result?.reason || '';
        if (reason === 'offer_expired' || result?.error?.toLowerCase().includes('expired')) {
          toast.error('Offer expired — finding the next available ride.');
        } else {
          toast.error(result?.error || 'Failed to accept offer');
        }
        await loadDriverState('action-accept-offer-failed');
        return;
      }
      toast.success('Offer accepted! Passengers assigned to you.');
      await loadDriverState('action-accept-offer-success');
    } catch (err: any) { toast.error(err?.message || 'Failed to accept offer'); }
    finally { setActionLoading(false); }
  };

  const handleDeclineOffer = async () => {
    if (!profile?.id || !driverState.queueStatus?.queue_entry_id) return;
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('driver_decline_offer', {
        p_driver_profile_id: profile.id,
        p_queue_entry_id: driverState.queueStatus.queue_entry_id,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Failed to decline offer'); return; }
      toast.success('Offer declined. Moved to end of driver queue.');
      await loadDriverState('action-decline-offer');
    } catch (err: any) { toast.error(err?.message || 'Failed to decline offer'); }
    finally { setActionLoading(false); }
  };

  const handleCancelBeforeTripStart = async () => {
    if (!profile?.id) return;
    if (!confirm('Cancel your assignment?\n\nPassengers will be rematched automatically. This cannot be undone.')) return;
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('driver_cancel_before_trip_start', {
        p_driver_profile_id: profile.id,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Failed to cancel'); return; }
      toast.success('Assignment cancelled. Passengers will be rematched automatically.');
      await loadDriverState('action-cancel-before-start');
    } catch (err: any) { toast.error(err?.message || 'Failed to cancel'); }
    finally { setActionLoading(false); }
  };

  const handleLeaveNow = async () => {
    if (!profile?.id) return;
    const qs = driverState.queueStatus;
    const bookedSeats = qs?.booked_seats ?? 0;
    const vehicleCapacity = qs?.vehicle_capacity ?? qs?.total_seats ?? 4;
    const isFull = bookedSeats >= vehicleCapacity;
    if (!isFull) {
      if (!confirm(`Leave with current passengers?\n\nVehicle is not full (${bookedSeats}/${vehicleCapacity} seats). You can still depart — passengers already in queue will not be added.`)) return;
    }
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('driver_leave_now', {
        p_driver_profile_id: profile.id,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Cannot depart yet'); return; }
      toast.success(`Departure lock started — ${result.departure_lock_seconds}s boarding window`);
      await loadDriverState('action-leave-now');
    } catch (err: any) { toast.error(err?.message || 'Failed to initiate departure'); }
    finally { setActionLoading(false); }
  };

  const handleWaitForMore = async () => {
    if (!profile?.id) return;
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('driver_wait_for_more', {
        p_driver_profile_id: profile.id,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Failed'); return; }
      toast.success('Waiting for more passengers — matching continues automatically.');
      await loadDriverState('action-wait-for-more');
    } catch (err: any) { toast.error(err?.message || 'Failed'); }
    finally { setActionLoading(false); }
  };

  const handleStartTrip = async () => {
    if (!driverState.driverId) return;
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('driver_start_trip', { p_driver_id: driverState.driverId });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Failed to start trip'); return; }
      toast.success('Trip started!');
      await loadDriverState('action-start-trip');
    } catch (err: any) { toast.error(err?.message || 'Failed to start trip'); }
    finally { setActionLoading(false); }
  };

  const handleCompleteTrip = async () => {
    if (!driverState.driverId) return;
    if (!confirm('Complete this trip?\n\nMake sure all passengers have been dropped off before completing.')) return;
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('driver_complete_trip', { p_driver_id: driverState.driverId });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Failed to complete trip'); return; }
      toast.success('Trip completed! You can go online again to join the queue.');
      await loadDriverState('action-complete-trip');
    } catch (err: any) { toast.error(err?.message || 'Failed to complete trip'); }
    finally { setActionLoading(false); }
  };

  const handleMarkFareCollected = async (bookingId: string) => {
    if (!profile?.id) return;
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('driver_mark_fare_collected', {
        p_booking_id: bookingId,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Failed to mark fare collected'); return; }
      if (result.already_collected) {
        toast.info('Fare was already marked as collected');
      } else {
        toast.success(`Fare collected ✓ — ₹${result.amount}`);
      }
      await loadPickupPlan('action-mark-fare-collected');
    } catch (err: any) { toast.error(err?.message || 'Failed to mark fare collected'); }
    finally { setActionLoading(false); }
  };

  const handleMarkNoShow = async (bookingId: string, passengerName: string) => {
    if (!profile?.id) return;
    if (!confirm(`Mark ${passengerName} as No Show?\n\nThis means the passenger did not arrive for pickup. Their seat(s) will be released. This is NOT counted as a passenger cancellation.`)) return;
    setActionLoading(true);
    try {
      const { data, error } = await supabase.rpc('driver_mark_no_show', {
        p_booking_id: bookingId,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Failed to mark no-show'); return; }
      if (result.already_no_show) {
        toast.info('Passenger was already marked as no-show');
      } else {
        toast.success(`${passengerName} marked as no-show. ${result.seats_released} seat(s) released.`);
      }
      await loadDriverState('action-mark-no-show');
      await loadPickupPlan('action-mark-no-show');
    } catch (err: any) { toast.error(err?.message || 'Failed to mark no-show'); }
    finally { setActionLoading(false); }
  };

  const tabs: { id: DriverTab; label: string; icon: React.ElementType }[] = [
    { id: 'home', label: 'Home', icon: Home },
    { id: 'queue', label: 'Queue', icon: List },
    { id: 'trips', label: 'Trips', icon: Clock },
    { id: 'profile', label: 'Profile', icon: User },
  ];

  return (
    <div className="min-h-screen bg-background flex flex-col max-w-md mx-auto relative">
      {/* Header */}
      <div className="sticky top-0 z-50 bg-card border-b flex items-center justify-between px-4 h-14">
        <div className="flex items-center gap-2">
          <AppLogo size={28} />
          <span className="font-extrabold text-base text-primary">Raahi</span>
          <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-secondary text-primary ml-1">Driver</span>
        </div>
        <button onClick={signOut} className="p-2 rounded-xl hover:bg-muted transition-colors" aria-label="Logout">
          <LogOut size={16} className="text-muted-foreground" />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto pb-20 px-4 py-5">
        {loading ? (
          <div className="flex flex-col gap-4">
            {[1, 2].map((i) => <div key={i} className="card-base p-5 h-24 animate-pulse bg-muted" />)}
          </div>
        ) : (
          <>
            {activeTab === 'home' && (
              <DriverHomeTab
                driverState={driverState}
                routes={routes}
                vehicles={vehicles}
                selectedRoute={selectedRoute}
                selectedVehicle={selectedVehicle}
                setSelectedRoute={setSelectedRoute}
                setSelectedVehicle={setSelectedVehicle}
                onGoOnline={handleGoOnline}
                onGoOffline={handleGoOffline}
                onAcceptOffer={handleAcceptOffer}
                onDeclineOffer={handleDeclineOffer}
                onCancelBeforeTripStart={handleCancelBeforeTripStart}
                onLeaveNow={handleLeaveNow}
                onWaitForMore={handleWaitForMore}
                onStartTrip={handleStartTrip}
                onCompleteTrip={handleCompleteTrip}
                onMarkFareCollected={handleMarkFareCollected}
                onMarkNoShow={handleMarkNoShow}
                actionLoading={actionLoading}
                profileName={profile?.name || 'Driver'}
                offerCountdown={offerCountdown}
                departureLockCountdown={departureLockCountdown}
                pickupPlan={pickupPlan}
                pickupPlanLoading={pickupPlanLoading}
              />
            )}
            {activeTab === 'queue' && <DriverQueueTab driverState={driverState} />}
            {activeTab === 'trips' && <div className="flex flex-col gap-4"><h2 className="text-lg font-bold text-foreground">Trip History</h2><DriverTripHistory /></div>}
            {activeTab === 'profile' && <div className="flex flex-col gap-4"><DriverProfileContent /></div>}
          </>
        )}
      </div>

      {/* Bottom nav */}
      <nav className="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-md z-50 bg-card border-t flex items-center justify-around h-16">
        {tabs.map((tab) => (
          <button
            key={`driver-tab-${tab.id}`}
            onClick={() => setActiveTab(tab.id)}
            className={`flex flex-col items-center gap-1 px-4 py-2 rounded-xl transition-colors min-w-[60px] ${activeTab === tab.id ? 'text-primary' : 'text-muted-foreground'}`}
          >
            <tab.icon size={20} />
            <span className="text-xs font-medium">{tab.label}</span>
          </button>
        ))}
      </nav>
    </div>
  );
}

// ============================================================
// Driver Home Tab — State Machine
// ============================================================
interface DriverHomeTabProps {
  driverState: DriverState;
  routes: Route[];
  vehicles: Vehicle[];
  selectedRoute: string;
  selectedVehicle: string;
  setSelectedRoute: (id: string) => void;
  setSelectedVehicle: (id: string) => void;
  onGoOnline: () => void;
  onGoOffline: () => void;
  onAcceptOffer: () => void;
  onDeclineOffer: () => void;
  onCancelBeforeTripStart: () => void;
  onLeaveNow: () => void;
  onWaitForMore: () => void;
  onStartTrip: () => void;
  onCompleteTrip: () => void;
  onMarkFareCollected: (bookingId: string) => void;
  onMarkNoShow: (bookingId: string, passengerName: string) => void;
  actionLoading: boolean;
  profileName: string;
  offerCountdown: number | null;
  departureLockCountdown: number | null;
  pickupPlan: PickupPlan | null;
  pickupPlanLoading: boolean;
}

function DriverHomeTab({
  driverState, routes, vehicles, selectedRoute, selectedVehicle,
  setSelectedRoute, setSelectedVehicle, onGoOnline, onGoOffline,
  onAcceptOffer, onDeclineOffer, onCancelBeforeTripStart,
  onLeaveNow, onWaitForMore,
  onStartTrip, onCompleteTrip,
  onMarkFareCollected, onMarkNoShow,
  actionLoading, profileName, offerCountdown,
  departureLockCountdown, pickupPlan, pickupPlanLoading,
}: DriverHomeTabProps) {
  const { status, queueStatus, vehicleInfo, verificationStatus } = driverState;

  const isOffline = status === 'offline' || status === 'completed';
  const isQueued = !isOffline && (queueStatus?.status === 'waiting' || status === 'queued' || status === 'online');
  const isOffered = queueStatus?.status === 'offered';
  const isAssigned = queueStatus?.status === 'assigned';
  const isTripStarted = queueStatus?.trip_status === 'in_progress' || status === 'trip_started' || status === 'on_trip';
  const isDeparturePending = queueStatus?.trip_status === 'departure_pending';

  const bookedSeats = queueStatus?.booked_seats ?? 0;
  const vehicleCapacity = queueStatus?.vehicle_capacity ?? queueStatus?.total_seats ?? 4;
  const minPassengers = queueStatus?.min_passengers ?? 1;
  const canDepart = queueStatus?.can_depart ?? (bookedSeats >= minPassengers);
  const isFull = queueStatus?.is_full ?? (bookedSeats >= vehicleCapacity);
  const seatsNeeded = Math.max(0, minPassengers - bookedSeats);

  if (verificationStatus !== 'approved') {
    return (
      <div className="flex flex-col gap-5">
        <div>
          <p className="text-sm text-muted-foreground">Good day,</p>
          <h1 className="text-xl font-bold text-foreground">{profileName} 👋</h1>
        </div>
        <div className="card-base p-5 border-warning bg-yellow-50/50">
          <div className="flex items-start gap-3">
            <AlertCircle size={18} className="text-warning shrink-0 mt-0.5" />
            <div>
              <p className="font-bold text-warning mb-1">Account not approved</p>
              <p className="text-sm text-muted-foreground">
                Your driver account is currently <strong>{verificationStatus}</strong>. You cannot go online until an admin approves your account.
              </p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      {/* Greeting */}
      <div>
        <p className="text-sm text-muted-foreground">Good day,</p>
        <h1 className="text-xl font-bold text-foreground">{profileName} 👋</h1>
        {vehicleInfo && (
          <p className="text-xs text-muted-foreground mt-0.5">
            {vehicleInfo.registration_number} · {vehicleInfo.make} {vehicleInfo.model} · {vehicleInfo.seating_capacity} seats
          </p>
        )}
      </div>

      {/* ── STATE 1: OFFLINE ── */}
      {isOffline && (
        <div className="card-base p-5 flex flex-col gap-4">
          <div className="flex items-center gap-2">
            <div className="w-2.5 h-2.5 rounded-full bg-muted-foreground" />
            <p className="font-semibold text-muted-foreground text-sm">Offline</p>
          </div>
          <p className="text-sm text-muted-foreground">Select a route and vehicle, then go online to join the driver queue.</p>

          <div>
            <p className="text-xs text-muted-foreground mb-2 font-medium">Select route</p>
            {routes.length === 0 ? (
              <p className="text-xs text-muted-foreground p-3 bg-muted rounded-xl">No active routes available.</p>
            ) : (
              <div className="flex flex-col gap-2">
                {routes.map((route) => (
                  <button
                    key={route.id}
                    onClick={() => setSelectedRoute(route.id)}
                    className={`flex items-center gap-2 p-3 rounded-xl border-2 text-sm font-medium transition-all text-left ${selectedRoute === route.id ? 'border-primary bg-secondary text-primary' : 'border-border text-muted-foreground hover:border-primary/40'}`}
                  >
                    <Radio size={14} className="shrink-0" />
                    {route.from_location} → {route.to_location}
                  </button>
                ))}
              </div>
            )}
          </div>

          {vehicles.length > 0 ? (
            <div>
              <p className="text-xs text-muted-foreground mb-2 font-medium">Select vehicle</p>
              <div className="flex flex-col gap-2">
                {vehicles.map((v) => (
                  <button
                    key={v.id}
                    onClick={() => setSelectedVehicle(v.id)}
                    className={`flex items-center gap-2 p-3 rounded-xl border-2 text-sm font-medium transition-all text-left ${selectedVehicle === v.id ? 'border-primary bg-secondary text-primary' : 'border-border text-muted-foreground hover:border-primary/40'}`}
                  >
                    <span className="font-bold">{v.make} {v.model}</span>
                    <span className="text-xs text-muted-foreground ml-auto">· {v.registration_number} · {v.seating_capacity} seats</span>
                  </button>
                ))}
              </div>
            </div>
          ) : (
            <div className="p-3 bg-muted rounded-xl">
              <p className="text-xs text-muted-foreground">No vehicles assigned. Contact admin to assign a vehicle before going online.</p>
            </div>
          )}

          <button
            onClick={onGoOnline}
            disabled={actionLoading || !selectedRoute || vehicles.length === 0 || !selectedVehicle}
            className="btn-primary w-full justify-center gap-2 py-4 text-base font-bold"
          >
            {actionLoading ? <span className="w-5 h-5 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <Power size={18} />}
            Go Online
          </button>
        </div>
      )}

      {/* ── STATE 2: QUEUED ── */}
      {isQueued && !isOffered && !isAssigned && !isTripStarted && (
        <div className="card-base p-5 flex flex-col gap-4">
          <div className="flex items-center gap-2">
            <div className="w-2.5 h-2.5 rounded-full bg-warning animate-pulse" />
            <p className="font-semibold text-warning text-sm">In Driver Queue</p>
          </div>
          <div className="p-5 bg-yellow-50 rounded-xl text-center">
            <p className="text-xs text-muted-foreground mb-1">Driver Queue Position</p>
            <p className="text-6xl font-extrabold text-warning tabular-nums mt-1">#{queueStatus?.queue_position ?? '—'}</p>
            {queueStatus?.drivers_ahead !== undefined && (
              <p className="text-sm text-muted-foreground mt-2">{queueStatus.drivers_ahead} driver{queueStatus.drivers_ahead !== 1 ? 's' : ''} ahead of you</p>
            )}
          </div>
          {queueStatus && (
            <div className="p-3 bg-muted rounded-xl text-xs">
              <p className="font-semibold text-foreground mb-0.5">{queueStatus.route_from} → {queueStatus.route_to}</p>
              <p className="text-muted-foreground">{queueStatus.vehicle_make} {queueStatus.vehicle_model} · {queueStatus.vehicle_capacity} seats</p>
            </div>
          )}
          <p className="text-xs text-muted-foreground text-center">You will receive a ride offer automatically when passengers are matched to you.</p>
          <button onClick={onGoOffline} disabled={actionLoading} className="btn-secondary w-full justify-center gap-2">
            {actionLoading ? <span className="w-4 h-4 border-2 border-muted-foreground/40 border-t-foreground rounded-full animate-spin" /> : <Power size={16} />}
            Leave Queue
          </button>
        </div>
      )}

      {/* ── STATE 3: OFFERED ── */}
      {isOffered && (
        <div className="card-base p-5 flex flex-col gap-4 border-2 border-primary bg-secondary/20">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className={`w-2.5 h-2.5 rounded-full ${offerCountdown === 0 ? 'bg-muted-foreground' : 'bg-primary animate-pulse'}`} />
              <p className={`font-bold ${offerCountdown === 0 ? 'text-muted-foreground' : 'text-primary'}`}>
                {offerCountdown === 0 ? 'Offer Expired' : 'Ride Available!'}
              </p>
            </div>
            {offerCountdown !== null && offerCountdown > 0 && (
              <span className={`text-sm font-bold tabular-nums px-3 py-1 rounded-full ${offerCountdown <= 10 ? 'bg-red-100 text-danger' : 'bg-secondary text-primary'}`}>
                {offerCountdown}s
              </span>
            )}
          </div>
          {offerCountdown === 0 ? (
            <div className="p-4 bg-muted rounded-xl flex flex-col items-center gap-3 text-center">
              <AlertCircle size={28} className="text-muted-foreground" />
              <div>
                <p className="font-semibold text-foreground text-sm">Offer expired</p>
                <p className="text-xs text-muted-foreground mt-1">Finding the next available ride…</p>
              </div>
              <div className="w-5 h-5 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
            </div>
          ) : (
            <>
              <div className="p-4 bg-card rounded-xl flex flex-col gap-3">
                <div>
                  <p className="text-xs text-muted-foreground">Route</p>
                  <p className="font-bold text-foreground text-base">{queueStatus?.route_from} → {queueStatus?.route_to}</p>
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <p className="text-xs text-muted-foreground">Passenger seats</p>
                    <p className="font-bold text-foreground tabular-nums text-lg">{queueStatus?.passenger_count ?? '—'}</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">Vehicle capacity</p>
                    <p className="font-bold text-foreground tabular-nums text-lg">{queueStatus?.vehicle_capacity} seats</p>
                  </div>
                  <div>
                    <p className="text-xs text-muted-foreground">Vehicle</p>
                    <p className="font-bold text-foreground">{queueStatus?.vehicle_make} {queueStatus?.vehicle_model}</p>
                  </div>
                  {queueStatus?.fare_per_seat && (
                    <div>
                      <p className="text-xs text-muted-foreground">Fare / seat</p>
                      <p className="font-bold text-foreground">₹{queueStatus.fare_per_seat}</p>
                    </div>
                  )}
                </div>
              </div>
              {offerCountdown !== null && offerCountdown <= 10 && offerCountdown > 0 && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-xl">
                  <p className="text-xs text-danger font-semibold text-center">⚠ Offer expires in {offerCountdown}s — respond now</p>
                </div>
              )}
              <div className="grid grid-cols-2 gap-3">
                <button onClick={onDeclineOffer} disabled={actionLoading} className="flex items-center justify-center gap-2 px-4 py-4 rounded-xl border-2 border-danger/30 text-danger font-bold text-base hover:bg-red-50 active:scale-95 transition-all disabled:opacity-50">
                  {actionLoading ? <span className="w-5 h-5 border-2 border-danger/40 border-t-danger rounded-full animate-spin" /> : <X size={18} />}
                  Decline
                </button>
                <button onClick={onAcceptOffer} disabled={actionLoading} className="flex items-center justify-center gap-2 px-4 py-4 rounded-xl bg-primary text-white font-bold text-base hover:bg-primary/90 active:scale-95 transition-all disabled:opacity-50 shadow-lg">
                  {actionLoading ? <span className="w-5 h-5 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <Check size={18} />}
                  Accept
                </button>
              </div>
            </>
          )}
        </div>
      )}

      {/* ── STATE 4: ASSIGNED — Departure Eligibility + Pickup Plan ── */}
      {isAssigned && !isTripStarted && !isDeparturePending && (
        <div className="flex flex-col gap-4">
          <div className="card-base p-5 flex flex-col gap-4">
            <div className="flex items-center gap-2">
              <div className="w-2.5 h-2.5 rounded-full bg-success animate-pulse-soft" />
              <p className="font-semibold text-success text-sm">Passengers Assigned</p>
            </div>
            <div className={`p-4 rounded-xl ${canDepart ? 'bg-green-50' : 'bg-yellow-50'}`}>
              <p className="text-xs text-muted-foreground mb-3">Seat occupancy</p>
              <div className="flex gap-1.5 flex-wrap mb-3">
                {Array.from({ length: vehicleCapacity }).map((_, si) => (
                  <div key={si} className={`w-7 h-7 rounded-md flex items-center justify-center text-xs font-bold ${si < bookedSeats ? 'bg-primary text-white' : 'bg-card border border-border text-muted-foreground'}`}>
                    {si < bookedSeats ? '✓' : si + 1}
                  </div>
                ))}
              </div>
              <p className="text-2xl font-extrabold text-foreground tabular-nums">
                {bookedSeats} / {vehicleCapacity}
                <span className="text-sm font-normal text-muted-foreground ml-2">seats filled</span>
              </p>
              <div className="flex items-center gap-2 mt-2">
                <Users size={13} className="text-muted-foreground" />
                <p className="text-xs text-muted-foreground">Minimum required: <span className="font-semibold text-foreground">{minPassengers}</span></p>
              </div>
            </div>

            {!canDepart && (
              <div className="p-4 bg-yellow-50 border border-yellow-200 rounded-xl">
                <div className="flex items-center gap-2 mb-1">
                  <AlertCircle size={15} className="text-warning shrink-0" />
                  <p className="text-sm font-bold text-warning">Waiting for minimum passengers</p>
                </div>
                <p className="text-xs text-muted-foreground">
                  {bookedSeats} of {minPassengers} minimum seats ready
                  {seatsNeeded > 0 && <span className="ml-1 font-semibold text-warning">— waiting for {seatsNeeded} more passenger{seatsNeeded !== 1 ? 's' : ''}</span>}
                </p>
              </div>
            )}
            {isFull && (
              <div className="p-4 bg-green-50 border border-green-200 rounded-xl">
                <div className="flex items-center gap-2 mb-1">
                  <CheckCircle size={15} className="text-success shrink-0" />
                  <p className="text-sm font-bold text-success">Vehicle full — ready to depart</p>
                </div>
              </div>
            )}
            {canDepart && !isFull && (
              <div className="p-4 bg-green-50 border border-green-200 rounded-xl">
                <div className="flex items-center gap-2 mb-1">
                  <CheckCircle size={15} className="text-success shrink-0" />
                  <p className="text-sm font-bold text-success">Minimum occupancy reached</p>
                </div>
                <p className="text-xs text-muted-foreground">{bookedSeats} of {vehicleCapacity} seats filled. You may leave now or wait for more passengers.</p>
              </div>
            )}

            {canDepart && (
              <div className="flex flex-col gap-3">
                {isFull ? (
                  <button onClick={onLeaveNow} disabled={actionLoading} className="btn-primary w-full justify-center gap-2 py-4 text-base font-bold">
                    {actionLoading ? <span className="w-5 h-5 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <ArrowRight size={18} />}
                    Start Departure
                  </button>
                ) : (
                  <div className="grid grid-cols-2 gap-3">
                    <button onClick={onLeaveNow} disabled={actionLoading} className="flex items-center justify-center gap-2 px-4 py-4 rounded-xl bg-primary text-white font-bold text-sm hover:bg-primary/90 active:scale-95 transition-all disabled:opacity-50 shadow-lg">
                      {actionLoading ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <ArrowRight size={16} />}
                      Leave Now
                    </button>
                    <button onClick={onWaitForMore} disabled={actionLoading} className="flex items-center justify-center gap-2 px-4 py-4 rounded-xl border-2 border-primary text-primary font-bold text-sm hover:bg-secondary active:scale-95 transition-all disabled:opacity-50">
                      {actionLoading ? <span className="w-4 h-4 border-2 border-primary/40 border-t-primary rounded-full animate-spin" /> : <Users size={16} />}
                      Wait for More
                    </button>
                  </div>
                )}
              </div>
            )}
            <button onClick={onCancelBeforeTripStart} disabled={actionLoading} className="text-xs text-danger text-center py-1 hover:underline transition-colors">
              Cancel assignment (passengers will be rematched)
            </button>
          </div>

          {/* Pickup Plan */}
          <PickupPlanCard
            pickupPlan={pickupPlan}
            loading={pickupPlanLoading}
            onMarkFareCollected={onMarkFareCollected}
            onMarkNoShow={onMarkNoShow}
            actionLoading={actionLoading}
            showFareActions={false}
          />
        </div>
      )}

      {/* ── STATE 4b: DEPARTURE PENDING ── */}
      {isAssigned && isDeparturePending && !isTripStarted && (
        <div className="flex flex-col gap-4">
          <div className="card-base p-5 flex flex-col gap-4 border-2 border-primary/40">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="w-2.5 h-2.5 rounded-full bg-primary animate-pulse" />
                <p className="font-bold text-primary text-sm">Preparing to Depart</p>
              </div>
              {departureLockCountdown !== null && (
                <span className={`text-sm font-bold tabular-nums px-3 py-1 rounded-full ${departureLockCountdown <= 15 ? 'bg-green-100 text-success' : 'bg-secondary text-primary'}`}>
                  <Timer size={12} className="inline mr-1" />
                  {departureLockCountdown}s
                </span>
              )}
            </div>
            <div className="p-4 bg-secondary rounded-xl">
              <p className="text-xs text-muted-foreground mb-1">Passengers on board</p>
              <p className="text-2xl font-extrabold text-foreground tabular-nums">
                {bookedSeats} / {vehicleCapacity}
                <span className="text-sm font-normal text-muted-foreground ml-2">seats</span>
              </p>
            </div>
            {departureLockCountdown !== null && departureLockCountdown > 0 ? (
              <div className="p-3 bg-blue-50 border border-blue-200 rounded-xl">
                <p className="text-xs text-blue-700 font-semibold text-center">Final boarding window — {departureLockCountdown}s remaining</p>
              </div>
            ) : (
              <div className="p-3 bg-green-50 border border-green-200 rounded-xl">
                <p className="text-xs text-success font-semibold text-center">Boarding window complete — you may start the trip now.</p>
              </div>
            )}
            <button
              onClick={onStartTrip}
              disabled={actionLoading || (departureLockCountdown !== null && departureLockCountdown > 0)}
              className={`btn-primary w-full justify-center gap-2 py-4 text-base font-bold ${departureLockCountdown !== null && departureLockCountdown > 0 ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              {actionLoading ? <span className="w-5 h-5 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <Play size={18} />}
              {departureLockCountdown !== null && departureLockCountdown > 0 ? `Start Trip (${departureLockCountdown}s)` : 'Start Trip'}
            </button>
            <button onClick={onWaitForMore} disabled={actionLoading} className="text-xs text-primary text-center py-1 hover:underline transition-colors">
              Cancel departure — wait for more passengers
            </button>
          </div>

          {/* Pickup Plan during departure pending */}
          <PickupPlanCard
            pickupPlan={pickupPlan}
            loading={pickupPlanLoading}
            onMarkFareCollected={onMarkFareCollected}
            onMarkNoShow={onMarkNoShow}
            actionLoading={actionLoading}
            showFareActions={false}
          />
        </div>
      )}

      {/* ── STATE 5: TRIP IN PROGRESS ── */}
      {isTripStarted && (
        <div className="flex flex-col gap-4">
          <div className="card-base p-5 flex flex-col gap-4">
            <div className="flex items-center gap-2">
              <div className="w-2.5 h-2.5 rounded-full bg-primary animate-pulse" />
              <p className="font-semibold text-primary text-sm">Trip in Progress</p>
            </div>
            <div className="p-4 bg-secondary rounded-xl">
              <p className="text-base font-bold text-foreground mb-1">{queueStatus?.route_from} → {queueStatus?.route_to}</p>
              {pickupPlan?.summary ? (
                <p className="text-sm text-muted-foreground">
                  {pickupPlan.summary.total_passengers} passenger{pickupPlan.summary.total_passengers !== 1 ? 's' : ''} · {pickupPlan.summary.total_seats} seat{pickupPlan.summary.total_seats !== 1 ? 's' : ''} onboard
                </p>
              ) : bookedSeats > 0 ? (
                <p className="text-sm text-muted-foreground">{bookedSeats} seat{bookedSeats !== 1 ? 's' : ''} onboard</p>
              ) : (
                <p className="text-sm text-muted-foreground">Loading passenger info…</p>
              )}
            </div>
            <button onClick={onCompleteTrip} disabled={actionLoading} className="btn-primary w-full justify-center gap-2 py-4 text-base font-bold">
              {actionLoading ? <span className="w-5 h-5 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <CheckCircle size={18} />}
              Complete Trip
            </button>
          </div>

          {/* Pickup Plan with fare collection during trip */}
          <PickupPlanCard
            pickupPlan={pickupPlan}
            loading={pickupPlanLoading}
            onMarkFareCollected={onMarkFareCollected}
            onMarkNoShow={onMarkNoShow}
            actionLoading={actionLoading}
            showFareActions={true}
          />
        </div>
      )}
    </div>
  );
}

// ============================================================
// Pickup Plan Card
// ============================================================
interface PickupPlanCardProps {
  pickupPlan: PickupPlan | null;
  loading: boolean;
  onMarkFareCollected: (bookingId: string) => void;
  onMarkNoShow: (bookingId: string, passengerName: string) => void;
  actionLoading: boolean;
  showFareActions: boolean;
}

function PickupPlanCard({ pickupPlan, loading, onMarkFareCollected, onMarkNoShow, actionLoading, showFareActions }: PickupPlanCardProps) {
  if (loading) {
    return (
      <div className="card-base p-5">
        <p className="text-sm font-bold text-foreground mb-3">Pickup Plan</p>
        <div className="flex flex-col gap-2">
          {[1, 2].map((i) => <div key={i} className="h-16 bg-muted rounded-xl animate-pulse" />)}
        </div>
      </div>
    );
  }

  if (!pickupPlan?.found || !pickupPlan.pickup_groups || pickupPlan.pickup_groups.length === 0) {
    return null;
  }

  const summary = pickupPlan.summary;

  return (
    <div className="card-base p-4 flex flex-col gap-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <MapPin size={15} className="text-primary" />
          <p className="text-sm font-bold text-foreground">Pickup Plan</p>
        </div>
        <span className="text-xs text-muted-foreground">{pickupPlan.pickup_groups.length} stop{pickupPlan.pickup_groups.length !== 1 ? 's' : ''}</span>
      </div>

      {/* Fare Summary — clear distinction between expected and collected */}
      {summary && (
        <div className="p-3 bg-muted rounded-xl">
          <p className="text-xs font-semibold text-muted-foreground mb-2">Fare Summary</p>
          <div className="flex flex-col gap-1.5">
            <div className="flex items-center justify-between">
              <span className="text-xs text-muted-foreground">Expected</span>
              <span className="text-sm font-bold text-foreground tabular-nums">₹{summary.expected_fare.toLocaleString('en-IN')}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-xs text-muted-foreground">Collected</span>
              <span className="text-sm font-bold text-success tabular-nums">₹{summary.fare_collected.toLocaleString('en-IN')}</span>
            </div>
            <div className="h-px bg-border my-0.5" />
            <div className="flex items-center justify-between">
              <span className="text-xs font-semibold text-muted-foreground">Remaining</span>
              <span className={`text-sm font-bold tabular-nums ${summary.fare_remaining > 0 ? 'text-warning' : 'text-success'}`}>
                ₹{summary.fare_remaining.toLocaleString('en-IN')}
              </span>
            </div>
          </div>
        </div>
      )}

      {/* Pickup Groups */}
      <div className="flex flex-col gap-5">
        {pickupPlan.pickup_groups.map((group, gi) => (
          <div key={group.pickup_point_id} className="flex flex-col gap-2">
            {/* Pickup point header */}
            <div className="flex items-start gap-2">
              <div className="w-6 h-6 rounded-full bg-primary text-white text-xs font-bold flex items-center justify-center shrink-0 mt-0.5">
                {gi + 1}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-bold text-foreground leading-tight">{group.pickup_name}</p>
                <p className="text-xs text-muted-foreground mt-0.5">
                  {group.passenger_count} passenger{group.passenger_count !== 1 ? 's' : ''} · {group.seat_count} seat{group.seat_count !== 1 ? 's' : ''}
                </p>
              </div>
            </div>

            {/* Passengers at this pickup */}
            <div className="flex flex-col gap-2 ml-8">
              {group.passengers.map((pax) => (
                <div key={pax.booking_id} className={`p-3 rounded-xl border ${pax.fare_collected ? 'bg-green-50 border-green-200' : 'bg-card border-border'}`}>
                  {/* Passenger name + fare status */}
                  <div className="flex items-start justify-between gap-2 mb-2">
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-foreground break-words">{pax.passenger_name}</p>
                      <p className="text-xs text-muted-foreground mt-0.5">
                        {pax.seats} seat{pax.seats !== 1 ? 's' : ''} · ₹{pax.fare_due.toLocaleString('en-IN')}
                      </p>
                    </div>
                    {pax.fare_collected ? (
                      <div className="flex items-center gap-1 shrink-0">
                        <CheckCircle size={13} className="text-success" />
                        <span className="text-xs font-semibold text-success whitespace-nowrap">Collected ✓</span>
                      </div>
                    ) : (
                      <span className="text-xs font-semibold text-warning shrink-0 whitespace-nowrap">Fare Due</span>
                    )}
                  </div>

                  {/* Actions — stacked on narrow screens */}
                  <div className="flex flex-wrap gap-2">
                    {pax.passenger_phone && (
                      <a
                        href={`tel:${pax.passenger_phone}`}
                        className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-secondary text-primary text-xs font-semibold hover:bg-primary hover:text-white transition-colors min-h-[36px]"
                      >
                        <Phone size={12} />
                        Call Passenger
                      </a>
                    )}

                    {showFareActions && !pax.fare_collected && (
                      <button
                        onClick={() => onMarkFareCollected(pax.booking_id)}
                        disabled={actionLoading}
                        className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-primary text-white text-xs font-semibold hover:bg-primary/90 transition-colors disabled:opacity-50 min-h-[36px]"
                      >
                        <IndianRupee size={12} />
                        Mark Fare Collected
                      </button>
                    )}

                    {!pax.fare_collected && (
                      <button
                        onClick={() => onMarkNoShow(pax.booking_id, pax.passenger_name)}
                        disabled={actionLoading}
                        className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg border border-danger/30 text-danger text-xs font-semibold hover:bg-red-50 transition-colors disabled:opacity-50 min-h-[36px]"
                      >
                        <UserX size={12} />
                        Mark No Show
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function DriverQueueTab({ driverState }: { driverState: DriverState }) {
  const { queueStatus } = driverState;
  return (
    <div className="flex flex-col gap-4">
      <h2 className="text-lg font-bold text-foreground">Queue Status</h2>
      <div className="card-base p-5">
        <div className="flex items-center justify-between mb-3">
          <p className="font-semibold text-sm text-foreground">Your position</p>
          <span className={`text-xs font-semibold px-2.5 py-1 rounded-full ${
            queueStatus?.status === 'offered' ? 'bg-primary/10 text-primary' :
            queueStatus?.status === 'assigned' ? 'bg-green-100 text-green-700' :
            queueStatus?.status === 'waiting' ? 'bg-yellow-100 text-yellow-700' : 'bg-muted text-muted-foreground'
          }`}>
            {queueStatus?.status === 'offered' ? 'Offer Pending' :
             queueStatus?.status === 'assigned' ? 'Assigned' :
             queueStatus?.status === 'waiting' ? 'In Queue' : 'Offline'}
          </span>
        </div>
        {queueStatus?.queue_position ? (
          <div className="text-center py-4">
            <p className="text-4xl font-extrabold text-primary tabular-nums">#{queueStatus.queue_position}</p>
            <p className="text-sm text-muted-foreground mt-1">in driver queue</p>
          </div>
        ) : (
          <p className="text-sm text-muted-foreground py-4 text-center">Not currently in queue</p>
        )}
        {queueStatus?.route_from && (
          <div className="mt-3 p-3 bg-muted rounded-xl text-xs">
            <p className="font-semibold text-foreground">{queueStatus.route_from} → {queueStatus.route_to}</p>
            <p className="text-muted-foreground mt-0.5">{queueStatus.vehicle_make} {queueStatus.vehicle_model} · {queueStatus.vehicle_capacity} seats</p>
          </div>
        )}
      </div>
      <div className="card-base p-4">
        <p className="section-label mb-3">How the driver queue works</p>
        <div className="flex flex-col gap-2 text-xs text-muted-foreground leading-relaxed">
          {[
            'Go online to join the driver queue for your chosen route.',
            'System matches you with waiting passengers based on your vehicle capacity.',
            'You receive a ride offer — accept or decline within the timeout.',
            'If you decline, you move to the end of the driver queue.',
            'Once accepted, collect fare from each passenger at their pickup point.',
            'After completing a trip, go online again to rejoin the queue.',
          ].map((rule, i) => (
            <div key={`rule-${i}`} className="flex items-start gap-2">
              <span className="w-4 h-4 rounded-full bg-secondary text-primary text-xs flex items-center justify-center font-bold shrink-0 mt-0.5">{i + 1}</span>
              <span>{rule}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
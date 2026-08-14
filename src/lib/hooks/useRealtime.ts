'use client';

import { useEffect } from 'react';
import { createClient } from '@/lib/supabase/client';

type RealtimeCallback = (payload: any) => void;

/**
 * Hook: Subscribe to booking changes for a passenger
 */
export function useBookingRealtime(passengerId: string | undefined, onUpdate: RealtimeCallback) {
  const supabase = createClient();

  useEffect(() => {
    if (!passengerId) return;

    const channel = supabase
      .channel(`bookings_passenger_${passengerId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'bookings',
        filter: `passenger_id=eq.${passengerId}`,
      }, onUpdate)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [passengerId, onUpdate, supabase]);
}

/**
 * Hook: Subscribe to driver queue changes for a route
 */
export function useDriverQueueRealtime(routeId: string | undefined, onUpdate: RealtimeCallback) {
  const supabase = createClient();

  useEffect(() => {
    if (!routeId) return;

    const channel = supabase
      .channel(`driver_queue_route_${routeId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'driver_queue',
        filter: `route_id=eq.${routeId}`,
      }, onUpdate)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [routeId, onUpdate, supabase]);
}

/**
 * Hook: Subscribe to trip status changes
 */
export function useTripStatusRealtime(tripId: string | undefined, onUpdate: RealtimeCallback) {
  const supabase = createClient();

  useEffect(() => {
    if (!tripId) return;

    const channel = supabase
      .channel(`trip_status_${tripId}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'trips',
        filter: `id=eq.${tripId}`,
      }, onUpdate)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [tripId, onUpdate, supabase]);
}

/**
 * Hook: Subscribe to all active trips for a route (for passengers)
 */
export function useActiveTripsRealtime(routeId: string | undefined, onUpdate: RealtimeCallback) {
  const supabase = createClient();

  useEffect(() => {
    if (!routeId) return;

    const channel = supabase
      .channel(`active_trips_route_${routeId}`)
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'trips',
        filter: `route_id=eq.${routeId}`,
      }, onUpdate)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [routeId, onUpdate, supabase]);
}

/**
 * Hook: Subscribe to notifications for a user
 */
export function useNotificationsRealtime(userId: string | undefined, onUpdate: RealtimeCallback) {
  const supabase = createClient();

  useEffect(() => {
    if (!userId) return;

    const channel = supabase
      .channel(`notifications_user_${userId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${userId}`,
      }, onUpdate)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId, onUpdate, supabase]);
}

/**
 * Hook: Admin — subscribe to all driver queue changes
 */
export function useAdminQueueRealtime(onUpdate: RealtimeCallback) {
  const supabase = createClient();

  useEffect(() => {
    const channel = supabase
      .channel('admin_driver_queue_all')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'driver_queue',
      }, onUpdate)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [onUpdate, supabase]);
}

/**
 * Hook: Admin — subscribe to all booking changes
 */
export function useAdminBookingsRealtime(onUpdate: RealtimeCallback) {
  const supabase = createClient();

  useEffect(() => {
    const channel = supabase
      .channel('admin_bookings_all')
      .on('postgres_changes', {
        event: '*',
        schema: 'public',
        table: 'bookings',
      }, onUpdate)
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [onUpdate, supabase]);
}

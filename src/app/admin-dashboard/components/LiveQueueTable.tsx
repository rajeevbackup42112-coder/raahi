'use client';
import React, { useState, useEffect, useCallback } from 'react';
import { RefreshCw, Users, SkipForward, Pause, Trash2, CheckCircle, Clock, Car } from 'lucide-react';
import { toast } from 'sonner';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

interface PassengerQueueEntry {
  queue_id: string;
  queue_position: number;
  passenger_name: string;
  seat_count: number;
  status: string;
  joined_at: string;
  assigned_trip_id: string | null;
}

interface DriverQueueEntry {
  queue_id: string;
  queue_position: number;
  driver_name: string;
  vehicle_make: string;
  vehicle_model: string;
  vehicle_registration: string;
  vehicle_capacity: number;
  status: string;
  joined_at: string;
  offered_at: string | null;
  offer_expires_at: string | null;
  provisional_trip_id: string | null;
}

interface CurrentMatch {
  trip_id: string;
  status: string;
  booked_seats: number;
  total_seats: number;
  driver_name: string;
  fare_per_seat: number;
}

interface RouteQueues {
  passenger_queue: PassengerQueueEntry[];
  driver_queue: DriverQueueEntry[];
  current_match: CurrentMatch | null;
  matching_status?: {
    state: string;
    message: string;
    driver_name?: string;
    vehicle_capacity?: number;
    waiting_seats?: number;
    seats_needed?: number;
    offer_expires_at?: string;
    seconds_remaining?: number;
  };
}

interface Route {
  id: string;
  from_location: string;
  to_location: string;
}

export default function LiveQueueTable() {
  const { profile } = useAuth();
  const supabase = createClient();
  const [routes, setRoutes] = useState<Route[]>([]);
  const [routeQueues, setRouteQueues] = useState<Map<string, RouteQueues>>(new Map());
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const loadQueues = useCallback(async () => {
    try {
      const { data: routesData } = await supabase
        .from('routes')
        .select('id, from_location, to_location')
        .eq('status', 'active');

      if (!routesData) return;
      setRoutes(routesData);

      const newMap = new Map<string, RouteQueues>();
      await Promise.all(
        routesData.map(async (route) => {
          const { data } = await supabase.rpc('get_route_queues_for_admin', {
            p_route_id: route.id,
          });
          if (data) {
            newMap.set(route.id, data as RouteQueues);
          }
        })
      );
      setRouteQueues(newMap);
    } catch {
      // Silently handle
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [supabase]);

  useEffect(() => { loadQueues(); }, [loadQueues]);

  useEffect(() => {
    const channel = supabase
      .channel('admin-live-queue-v2')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'driver_queue' }, () => loadQueues())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'passenger_queue' }, () => loadQueues())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'trips' }, () => loadQueues())
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [loadQueues, supabase]);

  const handleOverride = async (routeId: string, newQueueEntryId: string, driverName: string) => {
    if (!profile?.id) return;
    setActionLoading(newQueueEntryId);
    try {
      const { data, error } = await supabase.rpc('admin_override_active_driver', {
        p_admin_id: profile.id,
        p_route_id: routeId,
        p_new_queue_entry_id: newQueueEntryId,
        p_reason: `Admin manual override — activated ${driverName}`,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Override failed'); return; }
      toast.success(`Override applied — ${driverName} is now active`);
      await loadQueues();
    } catch (err: any) {
      toast.error(err?.message || 'Override failed');
    } finally {
      setActionLoading(null);
    }
  };

  const handlePause = async (queueEntryId: string, driverName: string) => {
    if (!profile?.id) return;
    if (!confirm(`Pause ${driverName}?`)) return;
    setActionLoading(queueEntryId);
    try {
      const { data, error } = await supabase.rpc('admin_pause_driver', {
        p_admin_id: profile.id,
        p_queue_entry_id: queueEntryId,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Pause failed'); return; }
      toast.success(`${driverName} paused`);
      await loadQueues();
    } catch (err: any) {
      toast.error(err?.message || 'Pause failed');
    } finally {
      setActionLoading(null);
    }
  };

  const handleSkip = async (queueEntryId: string, driverName: string) => {
    if (!profile?.id) return;
    setActionLoading(queueEntryId);
    try {
      const { data, error } = await supabase.rpc('admin_skip_driver', {
        p_admin_id: profile.id,
        p_queue_entry_id: queueEntryId,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Skip failed'); return; }
      toast.success(`${driverName} moved to end of queue`);
      await loadQueues();
    } catch (err: any) {
      toast.error(err?.message || 'Skip failed');
    } finally {
      setActionLoading(null);
    }
  };

  const handleRemove = async (queueEntryId: string, driverName: string) => {
    if (!profile?.id) return;
    if (!confirm(`Remove ${driverName} from queue?`)) return;
    setActionLoading(queueEntryId);
    try {
      const { data, error } = await supabase.rpc('admin_remove_from_queue', {
        p_admin_id: profile.id,
        p_queue_entry_id: queueEntryId,
        p_reason: 'Admin removed from queue',
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Remove failed'); return; }
      toast.success(`${driverName} removed from queue`);
      await loadQueues();
    } catch (err: any) {
      toast.error(err?.message || 'Remove failed');
    } finally {
      setActionLoading(null);
    }
  };

  const handleAdminRemovePassenger = async (queueId: string, passengerName: string) => {
    if (!profile?.id) return;
    if (!confirm(`Remove ${passengerName} from passenger queue?`)) return;
    setActionLoading(queueId);
    try {
      const { error } = await supabase
        .from('passenger_queue')
        .update({ status: 'CANCELLED', updated_at: new Date().toISOString() })
        .eq('id', queueId);
      if (error) throw error;

      await supabase.from('audit_logs').insert({
        performed_by: profile.id,
        action: 'admin_changed_queue_order',
        target_table: 'passenger_queue',
        target_id: queueId,
        notes: `Admin removed ${passengerName} from passenger queue`,
      });

      toast.success(`${passengerName} removed from passenger queue`);
      await loadQueues();
    } catch (err: any) {
      toast.error(err?.message || 'Remove failed');
    } finally {
      setActionLoading(null);
    }
  };

  const getDriverStatusBadge = (status: string) => {
    switch (status) {
      case 'offered': return 'bg-primary/10 text-primary';
      case 'assigned': return 'status-active';
      case 'active': return 'status-active';
      case 'paused': return 'bg-yellow-100 text-yellow-700';
      default: return 'status-waiting';
    }
  };

  const getPassengerStatusBadge = (status: string) => {
    switch (status) {
      case 'ASSIGNED': return 'status-active';
      case 'MATCHING': return 'bg-primary/10 text-primary';
      default: return 'status-waiting';
    }
  };

  return (
    <div className="card-base overflow-hidden">
      <div className="flex items-center justify-between px-5 py-4 border-b">
        <div>
          <h2 className="font-semibold text-sm text-foreground">Live Queue — Passenger & Driver</h2>
          <p className="text-xs text-muted-foreground mt-0.5">FIFO queues across all routes · Real-time</p>
        </div>
        <div className="flex items-center gap-2">
          <span className="flex items-center gap-1.5 text-xs text-success font-semibold">
            <span className="w-1.5 h-1.5 rounded-full bg-success animate-pulse-soft" />
            Live
          </span>
          <button onClick={() => { setRefreshing(true); loadQueues(); }} className="p-2 rounded-xl hover:bg-muted transition-colors" aria-label="Refresh queue">
            <RefreshCw size={14} className={`text-muted-foreground ${refreshing ? 'animate-spin' : ''}`} />
          </button>
        </div>
      </div>

      <div className="p-5">
        {loading ? (
          <div className="flex flex-col gap-4">
            {[1, 2].map((i) => <div key={i} className="h-48 bg-muted rounded-xl animate-pulse" />)}
          </div>
        ) : routes.length === 0 ? (
          <div className="text-center py-10">
            <Users size={32} className="text-muted-foreground mx-auto mb-3" />
            <p className="text-sm text-muted-foreground">No active routes.</p>
          </div>
        ) : (
          <div className="flex flex-col gap-8">
            {routes.map((route) => {
              const queues = routeQueues.get(route.id);
              const passengerQueue = queues?.passenger_queue ?? [];
              const driverQueue = queues?.driver_queue ?? [];
              const currentMatch = queues?.current_match;

              return (
                <div key={route.id}>
                  <div className="flex items-center gap-2 mb-4">
                    <p className="font-bold text-foreground text-sm">{route.from_location} → {route.to_location}</p>
                    <span className="text-xs text-muted-foreground">
                      {passengerQueue.length} waiting · {driverQueue.length} drivers
                    </span>
                  </div>

                  <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
                    {/* Passenger Queue */}
                    <div>
                      <div className="flex items-center gap-2 mb-2">
                        <Users size={13} className="text-primary" />
                        <p className="text-xs font-bold text-primary uppercase tracking-wide">Passenger Queue</p>
                      </div>
                      {passengerQueue.length === 0 ? (
                        <div className="p-3 bg-muted rounded-xl">
                          <p className="text-xs text-muted-foreground">No passengers waiting.</p>
                        </div>
                      ) : (
                        <div className="flex flex-col gap-1.5">
                          {passengerQueue.map((entry) => (
                            <div key={entry.queue_id} className="flex items-center gap-2 p-2.5 bg-muted/50 rounded-xl border border-border">
                              <span className="w-6 h-6 rounded-full bg-primary/10 text-primary text-xs font-bold flex items-center justify-center shrink-0">
                                #{entry.queue_position}
                              </span>
                              <div className="flex-1 min-w-0">
                                <p className="text-sm font-semibold text-foreground truncate">{entry.passenger_name}</p>
                                <p className="text-xs text-muted-foreground">{entry.seat_count} seat{entry.seat_count !== 1 ? 's' : ''}</p>
                              </div>
                              <span className={`text-xs font-semibold px-1.5 py-0.5 rounded-full ${getPassengerStatusBadge(entry.status)}`}>
                                {entry.status === 'ASSIGNED' ? 'Assigned' : entry.status === 'MATCHING' ? 'Matching' : 'Waiting'}
                              </span>
                              <button
                                onClick={() => handleAdminRemovePassenger(entry.queue_id, entry.passenger_name)}
                                disabled={actionLoading === entry.queue_id}
                                className="p-1 rounded-lg hover:bg-muted text-danger transition-colors"
                                title="Remove from queue"
                              >
                                <Trash2 size={11} />
                              </button>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>

                    {/* Driver Queue */}
                    <div>
                      <div className="flex items-center gap-2 mb-2">
                        <Car size={13} className="text-success" />
                        <p className="text-xs font-bold text-success uppercase tracking-wide">Driver Queue</p>
                      </div>
                      {driverQueue.length === 0 ? (
                        <div className="p-3 bg-muted rounded-xl">
                          <p className="text-xs text-muted-foreground">No drivers in queue.</p>
                        </div>
                      ) : (
                        <div className="flex flex-col gap-1.5">
                          {driverQueue.map((entry, idx) => (
                            <div key={entry.queue_id} className={`flex items-center gap-2 p-2.5 rounded-xl border ${entry.status === 'offered' ? 'bg-primary/5 border-primary/20' : entry.status === 'assigned' || entry.status === 'active' ? 'bg-green-50/50 border-success/20' : 'bg-muted/50 border-border'}`}>
                              <span className="w-6 h-6 rounded-full bg-success/10 text-success text-xs font-bold flex items-center justify-center shrink-0">
                                #{idx + 1}
                              </span>
                              <div className="flex-1 min-w-0">
                                <p className="text-sm font-semibold text-foreground truncate">{entry.driver_name}</p>
                                <p className="text-xs text-muted-foreground">
                                  {entry.vehicle_make} {entry.vehicle_model} · {entry.vehicle_capacity} seats
                                </p>
                                {entry.status === 'offered' && entry.offer_expires_at && (
                                  <p className="text-xs text-primary font-semibold mt-0.5">
                                    <Clock size={9} className="inline mr-0.5" />
                                    Offer pending
                                  </p>
                                )}
                              </div>
                              <span className={`text-xs font-semibold px-1.5 py-0.5 rounded-full ${getDriverStatusBadge(entry.status)}`}>
                                {entry.status === 'offered' ? 'Offered' :
                                 entry.status === 'assigned' || entry.status === 'active' ? 'Active' :
                                 entry.status === 'paused' ? 'Paused' : 'Queued'}
                              </span>
                              <div className="flex items-center gap-0.5">
                                {entry.status === 'waiting' && (
                                  <button
                                    onClick={() => handleOverride(route.id, entry.queue_id, entry.driver_name)}
                                    disabled={actionLoading === entry.queue_id}
                                    className="p-1 rounded-lg hover:bg-secondary text-success transition-colors"
                                    title="Make active"
                                  >
                                    <CheckCircle size={11} />
                                  </button>
                                )}
                                <button
                                  onClick={() => handleSkip(entry.queue_id, entry.driver_name)}
                                  disabled={actionLoading === entry.queue_id}
                                  className="p-1 rounded-lg hover:bg-muted text-muted-foreground transition-colors"
                                  title="Skip to end"
                                >
                                  <SkipForward size={11} />
                                </button>
                                <button
                                  onClick={() => handlePause(entry.queue_id, entry.driver_name)}
                                  disabled={actionLoading === entry.queue_id}
                                  className="p-1 rounded-lg hover:bg-muted text-warning transition-colors"
                                  title="Pause"
                                >
                                  <Pause size={11} />
                                </button>
                                <button
                                  onClick={() => handleRemove(entry.queue_id, entry.driver_name)}
                                  disabled={actionLoading === entry.queue_id}
                                  className="p-1 rounded-lg hover:bg-muted text-danger transition-colors"
                                  title="Remove"
                                >
                                  <Trash2 size={11} />
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Matching Status Panel */}
                  {queues?.matching_status && (
                    <div className={`mt-3 p-3 rounded-xl border ${
                      queues.matching_status.state === 'offer_sent' ? 'bg-primary/5 border-primary/20' :
                      queues.matching_status.state === 'active_trip' ? 'bg-green-50 border-green-200' :
                      queues.matching_status.state === 'waiting_for_passengers' ? 'bg-yellow-50 border-yellow-200' :
                      queues.matching_status.state === 'ready_to_match'? 'bg-green-50 border-green-200' : 'bg-muted border-border'
                    }`}>
                      <div className="flex items-center gap-2 mb-1">
                        <span className={`w-2 h-2 rounded-full ${
                          queues.matching_status.state === 'offer_sent' ? 'bg-primary animate-pulse' :
                          queues.matching_status.state === 'active_trip' ? 'bg-success animate-pulse-soft' :
                          queues.matching_status.state === 'waiting_for_passengers' ? 'bg-warning animate-pulse' :
                          queues.matching_status.state === 'ready_to_match'? 'bg-success animate-pulse-soft' : 'bg-muted-foreground'
                        }`} />
                        <p className={`text-xs font-bold uppercase tracking-wide ${
                          queues.matching_status.state === 'offer_sent' ? 'text-primary' :
                          queues.matching_status.state === 'active_trip' ? 'text-success' :
                          queues.matching_status.state === 'waiting_for_passengers' ? 'text-warning' :
                          queues.matching_status.state === 'ready_to_match'? 'text-success' : 'text-muted-foreground'
                        }`}>Matching Status</p>
                      </div>
                      <p className="text-xs text-foreground font-medium">{queues.matching_status.message}</p>
                      {queues.matching_status.state === 'waiting_for_passengers' && queues.matching_status.seats_needed !== undefined && (
                        <div className="mt-2 flex items-center gap-3">
                          <div className="flex-1 h-1.5 bg-muted rounded-full overflow-hidden">
                            <div
                              className="h-full bg-warning rounded-full transition-all"
                              style={{
                                width: `${Math.min(100, ((queues.matching_status.waiting_seats ?? 0) / (queues.matching_status.vehicle_capacity ?? 1)) * 100)}%`
                              }}
                            />
                          </div>
                          <span className="text-xs text-muted-foreground tabular-nums whitespace-nowrap">
                            {queues.matching_status.waiting_seats ?? 0} / {queues.matching_status.vehicle_capacity} seats
                          </span>
                        </div>
                      )}
                    </div>
                  )}

                  {/* Current Match / Trip */}
                  {currentMatch && (
                    <div className="mt-3 p-3 bg-secondary/50 rounded-xl border border-primary/10">
                      <p className="text-xs font-bold text-primary uppercase tracking-wide mb-2">Current Match / Trip</p>
                      <div className="flex items-center justify-between">
                        <div>
                          <p className="text-sm font-semibold text-foreground">Driver: {currentMatch.driver_name}</p>
                          <p className="text-xs text-muted-foreground">{currentMatch.booked_seats} / {currentMatch.total_seats} passengers · ₹{currentMatch.fare_per_seat}/seat</p>
                        </div>
                        <span className={`text-xs font-semibold px-2 py-1 rounded-full ${
                          currentMatch.status === 'in_progress' ? 'bg-primary/10 text-primary' :
                          currentMatch.status === 'accepting_bookings' ? 'status-active' :
                          currentMatch.status === 'full'|| currentMatch.status === 'ready' ? 'bg-green-100 text-green-700' : 'status-waiting'
                        }`}>
                          {currentMatch.status === 'accepting_bookings' ? 'Accepting' :
                           currentMatch.status === 'in_progress' ? 'In Progress' :
                           currentMatch.status === 'full' ? 'Full' :
                           currentMatch.status === 'ready' ? 'Ready' :
                           currentMatch.status}
                        </span>
                      </div>
                      {currentMatch.total_seats > 0 && (
                        <div className="flex gap-1 mt-2">
                          {Array.from({ length: currentMatch.total_seats }).map((_, si) => (
                            <div
                              key={`match-seat-${route.id}-${si}`}
                              className={`flex-1 h-2 rounded-full ${si < currentMatch.booked_seats ? 'bg-primary' : 'bg-muted border border-border'}`}
                            />
                          ))}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
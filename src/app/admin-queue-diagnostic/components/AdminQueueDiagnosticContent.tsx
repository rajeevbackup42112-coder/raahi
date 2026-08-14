'use client';
import React, { useState, useEffect, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import { Activity, RefreshCw, Users, Car, Zap, Clock, CheckCircle, AlertTriangle } from 'lucide-react';

interface Route { id: string; from_location: string; to_location: string; }

interface PassengerQueueRow {
  id: string;
  queue_sequence: number;
  display_position: number;
  passenger_name: string;
  seat_count: number;
  status: string;
  is_test_data: boolean;
  assigned_trip_id: string | null;
  joined_at: string;
}

interface DriverQueueRow {
  id: string;
  queue_order: number;
  driver_name: string;
  vehicle_make: string;
  vehicle_model: string;
  capacity: number;
  status: string;
  is_test_data: boolean;
  offer_expires_at: string | null;
  provisional_trip_id: string | null;
  joined_at: string;
}

interface TripRow {
  trip_id: string;
  status: string;
  notes: string | null;
  is_test_data: boolean;
  driver_name: string | null;
  vehicle_make: string | null;
  vehicle_model: string | null;
  total_seats: number;
  booked_seats: number;
  passenger_count: number;
  created_at: string;
}

interface AuditRow {
  action: string;
  notes: string | null;
  new_value: Record<string, unknown> | null;
  created_at: string;
}

interface HarnessState {
  route_id: string;
  passenger_queue: PassengerQueueRow[];
  driver_queue: DriverQueueRow[];
  current_trips: TripRow[];
  recent_audit: AuditRow[];
  snapshot_at: string;
}

export default function AdminQueueDiagnosticContent() {
  const { profile } = useAuth();
  const supabase = createClient();

  const [routes, setRoutes] = useState<Route[]>([]);
  const [selectedRouteId, setSelectedRouteId] = useState<string>('');
  const [state, setState] = useState<HarnessState | null>(null);
  const [loading, setLoading] = useState(false);
  const [autoRefresh, setAutoRefresh] = useState(false);
  const [now, setNow] = useState<Date | null>(null);

  useEffect(() => { setNow(new Date()); }, []);

  useEffect(() => {
    supabase.from('routes').select('id, from_location, to_location').eq('status', 'active').then(({ data }) => {
      if (data) setRoutes(data);
    });
  }, []);

  const refresh = useCallback(async () => {
    if (!selectedRouteId || !profile?.id) return;
    setLoading(true);
    const { data, error } = await supabase.rpc('get_test_harness_state', {
      p_route_id: selectedRouteId,
      p_admin_id: profile.id,
    });
    if (!error && data) setState(data as HarnessState);
    setLoading(false);
  }, [selectedRouteId, profile?.id]);

  useEffect(() => {
    if (selectedRouteId) refresh();
  }, [selectedRouteId, refresh]);

  useEffect(() => {
    if (!autoRefresh || !selectedRouteId) return;
    const interval = setInterval(refresh, 3000);
    return () => clearInterval(interval);
  }, [autoRefresh, selectedRouteId, refresh]);

  // Realtime subscription
  useEffect(() => {
    if (!selectedRouteId) return;
    const channel = supabase
      .channel('diagnostic-realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'passenger_queue' }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'driver_queue' }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'trips' }, refresh)
      .subscribe();
    return () => { supabase.removeChannel(channel); };
  }, [selectedRouteId, refresh]);

  const statusColor = (status: string) => {
    switch (status.toUpperCase()) {
      case 'WAITING': case 'waiting': return 'text-blue-600 bg-blue-50';
      case 'MATCHING': case 'offered': return 'text-yellow-700 bg-yellow-50';
      case 'ASSIGNED': case 'assigned': return 'text-green-700 bg-green-50';
      case 'CANCELLED': case 'offline': case 'cancelled': return 'text-red-600 bg-red-50';
      case 'COMPLETED': case 'completed': return 'text-gray-600 bg-gray-100';
      default: return 'text-muted-foreground bg-muted';
    }
  };

  const waitingSeats = state?.passenger_queue.filter(p => p.status === 'WAITING').reduce((s, p) => s + p.seat_count, 0) ?? 0;
  const firstDriver = state?.driver_queue[0];
  const matchingStatus = () => {
    if (!firstDriver) return 'No drivers in queue';
    if (firstDriver.status === 'offered') return `D1 offer sent — expires ${firstDriver.offer_expires_at ? new Date(firstDriver.offer_expires_at).toLocaleTimeString() : 'N/A'}`;
    if (firstDriver.status === 'assigned') return 'Driver assigned — trip active';
    const needed = firstDriver.capacity - waitingSeats;
    if (needed > 0) return `Waiting for ${needed} more seat${needed !== 1 ? 's' : ''} to fill ${firstDriver.driver_name}'s ${firstDriver.capacity}-seat vehicle`;
    return `Ready to match — ${waitingSeats} seats waiting, ${firstDriver.capacity}-seat vehicle available`;
  };

  return (
    <div className="p-6 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex items-center gap-3 mb-6">
        <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center">
          <Activity size={20} className="text-primary" />
        </div>
        <div>
          <h1 className="text-xl font-bold text-foreground">Queue Diagnostic View</h1>
          <p className="text-xs text-muted-foreground">Real-time passenger queue · driver queue · current trips · audit log</p>
        </div>
      </div>

      {/* Controls */}
      <div className="card-base p-4 mb-6 flex flex-wrap items-center gap-3">
        <select
          value={selectedRouteId}
          onChange={e => setSelectedRouteId(e.target.value)}
          className="border border-border rounded-xl px-3 py-2 text-sm bg-background flex-1 min-w-48"
        >
          <option value="">— Select route —</option>
          {routes.map(r => (
            <option key={r.id} value={r.id}>{r.from_location} → {r.to_location}</option>
          ))}
        </select>
        <button onClick={refresh} disabled={loading || !selectedRouteId}
          className="btn-secondary text-sm px-4 py-2 flex items-center gap-2">
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} /> Refresh
        </button>
        <label className="flex items-center gap-2 text-sm text-muted-foreground cursor-pointer">
          <input type="checkbox" checked={autoRefresh} onChange={e => setAutoRefresh(e.target.checked)} className="rounded" />
          Auto-refresh (3s)
        </label>
        {state && (
          <span className="text-xs text-muted-foreground">
            Snapshot: {now ? new Date(state.snapshot_at).toLocaleTimeString() : state.snapshot_at}
          </span>
        )}
      </div>

      {!selectedRouteId && (
        <div className="card-base p-10 text-center text-muted-foreground">
          <Activity size={32} className="mx-auto mb-3 opacity-30" />
          <p>Select a route to view queue state</p>
        </div>
      )}

      {selectedRouteId && state && (
        <>
          {/* Matching status banner */}
          <div className={`rounded-xl px-4 py-3 mb-6 flex items-center gap-3 ${firstDriver?.status === 'offered' ? 'bg-yellow-50 border border-yellow-200' : firstDriver?.status === 'assigned' ? 'bg-green-50 border border-green-200' : 'bg-muted border border-border'}`}>
            <Zap size={16} className={firstDriver?.status === 'offered' ? 'text-yellow-600' : firstDriver?.status === 'assigned' ? 'text-green-600' : 'text-muted-foreground'} />
            <p className="text-sm font-medium text-foreground">{matchingStatus()}</p>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
            {/* Passenger Queue */}
            <div className="card-base p-4">
              <div className="flex items-center gap-2 mb-4">
                <Users size={16} className="text-primary" />
                <h2 className="text-sm font-bold text-foreground">Passenger Queue</h2>
                <span className="ml-auto text-xs text-muted-foreground">{state.passenger_queue.length} entries · {waitingSeats} waiting seats</span>
              </div>
              {state.passenger_queue.length === 0 ? (
                <p className="text-xs text-muted-foreground text-center py-4">No passengers in queue</p>
              ) : (
                <div className="space-y-1.5">
                  <div className="grid grid-cols-6 text-xs font-semibold text-muted-foreground px-2 pb-1 border-b border-border">
                    <span>Pos</span>
                    <span>Seq#</span>
                    <span className="col-span-2">Passenger</span>
                    <span>Seats</span>
                    <span>Status</span>
                  </div>
                  {state.passenger_queue.map((p) => (
                    <div key={p.id} className={`grid grid-cols-6 text-xs px-2 py-1.5 rounded-lg items-center ${p.is_test_data ? 'bg-blue-50/60' : 'bg-muted/40'}`}>
                      <span className="font-bold text-foreground">#{p.display_position}</span>
                      <span className="text-muted-foreground font-mono">{p.queue_sequence}</span>
                      <span className="col-span-2 font-medium text-foreground truncate">
                        {p.passenger_name}
                        {p.is_test_data && <span className="ml-1 text-amber-500 text-[10px]">TEST</span>}
                      </span>
                      <span className="text-center">{p.seat_count}</span>
                      <span className={`text-[10px] font-semibold px-1.5 py-0.5 rounded-full text-center ${statusColor(p.status)}`}>{p.status}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Driver Queue */}
            <div className="card-base p-4">
              <div className="flex items-center gap-2 mb-4">
                <Car size={16} className="text-primary" />
                <h2 className="text-sm font-bold text-foreground">Driver Queue</h2>
                <span className="ml-auto text-xs text-muted-foreground">{state.driver_queue.length} drivers</span>
              </div>
              {state.driver_queue.length === 0 ? (
                <p className="text-xs text-muted-foreground text-center py-4">No drivers in queue</p>
              ) : (
                <div className="space-y-1.5">
                  <div className="grid grid-cols-5 text-xs font-semibold text-muted-foreground px-2 pb-1 border-b border-border">
                    <span>#</span>
                    <span className="col-span-2">Driver / Vehicle</span>
                    <span>Cap</span>
                    <span>Status</span>
                  </div>
                  {state.driver_queue.map((d) => (
                    <div key={d.id} className={`text-xs px-2 py-1.5 rounded-lg ${d.is_test_data ? 'bg-green-50/60' : 'bg-muted/40'}`}>
                      <div className="grid grid-cols-5 items-center">
                        <span className="font-bold text-foreground">#{d.queue_order}</span>
                        <span className="col-span-2 font-medium text-foreground truncate">
                          {d.driver_name}
                          {d.is_test_data && <span className="ml-1 text-amber-500 text-[10px]">TEST</span>}
                          <span className="block text-muted-foreground font-normal">{d.vehicle_make} {d.vehicle_model}</span>
                        </span>
                        <span className="text-center font-semibold">{d.capacity}</span>
                        <span className={`text-[10px] font-semibold px-1.5 py-0.5 rounded-full text-center ${statusColor(d.status)}`}>{d.status}</span>
                      </div>
                      {d.status === 'offered' && d.offer_expires_at && (
                        <div className="mt-1 flex items-center gap-1 text-yellow-600">
                          <Clock size={10} />
                          <span>Expires: {new Date(d.offer_expires_at).toLocaleTimeString()}</span>
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Current Trips */}
          <div className="card-base p-4 mb-6">
            <div className="flex items-center gap-2 mb-4">
              <Zap size={16} className="text-primary" />
              <h2 className="text-sm font-bold text-foreground">Current Trips</h2>
              <span className="ml-auto text-xs text-muted-foreground">{state.current_trips.length} active</span>
            </div>
            {state.current_trips.length === 0 ? (
              <p className="text-xs text-muted-foreground text-center py-4">No active trips</p>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                {state.current_trips.map(t => (
                  <div key={t.trip_id} className={`rounded-xl p-3 border ${t.is_test_data ? 'bg-amber-50 border-amber-200' : 'bg-muted border-border'}`}>
                    <div className="flex items-center justify-between mb-1">
                      <span className="text-sm font-semibold text-foreground">{t.driver_name ?? 'No driver'}</span>
                      <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${statusColor(t.status)}`}>{t.status}</span>
                    </div>
                    <p className="text-xs text-muted-foreground">{t.vehicle_make} {t.vehicle_model} · {t.passenger_count} passengers</p>
                    {t.notes && <p className="text-xs text-amber-600 mt-0.5">{t.notes}</p>}
                    {t.is_test_data && <span className="text-[10px] text-amber-500 font-semibold">TEST DATA</span>}
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Audit Log */}
          <div className="card-base p-4">
            <div className="flex items-center gap-2 mb-4">
              <Activity size={16} className="text-primary" />
              <h2 className="text-sm font-bold text-foreground">Recent Audit Events (last 2h)</h2>
            </div>
            {state.recent_audit.length === 0 ? (
              <p className="text-xs text-muted-foreground text-center py-4">No recent audit events</p>
            ) : (
              <div className="space-y-1 max-h-64 overflow-y-auto">
                {state.recent_audit.map((a, i) => (
                  <div key={i} className="flex items-start gap-2 text-xs py-1 border-b border-border/50 last:border-0">
                    <CheckCircle size={12} className="text-green-500 shrink-0 mt-0.5" />
                    <div className="flex-1 min-w-0">
                      <span className="font-semibold text-foreground">{a.action}</span>
                      {a.notes && <span className="text-muted-foreground ml-2">{a.notes}</span>}
                    </div>
                    <span className="text-muted-foreground shrink-0 font-mono">
                      {new Date(a.created_at).toLocaleTimeString()}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Fit-Aware FIFO Policy */}
          <div className="card-base p-4 mt-6 border-l-4 border-primary">
            <div className="flex items-center gap-2 mb-2">
              <AlertTriangle size={16} className="text-primary" />
              <h2 className="text-sm font-bold text-foreground">Fit-Aware FIFO Policy</h2>
            </div>
            <div className="text-xs text-muted-foreground space-y-1">
              <p><strong className="text-foreground">keep_multi_seat_booking_together = TRUE</strong></p>
              <p>If a multi-seat booking cannot fit remaining vehicle capacity, it is <strong>deferred</strong> without changing its queue_sequence.</p>
              <p>The system fills remaining seats from later smaller bookings. The deferred booking retains its original FIFO priority for the next vehicle.</p>
              <p className="mt-2 font-semibold text-foreground">Example: Vehicle = 4 seats, Booking A=3, B=2, C=1</p>
              <p>→ A(3) + C(1) = 4 seats assigned. B remains queue #1 for next vehicle.</p>
              <p>→ B's queue_sequence is NOT changed. B is considered before any later booking.</p>
            </div>
          </div>
        </>
      )}
    </div>
  );
}

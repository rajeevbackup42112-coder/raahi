'use client';
import React, { useEffect, useState } from 'react';
import { CheckCircle, AlertTriangle, XCircle, Activity } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

interface RouteStatus {
  id: string;
  route: string;
  activeVehicles: number;
  queueDepth: number;
}

const systemItems = [
  { id: 'sys-db', label: 'Database', status: 'ok', detail: 'Supabase PostgreSQL · Connected' },
  { id: 'sys-auth', label: 'Authentication', status: 'ok', detail: 'Supabase Auth · Active' },
  { id: 'sys-realtime', label: 'Realtime', status: 'ok', detail: 'Queue sync · Live' },
  { id: 'sys-sms', label: 'SMS / OTP', status: 'warning', detail: 'Provider not configured' },
  { id: 'sys-payments', label: 'Payments', status: 'off', detail: 'Not enabled in V1' },
];

const statusIcon = (s: string) => {
  if (s === 'ok') return <CheckCircle size={14} className="text-success" />;
  if (s === 'warning') return <AlertTriangle size={14} className="text-warning" />;
  if (s === 'off') return <XCircle size={14} className="text-muted-foreground" />;
  return <Activity size={14} className="text-info" />;
};

export default function SystemStatusPanel() {
  const [routeStatuses, setRouteStatuses] = useState<RouteStatus[]>([]);
  const [loadingRoutes, setLoadingRoutes] = useState(true);

  useEffect(() => {
    async function fetchRouteStatuses() {
      const supabase = createClient();

      const { data: routes } = await supabase
        .from('routes')
        .select('id, from_location, to_location')
        .eq('status', 'active');

      if (!routes) { setLoadingRoutes(false); return; }

      const enriched = await Promise.all(
        routes.map(async (r) => {
          const [vehicleRes, queueRes] = await Promise.all([
            supabase.from('driver_queue').select('id', { count: 'exact', head: true }).eq('route_id', r.id).in('status', ['waiting', 'offered', 'assigned']),
            supabase.from('passenger_queue').select('id', { count: 'exact', head: true }).eq('route_id', r.id).in('status', ['WAITING', 'MATCHING']),
          ]);
          return {
            id: r.id,
            route: `${r.from_location} → ${r.to_location}`,
            activeVehicles: vehicleRes.count ?? 0,
            queueDepth: queueRes.count ?? 0,
          };
        })
      );

      setRouteStatuses(enriched);
      setLoadingRoutes(false);
    }

    fetchRouteStatuses();
  }, []);

  return (
    <div className="flex flex-col gap-4">
      <div className="card-base p-5">
        <div className="flex items-center gap-2 mb-4">
          <Activity size={16} className="text-primary" />
          <h2 className="font-semibold text-sm text-foreground">System Status</h2>
        </div>
        <div className="flex flex-col gap-2">
          {systemItems.map((item) => (
            <div key={item.id} className="flex items-center justify-between gap-3 py-1.5">
              <div className="flex items-center gap-2 min-w-0">
                {statusIcon(item.status)}
                <div className="min-w-0">
                  <p className="text-xs font-semibold text-foreground">{item.label}</p>
                  <p className="text-xs text-muted-foreground truncate">{item.detail}</p>
                </div>
              </div>
              <span className={`text-xs font-semibold px-2 py-0.5 rounded-full shrink-0 ${item.status === 'ok' ? 'status-active' : item.status === 'warning' ? 'status-waiting' : 'status-offline'}`}>
                {item.status === 'ok' ? 'OK' : item.status === 'warning' ? 'Warn' : 'Off'}
              </span>
            </div>
          ))}
        </div>
      </div>

      <div className="card-base p-5">
        <h2 className="font-semibold text-sm text-foreground mb-4">Route Overview</h2>
        {loadingRoutes ? (
          <div className="flex flex-col gap-3">
            {[1, 2].map((i) => (
              <div key={i} className="p-3 rounded-xl bg-muted animate-pulse h-14" />
            ))}
          </div>
        ) : routeStatuses.length === 0 ? (
          <p className="text-xs text-muted-foreground">No active routes.</p>
        ) : (
          <div className="flex flex-col gap-3">
            {routeStatuses.map((r) => (
              <div key={r.id} className="p-3 rounded-xl bg-muted">
                <div className="flex items-center justify-between mb-2">
                  <p className="text-xs font-semibold text-foreground">{r.route}</p>
                  <span className="status-active text-xs font-semibold px-2 py-0.5 rounded-full">Active</span>
                </div>
                <div className="flex items-center gap-4 text-xs text-muted-foreground">
                  <span>{r.activeVehicles} driver{r.activeVehicles !== 1 ? 's' : ''} online</span>
                  <span>{r.queueDepth} in queue</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="card-base p-5 border-warning/40 bg-amber-50/50">
        <div className="flex items-start gap-2">
          <AlertTriangle size={16} className="text-warning shrink-0 mt-0.5" />
          <div>
            <p className="text-xs font-semibold text-foreground mb-1">Action needed</p>
            <p className="text-xs text-muted-foreground leading-relaxed">
              SMS provider is not configured. Mobile OTP login will not work until an SMS provider is connected in Business Settings.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
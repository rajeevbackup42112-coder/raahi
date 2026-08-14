'use client';
import React, { useState, useEffect, useCallback } from 'react';
import { Search, RefreshCw, FileText } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { toast } from 'sonner';

interface AuditLog {
  id: string;
  performed_by: string | null;
  action: string;
  target_table: string | null;
  target_id: string | null;
  old_value: any;
  new_value: any;
  notes: string | null;
  created_at: string;
  performer?: { name: string; role: string } | null;
}

const ACTION_COLORS: Record<string, string> = {
  booking_created: 'status-active',
  booking_cancelled: 'status-cancelled',
  no_show_marked: 'status-cancelled',
  driver_went_online: 'bg-blue-100 text-blue-700',
  driver_became_active: 'bg-green-100 text-green-700',
  driver_paused: 'status-waiting',
  driver_removed: 'status-cancelled',
  admin_override_driver: 'bg-purple-100 text-purple-700',
  passenger_replaced: 'bg-orange-100 text-orange-700',
  passenger_reassigned: 'bg-orange-100 text-orange-700',
  trip_became_full: 'bg-blue-100 text-blue-700',
  settings_updated: 'bg-gray-100 text-gray-700',
  route_updated: 'bg-gray-100 text-gray-700',
  vehicle_created: 'status-active',
  vehicle_updated: 'bg-gray-100 text-gray-700',
  vehicle_assigned: 'bg-blue-100 text-blue-700',
};

export default function AdminAuditLogContent() {
  const supabase = createClient();
  const [logs, setLogs] = useState<AuditLog[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [actionFilter, setActionFilter] = useState('all');
  const [dateFilter, setDateFilter] = useState('');

  const loadLogs = useCallback(async () => {
    setLoading(true);
    try {
      let query = supabase
        .from('audit_logs')
        .select(`
          id, performed_by, action, target_table, target_id,
          old_value, new_value, notes, created_at,
          performer:performed_by(name, role)
        `)
        .order('created_at', { ascending: false })
        .limit(300);

      if (dateFilter) {
        const start = new Date(dateFilter);
        const end = new Date(dateFilter);
        end.setDate(end.getDate() + 1);
        query = query.gte('created_at', start.toISOString()).lt('created_at', end.toISOString());
      }

      const { data, error } = await query;
      if (error) throw error;
      setLogs((data as any) || []);
    } catch {
      toast.error('Failed to load audit logs');
    } finally {
      setLoading(false);
    }
  }, [supabase, dateFilter]);

  useEffect(() => { loadLogs(); }, [loadLogs]);

  const filtered = logs.filter((l) => {
    const q = search.toLowerCase();
    const matchSearch = !q ||
      l.action.toLowerCase().includes(q) ||
      l.target_table?.toLowerCase().includes(q) ||
      l.notes?.toLowerCase().includes(q) ||
      (l.performer as any)?.name?.toLowerCase().includes(q) ||
      l.target_id?.toLowerCase().includes(q);
    const matchAction = actionFilter === 'all' || l.action === actionFilter;
    return matchSearch && matchAction;
  });

  const uniqueActions = Array.from(new Set(logs.map((l) => l.action))).sort();

  return (
    <div className="px-4 sm:px-6 lg:px-8 xl:px-10 py-6 max-w-screen-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Activity Log</h1>
          <p className="text-sm text-muted-foreground mt-0.5">Audit trail of all admin and system actions</p>
        </div>
        <button onClick={loadLogs} className="btn-secondary gap-2 px-3 py-2.5">
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
        </button>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap items-center gap-3 mb-5">
        <div className="relative flex-1 min-w-[200px] max-w-sm">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input
            type="text"
            placeholder="Search action, entity, notes..."
            className="input-field pl-9"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <select className="input-field w-auto" value={actionFilter} onChange={(e) => setActionFilter(e.target.value)}>
          <option value="all">All Actions</option>
          {uniqueActions.map((a) => (
            <option key={a} value={a}>{a.replace(/_/g, ' ')}</option>
          ))}
        </select>
        <input
          type="date"
          className="input-field w-auto"
          value={dateFilter}
          onChange={(e) => setDateFilter(e.target.value)}
        />
        {dateFilter && (
          <button onClick={() => setDateFilter('')} className="btn-secondary px-3 py-2.5 text-xs">Clear date</button>
        )}
      </div>

      {/* Table */}
      <div className="card-base overflow-hidden">
        {loading ? (
          <div className="p-8 flex items-center justify-center">
            <div className="w-6 h-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
          </div>
        ) : filtered.length === 0 ? (
          <div className="p-12 flex flex-col items-center gap-3 text-center">
            <FileText size={40} className="text-muted-foreground/30" />
            <p className="text-muted-foreground">No audit logs found</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50">
                  {['Timestamp', 'Performed By', 'Action', 'Entity', 'Record', 'Summary'].map((h) => (
                    <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide whitespace-nowrap">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filtered.map((log) => (
                  <tr key={log.id} className="border-b last:border-0 hover:bg-muted/30 transition-colors">
                    <td className="px-4 py-3 text-xs text-muted-foreground whitespace-nowrap">
                      {new Date(log.created_at).toLocaleString('en-IN', { dateStyle: 'short', timeStyle: 'short' })}
                    </td>
                    <td className="px-4 py-3">
                      <p className="text-sm font-semibold text-foreground">{(log.performer as any)?.name || 'System'}</p>
                      <p className="text-xs text-muted-foreground capitalize">{(log.performer as any)?.role || '—'}</p>
                    </td>
                    <td className="px-4 py-3">
                      <span className={`text-xs font-semibold px-2 py-0.5 rounded-full whitespace-nowrap ${ACTION_COLORS[log.action] || 'bg-muted text-muted-foreground'}`}>
                        {log.action.replace(/_/g, ' ')}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-muted-foreground text-xs">{log.target_table || '—'}</td>
                    <td className="px-4 py-3 font-mono text-xs text-muted-foreground">
                      {log.target_id ? `${log.target_id.slice(0, 8)}…` : '—'}
                    </td>
                    <td className="px-4 py-3 text-sm text-foreground max-w-xs truncate">
                      {log.notes || (log.new_value ? JSON.stringify(log.new_value).slice(0, 60) : '—')}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}

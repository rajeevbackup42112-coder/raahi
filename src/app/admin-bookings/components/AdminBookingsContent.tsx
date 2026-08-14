'use client';
import React, { useState, useEffect, useCallback } from 'react';
import { Search, RefreshCw, Eye, X, Check, AlertTriangle, UserX, Users, ArrowLeftRight, Ban, StopCircle, AlertOctagon } from 'lucide-react';
import { toast } from 'sonner';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

interface AdminBooking {
  id: string;
  passenger_id: string;
  trip_id: string | null;
  pickup_point_id: string | null;
  seats: number;
  fare_per_seat: number;
  total_fare: number;
  status: string;
  traveler_name: string | null;
  traveler_phone: string | null;
  admin_notes: string | null;
  no_show_fee: number | null;
  created_at: string;
  is_test_data?: boolean;
  // Resolved fields from RPC
  passenger_name: string;
  passenger_phone: string;
  passenger_email: string;
  pickup_name: string;
  queue_id: string | null;
  queue_status: string | null;
  route_from: string;
  route_to: string;
  trip_status: string;
  vehicle_make: string;
  vehicle_model: string;
  vehicle_reg: string;
  driver_name: string;
}

interface AdminTrip {
  id: string;
  status: string;
  total_seats: number;
  booked_seats: number;
  scheduled_departure: string | null;
  actual_departure: string | null;
  notes: string | null;
  created_at: string;
  from_location: string;
  to_location: string;
  route_id: string;
  vehicle_make: string;
  vehicle_model: string;
  vehicle_reg: string;
  driver_name: string;
  driver_phone: string;
  active_passenger_count: number;
}

const CANCEL_REASONS = [
  'Passenger requested cancellation',
  'Duplicate booking',
  'Operational issue',
  'Driver unavailable',
  'Test booking',
  'Other',
];

const STATUS_COLORS: Record<string, string> = {
  confirmed:  'status-active',
  queued:     'bg-yellow-100 text-yellow-700',
  matching:   'bg-blue-100 text-blue-700',
  cancelled:  'status-cancelled',
  no_show:    'status-cancelled',
  completed:  'bg-blue-100 text-blue-700',
};

const CANCELLABLE_STATUSES = ['queued', 'matching', 'confirmed'];

type PageTab = 'bookings' | 'trips';

export default function AdminBookingsContent() {
  const { profile } = useAuth();
  const supabase = createClient();
  const [pageTab, setPageTab] = useState<PageTab>('bookings');
  const [bookings, setBookings] = useState<AdminBooking[]>([]);
  const [trips, setTrips] = useState<AdminTrip[]>([]);
  const [tripsLoading, setTripsLoading] = useState(false);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedBooking, setSelectedBooking] = useState<AdminBooking | null>(null);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  // Detail panel sub-forms
  const [showReplaceForm, setShowReplaceForm] = useState(false);
  const [showSeatForm, setShowSeatForm] = useState(false);
  const [showReassignForm, setShowReassignForm] = useState(false);
  const [showCancelDialog, setShowCancelDialog] = useState(false);
  const [replaceForm, setReplaceForm] = useState({ traveler_name: '', traveler_phone: '' });
  const [newSeatCount, setNewSeatCount] = useState(1);
  const [compatibleTrips, setCompatibleTrips] = useState<any[]>([]);
  const [selectedTripId, setSelectedTripId] = useState('');
  const [cancelReason, setCancelReason] = useState(CANCEL_REASONS[0]);
  const [cancelReasonOther, setCancelReasonOther] = useState('');

  // ── Abort Trip ──────────────────────────────────────────────
  const [abortTripTarget, setAbortTripTarget] = useState<AdminTrip | null>(null);
  const [abortReason, setAbortReason] = useState('');

  const loadTrips = async () => {
    setTripsLoading(true);
    try {
      const { data, error } = await supabase.rpc('get_admin_active_trips', { p_limit: 100, p_offset: 0 });
      if (error) { toast.error('Failed to load trips'); return; }
      const result = data as any;
      setTrips(result?.trips || []);
    } catch {
      toast.error('Failed to load trips');
    } finally {
      setTripsLoading(false);
    }
  };

  useEffect(() => {
    if (pageTab === 'trips') loadTrips();
  }, [pageTab]);

  const handleAbortTrip = async () => {
    if (!abortTripTarget || !abortReason.trim()) return;
    setActionLoading('abort_' + abortTripTarget.id);
    try {
      const { data, error } = await supabase.rpc('admin_abort_trip', {
        p_trip_id: abortTripTarget.id,
        p_reason: abortReason.trim(),
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Abort failed'); return; }
      toast.success(result.message || 'Trip aborted and passengers returned to queue');
      setAbortTripTarget(null);
      setAbortReason('');
      await loadTrips();
    } catch (err: any) {
      toast.error(err?.message || 'Abort failed');
    } finally {
      setActionLoading(null);
    }
  };

  const TRIP_STATUS_COLORS: Record<string, string> = {
    accepting_bookings: 'bg-blue-100 text-blue-700',
    boarding:           'bg-yellow-100 text-yellow-700',
    in_progress:        'status-active',
    completed:          'bg-muted text-muted-foreground',
    cancelled:          'status-cancelled',
    scheduled:          'status-waiting',
  };

  const ABORTABLE_STATUSES = ['accepting_bookings', 'boarding', 'in_progress', 'scheduled'];

  const loadBookings = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.rpc('get_admin_bookings', {
        p_limit: 200,
        p_offset: 0,
      });

      if (error) {
        console.error('[GET_ADMIN_BOOKINGS_ERROR]', error);
        toast.error('Failed to load bookings');
        return;
      }

      const result = data as { bookings: AdminBooking[] };
      setBookings(result?.bookings || []);
    } catch (err: any) {
      console.error('[GET_ADMIN_BOOKINGS_EXCEPTION]', err);
      toast.error('Failed to load bookings');
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => { loadBookings(); }, [loadBookings]);

  const filtered = bookings.filter((b) => {
    const q = search.toLowerCase();
    const matchSearch = !q ||
      b.id.toLowerCase().includes(q) ||
      b.passenger_name?.toLowerCase().includes(q) ||
      b.passenger_phone?.includes(q) ||
      b.passenger_email?.toLowerCase().includes(q) ||
      b.route_from?.toLowerCase().includes(q) ||
      b.route_to?.toLowerCase().includes(q) ||
      b.vehicle_reg?.toLowerCase().includes(q) ||
      b.driver_name?.toLowerCase().includes(q);
    const matchStatus = statusFilter === 'all' || b.status === statusFilter;
    return matchSearch && matchStatus;
  });

  const openDetail = (b: AdminBooking) => {
    setSelectedBooking(b);
    setShowReplaceForm(false);
    setShowSeatForm(false);
    setShowReassignForm(false);
    setShowCancelDialog(false);
    setCancelReason(CANCEL_REASONS[0]);
    setCancelReasonOther('');
    setReplaceForm({
      traveler_name: b.traveler_name || b.passenger_name || '',
      traveler_phone: b.traveler_phone || b.passenger_phone || '',
    });
    setNewSeatCount(b.seats);
  };

  // ── Cancel Booking ──────────────────────────────────────────
  const handleCancelBooking = async () => {
    if (!selectedBooking) return;
    const finalReason = cancelReason === 'Other' ? (cancelReasonOther.trim() || 'Other') : cancelReason;
    setActionLoading('cancel');
    try {
      // New RPC: no p_admin_id — admin identity derived from auth.uid() server-side
      const { data, error } = await supabase.rpc('admin_cancel_booking', {
        p_booking_id: selectedBooking.id,
        p_reason: finalReason,
      });
      if (error) {
        console.error('[ADMIN_CANCEL_BOOKING_ERROR]', error);
        toast.error(error.message || 'Cancel failed');
        return;
      }
      const result = data as any;
      if (!result?.success) {
        toast.error(result?.error || 'Cancel failed');
        return;
      }
      toast.success('Booking cancelled successfully');
      setShowCancelDialog(false);
      setSelectedBooking(null);
      await loadBookings();
    } catch (err: any) {
      toast.error(err?.message || 'Cancel failed');
    } finally {
      setActionLoading(null);
    }
  };

  // ── Replace Passenger ───────────────────────────────────────
  const handleReplacePassenger = async () => {
    if (!selectedBooking || !profile?.id) return;
    setActionLoading('replace');
    try {
      const { data, error } = await supabase.rpc('admin_replace_passenger', {
        p_admin_id: profile.id,
        p_booking_id: selectedBooking.id,
        p_new_traveler_name: replaceForm.traveler_name,
        p_new_traveler_phone: replaceForm.traveler_phone,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Replace failed'); return; }
      toast.success('Passenger replaced successfully');
      setShowReplaceForm(false);
      await loadBookings();
      setSelectedBooking(null);
    } catch (err: any) {
      toast.error(err?.message || 'Replace failed');
    } finally {
      setActionLoading(null);
    }
  };

  // ── Change Seat Count ───────────────────────────────────────
  const handleChangeSeatCount = async () => {
    if (!selectedBooking || !profile?.id) return;
    setActionLoading('seats');
    try {
      const { data, error } = await supabase.rpc('admin_change_seat_count', {
        p_admin_id: profile.id,
        p_booking_id: selectedBooking.id,
        p_new_seat_count: newSeatCount,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Change failed'); return; }
      toast.success('Seat count updated');
      setShowSeatForm(false);
      await loadBookings();
      setSelectedBooking(null);
    } catch (err: any) {
      toast.error(err?.message || 'Change failed');
    } finally {
      setActionLoading(null);
    }
  };

  // ── Mark No Show ────────────────────────────────────────────
  const handleMarkNoShow = async () => {
    if (!selectedBooking || !profile?.id) return;
    if (!confirm('Mark this passenger as no-show?')) return;
    setActionLoading('noshow');
    try {
      const { data, error } = await supabase.rpc('admin_mark_no_show', {
        p_admin_id: profile.id,
        p_booking_id: selectedBooking.id,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Failed'); return; }
      toast.success(`Marked as no-show. Fee: ₹${result.no_show_fee}`);
      setSelectedBooking(null);
      await loadBookings();
    } catch (err: any) {
      toast.error(err?.message || 'Failed');
    } finally {
      setActionLoading(null);
    }
  };

  // ── Reassign ────────────────────────────────────────────────
  const loadCompatibleTrips = async () => {
    if (!selectedBooking || !selectedBooking.trip_id) {
      toast.error('Cannot reassign a queued booking without a trip');
      return;
    }
    const { data: tripData } = await supabase
      .from('trips')
      .select('route_id')
      .eq('id', selectedBooking.trip_id)
      .single();
    if (!tripData) { toast.error('Cannot determine route'); return; }
    const { data } = await supabase
      .from('trips')
      .select('id, total_seats, booked_seats, status, vehicle:vehicle_id(make, model), driver:driver_id(profiles:profile_id(name))')
      .eq('route_id', tripData.route_id)
      .eq('status', 'accepting_bookings')
      .neq('id', selectedBooking.trip_id);
    setCompatibleTrips((data as any) || []);
    setShowReassignForm(true);
  };

  const handleReassign = async () => {
    if (!selectedBooking || !profile?.id || !selectedTripId) return;
    setActionLoading('reassign');
    try {
      const { data, error } = await supabase.rpc('admin_reassign_booking', {
        p_admin_id: profile.id,
        p_booking_id: selectedBooking.id,
        p_target_trip_id: selectedTripId,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Reassign failed'); return; }
      toast.success('Booking reassigned successfully');
      setShowReassignForm(false);
      setSelectedBooking(null);
      await loadBookings();
    } catch (err: any) {
      toast.error(err?.message || 'Reassign failed');
    } finally {
      setActionLoading(null);
    }
  };

  const isCancellable = (b: AdminBooking) => CANCELLABLE_STATUSES.includes(b.status);

  return (
    <div className="px-4 sm:px-6 lg:px-8 xl:px-10 py-6 max-w-screen-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Bookings & Trips</h1>
          <p className="text-sm text-muted-foreground mt-0.5">View and manage all passenger bookings and active trips</p>
        </div>
        <button onClick={pageTab === 'bookings' ? loadBookings : loadTrips} className="btn-secondary gap-2 px-3 py-2.5">
          <RefreshCw size={14} className={(loading || tripsLoading) ? 'animate-spin' : ''} />
        </button>
      </div>

      {/* Page Tabs */}
      <div className="flex gap-2 mb-6 p-1 bg-muted rounded-xl w-fit">
        {(['bookings', 'trips'] as PageTab[]).map((tab) => (
          <button
            key={tab}
            onClick={() => setPageTab(tab)}
            className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold transition-all capitalize ${pageTab === tab ? 'bg-card shadow-card text-primary' : 'text-muted-foreground hover:text-foreground'}`}
          >
            {tab === 'bookings' ? <Users size={14} /> : <StopCircle size={14} />}
            {tab}
          </button>
        ))}
      </div>

      {/* ── TRIPS TAB ─────────────────────────────────────────── */}
      {pageTab === 'trips' && (
        <div className="card-base overflow-hidden">
          {tripsLoading ? (
            <div className="p-8 flex items-center justify-center">
              <div className="w-6 h-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
            </div>
          ) : trips.length === 0 ? (
            <div className="p-12 flex flex-col items-center gap-3 text-center">
              <StopCircle size={40} className="text-muted-foreground/30" />
              <p className="text-muted-foreground">No active trips</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b bg-muted/50">
                    {['Trip ID', 'Route', 'Driver', 'Vehicle', 'Seats', 'Passengers', 'Status', 'Created', ''].map((h) => (
                      <th key={h} className="text-left px-3 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide whitespace-nowrap">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {trips.map((t) => (
                    <React.Fragment key={t.id}>
                      <tr className="border-b last:border-0 hover:bg-muted/30 transition-colors">
                        <td className="px-3 py-3 font-mono text-xs text-muted-foreground">{t.id.slice(0, 8)}…</td>
                        <td className="px-3 py-3 whitespace-nowrap text-foreground">{t.from_location && t.to_location ? `${t.from_location} → ${t.to_location}` : '—'}</td>
                        <td className="px-3 py-3 text-muted-foreground">{t.driver_name || '—'}</td>
                        <td className="px-3 py-3 text-muted-foreground">{t.vehicle_make && t.vehicle_model ? `${t.vehicle_make} ${t.vehicle_model}` : '—'}</td>
                        <td className="px-3 py-3 text-foreground font-semibold">{t.booked_seats}/{t.total_seats}</td>
                        <td className="px-3 py-3 text-foreground font-semibold">{t.active_passenger_count}</td>
                        <td className="px-3 py-3">
                          <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${TRIP_STATUS_COLORS[t.status] || 'status-waiting'}`}>
                            {t.status.replace('_', ' ')}
                          </span>
                        </td>
                        <td className="px-3 py-3 text-xs text-muted-foreground whitespace-nowrap">
                          {new Date(t.created_at).toLocaleDateString()}
                        </td>
                        <td className="px-3 py-3">
                          {ABORTABLE_STATUSES.includes(t.status) && (
                            <button
                              onClick={() => { setAbortTripTarget(t); setAbortReason(''); }}
                              className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-lg bg-danger/10 text-danger hover:bg-danger/20 transition-colors"
                            >
                              <AlertOctagon size={12} /> Abort Trip
                            </button>
                          )}
                        </td>
                      </tr>
                      {/* Abort confirmation inline */}
                      {abortTripTarget?.id === t.id && (
                        <tr className="border-b bg-red-50/30">
                          <td colSpan={9} className="px-4 py-4">
                            <div className="flex flex-col gap-3 max-w-lg">
                              <div className="flex items-center gap-2">
                                <AlertTriangle size={15} className="text-danger shrink-0" />
                                <p className="text-sm font-semibold text-foreground">
                                  Abort Trip — {t.from_location} → {t.to_location}
                                </p>
                              </div>
                              <p className="text-xs text-muted-foreground">
                                This will cancel the trip and return <strong>{t.active_passenger_count} passenger(s)</strong> to the FIFO queue. The driver will be set offline. This action cannot be undone.
                              </p>
                              <textarea
                                className="input-field text-sm resize-none"
                                rows={2}
                                placeholder="Reason for aborting trip (required)"
                                value={abortReason}
                                onChange={(e) => setAbortReason(e.target.value)}
                              />
                              <div className="flex gap-2">
                                <button
                                  onClick={handleAbortTrip}
                                  disabled={!abortReason.trim() || actionLoading === 'abort_' + t.id}
                                  className="flex items-center gap-1.5 text-sm font-semibold px-4 py-2 rounded-lg bg-danger text-white hover:bg-danger/90 transition-colors disabled:opacity-50"
                                >
                                  {actionLoading === 'abort_' + t.id
                                    ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                                    : <AlertOctagon size={13} />
                                  }
                                  Confirm Abort
                                </button>
                                <button onClick={() => { setAbortTripTarget(null); setAbortReason(''); }} className="btn-secondary text-sm px-3 py-2">Cancel</button>
                              </div>
                            </div>
                          </td>
                        </tr>
                      )}
                    </React.Fragment>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* ── BOOKINGS TAB ──────────────────────────────────────── */}
      {pageTab === 'bookings' && (
        <>
          <div className="flex items-center justify-between mb-6">
            <div>
              <h2 className="text-xl font-bold text-foreground">Bookings</h2>
              <p className="text-sm text-muted-foreground mt-0.5">View and manage all passenger bookings</p>
            </div>
            <button onClick={loadBookings} className="btn-secondary gap-2 px-3 py-2.5">
              <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            </button>
          </div>

          {/* Filters */}
          <div className="flex flex-wrap items-center gap-3 mb-5">
            <div className="relative flex-1 min-w-[200px] max-w-sm">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
              <input
                type="text"
                placeholder="Search by ID, passenger, route, vehicle..."
                className="input-field pl-9"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <select className="input-field w-auto" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
              <option value="all">All Status</option>
              <option value="queued">Queued</option>
              <option value="matching">Matching</option>
              <option value="confirmed">Confirmed</option>
              <option value="cancelled">Cancelled</option>
              <option value="no_show">No Show</option>
              <option value="completed">Completed</option>
            </select>
          </div>

          {/* Table */}
          <div className="card-base overflow-hidden">
            {loading ? (
              <div className="p-8 flex items-center justify-center">
                <div className="w-6 h-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
              </div>
            ) : filtered.length === 0 ? (
              <div className="p-12 flex flex-col items-center gap-3 text-center">
                <Users size={40} className="text-muted-foreground/30" />
                <p className="text-muted-foreground font-medium">No bookings found</p>
                <p className="text-sm text-muted-foreground">Try adjusting your search or filter.</p>
              </div>
            ) : (
              <>
                {/* Mobile card list — visible on small screens */}
                <div className="flex flex-col divide-y sm:hidden">
                  {filtered.map((b) => (
                    <div key={b.id} className="p-4 flex flex-col gap-2">
                      <div className="flex items-start justify-between gap-2">
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-1.5 flex-wrap">
                            <p className="font-semibold text-foreground truncate">{b.passenger_name || '—'}</p>
                            {b.is_test_data && <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-100 text-amber-700 border border-amber-300 uppercase tracking-wide shrink-0">TEST</span>}
                          </div>
                          <p className="text-xs text-muted-foreground">{b.passenger_phone || '—'}</p>
                        </div>
                        <span className={`text-xs font-semibold px-2 py-0.5 rounded-full shrink-0 ${STATUS_COLORS[b.status] || 'status-waiting'}`}>
                          {b.status}
                        </span>
                      </div>
                      <p className="text-sm text-foreground">
                        {b.route_from && b.route_to ? `${b.route_from} → ${b.route_to}` : '—'}
                      </p>
                      <div className="flex items-center gap-3 text-xs text-muted-foreground">
                        <span>{b.seats} seat{b.seats !== 1 ? 's' : ''}</span>
                        <span>·</span>
                        <span className="font-semibold text-foreground">₹{b.total_fare}</span>
                        {b.pickup_name && <><span>·</span><span className="truncate">{b.pickup_name}</span></>}
                      </div>
                      <div className="flex items-center justify-between">
                        <p className="text-xs text-muted-foreground">{new Date(b.created_at).toLocaleDateString()}</p>
                        <button onClick={() => openDetail(b)} className="text-xs text-primary font-semibold hover:underline">
                          View Details
                        </button>
                      </div>
                    </div>
                  ))}
                </div>

                {/* Desktop table — hidden on small screens */}
                <div className="hidden sm:block overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b bg-muted/50">
                        {['Booking ID', 'Passenger', 'Route', 'Vehicle', 'Driver', 'Seats', 'Fare', 'Pickup', 'Status', 'Created', ''].map((h) => (
                          <th key={h} className="text-left px-3 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide whitespace-nowrap">{h}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {filtered.map((b) => (
                        <tr key={b.id} className="border-b last:border-0 hover:bg-muted/30 transition-colors">
                          <td className="px-3 py-3 font-mono text-xs text-muted-foreground">{b.id.slice(0, 8)}…</td>
                          <td className="px-3 py-3">
                            <div className="flex items-center gap-1.5 flex-wrap">
                              <p className="font-semibold text-foreground">{b.passenger_name || '—'}</p>
                              {b.is_test_data && <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-100 text-amber-700 border border-amber-300 uppercase tracking-wide">TEST</span>}
                            </div>
                            <p className="text-xs text-muted-foreground">{b.passenger_phone || '—'}</p>
                          </td>
                          <td className="px-3 py-3 text-foreground whitespace-nowrap">
                            {b.route_from && b.route_to ? `${b.route_from} → ${b.route_to}` : '—'}
                          </td>
                          <td className="px-3 py-3 text-muted-foreground">
                            {b.vehicle_make && b.vehicle_model ? `${b.vehicle_make} ${b.vehicle_model}` : '—'}
                          </td>
                          <td className="px-3 py-3 text-muted-foreground">{b.driver_name || '—'}</td>
                          <td className="px-3 py-3 text-foreground font-semibold">{b.seats}</td>
                          <td className="px-3 py-3 text-foreground font-semibold">₹{b.total_fare}</td>
                          <td className="px-3 py-3 text-muted-foreground">{b.pickup_name || '—'}</td>
                          <td className="px-3 py-3">
                            <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${STATUS_COLORS[b.status] || 'status-waiting'}`}>
                              {b.status}
                            </span>
                          </td>
                          <td className="px-3 py-3 text-xs text-muted-foreground whitespace-nowrap">
                            {new Date(b.created_at).toLocaleDateString()}
                          </td>
                          <td className="px-3 py-3">
                            <button onClick={() => openDetail(b)} className="p-1.5 rounded-lg hover:bg-muted transition-colors text-muted-foreground hover:text-foreground">
                              <Eye size={14} />
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </>
            )}
          </div>

          {/* Booking Detail Panel */}
          {selectedBooking && (
            <div className="fixed inset-0 bg-black/50 z-50 flex items-start justify-end">
              <div className="bg-card h-full w-full max-w-lg overflow-y-auto shadow-elevated">
                <div className="flex items-center justify-between p-5 border-b sticky top-0 bg-card z-10">
                  <div>
                    <h2 className="font-bold text-foreground">Booking Detail</h2>
                    <p className="text-xs text-muted-foreground font-mono">{selectedBooking.id}</p>
                  </div>
                  <button onClick={() => setSelectedBooking(null)} className="p-2 rounded-xl hover:bg-muted">
                    <X size={16} />
                  </button>
                </div>

                <div className="p-5 flex flex-col gap-4">
                  {/* Info */}
                  <div className="card-base p-4 flex flex-col gap-2">
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Passenger</span>
                      <span className="font-semibold text-foreground">{selectedBooking.passenger_name || '—'}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Phone</span>
                      <span className="text-foreground">{selectedBooking.passenger_phone || '—'}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Route</span>
                      <span className="text-foreground">
                        {selectedBooking.route_from && selectedBooking.route_to
                          ? `${selectedBooking.route_from} → ${selectedBooking.route_to}`
                          : '—'}
                      </span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Queue status</span>
                      <span className="text-foreground">{selectedBooking.queue_status || '—'}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Vehicle</span>
                      <span className="text-foreground">
                        {selectedBooking.vehicle_make && selectedBooking.vehicle_model
                          ? `${selectedBooking.vehicle_make} ${selectedBooking.vehicle_model} · ${selectedBooking.vehicle_reg}`
                          : '—'}
                      </span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Driver</span>
                      <span className="text-foreground">{selectedBooking.driver_name || '—'}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Seats</span>
                      <span className="font-semibold text-foreground">{selectedBooking.seats}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Fare</span>
                      <span className="font-semibold text-foreground">₹{selectedBooking.total_fare}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Pickup</span>
                      <span className="text-foreground">{selectedBooking.pickup_name || '—'}</span>
                    </div>
                    <div className="flex justify-between text-sm">
                      <span className="text-muted-foreground">Status</span>
                      <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${STATUS_COLORS[selectedBooking.status] || 'status-waiting'}`}>
                        {selectedBooking.status}
                      </span>
                    </div>
                    {selectedBooking.no_show_fee != null && (
                      <div className="flex justify-between text-sm">
                        <span className="text-muted-foreground">No-show fee</span>
                        <span className="text-danger font-semibold">₹{selectedBooking.no_show_fee}</span>
                      </div>
                    )}
                    {selectedBooking.admin_notes && (
                      <div className="flex justify-between text-sm">
                        <span className="text-muted-foreground">Admin notes</span>
                        <span className="text-foreground">{selectedBooking.admin_notes}</span>
                      </div>
                    )}
                  </div>

                  {/* Actions */}
                  <div className="flex flex-col gap-2">
                    <p className="section-label">Actions</p>

                    {/* Cancel Booking — for queued/matching/confirmed */}
                    {isCancellable(selectedBooking) && !showCancelDialog && (
                      <button
                        onClick={() => {
                          setShowCancelDialog(true);
                          setShowReplaceForm(false);
                          setShowSeatForm(false);
                          setShowReassignForm(false);
                        }}
                        className="btn-secondary gap-2 justify-start text-danger border-danger/30 hover:bg-danger/10"
                      >
                        <Ban size={14} /> Cancel Booking
                      </button>
                    )}

                    {/* Cancel Booking Dialog */}
                    {showCancelDialog && isCancellable(selectedBooking) && (
                      <div className="card-base p-4 flex flex-col gap-3 border-danger/20 bg-red-50/30">
                        <div className="flex items-center gap-2">
                          <AlertTriangle size={15} className="text-danger shrink-0" />
                          <p className="text-sm font-semibold text-foreground">Confirm Cancellation</p>
                        </div>

                        {/* Summary */}
                        <div className="text-xs text-muted-foreground flex flex-col gap-1 bg-muted/40 rounded-lg p-3">
                          <div className="flex justify-between">
                            <span>Passenger</span>
                            <span className="font-medium text-foreground">{selectedBooking.passenger_name || '—'}</span>
                          </div>
                          <div className="flex justify-between">
                            <span>Route</span>
                            <span className="font-medium text-foreground">
                              {selectedBooking.route_from && selectedBooking.route_to
                                ? `${selectedBooking.route_from} → ${selectedBooking.route_to}`
                                : '—'}
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span>Pickup</span>
                            <span className="font-medium text-foreground">{selectedBooking.pickup_name || '—'}</span>
                          </div>
                          <div className="flex justify-between">
                            <span>Seats</span>
                            <span className="font-medium text-foreground">{selectedBooking.seats}</span>
                          </div>
                          <div className="flex justify-between">
                            <span>Fare</span>
                            <span className="font-medium text-foreground">₹{selectedBooking.total_fare}</span>
                          </div>
                          <div className="flex justify-between">
                            <span>Current status</span>
                            <span className={`font-semibold px-1.5 py-0.5 rounded ${STATUS_COLORS[selectedBooking.status] || ''}`}>
                              {selectedBooking.status}
                            </span>
                          </div>
                        </div>

                        {/* Reason selector */}
                        <div>
                          <label className="text-xs font-semibold text-foreground mb-1 block">Cancellation reason *</label>
                          <select
                            className="input-field"
                            value={cancelReason}
                            onChange={(e) => setCancelReason(e.target.value)}
                          >
                            {CANCEL_REASONS.map((r) => (
                              <option key={r} value={r}>{r}</option>
                            ))}
                          </select>
                        </div>

                        {cancelReason === 'Other' && (
                          <input
                            className="input-field"
                            placeholder="Describe the reason..."
                            value={cancelReasonOther}
                            onChange={(e) => setCancelReasonOther(e.target.value)}
                          />
                        )}

                        <div className="flex gap-2">
                          <button
                            onClick={handleCancelBooking}
                            disabled={actionLoading === 'cancel' || (cancelReason === 'Other' && !cancelReasonOther.trim())}
                            className="btn-primary bg-danger hover:bg-danger/90 gap-2 flex-1 disabled:opacity-50"
                          >
                            {actionLoading === 'cancel'
                              ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                              : <Ban size={14} />}
                            Confirm Cancel
                          </button>
                          <button
                            onClick={() => setShowCancelDialog(false)}
                            className="btn-secondary flex-1"
                          >
                            Keep Booking
                          </button>
                        </div>
                      </div>
                    )}

                    {/* Actions only for confirmed bookings with a trip */}
                    {selectedBooking.status === 'confirmed' && selectedBooking.trip_id && (
                      <>
                        {/* Replace Passenger */}
                        <button
                          onClick={() => { setShowReplaceForm(!showReplaceForm); setShowSeatForm(false); setShowReassignForm(false); setShowCancelDialog(false); }}
                          className="btn-secondary gap-2 justify-start"
                        >
                          <Users size={14} /> Replace Passenger
                        </button>
                        {showReplaceForm && (
                          <div className="card-base p-4 flex flex-col gap-3">
                            <p className="text-sm font-semibold text-foreground">New Passenger Details</p>
                            <input className="input-field" placeholder="Full name" value={replaceForm.traveler_name} onChange={(e) => setReplaceForm({ ...replaceForm, traveler_name: e.target.value })} />
                            <input className="input-field" placeholder="Phone number" value={replaceForm.traveler_phone} onChange={(e) => setReplaceForm({ ...replaceForm, traveler_phone: e.target.value })} />
                            <button onClick={handleReplacePassenger} disabled={actionLoading === 'replace'} className="btn-primary gap-2">
                              {actionLoading === 'replace' ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <Check size={14} />}
                              Confirm Replace
                            </button>
                          </div>
                        )}

                        {/* Change Seat Count */}
                        <button
                          onClick={() => { setShowSeatForm(!showSeatForm); setShowReplaceForm(false); setShowReassignForm(false); setShowCancelDialog(false); }}
                          className="btn-secondary gap-2 justify-start"
                        >
                          <Users size={14} /> Change Seat Count
                        </button>
                        {showSeatForm && (
                          <div className="card-base p-4 flex flex-col gap-3">
                            <p className="text-sm font-semibold text-foreground">New seat count (current: {selectedBooking.seats})</p>
                            <input type="number" min={1} max={10} className="input-field" value={newSeatCount} onChange={(e) => setNewSeatCount(parseInt(e.target.value) || 1)} />
                            <button onClick={handleChangeSeatCount} disabled={actionLoading === 'seats'} className="btn-primary gap-2">
                              {actionLoading === 'seats' ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <Check size={14} />}
                              Update Seats
                            </button>
                          </div>
                        )}

                        {/* Reassign to another trip */}
                        <button
                          onClick={() => { loadCompatibleTrips(); setShowReplaceForm(false); setShowSeatForm(false); setShowCancelDialog(false); }}
                          className="btn-secondary gap-2 justify-start"
                        >
                          <ArrowLeftRight size={14} /> Reassign to Another Trip
                        </button>
                        {showReassignForm && (
                          <div className="card-base p-4 flex flex-col gap-3">
                            <p className="text-sm font-semibold text-foreground">Select compatible trip</p>
                            {compatibleTrips.length === 0 ? (
                              <p className="text-sm text-muted-foreground">No compatible trips available on this route.</p>
                            ) : (
                              <>
                                <select className="input-field" value={selectedTripId} onChange={(e) => setSelectedTripId(e.target.value)}>
                                  <option value="">— Select trip —</option>
                                  {compatibleTrips.map((t) => (
                                    <option key={t.id} value={t.id}>
                                      {(t.vehicle as any)?.make} {(t.vehicle as any)?.model} · {t.total_seats - t.booked_seats} seats free · Driver: {(t.driver as any)?.profiles?.name || '—'}
                                    </option>
                                  ))}
                                </select>
                                <button onClick={handleReassign} disabled={!selectedTripId || actionLoading === 'reassign'} className="btn-primary gap-2">
                                  {actionLoading === 'reassign' ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <Check size={14} />}
                                  Confirm Reassign
                                </button>
                              </>
                            )}
                          </div>
                        )}

                        {/* Mark No Show */}
                        <button
                          onClick={handleMarkNoShow}
                          disabled={actionLoading === 'noshow'}
                          className="btn-secondary gap-2 justify-start text-warning border-warning/30 hover:bg-warning/10"
                        >
                          <UserX size={14} /> Mark No-Show
                        </button>
                      </>
                    )}
                  </div>
                </div>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

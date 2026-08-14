'use client';
import React, { useState, useEffect, useCallback } from 'react';
import { Plus, Edit2, Power, MapPin, RefreshCw, X, Check, ChevronDown, ChevronUp, PauseCircle, PlayCircle } from 'lucide-react';
import { toast } from 'sonner';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

interface Route {
  id: string;
  from_location: string;
  to_location: string;
  distance_km: number | null;
  estimated_duration_min: number | null;
  fare_per_seat: number;
  min_passengers: number;
  status: string;
}

interface PickupPoint {
  id: string;
  route_id: string;
  name: string;
  landmark: string | null;
  sequence_order: number;
  direction: string;
  is_active: boolean;
}

const EMPTY_ROUTE = {
  from_location: '', to_location: '', distance_km: '', estimated_duration_min: '',
  fare_per_seat: '150', min_passengers: '1', status: 'active',
};
const EMPTY_PICKUP = { name: '', landmark: '', sequence_order: 0, direction: 'both', is_active: true };

export default function AdminRoutesContent() {
  const { profile } = useAuth();
  const supabase = createClient();
  const [routes, setRoutes] = useState<Route[]>([]);
  const [pickupPoints, setPickupPoints] = useState<PickupPoint[]>([]);
  const [loading, setLoading] = useState(true);
  const [expandedRoute, setExpandedRoute] = useState<string | null>(null);
  const [showRouteForm, setShowRouteForm] = useState(false);
  const [editingRouteId, setEditingRouteId] = useState<string | null>(null);
  const [routeForm, setRouteForm] = useState({ ...EMPTY_ROUTE });
  const [showPickupForm, setShowPickupForm] = useState<string | null>(null);
  const [editingPickupId, setEditingPickupId] = useState<string | null>(null);
  const [pickupForm, setPickupForm] = useState({ ...EMPTY_PICKUP });
  const [saving, setSaving] = useState(false);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    try {
      const { data: rData, error: rErr } = await supabase.from('routes').select('*').order('from_location');
      const { data: pData, error: pErr } = await supabase.from('pickup_points').select('*').order('sequence_order');
      if (rErr) throw rErr;
      if (pErr) throw pErr;
      if (rData) setRoutes(rData as Route[]);
      if (pData) setPickupPoints(pData as PickupPoint[]);
    } catch (err: any) {
      toast.error(err?.message || 'Failed to load routes');
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => { loadData(); }, [loadData]);

  const openAddRoute = () => {
    setEditingRouteId(null);
    setRouteForm({ ...EMPTY_ROUTE });
    setShowRouteForm(true);
  };

  const openEditRoute = (r: Route) => {
    setEditingRouteId(r.id);
    setRouteForm({
      from_location: r.from_location,
      to_location: r.to_location,
      distance_km: r.distance_km?.toString() || '',
      estimated_duration_min: r.estimated_duration_min?.toString() || '',
      fare_per_seat: r.fare_per_seat.toString(),
      min_passengers: (r.min_passengers ?? 1).toString(),
      status: r.status,
    });
    setShowRouteForm(true);
  };

  const handleSaveRoute = async () => {
    if (!routeForm.from_location || !routeForm.to_location) {
      toast.error('From and To locations are required');
      return;
    }
    setSaving(true);
    try {
      const payload: any = {
        from_location: routeForm.from_location.trim(),
        to_location: routeForm.to_location.trim(),
        distance_km: routeForm.distance_km ? parseFloat(routeForm.distance_km) : null,
        estimated_duration_min: routeForm.estimated_duration_min ? parseInt(routeForm.estimated_duration_min) : null,
        fare_per_seat: parseFloat(routeForm.fare_per_seat) || 150,
        min_passengers: parseInt(routeForm.min_passengers) || 1,
        status: routeForm.status,
        updated_at: new Date().toISOString(),
      };

      if (editingRouteId) {
        // Update fare via RPC to also update active trips
        if (profile?.id) {
          await supabase.rpc('admin_update_route_fare', {
            p_admin_id: profile.id,
            p_route_id: editingRouteId,
            p_new_fare: payload.fare_per_seat,
          });
        }
        const { error } = await supabase.from('routes').update({
          from_location: payload.from_location,
          to_location: payload.to_location,
          distance_km: payload.distance_km,
          estimated_duration_min: payload.estimated_duration_min,
          min_passengers: payload.min_passengers,
          status: payload.status,
          updated_at: payload.updated_at,
        }).eq('id', editingRouteId);
        if (error) throw error;
        toast.success('Route updated');
      } else {
        const { error } = await supabase.from('routes').insert(payload);
        if (error) throw error;
        toast.success('Route created — it will now appear in passenger booking and driver flows');
      }

      setShowRouteForm(false);
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  const toggleRouteStatus = async (r: Route) => {
    setActionLoading(r.id);
    try {
      if (r.status === 'active') {
        // Pause the route using the dedicated RPC
        const { data, error } = await supabase.rpc('admin_pause_route', {
          p_route_id: r.id,
          p_reason: 'Admin paused route',
        });
        if (error) throw error;
        const result = data as any;
        if (!result?.success) { toast.error(result?.error || 'Pause failed'); return; }
        toast.success('Route paused — no new bookings will be accepted');
      } else if (r.status === 'paused') {
        // Resume the route
        const { data, error } = await supabase.rpc('admin_resume_route', {
          p_route_id: r.id,
          p_reason: 'Admin resumed route',
        });
        if (error) throw error;
        const result = data as any;
        if (!result?.success) { toast.error(result?.error || 'Resume failed'); return; }
        toast.success('Route resumed — bookings can now be accepted');
      } else {
        // inactive → active (direct update for reactivation from fully inactive)
        const { error } = await supabase.from('routes').update({ status: 'active', updated_at: new Date().toISOString() }).eq('id', r.id);
        if (error) throw error;
        toast.success('Route activated — passengers can now book');
      }
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Action failed');
    } finally {
      setActionLoading(null);
    }
  };

  const openAddPickup = (routeId: string) => {
    setEditingPickupId(null);
    setPickupForm({
      name: '', landmark: '', direction: 'both',
      sequence_order: (pickupPoints.filter(p => p.route_id === routeId).length + 1),
      is_active: true,
    });
    setShowPickupForm(routeId);
  };

  const openEditPickup = (p: PickupPoint) => {
    setEditingPickupId(p.id);
    setPickupForm({
      name: p.name, landmark: p.landmark || '',
      sequence_order: p.sequence_order,
      direction: p.direction || 'both',
      is_active: p.is_active,
    });
    setShowPickupForm(p.route_id);
  };

  const handleSavePickup = async (routeId: string) => {
    if (!pickupForm.name) { toast.error('Pickup point name is required'); return; }
    setSaving(true);
    try {
      if (editingPickupId) {
        // Use server-side RPC for edits — enforces deactivation safety guard
        const { data, error } = await supabase.rpc('admin_edit_pickup_point', {
          p_pickup_point_id: editingPickupId,
          p_name: pickupForm.name.trim(),
          p_landmark: pickupForm.landmark.trim() || null,
          p_direction: pickupForm.direction,
          p_is_active: pickupForm.is_active,
        });
        if (error) throw error;
        const result = data as any;
        if (!result?.success) { toast.error(result?.error || 'Update failed'); return; }
        toast.success('Pickup point updated');
      } else {
        // Use server-side RPC for adds — audited
        const { data, error } = await supabase.rpc('admin_add_pickup_point', {
          p_route_id: routeId,
          p_name: pickupForm.name.trim(),
          p_landmark: pickupForm.landmark.trim() || null,
          p_sequence_order: pickupForm.sequence_order,
          p_direction: pickupForm.direction,
          p_is_active: pickupForm.is_active,
        });
        if (error) throw error;
        const result = data as any;
        if (!result?.success) { toast.error(result?.error || 'Add failed'); return; }
        toast.success('Pickup point added — passengers will see it when booking this route');
      }
      setShowPickupForm(null);
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  const togglePickupStatus = async (p: PickupPoint) => {
    setActionLoading(p.id);
    try {
      // Use server-side RPC — enforces active-booking guard before deactivation
      const { data, error } = await supabase.rpc('admin_edit_pickup_point', {
        p_pickup_point_id: p.id,
        p_name: null,
        p_landmark: null,
        p_direction: null,
        p_is_active: !p.is_active,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Action failed'); return; }
      toast.success(`Pickup point ${!p.is_active ? 'activated' : 'deactivated'}`);
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Action failed');
    } finally {
      setActionLoading(null);
    }
  };

  const directionLabel = (d: string) => {
    if (d === 'forward') return 'Forward only';
    if (d === 'return') return 'Return only';
    return 'Both directions';
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8 xl:px-10 py-6 max-w-screen-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Routes</h1>
          <p className="text-sm text-muted-foreground mt-0.5">Manage routes, fares, and pickup points — changes propagate automatically</p>
        </div>
        <div className="flex gap-2">
          <button onClick={loadData} className="btn-secondary gap-2 px-3 py-2.5">
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
          </button>
          <button onClick={openAddRoute} className="btn-primary gap-2">
            <Plus size={16} /> Add Route
          </button>
        </div>
      </div>

      {/* Route Form Modal */}
      {showRouteForm && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-card rounded-2xl shadow-elevated w-full max-w-md max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between p-5 border-b">
              <h2 className="font-bold text-foreground">{editingRouteId ? 'Edit Route' : 'Add Route'}</h2>
              <button onClick={() => setShowRouteForm(false)} className="p-2 rounded-xl hover:bg-muted"><X size={16} /></button>
            </div>
            <div className="p-5 flex flex-col gap-4">
              <div>
                <label className="section-label mb-1.5">From Location *</label>
                <input className="input-field" value={routeForm.from_location} onChange={(e) => setRouteForm({ ...routeForm, from_location: e.target.value })} placeholder="Gomoh" />
              </div>
              <div>
                <label className="section-label mb-1.5">To Location *</label>
                <input className="input-field" value={routeForm.to_location} onChange={(e) => setRouteForm({ ...routeForm, to_location: e.target.value })} placeholder="Dhanbad" />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="section-label mb-1.5">Distance (km)</label>
                  <input type="number" className="input-field" value={routeForm.distance_km} onChange={(e) => setRouteForm({ ...routeForm, distance_km: e.target.value })} placeholder="25" />
                </div>
                <div>
                  <label className="section-label mb-1.5">Duration (min)</label>
                  <input type="number" className="input-field" value={routeForm.estimated_duration_min} onChange={(e) => setRouteForm({ ...routeForm, estimated_duration_min: e.target.value })} placeholder="45" />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="section-label mb-1.5">Fare per Seat (₹)</label>
                  <input type="number" className="input-field" value={routeForm.fare_per_seat} onChange={(e) => setRouteForm({ ...routeForm, fare_per_seat: e.target.value })} placeholder="150" />
                </div>
                <div>
                  <label className="section-label mb-1.5">Minimum seats to depart</label>
                  <input type="number" min={1} className="input-field" value={routeForm.min_passengers} onChange={(e) => setRouteForm({ ...routeForm, min_passengers: e.target.value })} placeholder="1" />
                </div>
              </div>
              <div>
                <label className="section-label mb-1.5">Status</label>
                <select className="input-field" value={routeForm.status} onChange={(e) => setRouteForm({ ...routeForm, status: e.target.value })}>
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                </select>
              </div>
              <div className="flex gap-3 pt-2">
                <button onClick={() => setShowRouteForm(false)} className="btn-secondary flex-1">Cancel</button>
                <button onClick={handleSaveRoute} disabled={saving} className="btn-primary flex-1 gap-2">
                  {saving ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <Check size={16} />}
                  {editingRouteId ? 'Save' : 'Add Route'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Routes List */}
      {loading ? (
        <div className="flex flex-col gap-4">
          {[1, 2].map((i) => <div key={i} className="card-base p-5 h-20 animate-pulse bg-muted" />)}
        </div>
      ) : routes.length === 0 ? (
        <div className="card-base p-10 text-center">
          <MapPin size={32} className="text-muted-foreground mx-auto mb-3" />
          <p className="text-muted-foreground mb-4">No routes configured yet.</p>
          <button onClick={openAddRoute} className="btn-primary gap-2 inline-flex">
            <Plus size={16} /> Create First Route
          </button>
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {routes.map((r) => {
            const routePickups = pickupPoints.filter((p) => p.route_id === r.id);
            const isExpanded = expandedRoute === r.id;
            return (
              <div key={r.id} className="card-base overflow-hidden">
                <div className="flex items-center justify-between p-5">
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-full gradient-primary flex items-center justify-center shrink-0">
                      <MapPin size={16} className="text-white" />
                    </div>
                    <div>
                      <p className="font-bold text-foreground">{r.from_location} → {r.to_location}</p>
                      <div className="flex items-center gap-3 text-xs text-muted-foreground mt-0.5 flex-wrap">
                        <span className="font-semibold text-primary">₹{r.fare_per_seat}/seat</span>
                        <span>Min {r.min_passengers ?? 1} seats to depart</span>
                        {r.distance_km && <span>{r.distance_km} km</span>}
                        {r.estimated_duration_min && <span>~{r.estimated_duration_min} min</span>}
                        <span className={`font-semibold px-1.5 py-0.5 rounded-full ${r.status === 'active' ? 'status-active' : r.status === 'paused' ? 'bg-yellow-100 text-yellow-700' : 'status-cancelled'}`}>{r.status}</span>
                        <span className="text-muted-foreground">{routePickups.filter(p => p.is_active).length} pickup pts</span>
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <button onClick={() => openEditRoute(r)} className="p-1.5 rounded-lg hover:bg-muted text-muted-foreground hover:text-foreground"><Edit2 size={14} /></button>
                    <button
                      onClick={() => toggleRouteStatus(r)}
                      disabled={actionLoading === r.id}
                      title={r.status === 'active' ? 'Pause route' : r.status === 'paused' ? 'Resume route' : 'Activate route'}
                      className={`p-1.5 rounded-lg hover:bg-muted ${r.status === 'active' ? 'text-yellow-600' : 'text-success'}`}
                    >
                      {r.status === 'active' ? <PauseCircle size={14} /> : r.status === 'paused' ? <PlayCircle size={14} /> : <Power size={14} />}
                    </button>
                    <button onClick={() => setExpandedRoute(isExpanded ? null : r.id)} className="p-1.5 rounded-lg hover:bg-muted text-muted-foreground">
                      {isExpanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />}
                    </button>
                  </div>
                </div>

                {/* Pickup Points */}
                {isExpanded && (
                  <div className="border-t px-5 pb-5 pt-4">
                    <div className="flex items-center justify-between mb-3">
                      <p className="section-label">Pickup Points ({routePickups.length})</p>
                      <button onClick={() => openAddPickup(r.id)} className="btn-secondary gap-1.5 px-3 py-1.5 text-xs">
                        <Plus size={12} /> Add Pickup
                      </button>
                    </div>

                    {/* Pickup Form */}
                    {showPickupForm === r.id && (
                      <div className="card-base p-4 mb-3 flex flex-col gap-3">
                        <p className="text-sm font-semibold text-foreground">{editingPickupId ? 'Edit Pickup Point' : 'New Pickup Point'}</p>
                        <input className="input-field" placeholder="Name (e.g. Gomoh Station)" value={pickupForm.name} onChange={(e) => setPickupForm({ ...pickupForm, name: e.target.value })} />
                        <input className="input-field" placeholder="Landmark / description (optional)" value={pickupForm.landmark} onChange={(e) => setPickupForm({ ...pickupForm, landmark: e.target.value })} />
                        <div className="grid grid-cols-2 gap-3">
                          <div>
                            <label className="section-label mb-1">Display Order</label>
                            <input type="number" className="input-field" value={pickupForm.sequence_order} onChange={(e) => setPickupForm({ ...pickupForm, sequence_order: parseInt(e.target.value) || 0 })} />
                          </div>
                          <div>
                            <label className="section-label mb-1">Direction</label>
                            <select className="input-field" value={pickupForm.direction} onChange={(e) => setPickupForm({ ...pickupForm, direction: e.target.value })}>
                              <option value="both">Both directions</option>
                              <option value="forward">Forward only</option>
                              <option value="return">Return only</option>
                            </select>
                          </div>
                        </div>
                        <label className="flex items-center gap-2 cursor-pointer">
                          <input type="checkbox" checked={pickupForm.is_active} onChange={(e) => setPickupForm({ ...pickupForm, is_active: e.target.checked })} className="w-4 h-4 accent-primary" />
                          <span className="text-sm text-foreground">Active (visible to passengers)</span>
                        </label>
                        <div className="flex gap-2">
                          <button onClick={() => setShowPickupForm(null)} className="btn-secondary flex-1 text-sm py-2">Cancel</button>
                          <button onClick={() => handleSavePickup(r.id)} disabled={saving} className="btn-primary flex-1 text-sm py-2 gap-1.5">
                            {saving ? <span className="w-3 h-3 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <Check size={12} />}
                            Save
                          </button>
                        </div>
                      </div>
                    )}

                    {routePickups.length === 0 ? (
                      <p className="text-sm text-muted-foreground">No pickup points configured. Add at least one so passengers can book this route.</p>
                    ) : (
                      <div className="flex flex-col gap-2">
                        {routePickups.map((p) => (
                          <div key={p.id} className="flex items-center justify-between p-3 bg-muted/50 rounded-xl border border-border">
                            <div className="flex items-center gap-2">
                              <span className="w-5 h-5 rounded-full bg-muted flex items-center justify-center text-xs font-bold text-muted-foreground shrink-0">{p.sequence_order}</span>
                              <div>
                                <p className="text-sm font-semibold text-foreground">{p.name}</p>
                                <div className="flex items-center gap-2 text-xs text-muted-foreground">
                                  {p.landmark && <span>{p.landmark}</span>}
                                  <span className="text-primary/70">{directionLabel(p.direction || 'both')}</span>
                                </div>
                              </div>
                            </div>
                            <div className="flex items-center gap-2">
                              <span className={`text-xs px-1.5 py-0.5 rounded-full font-semibold ${p.is_active ? 'status-active' : 'status-cancelled'}`}>
                                {p.is_active ? 'Active' : 'Off'}
                              </span>
                              <button onClick={() => openEditPickup(p)} className="p-1 rounded hover:bg-muted text-muted-foreground"><Edit2 size={12} /></button>
                              <button onClick={() => togglePickupStatus(p)} disabled={actionLoading === p.id} className={`p-1 rounded hover:bg-muted ${p.is_active ? 'text-danger' : 'text-success'}`}><Power size={12} /></button>
                            </div>
                          </div>
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
  );
}

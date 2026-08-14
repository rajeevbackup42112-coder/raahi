'use client';
import React, { useState, useEffect, useCallback } from 'react';
import { Plus, Edit2, Power, Car, User, RefreshCw, X, Check } from 'lucide-react';
import { toast } from 'sonner';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

interface Vehicle {
  id: string;
  registration_number: string;
  make: string;
  model: string;
  vehicle_type: string;
  seating_capacity: number;
  fuel_type: string;
  color: string | null;
  status: string;
  assigned_driver_id: string | null;
  assigned_driver?: { name: string; phone: string | null } | null;
}

interface Driver {
  id: string;
  profile_id: string;
  verification_status: string;
  profiles: { name: string; phone: string | null };
}

const EMPTY_FORM = {
  registration_number: '',
  make: '',
  model: '',
  vehicle_type: 'car',
  seating_capacity: 4,
  fuel_type: 'petrol',
  color: '',
  status: 'active',
  assigned_driver_id: '',
};

export default function AdminVehiclesContent() {
  const { profile } = useAuth();
  const supabase = createClient();
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState({ ...EMPTY_FORM });
  const [saving, setSaving] = useState(false);
  const [actionLoading, setActionLoading] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    try {
      const { data: vData } = await supabase
        .from('vehicles')
        .select('id, registration_number, make, model, vehicle_type, seating_capacity, fuel_type, color, status, assigned_driver_id')
        .order('created_at', { ascending: false });

      const { data: dData } = await supabase
        .from('drivers')
        .select('id, profile_id, verification_status, profiles:profile_id(name, phone)')
        .eq('verification_status', 'approved');

      if (dData) setDrivers(dData as any);

      if (vData && dData) {
        const driverMap = new Map((dData as any[]).map((d) => [d.profile_id, d.profiles]));
        const enriched = (vData as Vehicle[]).map((v) => ({
          ...v,
          assigned_driver: v.assigned_driver_id ? driverMap.get(v.assigned_driver_id) || null : null,
        }));
        setVehicles(enriched);
      }
    } catch {
      toast.error('Failed to load vehicles');
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => { loadData(); }, [loadData]);

  const openAdd = () => {
    setEditingId(null);
    setForm({ ...EMPTY_FORM });
    setShowForm(true);
  };

  const openEdit = (v: Vehicle) => {
    setEditingId(v.id);
    setForm({
      registration_number: v.registration_number,
      make: v.make,
      model: v.model,
      vehicle_type: v.vehicle_type,
      seating_capacity: v.seating_capacity,
      fuel_type: v.fuel_type,
      color: v.color || '',
      status: v.status,
      assigned_driver_id: v.assigned_driver_id || '',
    });
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!form.registration_number || !form.make || !form.model) {
      toast.error('Registration number, make, and model are required');
      return;
    }
    setSaving(true);
    try {
      const payload: any = {
        registration_number: form.registration_number.toUpperCase(),
        make: form.make,
        model: form.model,
        vehicle_type: form.vehicle_type,
        seating_capacity: Number(form.seating_capacity),
        fuel_type: form.fuel_type,
        color: form.color || null,
        status: form.status,
        assigned_driver_id: form.assigned_driver_id || null,
        updated_at: new Date().toISOString(),
      };

      if (editingId) {
        const { error } = await supabase.from('vehicles').update(payload).eq('id', editingId);
        if (error) throw error;

        // Audit
        if (profile?.id) {
          await supabase.from('audit_logs').insert({
            performed_by: profile.id,
            action: 'vehicle_updated',
            target_table: 'vehicles',
            target_id: editingId,
            new_value: payload,
          });
        }
        toast.success('Vehicle updated');
      } else {
        const { data, error } = await supabase.from('vehicles').insert(payload).select('id').single();
        if (error) throw error;

        if (profile?.id && data) {
          await supabase.from('audit_logs').insert({
            performed_by: profile.id,
            action: 'vehicle_created',
            target_table: 'vehicles',
            target_id: data.id,
            new_value: payload,
          });
        }
        toast.success('Vehicle added');
      }

      setShowForm(false);
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  const toggleStatus = async (v: Vehicle) => {
    setActionLoading(v.id);
    const newStatus = v.status === 'active' ? 'inactive' : 'active';
    try {
      const { error } = await supabase.from('vehicles').update({ status: newStatus, updated_at: new Date().toISOString() }).eq('id', v.id);
      if (error) throw error;
      toast.success(`Vehicle ${newStatus === 'active' ? 'activated' : 'deactivated'}`);
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Action failed');
    } finally {
      setActionLoading(null);
    }
  };

  const statusBadge = (s: string) => {
    if (s === 'active') return 'status-active';
    if (s === 'maintenance') return 'status-waiting';
    return 'status-cancelled';
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8 xl:px-10 py-6 max-w-screen-2xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Vehicles</h1>
          <p className="text-sm text-muted-foreground mt-0.5">Manage fleet and driver assignments</p>
        </div>
        <div className="flex gap-2">
          <button onClick={loadData} className="btn-secondary gap-2 px-3 py-2.5">
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
          </button>
          <button onClick={openAdd} className="btn-primary gap-2">
            <Plus size={16} /> Add Vehicle
          </button>
        </div>
      </div>

      {/* Form Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
          <div className="bg-card rounded-2xl shadow-elevated w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between p-5 border-b">
              <h2 className="font-bold text-foreground">{editingId ? 'Edit Vehicle' : 'Add Vehicle'}</h2>
              <button onClick={() => setShowForm(false)} className="p-2 rounded-xl hover:bg-muted">
                <X size={16} />
              </button>
            </div>
            <div className="p-5 flex flex-col gap-4">
              <div className="grid grid-cols-2 gap-3">
                <div className="col-span-2">
                  <label className="section-label mb-1.5">Registration Number *</label>
                  <input className="input-field uppercase" value={form.registration_number} onChange={(e) => setForm({ ...form, registration_number: e.target.value })} placeholder="JH05AB1234" />
                </div>
                <div>
                  <label className="section-label mb-1.5">Make *</label>
                  <input className="input-field" value={form.make} onChange={(e) => setForm({ ...form, make: e.target.value })} placeholder="Maruti" />
                </div>
                <div>
                  <label className="section-label mb-1.5">Model *</label>
                  <input className="input-field" value={form.model} onChange={(e) => setForm({ ...form, model: e.target.value })} placeholder="Dzire" />
                </div>
                <div>
                  <label className="section-label mb-1.5">Seating Capacity</label>
                  <input type="number" min={1} max={20} className="input-field" value={form.seating_capacity} onChange={(e) => setForm({ ...form, seating_capacity: parseInt(e.target.value) || 4 })} />
                </div>
                <div>
                  <label className="section-label mb-1.5">Fuel Type</label>
                  <select className="input-field" value={form.fuel_type} onChange={(e) => setForm({ ...form, fuel_type: e.target.value })}>
                    <option value="petrol">Petrol</option>
                    <option value="diesel">Diesel</option>
                    <option value="cng">CNG</option>
                    <option value="electric">Electric</option>
                  </select>
                </div>
                <div>
                  <label className="section-label mb-1.5">Color</label>
                  <input className="input-field" value={form.color} onChange={(e) => setForm({ ...form, color: e.target.value })} placeholder="White" />
                </div>
                <div>
                  <label className="section-label mb-1.5">Status</label>
                  <select className="input-field" value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>
                    <option value="active">Active</option>
                    <option value="inactive">Inactive</option>
                    <option value="maintenance">Maintenance</option>
                  </select>
                </div>
                <div className="col-span-2">
                  <label className="section-label mb-1.5">Assign to Driver</label>
                  <select className="input-field" value={form.assigned_driver_id} onChange={(e) => setForm({ ...form, assigned_driver_id: e.target.value })}>
                    <option value="">— Unassigned —</option>
                    {drivers.map((d) => (
                      <option key={d.profile_id} value={d.profile_id}>
                        {(d.profiles as any)?.name} — {(d.profiles as any)?.phone || 'No phone'}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="flex gap-3 pt-2">
                <button onClick={() => setShowForm(false)} className="btn-secondary flex-1">Cancel</button>
                <button onClick={handleSave} disabled={saving} className="btn-primary flex-1 gap-2">
                  {saving ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <Check size={16} />}
                  {editingId ? 'Save Changes' : 'Add Vehicle'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Table */}
      <div className="card-base overflow-hidden">
        {loading ? (
          <div className="p-8 flex items-center justify-center">
            <div className="w-6 h-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
          </div>
        ) : vehicles.length === 0 ? (
          <div className="p-12 flex flex-col items-center gap-3 text-center">
            <Car size={40} className="text-muted-foreground/30" />
            <p className="text-muted-foreground">No vehicles yet. Add your first vehicle.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50">
                  {['Vehicle', 'Registration', 'Capacity', 'Fuel', 'Assigned Driver', 'Status', 'Actions'].map((h) => (
                    <th key={h} className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {vehicles.map((v) => (
                  <tr key={v.id} className="border-b last:border-0 hover:bg-muted/30 transition-colors">
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center shrink-0">
                          <Car size={14} className="text-muted-foreground" />
                        </div>
                        <div>
                          <p className="font-semibold text-foreground">{v.make} {v.model}</p>
                          <p className="text-xs text-muted-foreground capitalize">{v.vehicle_type} · {v.color || '—'}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 font-mono text-sm text-foreground">{v.registration_number}</td>
                    <td className="px-4 py-3 text-foreground font-semibold">{v.seating_capacity} seats</td>
                    <td className="px-4 py-3 text-muted-foreground capitalize">{v.fuel_type}</td>
                    <td className="px-4 py-3">
                      {v.assigned_driver ? (
                        <div className="flex items-center gap-1.5">
                          <User size={12} className="text-primary shrink-0" />
                          <span className="text-foreground text-sm">{(v.assigned_driver as any)?.name}</span>
                        </div>
                      ) : (
                        <span className="text-muted-foreground text-xs">Unassigned</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${statusBadge(v.status)}`}>
                        {v.status}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <button
                          onClick={() => openEdit(v)}
                          className="p-1.5 rounded-lg hover:bg-muted transition-colors text-muted-foreground hover:text-foreground"
                          title="Edit"
                        >
                          <Edit2 size={14} />
                        </button>
                        <button
                          onClick={() => toggleStatus(v)}
                          disabled={actionLoading === v.id}
                          className={`p-1.5 rounded-lg hover:bg-muted transition-colors ${v.status === 'active' ? 'text-danger' : 'text-success'}`}
                          title={v.status === 'active' ? 'Deactivate' : 'Activate'}
                        >
                          <Power size={14} />
                        </button>
                      </div>
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

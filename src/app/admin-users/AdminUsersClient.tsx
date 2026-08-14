'use client';
import React, { useState, useEffect } from 'react';
import AdminSidebar from '@/components/AdminSidebar';
import AdminTopbar from '../admin-dashboard/components/AdminTopbar';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import { Users, UserCheck, UserX, CheckCircle, XCircle, Search, RefreshCw, UserPlus, Car, ListPlus, AlertCircle, ShieldOff, ShieldCheck, Clock } from 'lucide-react';
import { toast } from 'sonner';

interface PassengerRecord {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  status: string;
  role: string;
  created_at: string;
  booking_cooldown_until: string | null;
  is_test_data?: boolean;
}

interface DriverRecord {
  id: string;
  profile_id: string;
  license_number: string | null;
  verification_status: string;
  availability_status: string;
  is_test_data?: boolean;
  profiles: {
    name: string;
    phone: string | null;
    email: string | null;
    status: string;
    is_test_data?: boolean;
  } | null;
  vehicles: {
    make: string;
    model: string;
    registration_number: string;
  } | null;
}

interface Vehicle {
  id: string;
  registration_number: string;
  make: string;
  model: string;
  seating_capacity: number;
  assigned_driver_id: string | null;
}

interface Route {
  id: string;
  from_location: string;
  to_location: string;
}

type Tab = 'passengers' | 'drivers';

export default function AdminUsersClient() {
  const { profile } = useAuth();
  const [activeTab, setActiveTab] = useState<Tab>('drivers');
  const [passengers, setPassengers] = useState<PassengerRecord[]>([]);
  const [drivers, setDrivers] = useState<DriverRecord[]>([]);
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [routes, setRoutes] = useState<Route[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [convertingId, setConvertingId] = useState<string | null>(null);
  const [licenseInput, setLicenseInput] = useState('');
  const [assignVehicleDriverId, setAssignVehicleDriverId] = useState<string | null>(null);
  const [selectedVehicleId, setSelectedVehicleId] = useState('');
  // Add to Queue modal state
  const [addToQueueDriverId, setAddToQueueDriverId] = useState<string | null>(null);
  const [queueRouteId, setQueueRouteId] = useState('');
  const [queueVehicleId, setQueueVehicleId] = useState('');
  // Passenger suspend/reactivate reason dialog
  const [passengerActionTarget, setPassengerActionTarget] = useState<{ id: string; name: string; action: 'suspend' | 'reactivate' } | null>(null);
  const [passengerActionReason, setPassengerActionReason] = useState('');
  // Driver suspend reason dialog
  const [driverSuspendTarget, setDriverSuspendTarget] = useState<{ id: string; name: string } | null>(null);
  const [driverSuspendReason, setDriverSuspendReason] = useState('');
  // Cooldown clear dialog
  const [cooldownClearTarget, setCooldownClearTarget] = useState<{ id: string; name: string; cooldown_until: string } | null>(null);
  const [cooldownClearReason, setCooldownClearReason] = useState('');
  const supabase = createClient();

  useEffect(() => {
    loadData();
  }, [activeTab]);

  const loadData = async () => {
    setLoading(true);
    try {
      if (activeTab === 'passengers') {
        const { data, error } = await supabase
          .from('profiles')
          .select('id, name, phone, email, status, role, created_at, booking_cooldown_until, is_test_data')
          .in('role', ['passenger'])
          .order('created_at', { ascending: false });
        if (!error && data) setPassengers(data as PassengerRecord[]);
      } else {
        const { data, error } = await supabase
          .from('drivers')
          .select(`
            id, profile_id, license_number, verification_status, availability_status, is_test_data,
            profiles:profile_id (name, phone, email, status, is_test_data),
            vehicles:current_vehicle_id (make, model, registration_number)
          `)
          .order('created_at', { ascending: false });
        if (!error && data) setDrivers(data as any);

        // Load vehicles for assignment
        const { data: vData } = await supabase
          .from('vehicles')
          .select('id, registration_number, make, model, seating_capacity, assigned_driver_id')
          .eq('status', 'active')
          .order('make');
        if (vData) setVehicles(vData as Vehicle[]);

        // Load routes for Add to Queue
        const { data: rData } = await supabase
          .from('routes')
          .select('id, from_location, to_location')
          .eq('status', 'active')
          .order('from_location');
        if (rData) setRoutes(rData as Route[]);
      }
    } catch {
      toast.error('Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  const updateDriverStatus = async (driverId: string, verificationStatus: string) => {
    setActionLoading(driverId);
    try {
      const { error } = await supabase
        .from('drivers')
        .update({ verification_status: verificationStatus, updated_at: new Date().toISOString() })
        .eq('id', driverId);
      if (error) throw error;

      if (profile?.id) {
        const action = verificationStatus === 'approved' ? 'driver_approved' : 'driver_activated';
        await supabase.from('audit_logs').insert({
          performed_by: profile.id,
          action,
          target_table: 'drivers',
          target_id: driverId,
          new_value: { verification_status: verificationStatus },
        });
      }

      toast.success('Driver approved — they can now go online');
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Action failed');
    } finally {
      setActionLoading(null);
    }
  };

  const suspendDriver = async (driverId: string, reason: string) => {
    setActionLoading(driverId);
    try {
      const { data, error } = await supabase.rpc('admin_suspend_driver', {
        p_driver_id: driverId,
        p_reason: reason,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Suspend failed'); return; }
      toast.success('Driver suspended and removed from queue');
      setDriverSuspendTarget(null);
      setDriverSuspendReason('');
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Suspend failed');
    } finally {
      setActionLoading(null);
    }
  };

  const reactivateDriver = async (driverId: string) => {
    setActionLoading(driverId);
    try {
      const { error } = await supabase
        .from('drivers')
        .update({
          verification_status: 'approved',
          availability_status: 'offline',
          updated_at: new Date().toISOString(),
        })
        .eq('id', driverId);
      if (error) throw error;

      if (profile?.id) {
        await supabase.from('audit_logs').insert({
          performed_by: profile.id,
          action: 'driver_reactivated' as any,
          target_table: 'drivers',
          target_id: driverId,
          new_value: { verification_status: 'approved', availability_status: 'offline' },
        });
      }

      toast.success('Driver reactivated — they can go online.');
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Reactivation failed');
    } finally {
      setActionLoading(null);
    }
  };

  const convertToDriver = async (userId: string) => {
    if (!profile?.id) return;
    setActionLoading(userId);
    try {
      const { data, error } = await supabase.rpc('convert_user_to_driver', {
        p_user_id: userId,
        p_license_number: licenseInput.trim() || null,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Conversion failed'); return; }
      toast.success(result.message || 'User converted to driver. Approve them to allow going online.');
      setConvertingId(null);
      setLicenseInput('');
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Conversion failed');
    } finally {
      setActionLoading(null);
    }
  };

  const assignVehicleToDriver = async (driverId: string, vehicleId: string) => {
    if (!profile?.id || !vehicleId) return;
    setActionLoading(driverId);
    try {
      const { data, error } = await supabase.rpc('admin_assign_vehicle_to_driver', {
        p_driver_id: driverId,
        p_vehicle_id: vehicleId,
        p_reason: 'Admin vehicle assignment',
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Assignment failed'); return; }
      toast.success('Vehicle assigned to driver');
      setAssignVehicleDriverId(null);
      setSelectedVehicleId('');
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Assignment failed');
    } finally {
      setActionLoading(null);
    }
  };

  const handleAddToQueue = async (driverId: string) => {
    if (!queueRouteId || !queueVehicleId) {
      toast.error('Please select both a route and a vehicle');
      return;
    }
    setActionLoading(driverId);
    try {
      const { data, error } = await supabase.rpc('admin_add_driver_to_queue', {
        p_driver_id: driverId,
        p_route_id: queueRouteId,
        p_vehicle_id: queueVehicleId,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) {
        toast.error(result?.error || 'Failed to add driver to queue');
        return;
      }
      toast.success(result.message || 'Driver added to queue');
      setAddToQueueDriverId(null);
      setQueueRouteId('');
      setQueueVehicleId('');
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Failed to add driver to queue');
    } finally {
      setActionLoading(null);
    }
  };

  const handlePassengerAction = async () => {
    if (!passengerActionTarget) return;
    const { id, action } = passengerActionTarget;
    const reason = passengerActionReason.trim();
    if (action === 'suspend' && !reason) {
      toast.error('A reason is required to suspend a passenger');
      return;
    }
    setActionLoading(id);
    try {
      if (action === 'suspend') {
        const { data, error } = await supabase.rpc('admin_suspend_passenger', {
          p_passenger_id: id,
          p_reason: reason,
        });
        if (error) throw error;
        const result = data as any;
        if (!result?.success) { toast.error(result?.error || 'Suspend failed'); return; }
        toast.success('Passenger suspended');
      } else {
        const { data, error } = await supabase.rpc('admin_reactivate_passenger', {
          p_passenger_id: id,
          p_reason: reason || 'Admin reactivated passenger',
        });
        if (error) throw error;
        const result = data as any;
        if (!result?.success) { toast.error(result?.error || 'Reactivate failed'); return; }
        toast.success('Passenger reactivated — they can book again');
      }
      setPassengerActionTarget(null);
      setPassengerActionReason('');
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Action failed');
    } finally {
      setActionLoading(null);
    }
  };

  const handleClearCooldown = async () => {
    if (!cooldownClearTarget) return;
    const reason = cooldownClearReason.trim();
    if (!reason) {
      toast.error('A reason is required to clear a booking cooldown');
      return;
    }
    setActionLoading(cooldownClearTarget.id);
    try {
      const { data, error } = await supabase.rpc('admin_clear_booking_cooldown', {
        p_profile_id: cooldownClearTarget.id,
        p_reason: reason,
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Clear cooldown failed'); return; }
      toast.success('Booking cooldown cleared — passenger may book immediately');
      setCooldownClearTarget(null);
      setCooldownClearReason('');
      await loadData();
    } catch (err: any) {
      toast.error(err?.message || 'Clear cooldown failed');
    } finally {
      setActionLoading(null);
    }
  };

  const openAddToQueue = (driver: DriverRecord) => {
    setAddToQueueDriverId(driver.id);
    setAssignVehicleDriverId(null);
    setConvertingId(null);
    const currentVehicle = vehicles.find(v => v.assigned_driver_id === driver.profile_id);
    setQueueVehicleId(currentVehicle?.id || '');
    setQueueRouteId('');
  };

  const isCooldownActive = (cooldown_until: string | null): boolean => {
    if (!cooldown_until) return false;
    return new Date(cooldown_until) > new Date();
  };

  const cooldownRemainingMinutes = (cooldown_until: string | null): number => {
    if (!cooldown_until) return 0;
    const diff = new Date(cooldown_until).getTime() - Date.now();
    return Math.max(0, Math.ceil(diff / 60000));
  };

  const filteredPassengers = passengers.filter((p) =>
    p.name?.toLowerCase().includes(search.toLowerCase()) ||
    p.phone?.includes(search) ||
    p.email?.toLowerCase().includes(search.toLowerCase())
  );

  const filteredDrivers = drivers.filter((d) =>
    d.profiles?.name?.toLowerCase().includes(search.toLowerCase()) ||
    d.profiles?.phone?.includes(search) ||
    d.vehicles?.registration_number?.toLowerCase().includes(search.toLowerCase())
  );

  const verificationBadge = (status: string) => {
    if (status === 'approved') return { label: 'Approved', cls: 'status-active' };
    if (status === 'pending') return { label: 'Pending', cls: 'status-waiting' };
    if (status === 'rejected') return { label: 'Rejected', cls: 'status-cancelled' };
    if (status === 'suspended') return { label: 'Suspended', cls: 'status-cancelled' };
    return { label: status, cls: 'status-waiting' };
  };

  const availabilityBadge = (status: string) => {
    if (status === 'queued' || status === 'online') return 'text-success font-semibold';
    if (status === 'active' || status === 'on_trip' || status === 'trip_started') return 'text-primary font-semibold';
    if (status === 'offline') return 'text-muted-foreground';
    if (status === 'completed') return 'text-muted-foreground';
    return 'text-muted-foreground';
  };

  const canAddToQueue = (driver: DriverRecord) => {
    if (driver.verification_status !== 'approved') return false;
    const activeStatuses = ['queued', 'online', 'active', 'on_trip', 'trip_started'];
    if (activeStatuses.includes(driver.availability_status)) return false;
    return true;
  };

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <AdminSidebar />
      <main className="flex-1 overflow-y-auto">
        <AdminTopbar />
        <div className="px-4 sm:px-6 lg:px-8 xl:px-10 py-6 max-w-screen-2xl mx-auto">
          <div className="mb-6">
            <h1 className="text-2xl font-bold text-foreground">User Management</h1>
            <p className="text-sm text-muted-foreground mt-0.5">Manage passengers and drivers — approve drivers to allow them to go online</p>
          </div>

          <div className="flex gap-2 mb-6 p-1 bg-muted rounded-xl w-fit">
            {(['drivers', 'passengers'] as Tab[]).map((tab) => (
              <button
                key={tab}
                onClick={() => { setActiveTab(tab); setSearch(''); }}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-semibold transition-all capitalize ${activeTab === tab ? 'bg-card shadow-card text-primary' : 'text-muted-foreground hover:text-foreground'}`}
              >
                {tab === 'drivers' ? <UserCheck size={14} /> : <Users size={14} />}
                {tab}
              </button>
            ))}
          </div>

          <div className="flex items-center gap-3 mb-5">
            <div className="relative flex-1 max-w-sm">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
              <input
                type="text"
                placeholder={`Search ${activeTab}...`}
                className="input-field pl-9"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
            <button onClick={loadData} className="btn-secondary gap-2 px-3 py-2.5" disabled={loading}>
              <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
              Refresh
            </button>
          </div>

          {activeTab === 'drivers' && (
            <div className="card-base overflow-hidden">
              {loading ? (
                <div className="p-8 flex items-center justify-center">
                  <div className="w-6 h-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
                </div>
              ) : filteredDrivers.length === 0 ? (
                <div className="p-12 flex flex-col items-center gap-3 text-center">
                  <UserCheck size={40} className="text-muted-foreground/30" />
                  <p className="text-muted-foreground">No drivers found</p>
                  <p className="text-xs text-muted-foreground">Convert a passenger to driver from the Passengers tab</p>
                </div>
              ) : (
                <>
                  {/* Mobile card list */}
                  <div className="flex flex-col divide-y lg:hidden">
                    {filteredDrivers.map((driver) => {
                      const badge = verificationBadge(driver.verification_status);
                      const isLoading = actionLoading === driver.id;
                      const showAddToQueue = canAddToQueue(driver);
                      return (
                        <div key={driver.id} className="p-4 flex flex-col gap-3">
                          <div className="flex items-start justify-between gap-2">
                            <div className="flex items-center gap-2 flex-1 min-w-0">
                              <div className="w-9 h-9 rounded-full gradient-primary flex items-center justify-center text-white text-sm font-bold shrink-0">
                                {driver.profiles?.name?.charAt(0)?.toUpperCase() || 'D'}
                              </div>
                              <div className="min-w-0">
                                <div className="flex items-center gap-1.5 flex-wrap">
                                  <p className="font-semibold text-foreground truncate">{driver.profiles?.name || '—'}</p>
                                  {(driver.is_test_data || driver.profiles?.is_test_data) && <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-100 text-amber-700 border border-amber-300 uppercase tracking-wide shrink-0">TEST</span>}
                                </div>
                                <p className="text-xs text-muted-foreground truncate">{driver.profiles?.phone || driver.profiles?.email || '—'}</p>
                              </div>
                            </div>
                            <span className={`text-xs font-semibold px-2 py-0.5 rounded-full shrink-0 ${badge.cls}`}>{badge.label}</span>
                          </div>
                          {driver.vehicles && (
                            <p className="text-xs text-muted-foreground">
                              {driver.vehicles.make} {driver.vehicles.model} · {driver.vehicles.registration_number}
                            </p>
                          )}
                          <div className="flex flex-wrap gap-2">
                            {driver.verification_status === 'pending' && (
                              <button onClick={() => updateDriverStatus(driver.id, 'approved')} disabled={isLoading}
                                className="flex items-center gap-1 text-xs font-semibold px-2.5 py-2 rounded-lg bg-success/10 text-success hover:bg-success/20 transition-colors disabled:opacity-50 min-h-[36px]">
                                <CheckCircle size={12} /> Approve
                              </button>
                            )}
                            {driver.verification_status === 'approved' && (
                              <button onClick={() => { setDriverSuspendTarget({ id: driver.id, name: driver.profiles?.name || 'Driver' }); setDriverSuspendReason(''); }} disabled={isLoading}
                                className="flex items-center gap-1 text-xs font-semibold px-2.5 py-2 rounded-lg bg-danger/10 text-danger hover:bg-danger/20 transition-colors disabled:opacity-50 min-h-[36px]">
                                <XCircle size={12} /> Suspend
                              </button>
                            )}
                            {driver.verification_status === 'suspended' && (
                              <button onClick={() => reactivateDriver(driver.id)} disabled={isLoading}
                                className="flex items-center gap-1 text-xs font-semibold px-2.5 py-2 rounded-lg bg-primary/10 text-primary hover:bg-primary/20 transition-colors disabled:opacity-50 min-h-[36px]">
                                <CheckCircle size={12} /> Reactivate
                              </button>
                            )}
                            {showAddToQueue && (
                              <button onClick={() => openAddToQueue(driver)} disabled={isLoading}
                                className="flex items-center gap-1 text-xs font-semibold px-2.5 py-2 rounded-lg bg-blue-50 text-blue-700 hover:bg-blue-100 transition-colors disabled:opacity-50 min-h-[36px]">
                                <ListPlus size={12} /> Add to Queue
                              </button>
                            )}
                          </div>
                          {/* Inline dialogs for mobile */}
                          {driverSuspendTarget?.id === driver.id && (
                            <div className="flex flex-col gap-2 p-3 bg-red-50/50 rounded-xl border border-red-200">
                              <p className="text-xs font-semibold text-danger">Suspend {driverSuspendTarget.name}</p>
                              <textarea className="input-field text-sm resize-none" rows={2} placeholder="Reason (required)" value={driverSuspendReason} onChange={(e) => setDriverSuspendReason(e.target.value)} />
                              <div className="flex gap-2">
                                <button onClick={() => suspendDriver(driver.id, driverSuspendReason)} disabled={!driverSuspendReason.trim() || isLoading} className="flex-1 flex items-center justify-center gap-1 text-xs font-semibold py-2 rounded-lg bg-danger text-white disabled:opacity-50">Confirm Suspend</button>
                                <button onClick={() => { setDriverSuspendTarget(null); setDriverSuspendReason(''); }} className="flex-1 btn-secondary text-xs py-2">Cancel</button>
                              </div>
                            </div>
                          )}
                          {addToQueueDriverId === driver.id && (
                            <div className="flex flex-col gap-2 p-3 bg-blue-50/50 rounded-xl border border-blue-200">
                              <p className="text-xs font-semibold text-blue-800">Add to Queue</p>
                              <select className="input-field text-sm" value={queueRouteId} onChange={(e) => setQueueRouteId(e.target.value)}>
                                <option value="">— Select route —</option>
                                {routes.map((r) => <option key={r.id} value={r.id}>{r.from_location} → {r.to_location}</option>)}
                              </select>
                              <select className="input-field text-sm" value={queueVehicleId} onChange={(e) => setQueueVehicleId(e.target.value)}>
                                <option value="">— Select vehicle —</option>
                                {vehicles.map((v) => <option key={v.id} value={v.id}>{v.make} {v.model} · {v.registration_number}</option>)}
                              </select>
                              <div className="flex gap-2">
                                <button onClick={() => handleAddToQueue(driver.id)} disabled={!queueRouteId || !queueVehicleId || isLoading} className="flex-1 flex items-center justify-center gap-1 text-xs font-semibold py-2 rounded-lg bg-blue-600 text-white disabled:opacity-50">Confirm</button>
                                <button onClick={() => { setAddToQueueDriverId(null); setQueueRouteId(''); setQueueVehicleId(''); }} className="flex-1 btn-secondary text-xs py-2">Cancel</button>
                              </div>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>

                  {/* Desktop table */}
                  <div className="hidden lg:block overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b bg-muted/50">
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Driver</th>
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Phone</th>
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Vehicle</th>
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Status</th>
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Availability</th>
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {filteredDrivers.map((driver) => {
                          const badge = verificationBadge(driver.verification_status);
                          const isLoading = actionLoading === driver.id;
                          const isAssigning = assignVehicleDriverId === driver.id;
                          const isAddingToQueue = addToQueueDriverId === driver.id;
                          const showAddToQueue = canAddToQueue(driver);
                          return (
                            <React.Fragment key={driver.id}>
                              <tr className="border-b last:border-0 hover:bg-muted/30 transition-colors">
                                <td className="px-4 py-3">
                                  <div className="flex items-center gap-2">
                                    <div className="w-8 h-8 rounded-full gradient-primary flex items-center justify-center text-white text-xs font-bold shrink-0">
                                      {driver.profiles?.name?.charAt(0)?.toUpperCase() || 'D'}
                                    </div>
                                    <div>
                                      <div className="flex items-center gap-1.5 flex-wrap">
                                        <p className="font-semibold text-foreground">{driver.profiles?.name || '—'}</p>
                                        {(driver.is_test_data || driver.profiles?.is_test_data) && <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-100 text-amber-700 border border-amber-300 uppercase tracking-wide">TEST</span>}
                                      </div>
                                      <p className="text-xs text-muted-foreground">{driver.profiles?.email || '—'}</p>
                                    </div>
                                  </div>
                                </td>
                                <td className="px-4 py-3 text-muted-foreground">{driver.profiles?.phone || '—'}</td>
                                <td className="px-4 py-3">
                                  {driver.vehicles ? (
                                    <div>
                                      <p className="font-medium text-foreground">{driver.vehicles.make} {driver.vehicles.model}</p>
                                      <p className="text-xs text-muted-foreground">{driver.vehicles.registration_number}</p>
                                    </div>
                                  ) : (
                                    <button onClick={() => { setAssignVehicleDriverId(driver.id); setSelectedVehicleId(''); setAddToQueueDriverId(null); }} className="text-xs text-primary hover:underline flex items-center gap-1">
                                      <Car size={11} /> Assign vehicle
                                    </button>
                                  )}
                                </td>
                                <td className="px-4 py-3">
                                  <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${badge.cls}`}>{badge.label}</span>
                                </td>
                                <td className="px-4 py-3">
                                  <span className={`text-xs capitalize ${availabilityBadge(driver.availability_status)}`}>{driver.availability_status}</span>
                                </td>
                                <td className="px-4 py-3">
                                  <div className="flex items-center gap-1.5 flex-wrap">
                                    {driver.verification_status === 'pending' && (
                                      <button onClick={() => updateDriverStatus(driver.id, 'approved')} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-lg bg-success/10 text-success hover:bg-success/20 transition-colors disabled:opacity-50"><CheckCircle size={12} /> Approve</button>
                                    )}
                                    {driver.verification_status === 'approved' && (
                                      <button onClick={() => { setDriverSuspendTarget({ id: driver.id, name: driver.profiles?.name || 'Driver' }); setDriverSuspendReason(''); setAssignVehicleDriverId(null); setAddToQueueDriverId(null); }} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-lg bg-danger/10 text-danger hover:bg-danger/20 transition-colors disabled:opacity-50"><XCircle size={12} /> Suspend</button>
                                    )}
                                    {driver.verification_status === 'suspended' && (
                                      <button onClick={() => reactivateDriver(driver.id)} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-lg bg-primary/10 text-primary hover:bg-primary/20 transition-colors disabled:opacity-50"><CheckCircle size={12} /> Reactivate</button>
                                    )}
                                    {!driver.vehicles && (
                                      <button onClick={() => { setAssignVehicleDriverId(driver.id); setSelectedVehicleId(''); setAddToQueueDriverId(null); }} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-lg bg-muted text-muted-foreground hover:bg-muted/80 transition-colors disabled:opacity-50"><Car size={12} /> Vehicle</button>
                                    )}
                                    {showAddToQueue && (
                                      <button onClick={() => isAddingToQueue ? setAddToQueueDriverId(null) : openAddToQueue(driver)} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-lg bg-blue-50 text-blue-700 hover:bg-blue-100 transition-colors disabled:opacity-50"><ListPlus size={12} /> Add to Queue</button>
                                    )}
                                    {isLoading && <div className="w-4 h-4 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />}
                                  </div>
                                </td>
                              </tr>
                              {isAssigning && (
                                <tr className="border-b bg-muted/20">
                                  <td colSpan={6} className="px-4 py-3">
                                    <div className="flex items-center gap-3 flex-wrap">
                                      <p className="text-sm font-semibold text-foreground">Assign vehicle to {driver.profiles?.name}:</p>
                                      <select className="input-field max-w-xs text-sm" value={selectedVehicleId} onChange={(e) => setSelectedVehicleId(e.target.value)}>
                                        <option value="">— Select vehicle —</option>
                                        {vehicles.map((v) => <option key={v.id} value={v.id}>{v.make} {v.model} · {v.registration_number} · {v.seating_capacity} seats{v.assigned_driver_id ? ' (assigned)' : ''}</option>)}
                                      </select>
                                      <button onClick={() => assignVehicleToDriver(driver.id, selectedVehicleId)} disabled={!selectedVehicleId || isLoading} className="btn-primary text-sm px-3 py-1.5 gap-1"><CheckCircle size={12} /> Assign</button>
                                      <button onClick={() => setAssignVehicleDriverId(null)} className="btn-secondary text-sm px-3 py-1.5">Cancel</button>
                                    </div>
                                  </td>
                                </tr>
                              )}
                              {isAddingToQueue && (
                                <tr className="border-b bg-blue-50/40">
                                  <td colSpan={6} className="px-4 py-4">
                                    <div className="flex flex-col gap-3">
                                      <div className="flex items-center gap-2"><AlertCircle size={14} className="text-blue-600 shrink-0" /><p className="text-sm font-semibold text-blue-800">Admin Override — Add {driver.profiles?.name} to Driver Queue</p></div>
                                      <div className="flex items-center gap-3 flex-wrap">
                                        <select className="input-field text-sm min-w-[200px]" value={queueRouteId} onChange={(e) => setQueueRouteId(e.target.value)}>
                                          <option value="">— Select route —</option>
                                          {routes.map((r) => <option key={r.id} value={r.id}>{r.from_location} → {r.to_location}</option>)}
                                        </select>
                                        <select className="input-field text-sm min-w-[220px]" value={queueVehicleId} onChange={(e) => setQueueVehicleId(e.target.value)}>
                                          <option value="">— Select vehicle —</option>
                                          {vehicles.map((v) => <option key={v.id} value={v.id}>{v.make} {v.model} · {v.registration_number} · {v.seating_capacity} seats</option>)}
                                        </select>
                                      </div>
                                      <div className="flex items-center gap-2">
                                        <button onClick={() => handleAddToQueue(driver.id)} disabled={!queueRouteId || !queueVehicleId || isLoading} className="flex items-center gap-1.5 text-sm font-semibold px-4 py-2 rounded-lg bg-blue-600 text-white hover:bg-blue-700 transition-colors disabled:opacity-50">{isLoading ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <ListPlus size={14} />}Confirm — Add to Queue</button>
                                        <button onClick={() => { setAddToQueueDriverId(null); setQueueRouteId(''); setQueueVehicleId(''); }} className="btn-secondary text-sm px-3 py-2">Cancel</button>
                                      </div>
                                    </div>
                                  </td>
                                </tr>
                              )}
                              {driverSuspendTarget?.id === driver.id && (
                                <tr className="border-b bg-red-50/30">
                                  <td colSpan={6} className="px-4 py-4">
                                    <div className="flex flex-col gap-3">
                                      <div className="flex items-center gap-2"><ShieldOff size={14} className="text-danger shrink-0" /><p className="text-sm font-semibold text-foreground">Suspend {driverSuspendTarget.name}</p></div>
                                      <textarea className="input-field text-sm resize-none" rows={2} placeholder="Reason for suspension (required)" value={driverSuspendReason} onChange={(e) => setDriverSuspendReason(e.target.value)} />
                                      <div className="flex gap-2">
                                        <button onClick={() => suspendDriver(driver.id, driverSuspendReason)} disabled={!driverSuspendReason.trim() || isLoading} className="flex items-center gap-1.5 text-sm font-semibold px-4 py-2 rounded-lg bg-danger text-white hover:bg-danger/90 transition-colors disabled:opacity-50">{isLoading ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <ShieldOff size={13} />}Confirm Suspend</button>
                                        <button onClick={() => { setDriverSuspendTarget(null); setDriverSuspendReason(''); }} className="btn-secondary text-sm px-3 py-2">Cancel</button>
                                      </div>
                                    </div>
                                  </td>
                                </tr>
                              )}
                            </React.Fragment>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                </>
              )}
            </div>
          )}

          {activeTab === 'passengers' && (
            <div className="card-base overflow-hidden">
              {loading ? (
                <div className="p-8 flex items-center justify-center">
                  <div className="w-6 h-6 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
                </div>
              ) : filteredPassengers.length === 0 ? (
                <div className="p-12 flex flex-col items-center gap-3 text-center">
                  <Users size={40} className="text-muted-foreground/30" />
                  <p className="text-muted-foreground">No passengers found</p>
                </div>
              ) : (
                <>
                  {/* Mobile card list */}
                  <div className="flex flex-col divide-y lg:hidden">
                    {filteredPassengers.map((passenger) => {
                      const isLoading = actionLoading === passenger.id;
                      const cooldownActive = isCooldownActive(passenger.booking_cooldown_until);
                      const remainingMin = cooldownRemainingMinutes(passenger.booking_cooldown_until);
                      const isCooldownTarget = cooldownClearTarget?.id === passenger.id;
                      return (
                        <div key={passenger.id} className="p-4 flex flex-col gap-3">
                          <div className="flex items-start justify-between gap-2">
                            <div className="flex items-center gap-2 flex-1 min-w-0">
                              <div className="w-9 h-9 rounded-full bg-secondary flex items-center justify-center text-primary text-sm font-bold shrink-0">
                                {passenger.name?.charAt(0)?.toUpperCase() || 'P'}
                              </div>
                              <div className="min-w-0">
                                <div className="flex items-center gap-1.5 flex-wrap">
                                  <p className="font-semibold text-foreground truncate">{passenger.name || '—'}</p>
                                  {passenger.is_test_data && <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-100 text-amber-700 border border-amber-300 uppercase tracking-wide shrink-0">TEST</span>}
                                </div>
                                <p className="text-xs text-muted-foreground truncate">{passenger.phone || passenger.email || '—'}</p>
                              </div>
                            </div>
                            <div className="flex flex-col items-end gap-1 shrink-0">
                              <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${passenger.status === 'active' ? 'status-active' : 'status-cancelled'}`}>{passenger.status}</span>
                              {cooldownActive && (
                                <span className="text-xs font-semibold text-amber-700 flex items-center gap-1"><Clock size={10} />{remainingMin}m cooldown</span>
                              )}
                            </div>
                          </div>
                          <div className="flex flex-wrap gap-2">
                            {passenger.status !== 'suspended' ? (
                              <button onClick={() => { setPassengerActionTarget({ id: passenger.id, name: passenger.name, action: 'suspend' }); setPassengerActionReason(''); }} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-2 rounded-lg bg-danger/10 text-danger hover:bg-danger/20 transition-colors disabled:opacity-50 min-h-[36px]"><UserX size={12} /> Suspend</button>
                            ) : (
                              <button onClick={() => { setPassengerActionTarget({ id: passenger.id, name: passenger.name, action: 'reactivate' }); setPassengerActionReason(''); }} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-2 rounded-lg bg-success/10 text-success hover:bg-success/20 transition-colors disabled:opacity-50 min-h-[36px]"><ShieldCheck size={12} /> Reactivate</button>
                            )}
                            {cooldownActive && (
                              <button onClick={() => { setCooldownClearTarget({ id: passenger.id, name: passenger.name, cooldown_until: passenger.booking_cooldown_until! }); setCooldownClearReason(''); }} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-2 rounded-lg bg-amber-50 text-amber-700 hover:bg-amber-100 transition-colors disabled:opacity-50 min-h-[36px]"><Clock size={12} /> Clear Cooldown</button>
                            )}
                          </div>
                          {/* Inline dialogs for mobile */}
                          {passengerActionTarget?.id === passenger.id && (
                            <div className={`flex flex-col gap-2 p-3 rounded-xl border ${passengerActionTarget.action === 'suspend' ? 'bg-red-50/50 border-red-200' : 'bg-green-50/50 border-green-200'}`}>
                              <p className="text-xs font-semibold">{passengerActionTarget.action === 'suspend' ? 'Suspend' : 'Reactivate'} {passengerActionTarget.name}</p>
                              <textarea className="input-field text-sm resize-none" rows={2} placeholder={passengerActionTarget.action === 'suspend' ? 'Reason (required)' : 'Reason (optional)'} value={passengerActionReason} onChange={(e) => setPassengerActionReason(e.target.value)} />
                              <div className="flex gap-2">
                                <button onClick={handlePassengerAction} disabled={(passengerActionTarget.action === 'suspend' && !passengerActionReason.trim()) || isLoading} className={`flex-1 flex items-center justify-center gap-1 text-xs font-semibold py-2 rounded-lg text-white disabled:opacity-50 ${passengerActionTarget.action === 'suspend' ? 'bg-danger' : 'bg-success'}`}>Confirm</button>
                                <button onClick={() => { setPassengerActionTarget(null); setPassengerActionReason(''); }} className="flex-1 btn-secondary text-xs py-2">Cancel</button>
                              </div>
                            </div>
                          )}
                          {isCooldownTarget && (
                            <div className="flex flex-col gap-2 p-3 bg-amber-50/50 rounded-xl border border-amber-200">
                              <p className="text-xs font-semibold text-amber-800">Clear Cooldown — {cooldownClearTarget!.name}</p>
                              <textarea className="input-field text-sm resize-none" rows={2} placeholder="Reason (required)" value={cooldownClearReason} onChange={(e) => setCooldownClearReason(e.target.value)} />
                              <div className="flex gap-2">
                                <button onClick={handleClearCooldown} disabled={!cooldownClearReason.trim() || isLoading} className="flex-1 flex items-center justify-center gap-1 text-xs font-semibold py-2 rounded-lg bg-amber-600 text-white disabled:opacity-50">Clear</button>
                                <button onClick={() => { setCooldownClearTarget(null); setCooldownClearReason(''); }} className="flex-1 btn-secondary text-xs py-2">Cancel</button>
                              </div>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>

                  {/* Desktop table */}
                  <div className="hidden lg:block overflow-x-auto">
                    <table className="w-full text-sm">
                      <thead>
                        <tr className="border-b bg-muted/50">
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Passenger</th>
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Phone</th>
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Joined</th>
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Status</th>
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Booking Status</th>
                          <th className="text-left px-4 py-3 text-xs font-semibold text-muted-foreground uppercase tracking-wide">Actions</th>
                        </tr>
                      </thead>
                      <tbody>
                        {filteredPassengers.map((passenger) => {
                          const isLoading = actionLoading === passenger.id;
                          const isConverting = convertingId === passenger.id;
                          const cooldownActive = isCooldownActive(passenger.booking_cooldown_until);
                          const remainingMin = cooldownRemainingMinutes(passenger.booking_cooldown_until);
                          const isCooldownTarget = cooldownClearTarget?.id === passenger.id;
                          return (
                            <React.Fragment key={passenger.id}>
                              <tr className="border-b last:border-0 hover:bg-muted/30 transition-colors">
                                <td className="px-4 py-3">
                                  <div className="flex items-center gap-2">
                                    <div className="w-8 h-8 rounded-full bg-secondary flex items-center justify-center text-primary text-xs font-bold shrink-0">{passenger.name?.charAt(0)?.toUpperCase() || 'P'}</div>
                                    <div>
                                      <div className="flex items-center gap-1.5 flex-wrap">
                                        <p className="font-semibold text-foreground">{passenger.name || '—'}</p>
                                        {passenger.is_test_data && <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-100 text-amber-700 border border-amber-300 uppercase tracking-wide">TEST</span>}
                                      </div>
                                      <p className="text-xs text-muted-foreground">{passenger.email || '—'}</p>
                                    </div>
                                  </div>
                                </td>
                                <td className="px-4 py-3 text-muted-foreground">{passenger.phone || '—'}</td>
                                <td className="px-4 py-3 text-muted-foreground text-xs">{new Date(passenger.created_at).toLocaleDateString('en-IN')}</td>
                                <td className="px-4 py-3"><span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${passenger.status === 'active' ? 'status-active' : 'status-cancelled'}`}>{passenger.status}</span></td>
                                <td className="px-4 py-3">
                                  {cooldownActive ? (
                                    <div className="flex items-center gap-1.5"><Clock size={12} className="text-amber-600 shrink-0" /><span className="text-xs font-semibold text-amber-700">Cooldown · {remainingMin}m left</span></div>
                                  ) : <span className="text-xs text-muted-foreground">—</span>}
                                </td>
                                <td className="px-4 py-3">
                                  <div className="flex items-center gap-1.5 flex-wrap">
                                    {passenger.status !== 'suspended' ? (
                                      <button onClick={() => { setPassengerActionTarget({ id: passenger.id, name: passenger.name, action: 'suspend' }); setPassengerActionReason(''); }} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-lg bg-danger/10 text-danger hover:bg-danger/20 transition-colors disabled:opacity-50"><UserX size={12} /> Suspend</button>
                                    ) : (
                                      <button onClick={() => { setPassengerActionTarget({ id: passenger.id, name: passenger.name, action: 'reactivate' }); setPassengerActionReason(''); }} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-lg bg-success/10 text-success hover:bg-success/20 transition-colors disabled:opacity-50"><ShieldCheck size={12} /> Reactivate</button>
                                    )}
                                    {cooldownActive && (
                                      <button onClick={() => { setCooldownClearTarget({ id: passenger.id, name: passenger.name, cooldown_until: passenger.booking_cooldown_until! }); setCooldownClearReason(''); }} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-lg bg-amber-50 text-amber-700 hover:bg-amber-100 transition-colors disabled:opacity-50"><Clock size={12} /> Clear Cooldown</button>
                                    )}
                                    <button onClick={() => { setConvertingId(isConverting ? null : passenger.id); setLicenseInput(''); }} disabled={isLoading} className="flex items-center gap-1 text-xs font-semibold px-2.5 py-1.5 rounded-lg bg-primary/10 text-primary hover:bg-primary/20 transition-colors disabled:opacity-50"><UserPlus size={12} /> Make Driver</button>
                                    {isLoading && <div className="w-4 h-4 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />}
                                  </div>
                                </td>
                              </tr>
                              {isConverting && (
                                <tr className="border-b bg-muted/20"><td colSpan={6} className="px-4 py-3"><div className="flex items-center gap-3 flex-wrap"><p className="text-sm font-semibold text-foreground">Convert {passenger.name} to driver:</p><input className="input-field max-w-xs text-sm" placeholder="License number (optional)" value={licenseInput} onChange={(e) => setLicenseInput(e.target.value)} /><button onClick={() => convertToDriver(passenger.id)} disabled={isLoading} className="btn-primary text-sm px-3 py-1.5 gap-1"><UserPlus size={12} /> Convert</button><button onClick={() => setConvertingId(null)} className="btn-secondary text-sm px-3 py-1.5">Cancel</button></div></td></tr>
                              )}
                              {passengerActionTarget?.id === passenger.id && (
                                <tr className="border-b bg-muted/20"><td colSpan={6} className="px-4 py-4"><div className="flex flex-col gap-3"><div className="flex items-center gap-2">{passengerActionTarget.action === 'suspend' ? <ShieldOff size={14} className="text-danger shrink-0" /> : <ShieldCheck size={14} className="text-success shrink-0" />}<p className="text-sm font-semibold text-foreground">{passengerActionTarget.action === 'suspend' ? 'Suspend' : 'Reactivate'} {passengerActionTarget.name}</p></div><textarea className="input-field text-sm resize-none" rows={2} placeholder={passengerActionTarget.action === 'suspend' ? 'Reason for suspension (required)' : 'Reason (optional)'} value={passengerActionReason} onChange={(e) => setPassengerActionReason(e.target.value)} /><div className="flex gap-2"><button onClick={handlePassengerAction} disabled={(passengerActionTarget.action === 'suspend' && !passengerActionReason.trim()) || isLoading} className={`flex items-center gap-1.5 text-sm font-semibold px-4 py-2 rounded-lg text-white transition-colors disabled:opacity-50 ${passengerActionTarget.action === 'suspend' ? 'bg-danger hover:bg-danger/90' : 'bg-success hover:bg-success/90'}`}>{isLoading ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : null}Confirm {passengerActionTarget.action === 'suspend' ? 'Suspend' : 'Reactivate'}</button><button onClick={() => { setPassengerActionTarget(null); setPassengerActionReason(''); }} className="btn-secondary text-sm px-3 py-2">Cancel</button></div></div></td></tr>
                              )}
                              {isCooldownTarget && (
                                <tr className="border-b bg-amber-50/40"><td colSpan={6} className="px-4 py-4"><div className="flex flex-col gap-3"><div className="flex items-center gap-2"><Clock size={14} className="text-amber-600 shrink-0" /><p className="text-sm font-semibold text-foreground">Clear Booking Cooldown — {cooldownClearTarget!.name}</p></div><p className="text-xs text-muted-foreground">Cooldown active until {new Date(cooldownClearTarget!.cooldown_until).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}. Clearing allows the passenger to book immediately.</p><textarea className="input-field text-sm resize-none" rows={2} placeholder="Reason for clearing cooldown (required)" value={cooldownClearReason} onChange={(e) => setCooldownClearReason(e.target.value)} /><div className="flex gap-2"><button onClick={handleClearCooldown} disabled={!cooldownClearReason.trim() || isLoading} className="flex items-center gap-1.5 text-sm font-semibold px-4 py-2 rounded-lg bg-amber-600 text-white hover:bg-amber-700 transition-colors disabled:opacity-50">{isLoading ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <Clock size={13} />}Clear Cooldown</button><button onClick={() => { setCooldownClearTarget(null); setCooldownClearReason(''); }} className="btn-secondary text-sm px-3 py-2">Cancel</button></div></div></td></tr>
                              )}
                            </React.Fragment>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                </>
              )}
            </div>
          )}
        </div>
      </main>
    </div>
  );
}

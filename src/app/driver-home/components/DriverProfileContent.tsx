'use client';
import React, { useState, useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { createClient } from '@/lib/supabase/client';
import { LogOut, Clock, Car, Phone, User, AlertCircle, Shield } from 'lucide-react';
import { toast } from 'sonner';

interface DriverRecord {
  id: string;
  license_number: string | null;
  verification_status: string;
  availability_status: string;
  current_route_id: string | null;
  vehicles: {
    make: string;
    model: string;
    registration_number: string;
    seating_capacity: number;
    vehicle_type: string;
  } | null;
}

interface TripSummary {
  id: string;
  status: string;
  created_at: string;
  routes: { from_location: string; to_location: string } | null;
}

export default function DriverProfileContent() {
  const { profile, signOut } = useAuth();
  const [driver, setDriver] = useState<DriverRecord | null>(null);
  const [trips, setTrips] = useState<TripSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const supabase = createClient();

  useEffect(() => {
    if (profile?.id) {
      loadDriverData();
    }
  }, [profile?.id]);

  const loadDriverData = async () => {
    if (!profile?.id) return;
    setLoading(true);
    try {
      const { data: driverData } = await supabase
        .from('drivers')
        .select(`
          id, license_number, verification_status, availability_status, current_route_id,
          vehicles:current_vehicle_id (make, model, registration_number, seating_capacity, vehicle_type)
        `)
        .eq('profile_id', profile.id)
        .maybeSingle();

      if (driverData) {
        setDriver(driverData as any);

        // Load trip history
        const { data: tripData } = await supabase
          .from('trips')
          .select(`id, status, created_at, routes (from_location, to_location)`)
          .eq('driver_id', driverData.id)
          .order('created_at', { ascending: false })
          .limit(5);

        if (tripData) setTrips(tripData as any);
      }
    } catch {
      // Silently handle
    } finally {
      setLoading(false);
    }
  };

  const handleSignOut = async () => {
    try {
      await signOut();
    } catch {
      toast.error('Sign out failed');
    }
  };

  const displayName = profile?.name || 'Driver';
  const initial = displayName.charAt(0).toUpperCase();

  const verificationBadge = (status: string) => {
    if (status === 'approved') return { label: 'Verified Driver', cls: 'status-active' };
    if (status === 'pending') return { label: 'Verification Pending', cls: 'status-waiting' };
    if (status === 'rejected') return { label: 'Verification Rejected', cls: 'status-cancelled' };
    if (status === 'suspended') return { label: 'Suspended', cls: 'status-cancelled' };
    return { label: 'Pending', cls: 'status-waiting' };
  };

  const badge = verificationBadge(driver?.verification_status || 'pending');

  return (
    <div className="flex flex-col gap-5">
      {/* Profile card */}
      <div className="card-base p-5">
        <div className="flex items-center gap-4 mb-5">
          <div className="w-16 h-16 rounded-2xl gradient-primary flex items-center justify-center text-white text-2xl font-bold">
            {initial}
          </div>
          <div className="flex-1 min-w-0">
            <p className="font-bold text-lg text-foreground truncate">{displayName}</p>
            <div className="flex items-center gap-2 mt-1">
              <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${badge.cls}`}>
                {badge.label}
              </span>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-3">
          <div className="flex items-center gap-3 p-3 bg-muted rounded-xl">
            <Phone size={14} className="text-muted-foreground shrink-0" />
            <div>
              <p className="text-xs text-muted-foreground">Mobile</p>
              <p className="text-sm font-semibold text-foreground">
                {profile?.phone ? `+91 ${profile.phone.replace('+91', '')}` : 'Not set'}
              </p>
            </div>
          </div>
          <div className="flex items-center gap-3 p-3 bg-muted rounded-xl">
            <Shield size={14} className="text-muted-foreground shrink-0" />
            <div>
              <p className="text-xs text-muted-foreground">License Number</p>
              <p className="text-sm font-semibold text-foreground">
                {driver?.license_number || 'Not provided'}
              </p>
            </div>
          </div>
          <div className="flex items-center gap-3 p-3 bg-muted rounded-xl">
            <User size={14} className="text-muted-foreground shrink-0" />
            <div>
              <p className="text-xs text-muted-foreground">Current Status</p>
              <p className="text-sm font-semibold text-foreground capitalize">
                {driver?.availability_status || 'Offline'}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Vehicle info */}
      {loading ? (
        <div className="card-base p-5">
          <div className="h-24 bg-muted rounded-xl animate-pulse" />
        </div>
      ) : driver?.vehicles ? (
        <div className="card-base p-5">
          <div className="flex items-center gap-2 mb-4">
            <Car size={16} className="text-primary" />
            <h3 className="font-semibold text-foreground">Assigned Vehicle</h3>
          </div>
          <div className="grid grid-cols-2 gap-3">
            {[
              { label: 'Vehicle', value: `${driver.vehicles.make} ${driver.vehicles.model}` },
              { label: 'Registration', value: driver.vehicles.registration_number },
              { label: 'Type', value: driver.vehicles.vehicle_type },
              { label: 'Capacity', value: `${driver.vehicles.seating_capacity} seats` },
            ].map((item) => (
              <div key={item.label} className="p-3 bg-muted rounded-xl">
                <p className="text-xs text-muted-foreground mb-0.5">{item.label}</p>
                <p className="text-sm font-bold text-foreground">{item.value}</p>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="card-base p-5">
          <div className="flex items-center gap-2 mb-2">
            <Car size={16} className="text-muted-foreground" />
            <h3 className="font-semibold text-foreground">Vehicle</h3>
          </div>
          <div className="flex items-center gap-2 p-3 bg-muted rounded-xl">
            <AlertCircle size={14} className="text-muted-foreground" />
            <p className="text-sm text-muted-foreground">No vehicle assigned yet. Contact Admin.</p>
          </div>
        </div>
      )}

      {/* Verification notice */}
      {driver?.verification_status !== 'approved' && (
        <div className="p-4 bg-accent/10 border border-accent/30 rounded-xl">
          <div className="flex items-start gap-2">
            <AlertCircle size={16} className="text-accent shrink-0 mt-0.5" />
            <div>
              <p className="text-sm font-semibold text-foreground">Verification Required</p>
              <p className="text-xs text-muted-foreground mt-0.5">
                Your account is pending Admin verification. You cannot go online until approved.
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Trip history */}
      <div className="card-base p-5">
        <div className="flex items-center gap-2 mb-4">
          <Clock size={16} className="text-primary" />
          <h3 className="font-semibold text-foreground">Trip History</h3>
        </div>
        {trips.length === 0 ? (
          <div className="flex flex-col items-center py-6 gap-2 text-center">
            <Clock size={28} className="text-muted-foreground/40" />
            <p className="text-sm text-muted-foreground">No trips completed yet</p>
          </div>
        ) : (
          <div className="flex flex-col gap-2">
            {trips.map((trip) => (
              <div key={trip.id} className="flex items-center justify-between p-3 bg-muted rounded-xl">
                <div>
                  <p className="text-sm font-semibold text-foreground">
                    {trip.routes?.from_location || '—'} → {trip.routes?.to_location || '—'}
                  </p>
                  <p className="text-xs text-muted-foreground">
                    {new Date(trip.created_at).toLocaleDateString('en-IN')}
                  </p>
                </div>
                <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${
                  trip.status === 'completed' ? 'status-active' :
                  trip.status === 'in_progress' ? 'status-confirmed' : 'status-waiting'
                }`}>
                  {trip.status}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Sign out */}
      <button
        onClick={handleSignOut}
        className="w-full flex items-center justify-center gap-2 py-3.5 rounded-xl border-2 border-danger/30 text-danger font-semibold text-sm hover:bg-danger/5 transition-colors"
      >
        <LogOut size={16} />
        Sign Out
      </button>
    </div>
  );
}

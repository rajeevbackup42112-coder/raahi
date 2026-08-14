'use client';
import React, { useState, useEffect } from 'react';
import PassengerHeader from '@/components/PassengerHeader';
import { useAuth } from '@/contexts/AuthContext';
import { createClient } from '@/lib/supabase/client';
import { Phone, Mail, Camera, BookOpen, AlertCircle, HelpCircle, FileText, Shield, Package, LogOut, ChevronRight, CheckCircle, Edit2, X } from 'lucide-react';
import { toast } from 'sonner';

interface Booking {
  id: string;
  booked_at: string;
  seats: number;
  total_fare: number;
  status: string;
  trips: {
    routes: {
      from_location: string;
      to_location: string;
    };
  } | null;
}

export default function PassengerProfilePage() {
  const { profile, signOut, refreshProfile } = useAuth();
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loadingBookings, setLoadingBookings] = useState(true);
  const [editingName, setEditingName] = useState(false);
  const [newName, setNewName] = useState('');
  const [savingName, setSavingName] = useState(false);
  const [editingPhone, setEditingPhone] = useState(false);
  const [newPhone, setNewPhone] = useState('');
  const [savingPhone, setSavingPhone] = useState(false);
  const [phoneError, setPhoneError] = useState('');
  const supabase = createClient();

  useEffect(() => {
    if (profile?.id) loadBookings();
  }, [profile?.id]);

  const loadBookings = async () => {
    if (!profile?.id) return;
    setLoadingBookings(true);
    try {
      const { data, error } = await supabase
        .from('bookings')
        .select(`id, booked_at, seats, total_fare, status, trips (routes (from_location, to_location))`)
        .eq('passenger_id', profile.id)
        .order('booked_at', { ascending: false })
        .limit(5);
      if (!error && data) setBookings(data as any);
    } catch { /* Silently handle */ }
    finally { setLoadingBookings(false); }
  };

  const handleSaveName = async () => {
    if (!newName.trim() || !profile?.id) return;
    setSavingName(true);
    try {
      const { error } = await supabase.from('profiles').update({ name: newName.trim() }).eq('id', profile.id);
      if (error) throw error;
      await refreshProfile();
      setEditingName(false);
      toast.success('Name updated successfully');
    } catch (err: any) {
      toast.error(err?.message || 'Failed to update name');
    } finally {
      setSavingName(false);
    }
  };

  const validatePhone = (phone: string): string => {
    const cleaned = phone.replace(/[^0-9]/g, '').replace(/^91/, '');
    if (cleaned.length !== 10) return 'Enter a 10-digit mobile number';
    if (!/^[6-9]/.test(cleaned)) return 'Number must start with 6, 7, 8, or 9';
    return '';
  };

  const handleSavePhone = async () => {
    if (!profile?.id) return;
    const err = validatePhone(newPhone);
    if (err) { setPhoneError(err); return; }
    setPhoneError('');
    setSavingPhone(true);
    try {
      const { data, error } = await supabase.rpc('update_passenger_phone', { p_phone: newPhone });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { setPhoneError(result?.error || 'Failed to save number'); return; }
      await refreshProfile();
      setEditingPhone(false);
      setNewPhone('');
      toast.success('Contact number saved');
    } catch (err: any) {
      setPhoneError(err?.message || 'Failed to save number');
    } finally {
      setSavingPhone(false);
    }
  };

  const displayName = profile?.name || 'User';
  const initial = displayName.charAt(0).toUpperCase();

  const menuItems = [
    { icon: HelpCircle, label: 'Help & Support', href: '#' },
    { icon: FileText, label: 'Terms & Conditions', href: '#' },
    { icon: Shield, label: 'Privacy Policy', href: '#' },
    { icon: Package, label: 'Luggage Policy', href: '#' },
  ];

  return (
    <div className="min-h-screen bg-background pb-20 sm:pb-0">
      <PassengerHeader />
      <main className="max-w-screen-md mx-auto px-4 sm:px-6 py-6 lg:py-8">
        {/* Profile header */}
        <div className="card-base p-6 mb-6">
          <div className="flex items-center gap-4">
            <div className="relative">
              <div className="w-20 h-20 rounded-2xl gradient-primary flex items-center justify-center text-white text-3xl font-bold">
                {profile?.avatar_url ? (
                  <img src={profile.avatar_url} alt={displayName} className="w-full h-full rounded-2xl object-cover" />
                ) : initial}
              </div>
              <button className="absolute -bottom-1 -right-1 w-7 h-7 bg-card border-2 border-background rounded-full flex items-center justify-center hover:bg-muted transition-colors" aria-label="Change photo">
                <Camera size={12} className="text-muted-foreground" />
              </button>
            </div>
            <div className="flex-1 min-w-0">
              {editingName ? (
                <div className="flex items-center gap-2">
                  <input
                    type="text"
                    className="input-field text-lg font-bold flex-1"
                    value={newName}
                    onChange={(e) => setNewName(e.target.value)}
                    autoFocus
                    onKeyDown={(e) => { if (e.key === 'Enter') handleSaveName(); if (e.key === 'Escape') setEditingName(false); }}
                  />
                  <button onClick={handleSaveName} disabled={savingName} className="btn-primary px-3 py-2 text-xs">{savingName ? '...' : 'Save'}</button>
                  <button onClick={() => setEditingName(false)} className="btn-secondary px-3 py-2 text-xs">Cancel</button>
                </div>
              ) : (
                <div className="flex items-center gap-2">
                  <h1 className="text-xl font-bold text-foreground truncate">{displayName}</h1>
                  <button onClick={() => { setNewName(displayName); setEditingName(true); }} className="text-xs text-primary hover:underline shrink-0">Edit</button>
                </div>
              )}
              <span className="inline-flex items-center gap-1 text-xs font-semibold px-2 py-0.5 rounded-full status-active mt-1">
                <CheckCircle size={10} />
                {profile?.status === 'active' ? 'Active' : profile?.status || 'Active'}
              </span>
            </div>
          </div>

          <div className="mt-5 grid grid-cols-1 gap-3">
            {/* Phone field */}
            <div className="flex items-start gap-3 p-3 bg-muted rounded-xl">
              <Phone size={16} className="text-muted-foreground shrink-0 mt-0.5" />
              <div className="flex-1 min-w-0">
                <p className="text-xs text-muted-foreground">Mobile</p>
                {editingPhone ? (
                  <div className="mt-1">
                    <div className="flex items-center gap-2">
                      <input
                        type="tel"
                        inputMode="numeric"
                        maxLength={10}
                        placeholder="10-digit mobile number"
                        className="input-field text-sm flex-1"
                        value={newPhone}
                        onChange={(e) => { setNewPhone(e.target.value.replace(/[^0-9]/g, '')); setPhoneError(''); }}
                        autoFocus
                        onKeyDown={(e) => { if (e.key === 'Enter') handleSavePhone(); if (e.key === 'Escape') { setEditingPhone(false); setPhoneError(''); } }}
                      />
                      <button onClick={handleSavePhone} disabled={savingPhone} className="btn-primary px-3 py-2 text-xs shrink-0">{savingPhone ? '...' : 'Save'}</button>
                      <button onClick={() => { setEditingPhone(false); setPhoneError(''); }} className="p-2 hover:bg-card rounded-lg transition-colors">
                        <X size={14} className="text-muted-foreground" />
                      </button>
                    </div>
                    {phoneError && <p className="text-xs text-danger mt-1">{phoneError}</p>}
                    <p className="text-xs text-muted-foreground mt-1">Indian mobile number (e.g. 9876543210). No OTP required.</p>
                  </div>
                ) : (
                  <div className="flex items-center justify-between">
                    <p className="text-sm font-semibold text-foreground truncate">
                      {profile?.phone ? `+91 ${profile.phone}` : (
                        <span className="text-warning font-semibold">Not set — required for booking</span>
                      )}
                    </p>
                    <button
                      onClick={() => { setNewPhone(profile?.phone || ''); setEditingPhone(true); setPhoneError(''); }}
                      className="flex items-center gap-1 text-xs text-primary hover:underline shrink-0 ml-2"
                    >
                      <Edit2 size={11} />
                      {profile?.phone ? 'Edit' : 'Add'}
                    </button>
                  </div>
                )}
              </div>
            </div>

            {/* Email field */}
            <div className="flex items-center gap-3 p-3 bg-muted rounded-xl">
              <Mail size={16} className="text-muted-foreground shrink-0" />
              <div className="min-w-0">
                <p className="text-xs text-muted-foreground">Email</p>
                <p className="text-sm font-semibold text-foreground truncate">{profile?.email || 'Not set'}</p>
              </div>
            </div>
          </div>

          {/* Phone required notice */}
          {!profile?.phone && (
            <div className="mt-3 flex items-start gap-2 p-3 bg-yellow-50 border border-yellow-200 rounded-xl">
              <AlertCircle size={14} className="text-warning shrink-0 mt-0.5" />
              <p className="text-xs text-warning font-medium">
                A contact number is required before you can book a ride. Add your mobile number above.
              </p>
            </div>
          )}
        </div>

        {/* My Bookings */}
        <div className="card-base p-5 mb-6">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <BookOpen size={16} className="text-primary" />
              <h2 className="font-semibold text-foreground">My Bookings</h2>
            </div>
          </div>
          {loadingBookings ? (
            <div className="flex flex-col gap-2">{[1, 2].map((i) => <div key={i} className="h-14 bg-muted rounded-xl animate-pulse" />)}</div>
          ) : bookings.length === 0 ? (
            <div className="flex flex-col items-center py-6 gap-2 text-center">
              <BookOpen size={32} className="text-muted-foreground/40" />
              <p className="text-sm text-muted-foreground">No bookings yet</p>
              <a href="/available-routes" className="text-xs text-primary font-semibold hover:underline">Book your first ride →</a>
            </div>
          ) : (
            <div className="flex flex-col gap-2">
              {bookings.map((booking) => (
                <div key={booking.id} className="flex items-center justify-between p-3 bg-muted rounded-xl">
                  <div className="min-w-0">
                    <p className="text-sm font-semibold text-foreground truncate">
                      {booking.trips?.routes?.from_location || '—'} → {booking.trips?.routes?.to_location || '—'}
                    </p>
                    <p className="text-xs text-muted-foreground">{booking.seats} seat{booking.seats > 1 ? 's' : ''} · ₹{booking.total_fare}</p>
                  </div>
                  <span className={`text-xs font-semibold px-2 py-0.5 rounded-full shrink-0 ${
                    booking.status === 'confirmed' ? 'status-confirmed' :
                    booking.status === 'completed' ? 'status-active' :
                    booking.status === 'cancelled' ? 'status-cancelled' : 'status-waiting'
                  }`}>{booking.status}</span>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Menu items */}
        <div className="card-base overflow-hidden mb-6">
          {menuItems.map((item, idx) => (
            <a key={item.label} href={item.href} className={`flex items-center justify-between px-5 py-4 hover:bg-muted transition-colors ${idx < menuItems.length - 1 ? 'border-b' : ''}`}>
              <div className="flex items-center gap-3">
                <item.icon size={16} className="text-muted-foreground" />
                <span className="text-sm font-medium text-foreground">{item.label}</span>
              </div>
              <ChevronRight size={16} className="text-muted-foreground" />
            </a>
          ))}
        </div>

        {/* Sign out */}
        <button
          onClick={async () => { try { await signOut(); } catch { toast.error('Sign out failed'); } }}
          className="w-full flex items-center justify-center gap-2 px-5 py-4 rounded-2xl border border-danger/30 text-danger hover:bg-red-50 transition-colors font-semibold"
        >
          <LogOut size={16} />
          Sign Out
        </button>
      </main>
    </div>
  );
}

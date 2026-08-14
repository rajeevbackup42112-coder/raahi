'use client';
import React, { useState, useEffect, useCallback } from 'react';
import { Save, RefreshCw } from 'lucide-react';
import { toast } from 'sonner';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';

interface Setting {
  id: string;
  key: string;
  value: string;
  description: string | null;
  updated_at: string;
}

const PRODUCTION_SETTING_KEYS = [
  'cancellation_fee_inr',
  'no_show_fee_inr',
  'grace_period_minutes',
  'max_seats_per_booking',
  'default_fare_inr',
  'luggage_policy',
  'driver_offer_timeout_seconds',
  'automatic_matching_enabled',
  'driver_decline_queue_behavior',
  'driver_timeout_queue_behavior',
  'departure_lock_seconds',
];

const BOOKING_PROTECTION_KEYS = [
  'booking_abuse_protection_enabled',
  'cancellation_limit_in_window',
  'cancellation_window_minutes',
  'booking_cooldown_minutes',
  'booking_action_rate_limit_enabled',
  'booking_action_limit',
  'booking_action_window_seconds',
];

const SETTING_LABELS: Record<string, { label: string; description: string; type: 'number' | 'text' | 'textarea' | 'select'; options?: string[] }> = {
  cancellation_fee_inr: { label: 'Cancellation Fee (₹)', description: 'Fee charged when a passenger cancels a confirmed booking', type: 'number' },
  no_show_fee_inr: { label: 'No-Show Fee (₹)', description: 'Fee charged when a passenger does not show up', type: 'number' },
  grace_period_minutes: { label: 'Grace Period (minutes)', description: 'Time allowed after booking before no-show is recorded', type: 'number' },
  max_seats_per_booking: { label: 'Max Seats per Booking', description: 'Maximum number of seats a single passenger can book', type: 'number' },
  default_fare_inr: { label: 'Default Fare (₹)', description: 'Default fare per seat used when no route-specific fare is set', type: 'number' },
  luggage_policy: { label: 'Luggage Policy', description: 'Displayed to passengers on the booking page', type: 'textarea' },
  driver_offer_timeout_seconds: { label: 'Driver Offer Timeout (seconds)', description: 'How long a driver has to accept or decline a ride offer', type: 'number' },
  automatic_matching_enabled: { label: 'Automatic FIFO Matching', description: 'When enabled, matching triggers automatically when conditions are met — no admin action required', type: 'select', options: ['true', 'false'] },
  driver_decline_queue_behavior: { label: 'Driver Decline Behavior', description: 'What happens when a driver declines an offer', type: 'select', options: ['MOVE_TO_END', 'REMOVE'] },
  driver_timeout_queue_behavior: { label: 'Driver Timeout Behavior', description: 'What happens when a driver offer expires', type: 'select', options: ['MOVE_TO_END', 'REMOVE'] },
  departure_lock_seconds: { label: 'Departure Lock Window (seconds)', description: 'Final boarding window after driver presses Leave Now. No new passengers are assigned during this period.', type: 'number' },
  // Booking protection
  booking_abuse_protection_enabled: { label: 'Repeated Cancellation Protection', description: 'Pause new bookings for passengers who cancel repeatedly within a short window', type: 'select', options: ['true', 'false'] },
  cancellation_limit_in_window: { label: 'Pause bookings after (cancellations)', description: 'Number of passenger-initiated cancellations within the window that triggers a booking pause', type: 'number' },
  cancellation_window_minutes: { label: 'Cancellation counting window (minutes)', description: 'Time window in which cancellations are counted toward the threshold', type: 'number' },
  booking_cooldown_minutes: { label: 'Pause new bookings for (minutes)', description: 'Duration of the booking pause after the cancellation threshold is reached', type: 'number' },
  booking_action_rate_limit_enabled: { label: 'Rapid-Action Protection', description: 'Prevent scripts or rapid repeated booking/cancellation calls from a single passenger', type: 'select', options: ['true', 'false'] },
  booking_action_limit: { label: 'Maximum booking/cancellation actions', description: 'Maximum number of booking or cancellation actions allowed within the rate-limit window', type: 'number' },
  booking_action_window_seconds: { label: 'Rate-limit window (seconds)', description: 'Time window for counting rapid booking/cancellation actions', type: 'number' },
};

export default function AdminSettingsContent() {
  const { profile } = useAuth();
  const supabase = createClient();
  const [settings, setSettings] = useState<Setting[]>([]);
  const [editValues, setEditValues] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState<string | null>(null);

  const loadSettings = useCallback(async () => {
    try {
      const { data, error } = await supabase.from('business_settings').select('*').order('key');
      if (error) throw error;
      const s = (data as Setting[]) || [];
      setSettings(s);
      const vals: Record<string, string> = {};
      s.forEach((item) => { vals[item.key] = item.value; });
      setEditValues(vals);
    } catch {
      toast.error('Failed to load settings');
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => { loadSettings(); }, [loadSettings]);

  const handleSave = async (key: string) => {
    if (!profile?.id) return;
    setSaving(key);
    try {
      const { data, error } = await supabase.rpc('admin_update_business_setting', {
        p_admin_id: profile.id,
        p_key: key,
        p_value: editValues[key],
      });
      if (error) throw error;
      const result = data as any;
      if (!result?.success) { toast.error(result?.error || 'Save failed'); return; }
      toast.success(`${SETTING_LABELS[key]?.label || key} updated`);
      await loadSettings();
    } catch (err: any) {
      toast.error(err?.message || 'Save failed');
    } finally {
      setSaving(null);
    }
  };

  const renderSettingRow = (key: string) => {
    const meta = SETTING_LABELS[key];
    if (!meta) return null;
    const currentValue = editValues[key] ?? '';
    const savedValue = settings.find((s) => s.key === key)?.value ?? '';
    const isDirty = currentValue !== savedValue;
    return (
      <div key={key} className="card-base p-5">
        <div className="flex items-start justify-between gap-4">
          <div className="flex-1">
            <label className="font-semibold text-foreground text-sm">{meta.label}</label>
            <p className="text-xs text-muted-foreground mt-0.5 mb-3">{meta.description}</p>
            {meta.type === 'textarea' ? (
              <textarea
                className="input-field resize-none"
                rows={3}
                value={currentValue}
                onChange={(e) => setEditValues({ ...editValues, [key]: e.target.value })}
              />
            ) : meta.type === 'select' ? (
              <select
                className="input-field max-w-xs"
                value={currentValue}
                onChange={(e) => setEditValues({ ...editValues, [key]: e.target.value })}
              >
                {meta.options?.map((opt) => (
                  <option key={opt} value={opt}>{opt}</option>
                ))}
              </select>
            ) : (
              <input
                type={meta.type}
                className="input-field max-w-xs"
                value={currentValue}
                onChange={(e) => setEditValues({ ...editValues, [key]: e.target.value })}
              />
            )}
          </div>
          <button
            onClick={() => handleSave(key)}
            disabled={saving === key || !isDirty}
            className={`btn-primary gap-2 shrink-0 mt-6 ${!isDirty ? 'opacity-40 cursor-not-allowed' : ''}`}
          >
            {saving === key ? <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" /> : <Save size={14} />}
            Save
          </button>
        </div>
        <p className="text-xs text-muted-foreground mt-2">
          Current value: <span className="font-mono font-semibold text-foreground">{savedValue || '—'}</span>
          {settings.find((s) => s.key === key)?.updated_at && (
            <span className="ml-2">· Updated {new Date(settings.find((s) => s.key === key)!.updated_at).toLocaleDateString()}</span>
          )}
        </p>
      </div>
    );
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8 xl:px-10 py-6 max-w-screen-xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Business Settings</h1>
          <p className="text-sm text-muted-foreground mt-0.5">Configure fees, policies, and operational parameters — all values read from database</p>
        </div>
        <button onClick={loadSettings} className="btn-secondary gap-2 px-3 py-2.5">
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
        </button>
      </div>

      {loading ? (
        <div className="flex flex-col gap-4">
          {[1, 2, 3, 4].map((i) => <div key={i} className="card-base p-5 h-20 animate-pulse bg-muted" />)}
        </div>
      ) : (
        <div className="flex flex-col gap-8">
          {/* Operational Settings */}
          <section>
            <h2 className="text-base font-bold text-foreground mb-3">Operational Settings</h2>
            <div className="flex flex-col gap-4">
              {PRODUCTION_SETTING_KEYS.map(renderSettingRow)}
            </div>
          </section>

          {/* Booking Protection */}
          <section>
            <div className="mb-3">
              <h2 className="text-base font-bold text-foreground">Booking Protection</h2>
              <p className="text-xs text-muted-foreground mt-0.5">
                Lightweight protection against repeated cancellation abuse and rapid automated actions.
                Only passenger-initiated cancellations count toward the threshold — admin, driver, and system cancellations are excluded.
              </p>
            </div>
            <div className="flex flex-col gap-4">
              {BOOKING_PROTECTION_KEYS.map(renderSettingRow)}
            </div>
          </section>

          {settings.length === 0 && (
            <div className="card-base p-10 text-center">
              <p className="text-muted-foreground">No settings found. Run the Stage 7 migration to initialize settings.</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

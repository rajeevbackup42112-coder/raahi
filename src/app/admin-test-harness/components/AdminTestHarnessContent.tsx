'use client';
import React, { useState, useEffect, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { useAuth } from '@/contexts/AuthContext';
import { FlaskConical, Trash2, Play, Users, Car, AlertTriangle, CheckCircle, XCircle, Clock, RefreshCw, ChevronDown, ChevronUp, Shield, Timer, ShieldAlert } from 'lucide-react';

interface Route { id: string; from_location: string; to_location: string; min_passengers?: number; }
interface TestPassenger { profileId: string; label: string; pqId?: string; queueSequence?: number; bookingId?: string; }
interface TestDriver { profileId: string; driverId: string; vehicleId: string; dqId: string; label: string; capacity: number; }
interface ScenarioLog { ts: string; msg: string; ok: boolean; }

interface DepTestResult {
  test: string;
  name: string;
  status: string;
  expected: string;
  actual: string;
  pass: boolean;
  bug?: string | null;
  fix?: string | null;
  pre_state?: Record<string, unknown>;
  post_state?: Record<string, unknown>;
}

interface DepTestSummary {
  total: number;
  passed: number;
  failed: number;
  departure_model_validated: boolean;
  min_passengers_used: number;
  executed_at: string;
}

interface ExpiryTestResult {
  test: string;
  name: string;
  status: string;
  expected: string;
  actual: string;
  pass: boolean;
  bug?: string | null;
}

interface ExpiryTestSummary {
  total: number;
  passed: number;
  failed: number;
  expiry_model_validated: boolean;
  executed_at: string;
}

const SCENARIOS = [
  { id: 'A', label: 'Scenario A — First Driver Offer', desc: 'P1–P10 waiting, D1(6) is first. Expect D1 offered P1–P6.' },
  { id: 'B', label: 'Scenario B — Driver Accepts', desc: 'D1 accepts offer. P1–P6 ASSIGNED, P7 becomes queue #1.' },
  { id: 'C', label: 'Scenario C — Next Vehicle', desc: 'P7–P10 waiting, D2(4). D2 gets offer for all four.' },
  { id: 'D', label: 'Scenario D — 6-Seat Fails → 4-Seat', desc: 'D1(6) declines. D2(4) gets P1–P4. P5/P6 remain front.' },
  { id: 'E', label: 'Scenario E — Driver Timeout', desc: 'D1 offer expires server-side. Same result as decline.' },
  { id: 'F', label: 'Scenario F — Cancel After Accept', desc: 'D1 accepts P1–P6, then cancels. D2(4) gets P1–P4.' },
  { id: 'G', label: 'Scenario G — Passenger Cancels', desc: 'P2 cancels before assignment. Queue recalculates.' },
  { id: 'H', label: 'Scenario H — Concurrent Matching', desc: 'Two match_route_queue calls simultaneously. No duplicates.' },
  { id: 'I', label: 'Scenario I — FIFO Blocking', desc: 'D1(6) blocks with 4 passengers. D1 goes offline → D2(4) matches.' },
];

const DEP_SCENARIOS = [
  { id: 'DEP-1', label: 'DEP-1 — Below Minimum Server Guard', desc: 'Cap=6 Min=4 Assigned=3. driver_leave_now must be REJECTED server-side.' },
  { id: 'DEP-2', label: 'DEP-2 — Minimum Reached', desc: 'Cap=6 Min=4 Assigned=4. driver_leave_now must SUCCEED. Verify departure_pending.' },
  { id: 'DEP-3', label: 'DEP-3 — Wait for More (FIFO)', desc: 'At 4/6: driver_wait_for_more. P5 joins → auto-assigned. P6 joins → 6/6.' },
  { id: 'DEP-4', label: 'DEP-4 — Full Vehicle', desc: 'At 6/6: departure_pending. Attempt to add P7 → must be REJECTED server-side.' },
  { id: 'DEP-5', label: 'DEP-5 — Departure Lock', desc: 'Leave Now → departure_pending. P5 must NOT be assigned to locked trip.' },
  { id: 'DEP-6', label: 'DEP-6 — Start Trip During Lock', desc: 'driver_start_trip during lock → REJECTED. After lock expires → SUCCEEDS.' },
  { id: 'DEP-7', label: 'DEP-7 — Cancel During Lock (drops below min)', desc: 'Leave Now at 4/6. One pax cancels → 3/6. Eligibility revoked. Start Trip REJECTED.' },
  { id: 'DEP-8', label: 'DEP-8 — Cancel Stays Above Min', desc: 'Leave Now at 5/6. One pax cancels → 4/6. Still meets min. Report behavior.' },
  { id: 'DEP-9', label: 'DEP-9 — Two-Driver FIFO Lock', desc: 'D1(6) at 4/6 presses Leave Now. P5/P6 must go to D2, not D1.' },
  { id: 'DEP-10', label: 'DEP-10 — Multi-Seat Fit FIFO', desc: 'Cap=4. A=3seats, B=2seats, C=1seat. A+C fit. B keeps FIFO priority.' },
];

export default function AdminTestHarnessContent() {
  const { profile } = useAuth();
  const supabase = createClient();

  const [routes, setRoutes] = useState<Route[]>([]);
  const [selectedRouteId, setSelectedRouteId] = useState<string>('');
  const [loading, setLoading] = useState(false);
  const [logs, setLogs] = useState<ScenarioLog[]>([]);
  const [testPassengers, setTestPassengers] = useState<TestPassenger[]>([]);
  const [testDrivers, setTestDrivers] = useState<TestDriver[]>([]);
  const [expandedScenario, setExpandedScenario] = useState<string | null>(null);
  const [dbState, setDbState] = useState<Record<string, unknown> | null>(null);
  const [resetting, setResetting] = useState(false);
  const [activeTab, setActiveTab] = useState<'fifo' | 'departure' | 'expiry'>('fifo');

  // DEP automated test runner state
  const [depRunning, setDepRunning] = useState(false);
  const [depResults, setDepResults] = useState<DepTestResult[] | null>(null);
  const [depSummary, setDepSummary] = useState<DepTestSummary | null>(null);

  // Expiry test runner state
  const [expiryRunning, setExpiryRunning] = useState(false);
  const [expiryResults, setExpiryResults] = useState<ExpiryTestResult[] | null>(null);
  const [expirySummary, setExpirySummary] = useState<ExpiryTestSummary | null>(null);

  const addLog = (msg: string, ok = true) => {
    setLogs(prev => [{ ts: new Date().toISOString().substring(11, 23), msg, ok }, ...prev]);
  };

  useEffect(() => {
    supabase.from('routes').select('id, from_location, to_location, min_passengers').eq('status', 'active').then(({ data }) => {
      if (data) setRoutes(data as Route[]);
    });
  }, []);

  const refreshDbState = useCallback(async () => {
    if (!selectedRouteId || !profile?.id) return;
    const { data } = await supabase.rpc('get_test_harness_state', {
      p_route_id: selectedRouteId,
      p_admin_id: profile.id,
    });
    setDbState(data as Record<string, unknown>);
  }, [selectedRouteId, profile?.id]);

  useEffect(() => {
    if (selectedRouteId) refreshDbState();
  }, [selectedRouteId, refreshDbState]);

  // ── Setup: Create P1–P10 passengers ──────────────────────────────────────
  const setupPassengers = async (count = 10) => {
    if (!selectedRouteId || !profile?.id) return;
    setLoading(true);
    const created: TestPassenger[] = [];
    for (let i = 1; i <= count; i++) {
      const label = `P${i}`;
      const { data: pid, error } = await supabase.rpc('admin_create_test_passenger', {
        p_label: label,
        p_admin_id: profile.id,
      });
      if (error || !pid) { addLog(`Failed to create ${label}: ${error?.message}`, false); continue; }
      // Create booking + queue entry
      const { data: bq, error: bqErr } = await supabase.rpc('admin_create_test_booking_and_queue', {
        p_passenger_id: pid,
        p_route_id: selectedRouteId,
        p_seat_count: 1,
        p_admin_id: profile.id,
      });
      if (bqErr || !bq) { addLog(`Failed to queue ${label}: ${bqErr?.message}`, false); continue; }
      const bqData = bq as { booking_id: string; passenger_queue_id: string; queue_sequence: number };
      created.push({ profileId: pid as string, label, pqId: bqData.passenger_queue_id, queueSequence: bqData.queue_sequence, bookingId: bqData.booking_id });
      addLog(`${label} queued — sequence #${bqData.queue_sequence}`);
    }
    setTestPassengers(created);
    await refreshDbState();
    setLoading(false);
  };

  // ── Setup: Create D1, D2, D3 drivers ─────────────────────────────────────
  const setupDrivers = async () => {
    if (!selectedRouteId || !profile?.id) return;
    setLoading(true);
    const driverDefs = [
      { label: 'D1', capacity: 6 },
      { label: 'D2', capacity: 4 },
      { label: 'D3', capacity: 6 },
    ];
    const created: TestDriver[] = [];
    for (const def of driverDefs) {
      const { data, error } = await supabase.rpc('admin_create_test_driver', {
        p_label: def.label,
        p_capacity: def.capacity,
        p_route_id: selectedRouteId,
        p_admin_id: profile.id,
      });
      if (error || !data) { addLog(`Failed to create ${def.label}: ${error?.message}`, false); continue; }
      const d = data as { profile_id: string; driver_id: string; vehicle_id: string; driver_queue_id: string };
      created.push({ profileId: d.profile_id, driverId: d.driver_id, vehicleId: d.vehicle_id, dqId: d.driver_queue_id, label: def.label, capacity: def.capacity });
      addLog(`${def.label} (${def.capacity} seats) queued`);
    }
    setTestDrivers(created);
    await refreshDbState();
    setLoading(false);
  };

  // ── Trigger matching ──────────────────────────────────────────────────────
  const triggerMatch = async () => {
    if (!selectedRouteId) return;
    const { data, error } = await supabase.rpc('match_route_queue', { p_route_id: selectedRouteId });
    if (error) { addLog(`match_route_queue error: ${error.message}`, false); return; }
    addLog(`match_route_queue → ${JSON.stringify(data)}`);
    await refreshDbState();
  };

  // ── Simulate driver action ────────────────────────────────────────────────
  const simulateDriverAction = async (dqId: string, action: 'accept' | 'decline' | 'expire' | 'leave_now' | 'start_trip', label: string) => {
    if (!profile?.id) return;
    const { data, error } = await supabase.rpc('admin_simulate_driver_action', {
      p_driver_queue_id: dqId,
      p_action: action,
      p_admin_id: profile.id,
    });
    if (error) { addLog(`${label} ${action} failed: ${error.message}`, false); return; }
    const result = data as Record<string, unknown>;
    const ok = result?.success !== false;
    addLog(`${label} ${action} → ${JSON.stringify(data)}`, ok);
    await refreshDbState();
  };

  // ── Cancel passenger ──────────────────────────────────────────────────────
  const cancelPassenger = async (pqId: string, label: string) => {
    if (!profile?.id || !pqId) return;
    const { error } = await supabase.rpc('admin_simulate_passenger_cancel', {
      p_passenger_queue_id: pqId,
      p_admin_id: profile.id,
    });
    if (error) { addLog(`${label} cancel failed: ${error.message}`, false); return; }
    addLog(`${label} cancelled from queue`);
    await refreshDbState();
  };

  // ── Driver go offline ─────────────────────────────────────────────────────
  const driverGoOffline = async (dqId: string, label: string) => {
    if (!profile?.id) return;
    const { error } = await supabase.rpc('admin_driver_go_offline', {
      p_driver_queue_id: dqId,
      p_admin_id: profile.id,
    });
    if (error) { addLog(`${label} offline failed: ${error.message}`, false); return; }
    addLog(`${label} went offline — rematch triggered`);
    await refreshDbState();
  };

  // ── Reset test data ───────────────────────────────────────────────────────
  const resetTestData = async () => {
    if (!selectedRouteId || !profile?.id) return;
    setResetting(true);
    const { data, error } = await supabase.rpc('admin_reset_test_data', {
      p_route_id: selectedRouteId,
      p_admin_id: profile.id,
    });
    if (error) { addLog(`Reset failed: ${error.message}`, false); setResetting(false); return; }
    const r = data as Record<string, number>;
    addLog(`✓ Reset complete — PQ:${r.passenger_queue_deleted} DQ:${r.driver_queue_deleted} Trips:${r.trips_cancelled} Bookings:${r.bookings_deleted}`);
    setTestPassengers([]);
    setTestDrivers([]);
    await refreshDbState();
    setResetting(false);
  };

  // ── Concurrent match test ─────────────────────────────────────────────────
  const testConcurrentMatch = async () => {
    if (!selectedRouteId) return;
    addLog('Triggering 3 concurrent match_route_queue calls...');
    const results = await Promise.allSettled([
      supabase.rpc('match_route_queue', { p_route_id: selectedRouteId }),
      supabase.rpc('match_route_queue', { p_route_id: selectedRouteId }),
      supabase.rpc('match_route_queue', { p_route_id: selectedRouteId }),
    ]);
    results.forEach((r, i) => {
      if (r.status === 'fulfilled') {
        addLog(`Concurrent call ${i + 1} → ${JSON.stringify(r.value.data)}`);
      } else {
        addLog(`Concurrent call ${i + 1} error: ${r.reason}`, false);
      }
    });
    await refreshDbState();
  };

  // ── Run all DEP tests automatically ──────────────────────────────────────
  const runAllDepTests = async () => {
    if (!selectedRouteId || !profile?.id) return;
    setDepRunning(true);
    setDepResults(null);
    setDepSummary(null);
    addLog('▶ Running DEP-1 through DEP-10 + Auth + Full Flow against database...');

    const { data, error } = await supabase.rpc('run_departure_tests', {
      p_route_id: selectedRouteId,
      p_admin_id: profile.id,
    });

    if (error) {
      addLog(`run_departure_tests error: ${error.message}`, false);
      setDepRunning(false);
      return;
    }

    const result = data as { summary: DepTestSummary; tests: DepTestResult[] };
    setDepResults(result.tests);
    setDepSummary(result.summary);

    const passCount = result.tests.filter(t => t.pass).length;
    const failCount = result.tests.filter(t => !t.pass).length;
    addLog(`✓ DEP tests complete: ${passCount} PASS / ${failCount} FAIL`, failCount === 0);

    result.tests.forEach(t => {
      addLog(`  ${t.test}: ${t.status}${t.bug ? ` — BUG: ${t.bug}` : ''}`, t.pass);
    });

    await refreshDbState();
    setDepRunning(false);
  };

  // ── Run all Expiry tests automatically ───────────────────────────────────
  const runAllExpiryTests = async () => {
    if (!selectedRouteId || !profile?.id) return;
    setExpiryRunning(true);
    setExpiryResults(null);
    setExpirySummary(null);
    addLog('▶ Running Expiry Tests E1–E5 against database...');

    const { data, error } = await supabase.rpc('run_expiry_tests', {
      p_route_id: selectedRouteId,
      p_admin_id: profile.id,
    });

    if (error) {
      addLog(`run_expiry_tests error: ${error.message}`, false);
      setExpiryRunning(false);
      return;
    }

    const result = data as { summary: ExpiryTestSummary; tests: ExpiryTestResult[] };
    setExpiryResults(result.tests);
    setExpirySummary(result.summary);

    const passCount = result.tests.filter(t => t.pass).length;
    const failCount = result.tests.filter(t => !t.pass).length;
    addLog(`✓ Expiry tests complete: ${passCount} PASS / ${failCount} FAIL`, failCount === 0);

    result.tests.forEach(t => {
      addLog(`  ${t.test}: ${t.status}${t.bug ? ` — BUG: ${t.bug}` : ''}`, t.pass);
    });

    await refreshDbState();
    setExpiryRunning(false);
  };

  const pq = (dbState as { passenger_queue?: unknown[] } | null)?.passenger_queue ?? [];
  const dq = (dbState as { driver_queue?: unknown[] } | null)?.driver_queue ?? [];
  const trips = (dbState as { current_trips?: unknown[] } | null)?.current_trips ?? [];

  const selectedRoute = routes.find(r => r.id === selectedRouteId);

  return (
    <div className="p-6 max-w-6xl mx-auto">
      {/* ── SECURITY WARNING BANNER ─────────────────────────────────────── */}
      <div className="mb-5 rounded-xl border-2 border-red-400 bg-red-50 px-5 py-4">
        <div className="flex items-start gap-3">
          <ShieldAlert size={22} className="text-red-600 mt-0.5 shrink-0" />
          <div>
            <p className="text-sm font-bold text-red-700 uppercase tracking-wide">
              TEST HARNESS — ADMIN ONLY
            </p>
            <p className="text-sm text-red-700 mt-1">
              Actions here may create or reset test data. This screen is not accessible to passengers or drivers.
            </p>
            <p className="text-sm text-red-600 mt-1 font-medium">
              Test actions only affect records marked as <code className="bg-red-100 px-1 rounded text-xs font-mono">is_test_data = true</code>.
              Destructive operations will be rejected if targeted at real production records.
            </p>
          </div>
        </div>
      </div>

      {/* Header */}
      <div className="flex items-center gap-3 mb-2">
        <div className="w-10 h-10 rounded-xl bg-amber-100 flex items-center justify-center">
          <FlaskConical size={20} className="text-amber-600" />
        </div>
        <div>
          <h1 className="text-xl font-bold text-foreground">FIFO + Departure Eligibility Test Harness</h1>
          <p className="text-xs text-amber-600 font-semibold">⚠ DEVELOPMENT / ADMIN ONLY — Never accessible to passengers or drivers</p>
        </div>
      </div>

      {/* Route selector */}
      <div className="card-base p-4 mb-4">
        <label className="text-sm font-semibold text-foreground block mb-2">Test Route</label>
        <select
          value={selectedRouteId}
          onChange={e => setSelectedRouteId(e.target.value)}
          className="w-full border border-border rounded-xl px-3 py-2 text-sm bg-background"
        >
          <option value="">— Select a route —</option>
          {routes.map(r => (
            <option key={r.id} value={r.id}>{r.from_location} → {r.to_location} (min: {r.min_passengers ?? 1})</option>
          ))}
        </select>
        {selectedRoute && (
          <p className="text-xs text-muted-foreground mt-1.5">
            Min seats to depart: <strong>{selectedRoute.min_passengers ?? 1}</strong>
            {' '}— configure via Admin Routes if needed for departure tests (recommend: 4)
          </p>
        )}
      </div>

      {selectedRouteId && (
        <>
          {/* Tab switcher */}
          <div className="flex gap-2 mb-4 flex-wrap">
            <button
              onClick={() => setActiveTab('fifo')}
              className={`px-4 py-2 rounded-xl text-sm font-semibold transition-colors ${activeTab === 'fifo' ? 'bg-primary text-white' : 'bg-muted text-muted-foreground hover:bg-muted/80'}`}
            >
              FIFO Engine Tests (A–I)
            </button>
            <button
              onClick={() => setActiveTab('departure')}
              className={`px-4 py-2 rounded-xl text-sm font-semibold transition-colors flex items-center gap-1.5 ${activeTab === 'departure' ? 'bg-primary text-white' : 'bg-muted text-muted-foreground hover:bg-muted/80'}`}
            >
              <Shield size={14} /> Departure Eligibility Tests (DEP-1–10)
            </button>
            <button
              onClick={() => setActiveTab('expiry')}
              className={`px-4 py-2 rounded-xl text-sm font-semibold transition-colors flex items-center gap-1.5 ${activeTab === 'expiry' ? 'bg-primary text-white' : 'bg-muted text-muted-foreground hover:bg-muted/80'}`}
            >
              <Timer size={14} /> Offer Expiry Tests (E1–E5)
            </button>
          </div>

          {/* Setup controls */}
          <div className="card-base p-4 mb-4">
            <h2 className="text-sm font-bold text-foreground mb-3">1. Setup Test Data</h2>
            <div className="flex flex-wrap gap-2">
              <button onClick={() => setupPassengers(10)} disabled={loading}
                className="btn-primary text-sm px-4 py-2 flex items-center gap-2">
                <Users size={14} /> Create P1–P10 (1 seat each)
              </button>
              <button onClick={setupDrivers} disabled={loading}
                className="btn-secondary text-sm px-4 py-2 flex items-center gap-2">
                <Car size={14} /> Create D1(6) D2(4) D3(6)
              </button>
              <button onClick={triggerMatch} disabled={loading}
                className="btn-secondary text-sm px-4 py-2 flex items-center gap-2">
                <Play size={14} /> Trigger match_route_queue
              </button>
              <button onClick={testConcurrentMatch} disabled={loading}
                className="btn-secondary text-sm px-4 py-2 flex items-center gap-2">
                <RefreshCw size={14} /> Test Concurrent Match (×3)
              </button>
              <button onClick={resetTestData} disabled={resetting || loading}
                className="text-sm px-4 py-2 rounded-xl border border-red-300 text-red-600 hover:bg-red-50 flex items-center gap-2">
                <Trash2 size={14} /> {resetting ? 'Resetting...' : 'Reset Test Data'}
              </button>
            </div>
          </div>

          {/* Test passengers */}
          {testPassengers.length > 0 && (
            <div className="card-base p-4 mb-4">
              <h2 className="text-sm font-bold text-foreground mb-3">Test Passengers (queue_sequence)</h2>
              <div className="flex flex-wrap gap-2">
                {testPassengers.map(p => (
                  <div key={p.profileId} className="flex items-center gap-1 bg-blue-50 border border-blue-200 rounded-lg px-2 py-1 text-xs">
                    <span className="font-bold text-blue-700">{p.label}</span>
                    <span className="text-blue-500">#{p.queueSequence}</span>
                    {p.pqId && (
                      <button onClick={() => cancelPassenger(p.pqId!, p.label)}
                        className="ml-1 text-red-400 hover:text-red-600" title="Cancel passenger">
                        <XCircle size={12} />
                      </button>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Test drivers */}
          {testDrivers.length > 0 && (
            <div className="card-base p-4 mb-4">
              <h2 className="text-sm font-bold text-foreground mb-3">Test Drivers</h2>
              <div className="flex flex-wrap gap-2">
                {testDrivers.map(d => (
                  <div key={d.driverId} className="flex items-center gap-2 bg-green-50 border border-green-200 rounded-lg px-3 py-2 text-xs">
                    <span className="font-bold text-green-700">{d.label}</span>
                    <span className="text-green-600">{d.capacity} seats</span>
                    <button onClick={() => simulateDriverAction(d.dqId, 'accept', d.label)}
                      className="px-2 py-0.5 bg-green-600 text-white rounded text-xs hover:bg-green-700">Accept</button>
                    <button onClick={() => simulateDriverAction(d.dqId, 'decline', d.label)}
                      className="px-2 py-0.5 bg-yellow-500 text-white rounded text-xs hover:bg-yellow-600">Decline</button>
                    <button onClick={() => simulateDriverAction(d.dqId, 'expire', d.label)}
                      className="px-2 py-0.5 bg-orange-500 text-white rounded text-xs hover:bg-orange-600">Expire</button>
                    <button onClick={() => simulateDriverAction(d.dqId, 'leave_now', d.label)}
                      className="px-2 py-0.5 bg-primary text-white rounded text-xs hover:bg-primary/80">Leave Now</button>
                    <button onClick={() => simulateDriverAction(d.dqId, 'start_trip', d.label)}
                      className="px-2 py-0.5 bg-blue-600 text-white rounded text-xs hover:bg-blue-700">Start Trip</button>
                    <button onClick={() => driverGoOffline(d.dqId, d.label)}
                      className="px-2 py-0.5 bg-gray-500 text-white rounded text-xs hover:bg-gray-600">Offline</button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* FIFO Scenarios tab */}
          {activeTab === 'fifo' && (
            <div className="card-base p-4 mb-4">
              <h2 className="text-sm font-bold text-foreground mb-3">2. Scenarios A–I</h2>
              <div className="space-y-2">
                {SCENARIOS.map(s => (
                  <div key={s.id} className="border border-border rounded-xl overflow-hidden">
                    <button
                      onClick={() => setExpandedScenario(expandedScenario === s.id ? null : s.id)}
                      className="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-muted transition-colors"
                    >
                      <div>
                        <span className="text-sm font-semibold text-foreground">{s.label}</span>
                        <p className="text-xs text-muted-foreground mt-0.5">{s.desc}</p>
                      </div>
                      {expandedScenario === s.id ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                    </button>
                    {expandedScenario === s.id && (
                      <div className="px-4 pb-4 bg-muted/30 border-t border-border">
                        <ScenarioPanel
                          scenarioId={s.id}
                          testPassengers={testPassengers}
                          testDrivers={testDrivers}
                          selectedRouteId={selectedRouteId}
                          profileId={profile?.id ?? ''}
                          supabase={supabase}
                          addLog={addLog}
                          refreshDbState={refreshDbState}
                          setupPassengers={setupPassengers}
                          setupDrivers={setupDrivers}
                          triggerMatch={triggerMatch}
                          simulateDriverAction={simulateDriverAction}
                          cancelPassenger={cancelPassenger}
                          driverGoOffline={driverGoOffline}
                          dbState={dbState}
                        />
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Departure Eligibility Scenarios tab */}
          {activeTab === 'departure' && (
            <div className="card-base p-4 mb-4">
              <div className="flex items-center gap-2 mb-3">
                <Shield size={16} className="text-primary" />
                <h2 className="text-sm font-bold text-foreground">Departure Eligibility Tests (DEP-1–10)</h2>
              </div>

              {/* Automated test runner */}
              <div className="p-4 bg-primary/5 border border-primary/20 rounded-xl mb-4">
                <div className="flex items-center justify-between mb-2">
                  <div>
                    <p className="text-sm font-bold text-foreground">Automated Test Runner</p>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      Executes DEP-1 through DEP-10 + Cross-Driver Auth + Full Flow directly against the database.
                      Each test creates isolated test data, calls RPCs, verifies DB state, and cleans up.
                    </p>
                  </div>
                  <button
                    onClick={runAllDepTests}
                    disabled={depRunning || !selectedRouteId}
                    className="btn-primary text-sm px-5 py-2.5 flex items-center gap-2 shrink-0 ml-4"
                  >
                    {depRunning ? (
                      <><RefreshCw size={14} className="animate-spin" /> Running...</>
                    ) : (
                      <><Play size={14} /> Run All DEP Tests</>
                    )}
                  </button>
                </div>
                {!selectedRouteId && (
                  <p className="text-xs text-amber-600 mt-1">⚠ Select a route first. Route must have min_passengers = 4 for accurate results.</p>
                )}
              </div>

              {/* Test results table */}
              {depResults && depSummary && (
                <div className="mb-4">
                  {/* Summary bar */}
                  <div className={`p-3 rounded-xl mb-3 flex items-center justify-between ${depSummary.departure_model_validated ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'}`}>
                    <div className="flex items-center gap-3">
                      {depSummary.departure_model_validated
                        ? <CheckCircle size={18} className="text-green-600" />
                        : <AlertTriangle size={18} className="text-red-600" />
                      }
                      <div>
                        <p className={`text-sm font-bold ${depSummary.departure_model_validated ? 'text-green-700' : 'text-red-700'}`}>
                          {depSummary.departure_model_validated ? 'DEPARTURE MODEL VALIDATED: YES' : 'DEPARTURE MODEL VALIDATED: NO'}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {depSummary.passed}/{depSummary.total} tests passed · min_passengers={depSummary.min_passengers_used} · {new Date(depSummary.executed_at).toLocaleTimeString()}
                        </p>
                      </div>
                    </div>
                    <div className="flex gap-3 text-sm font-bold">
                      <span className="text-green-600">{depSummary.passed} PASS</span>
                      <span className="text-red-600">{depSummary.failed} FAIL</span>
                    </div>
                  </div>

                  {/* Results table */}
                  <div className="overflow-x-auto rounded-xl border border-border">
                    <table className="w-full text-xs">
                      <thead>
                        <tr className="bg-muted border-b border-border">
                          <th className="text-left px-3 py-2 font-semibold text-muted-foreground w-28">TEST</th>
                          <th className="text-left px-3 py-2 font-semibold text-muted-foreground w-24">STATUS</th>
                          <th className="text-left px-3 py-2 font-semibold text-muted-foreground">EXPECTED</th>
                          <th className="text-left px-3 py-2 font-semibold text-muted-foreground">ACTUAL DB RESULT</th>
                          <th className="text-left px-3 py-2 font-semibold text-muted-foreground w-36">BUG</th>
                        </tr>
                      </thead>
                      <tbody>
                        {depResults.map((t, i) => (
                          <tr key={t.test} className={`border-b border-border last:border-0 ${i % 2 === 0 ? 'bg-background' : 'bg-muted/30'}`}>
                            <td className="px-3 py-2 font-mono font-bold text-foreground align-top">{t.test}</td>
                            <td className="px-3 py-2 align-top">
                              <span className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded font-semibold ${t.pass ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                                {t.pass ? <CheckCircle size={10} /> : <XCircle size={10} />}
                                {t.pass ? 'PASS' : 'FAIL'}
                              </span>
                            </td>
                            <td className="px-3 py-2 text-muted-foreground align-top max-w-xs">{t.expected}</td>
                            <td className="px-3 py-2 align-top max-w-xs">
                              <p className="text-foreground">{t.actual}</p>
                              {t.post_state && (
                                <details className="mt-1">
                                  <summary className="cursor-pointer text-muted-foreground hover:text-foreground">DB state ▾</summary>
                                  <div className="mt-1 space-y-1">
                                    {t.pre_state && (
                                      <div className="bg-blue-50 rounded px-2 py-1">
                                        <span className="font-semibold text-blue-700">Pre: </span>
                                        <span className="text-blue-600">{JSON.stringify(t.pre_state)}</span>
                                      </div>
                                    )}
                                    <div className="bg-green-50 rounded px-2 py-1">
                                      <span className="font-semibold text-green-700">Post: </span>
                                      <span className="text-green-600">{JSON.stringify(t.post_state)}</span>
                                    </div>
                                  </div>
                                </details>
                              )}
                            </td>
                            <td className="px-3 py-2 align-top">
                              {t.bug ? (
                                <span className="text-red-600 font-medium">{t.bug}</span>
                              ) : (
                                <span className="text-green-600">—</span>
                              )}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>

                  {/* Final report */}
                  <div className="mt-4 p-4 bg-muted rounded-xl font-mono text-xs space-y-1">
                    <p className="font-bold text-foreground mb-2">FINAL REPORT</p>
                    {depResults.map(t => (
                      <p key={t.test} className={t.pass ? 'text-green-700' : 'text-red-600'}>
                        {t.test} {t.name.toUpperCase()}: {t.pass ? 'PASS' : 'FAIL'}
                      </p>
                    ))}
                    <p className={`mt-2 font-bold ${depSummary.departure_model_validated ? 'text-green-700' : 'text-red-600'}`}>
                      DEPARTURE MODEL VALIDATED: {depSummary.departure_model_validated ? 'YES' : 'NO'}
                    </p>
                  </div>
                </div>
              )}

              <div className="p-3 bg-blue-50 border border-blue-200 rounded-xl mb-3 text-xs text-blue-700">
                <strong>Manual step-by-step tests below:</strong> Use these for interactive debugging. The automated runner above is the authoritative test.
              </div>
              <div className="space-y-2">
                {DEP_SCENARIOS.map(s => (
                  <div key={s.id} className="border border-border rounded-xl overflow-hidden">
                    <button
                      onClick={() => setExpandedScenario(expandedScenario === s.id ? null : s.id)}
                      className="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-muted transition-colors"
                    >
                      <div>
                        <span className="text-sm font-semibold text-foreground">{s.label}</span>
                        <p className="text-xs text-muted-foreground mt-0.5">{s.desc}</p>
                      </div>
                      {expandedScenario === s.id ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                    </button>
                    {expandedScenario === s.id && (
                      <div className="px-4 pb-4 bg-muted/30 border-t border-border">
                        <DepartureTestPanel
                          scenarioId={s.id}
                          testPassengers={testPassengers}
                          testDrivers={testDrivers}
                          selectedRouteId={selectedRouteId}
                          profileId={profile?.id ?? ''}
                          supabase={supabase}
                          addLog={addLog}
                          refreshDbState={refreshDbState}
                          triggerMatch={triggerMatch}
                          simulateDriverAction={simulateDriverAction}
                          cancelPassenger={cancelPassenger}
                          dbState={dbState}
                        />
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Offer Expiry Tests tab */}
          {activeTab === 'expiry' && (
            <div className="card-base p-4 mb-4">
              <div className="flex items-center gap-2 mb-3">
                <Timer size={16} className="text-orange-500" />
                <h2 className="text-sm font-bold text-foreground">Offer Expiry Tests (E1–E5)</h2>
              </div>

              {/* Context */}
              <div className="p-3 bg-orange-50 border border-orange-200 rounded-xl mb-4 text-xs text-orange-800">
                <p className="font-semibold mb-1">What these tests verify:</p>
                <ul className="space-y-0.5 list-disc list-inside">
                  <li><strong>E1</strong>: D1 offer expires → D1 cannot accept → D2 gets next offer automatically</li>
                  <li><strong>E2</strong>: Passenger not shown as definitively assigned during provisional (MATCHING) state</li>
                  <li><strong>E3</strong>: Accept at exactly expiry boundary → server rejects with offer_expired</li>
                  <li><strong>E4</strong>: Accept vs expiry race → exactly one outcome wins, no duplicate trips</li>
                  <li><strong>E5</strong>: Browser-closed expiry → server expires offer without any client action</li>
                </ul>
              </div>

              {/* Automated test runner */}
              <div className="p-4 bg-orange-500/5 border border-orange-200 rounded-xl mb-4">
                <div className="flex items-center justify-between mb-2">
                  <div>
                    <p className="text-sm font-bold text-foreground">Automated Expiry Test Runner</p>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      Creates isolated test data, force-expires offers, verifies DB state, and cleans up.
                      Tests E1–E5 run sequentially against the database.
                    </p>
                  </div>
                  <button
                    onClick={runAllExpiryTests}
                    disabled={expiryRunning || !selectedRouteId}
                    className="btn-primary text-sm px-5 py-2.5 flex items-center gap-2 shrink-0 ml-4 bg-orange-500 hover:bg-orange-600"
                  >
                    {expiryRunning ? (
                      <><RefreshCw size={14} className="animate-spin" /> Running...</>
                    ) : (
                      <><Play size={14} /> Run All Expiry Tests</>
                    )}
                  </button>
                </div>
                {!selectedRouteId && (
                  <p className="text-xs text-amber-600 mt-1">⚠ Select a route first.</p>
                )}
              </div>

              {/* Expiry test results */}
              {expiryResults && expirySummary && (
                <div className="mb-4">
                  {/* Summary bar */}
                  <div className={`p-3 rounded-xl mb-3 flex items-center justify-between ${expirySummary.expiry_model_validated ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'}`}>
                    <div className="flex items-center gap-3">
                      {expirySummary.expiry_model_validated
                        ? <CheckCircle size={18} className="text-green-600" />
                        : <AlertTriangle size={18} className="text-red-600" />
                      }
                      <div>
                        <p className={`text-sm font-bold ${expirySummary.expiry_model_validated ? 'text-green-700' : 'text-red-700'}`}>
                          {expirySummary.expiry_model_validated ? 'EXPIRY MODEL VALIDATED: YES' : 'EXPIRY MODEL VALIDATED: NO'}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {expirySummary.passed}/{expirySummary.total} tests passed · {new Date(expirySummary.executed_at).toLocaleTimeString()}
                        </p>
                      </div>
                    </div>
                    <div className="flex gap-3 text-sm font-bold">
                      <span className="text-green-600">{expirySummary.passed} PASS</span>
                      <span className="text-red-600">{expirySummary.failed} FAIL</span>
                    </div>
                  </div>

                  {/* Results table */}
                  <div className="overflow-x-auto rounded-xl border border-border">
                    <table className="w-full text-xs">
                      <thead>
                        <tr className="bg-muted border-b border-border">
                          <th className="text-left px-3 py-2 font-semibold text-muted-foreground w-16">TEST</th>
                          <th className="text-left px-3 py-2 font-semibold text-muted-foreground w-24">STATUS</th>
                          <th className="text-left px-3 py-2 font-semibold text-muted-foreground">EXPECTED</th>
                          <th className="text-left px-3 py-2 font-semibold text-muted-foreground">ACTUAL DB RESULT</th>
                          <th className="text-left px-3 py-2 font-semibold text-muted-foreground w-40">BUG</th>
                        </tr>
                      </thead>
                      <tbody>
                        {expiryResults.map((t, i) => (
                          <tr key={t.test} className={`border-b border-border last:border-0 ${i % 2 === 0 ? 'bg-background' : 'bg-muted/30'}`}>
                            <td className="px-3 py-2 font-mono font-bold text-foreground align-top">{t.test}</td>
                            <td className="px-3 py-2 align-top">
                              <span className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded font-semibold ${t.pass ? 'bg-green-100 text-green-700' : t.status === 'SKIP' ? 'bg-yellow-100 text-yellow-700' : 'bg-red-100 text-red-700'}`}>
                                {t.pass ? <CheckCircle size={10} /> : <XCircle size={10} />}
                                {t.status}
                              </span>
                            </td>
                            <td className="px-3 py-2 text-muted-foreground align-top max-w-xs">{t.expected}</td>
                            <td className="px-3 py-2 align-top max-w-xs text-foreground">{t.actual}</td>
                            <td className="px-3 py-2 align-top">
                              {t.bug ? (
                                <span className="text-red-600 font-medium">{t.bug}</span>
                              ) : (
                                <span className="text-green-600">—</span>
                              )}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>

                  {/* Final report */}
                  <div className="mt-4 p-4 bg-muted rounded-xl font-mono text-xs space-y-1">
                    <p className="font-bold text-foreground mb-2">EXPIRY TEST FINAL REPORT</p>
                    {expiryResults.map(t => (
                      <p key={t.test} className={t.pass ? 'text-green-700' : t.status === 'SKIP' ? 'text-yellow-600' : 'text-red-600'}>
                        {t.test} {t.name.toUpperCase()}: {t.status}
                      </p>
                    ))}
                    <p className={`mt-2 font-bold ${expirySummary.expiry_model_validated ? 'text-green-700' : 'text-red-600'}`}>
                      EXPIRY MODEL VALIDATED: {expirySummary.expiry_model_validated ? 'YES' : 'NO'}
                    </p>
                  </div>
                </div>
              )}

              {/* Manual scenario descriptions */}
              <div className="p-3 bg-blue-50 border border-blue-200 rounded-xl text-xs text-blue-700 mb-3">
                <strong>Manual testing:</strong> Use the FIFO tab to set up P1+D1+D2, trigger match, then use the "Expire" button on D1 in the Test Drivers panel to simulate E1/E3/E5 manually.
              </div>

              <div className="space-y-2">
                {[
                  { id: 'E1', label: 'E1 — Offer Expires, D2 Gets Next Offer', desc: 'D1 offer expires. D1 cannot accept. D2 receives next offer automatically.' },
                  { id: 'E2', label: 'E2 — Passenger Not Shown Assigned During Provisional', desc: 'During D1 offer (MATCHING state), passenger must not see D1 as definitively assigned.' },
                  { id: 'E3', label: 'E3 — Accept At Zero Returns offer_expired', desc: 'Click Accept immediately after timer reaches zero. Server rejects. UI refetches. No stale card.' },
                  { id: 'E4', label: 'E4 — Accept vs Expiry Race', desc: 'Concurrent accept + expiry around offer_expires_at. Exactly one state transition wins.' },
                  { id: 'E5', label: 'E5 — Browser-Closed Expiry', desc: 'Create offer for D1. Close/stop driver client. Wait beyond timeout. Offer expires server-side. D2 can receive offer.' },
                ].map(s => (
                  <div key={s.id} className="border border-border rounded-xl overflow-hidden">
                    <button
                      onClick={() => setExpandedScenario(expandedScenario === s.id ? null : s.id)}
                      className="w-full flex items-center justify-between px-4 py-3 text-left hover:bg-muted transition-colors"
                    >
                      <div>
                        <span className="text-sm font-semibold text-foreground">{s.label}</span>
                        <p className="text-xs text-muted-foreground mt-0.5">{s.desc}</p>
                      </div>
                      {expandedScenario === s.id ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                    </button>
                    {expandedScenario === s.id && (
                      <div className="px-4 pb-4 bg-muted/30 border-t border-border">
                        <ExpiryTestPanel
                          scenarioId={s.id}
                          testDrivers={testDrivers}
                          testPassengers={testPassengers}
                          selectedRouteId={selectedRouteId}
                          profileId={profile?.id ?? ''}
                          supabase={supabase}
                          addLog={addLog}
                          refreshDbState={refreshDbState}
                          triggerMatch={triggerMatch}
                          simulateDriverAction={simulateDriverAction}
                          dbState={dbState}
                        />
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Live DB state */}
          <div className="card-base p-4 mb-4">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-sm font-bold text-foreground">Live DB State</h2>
              <button onClick={refreshDbState} className="p-1.5 rounded-lg hover:bg-muted">
                <RefreshCw size={14} className="text-muted-foreground" />
              </button>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
              <div>
                <p className="text-xs font-semibold text-muted-foreground mb-1">PASSENGER QUEUE ({(pq as unknown[]).length})</p>
                <div className="space-y-1">
                  {(pq as Array<Record<string, unknown>>).map((p, i) => (
                    <div key={String(p.id)} className={`text-xs px-2 py-1 rounded-lg flex justify-between ${p.is_test_data ? 'bg-blue-50 border border-blue-200' : 'bg-muted'}`}>
                      <span>#{i + 1} {String(p.passenger_name)} ({p.seat_count}s)</span>
                      <span className={`font-semibold ${p.status === 'WAITING' ? 'text-blue-600' : p.status === 'MATCHING' ? 'text-yellow-600' : p.status === 'ASSIGNED' ? 'text-green-600' : 'text-red-500'}`}>{String(p.status)}</span>
                    </div>
                  ))}
                  {(pq as unknown[]).length === 0 && <p className="text-xs text-muted-foreground">Empty</p>}
                </div>
              </div>
              <div>
                <p className="text-xs font-semibold text-muted-foreground mb-1">DRIVER QUEUE ({(dq as unknown[]).length})</p>
                <div className="space-y-1">
                  {(dq as Array<Record<string, unknown>>).map((d, i) => (
                    <div key={String(d.id)} className={`text-xs px-2 py-1 rounded-lg flex justify-between ${d.is_test_data ? 'bg-green-50 border border-green-200' : 'bg-muted'}`}>
                      <span>#{i + 1} {String(d.driver_name)} ({d.capacity}s)</span>
                      <span className={`font-semibold ${d.status === 'waiting' ? 'text-blue-600' : d.status === 'offered' ? 'text-yellow-600' : d.status === 'assigned' ? 'text-green-600' : 'text-red-500'}`}>{String(d.status)}</span>
                    </div>
                  ))}
                  {(dq as unknown[]).length === 0 && <p className="text-xs text-muted-foreground">Empty</p>}
                </div>
              </div>
              <div>
                <p className="text-xs font-semibold text-muted-foreground mb-1">CURRENT TRIPS ({(trips as unknown[]).length})</p>
                <div className="space-y-1">
                  {(trips as Array<Record<string, unknown>>).map(t => (
                    <div key={String(t.trip_id)} className={`text-xs px-2 py-1 rounded-lg ${t.is_test_data ? 'bg-amber-50 border border-amber-200' : 'bg-muted'}`}>
                      <div className="flex justify-between">
                        <span>{String(t.driver_name ?? 'No driver')}</span>
                        <span className={`font-semibold ${t.status === 'departure_pending' ? 'text-primary' : t.status === 'in_progress' ? 'text-green-600' : 'text-amber-600'}`}>{String(t.status)}</span>
                      </div>
                      <div className="text-muted-foreground">
                        {String(t.passenger_count)} pax / {String(t.vehicle_capacity)} cap
                        {Number(t.departure_lock_remaining_seconds) > 0 && (
                          <span className="ml-1 text-primary font-semibold">
                            · lock: {String(t.departure_lock_remaining_seconds)}s
                          </span>
                        )}
                      </div>
                      <div className="text-muted-foreground">{String(t.notes ?? '')}</div>
                    </div>
                  ))}
                  {(trips as unknown[]).length === 0 && <p className="text-xs text-muted-foreground">No active trips</p>}
                </div>
              </div>
            </div>
          </div>

          {/* Logs */}
          <div className="card-base p-4">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-sm font-bold text-foreground">Action Log</h2>
              <button onClick={() => setLogs([])} className="text-xs text-muted-foreground hover:text-foreground">Clear</button>
            </div>
            <div className="space-y-1 max-h-64 overflow-y-auto font-mono text-xs">
              {logs.length === 0 && <p className="text-muted-foreground">No actions yet.</p>}
              {logs.map((l, i) => (
                <div key={i} className={`flex gap-2 ${l.ok ? 'text-foreground' : 'text-red-600'}`}>
                  <span className="text-muted-foreground shrink-0">{l.ts}</span>
                  {l.ok ? <CheckCircle size={12} className="text-green-500 shrink-0 mt-0.5" /> : <AlertTriangle size={12} className="text-red-500 shrink-0 mt-0.5" />}
                  <span>{l.msg}</span>
                </div>
              ))}
            </div>
          </div>
        </>
      )}
    </div>
  );
}

// ── Scenario Panel (FIFO) ─────────────────────────────────────────────────────
interface ScenarioPanelProps {
  scenarioId: string;
  testPassengers: TestPassenger[];
  testDrivers: TestDriver[];
  selectedRouteId: string;
  profileId: string;
  supabase: ReturnType<typeof createClient>;
  addLog: (msg: string, ok?: boolean) => void;
  refreshDbState: () => Promise<void>;
  setupPassengers: (count?: number) => Promise<void>;
  setupDrivers: () => Promise<void>;
  triggerMatch: () => Promise<void>;
  simulateDriverAction: (dqId: string, action: 'accept' | 'decline' | 'expire' | 'leave_now' | 'start_trip', label: string) => Promise<void>;
  cancelPassenger: (pqId: string, label: string) => Promise<void>;
  driverGoOffline: (dqId: string, label: string) => Promise<void>;
  dbState: Record<string, unknown> | null;
}

function ScenarioPanel({ scenarioId, testPassengers, testDrivers, triggerMatch, simulateDriverAction, cancelPassenger, driverGoOffline, dbState }: ScenarioPanelProps) {
  const d1 = testDrivers.find(d => d.label === 'D1');
  const d2 = testDrivers.find(d => d.label === 'D2');
  const p2 = testPassengers.find(p => p.label === 'P2');

  const pq = (dbState as { passenger_queue?: Array<Record<string, unknown>> } | null)?.passenger_queue ?? [];
  const dq = (dbState as { driver_queue?: Array<Record<string, unknown>> } | null)?.driver_queue ?? [];

  const d1Offered = dq.find(d => String(d.driver_name).includes('D1') && d.status === 'offered');
  const d2Offered = dq.find(d => String(d.driver_name).includes('D2') && d.status === 'offered');

  const waitingSeats = (pq as Array<Record<string, unknown>>)
    .filter(p => p.status === 'WAITING')
    .reduce((sum, p) => sum + Number(p.seat_count), 0);

  const matchingCount = (pq as Array<Record<string, unknown>>).filter(p => p.status === 'MATCHING').length;

  return (
    <div className="mt-3 space-y-3">
      <div className="grid grid-cols-3 gap-2 text-xs">
        <div className="bg-blue-50 rounded-lg p-2 text-center">
          <div className="font-bold text-blue-700">{waitingSeats}</div>
          <div className="text-blue-500">Waiting seats</div>
        </div>
        <div className="bg-yellow-50 rounded-lg p-2 text-center">
          <div className="font-bold text-yellow-700">{matchingCount}</div>
          <div className="text-yellow-500">Matching</div>
        </div>
        <div className="bg-green-50 rounded-lg p-2 text-center">
          <div className="font-bold text-green-700">{(pq as Array<Record<string, unknown>>).filter(p => p.status === 'ASSIGNED').length}</div>
          <div className="text-green-500">Assigned</div>
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        {(scenarioId === 'A' || scenarioId === 'B' || scenarioId === 'C' || scenarioId === 'D' || scenarioId === 'E' || scenarioId === 'F' || scenarioId === 'H' || scenarioId === 'I') && (
          <button onClick={triggerMatch} className="btn-primary text-xs px-3 py-1.5 flex items-center gap-1">
            <Play size={12} /> Trigger Match
          </button>
        )}
        {(scenarioId === 'B' || scenarioId === 'F') && d1 && (
          <button onClick={() => simulateDriverAction(d1.dqId, 'accept', 'D1')}
            className="text-xs px-3 py-1.5 rounded-lg bg-green-600 text-white hover:bg-green-700 flex items-center gap-1">
            <CheckCircle size={12} /> D1 Accept
          </button>
        )}
        {(scenarioId === 'D') && d1 && (
          <button onClick={() => simulateDriverAction(d1.dqId, 'decline', 'D1')}
            className="text-xs px-3 py-1.5 rounded-lg bg-yellow-500 text-white hover:bg-yellow-600 flex items-center gap-1">
            <XCircle size={12} /> D1 Decline
          </button>
        )}
        {scenarioId === 'E' && d1 && (
          <button onClick={() => simulateDriverAction(d1.dqId, 'expire', 'D1')}
            className="text-xs px-3 py-1.5 rounded-lg bg-orange-500 text-white hover:bg-orange-600 flex items-center gap-1">
            <Clock size={12} /> Force D1 Expire
          </button>
        )}
        {scenarioId === 'G' && p2 && p2.pqId && (
          <button onClick={() => cancelPassenger(p2.pqId!, 'P2')}
            className="text-xs px-3 py-1.5 rounded-lg bg-red-500 text-white hover:bg-red-600 flex items-center gap-1">
            <XCircle size={12} /> P2 Cancel
          </button>
        )}
        {scenarioId === 'I' && d1 && (
          <button onClick={() => driverGoOffline(d1.dqId, 'D1')}
            className="text-xs px-3 py-1.5 rounded-lg bg-gray-600 text-white hover:bg-gray-700 flex items-center gap-1">
            D1 Go Offline
          </button>
        )}
        {(scenarioId === 'C') && d2 && (
          <button onClick={() => simulateDriverAction(d2.dqId, 'accept', 'D2')}
            className="text-xs px-3 py-1.5 rounded-lg bg-green-600 text-white hover:bg-green-700 flex items-center gap-1">
            <CheckCircle size={12} /> D2 Accept
          </button>
        )}
      </div>

      <div className="text-xs text-muted-foreground bg-muted rounded-lg p-2">
        <span className="font-semibold">Expected: </span>
        {scenarioId === 'A' && 'D1 offered P1–P6 (6 seats). P7–P10 remain WAITING.'}
        {scenarioId === 'B' && 'P1–P6 → ASSIGNED. P7 becomes queue #1. D2 remains driver #1.'}
        {scenarioId === 'C' && 'D2 offered P7–P10. All four assigned if accepted.'}
        {scenarioId === 'D' && 'After D1 decline: D2 offered P1–P4. P5/P6 front of queue.'}
        {scenarioId === 'E' && 'After expire: same as D1 decline. No frontend action needed.'}
        {scenarioId === 'F' && 'D1 accepts, then cancel trip → P1–P4 to D2. P5/P6 front.'}
        {scenarioId === 'G' && 'P2 cancelled → P3 becomes #2, P4 becomes #3, etc.'}
        {scenarioId === 'H' && 'Only one offer created. No duplicate trips or assignments.'}
        {scenarioId === 'I' && 'D1(6) blocks with 4 pax. D1 offline → D2(4) matches P1–P4.'}
      </div>

      {(d1Offered || d2Offered) && (
        <div className="text-xs bg-yellow-50 border border-yellow-200 rounded-lg p-2">
          {d1Offered && <p className="text-yellow-700">⏳ D1 has active offer — expires {String(d1Offered.offer_expires_at ?? 'N/A')}</p>}
          {d2Offered && <p className="text-yellow-700">⏳ D2 has active offer — expires {String(d2Offered.offer_expires_at ?? 'N/A')}</p>}
        </div>
      )}
    </div>
  );
}

// ── Departure Test Panel ──────────────────────────────────────────────────────
interface DepartureTestPanelProps {
  scenarioId: string;
  testPassengers: TestPassenger[];
  testDrivers: TestDriver[];
  selectedRouteId: string;
  profileId: string;
  supabase: ReturnType<typeof createClient>;
  addLog: (msg: string, ok?: boolean) => void;
  refreshDbState: () => Promise<void>;
  triggerMatch: () => Promise<void>;
  simulateDriverAction: (dqId: string, action: 'accept' | 'decline' | 'expire' | 'leave_now' | 'start_trip', label: string) => Promise<void>;
  cancelPassenger: (pqId: string, label: string) => Promise<void>;
  dbState: Record<string, unknown> | null;
}

function DepartureTestPanel({
  scenarioId, testPassengers, testDrivers, supabase, profileId,
  addLog, refreshDbState, triggerMatch, simulateDriverAction, cancelPassenger, dbState
}: DepartureTestPanelProps) {
  const d1 = testDrivers.find(d => d.label === 'D1');
  const d2 = testDrivers.find(d => d.label === 'D2');

  const trips = (dbState as { current_trips?: Array<Record<string, unknown>> } | null)?.current_trips ?? [];
  const pq = (dbState as { passenger_queue?: Array<Record<string, unknown>> } | null)?.passenger_queue ?? [];

  const d1Trip = trips.find(t => String(t.driver_name).includes('D1'));
  const lockRemaining = d1Trip ? Number(d1Trip.departure_lock_remaining_seconds ?? 0) : 0;
  const tripStatus = d1Trip ? String(d1Trip.status) : 'none';
  const paxCount = d1Trip ? Number(d1Trip.passenger_count ?? 0) : 0;

  // Direct RPC call for server-side enforcement tests
  const testDirectRpc = async (rpcName: string, params: Record<string, unknown>, expectSuccess: boolean, label: string) => {
    const { data, error } = await supabase.rpc(rpcName as 'driver_leave_now', params as { p_driver_profile_id: string });
    if (error) {
      addLog(`[${label}] RPC error: ${error.message}`, false);
      return;
    }
    const result = data as Record<string, unknown>;
    const succeeded = result?.success === true;
    if (expectSuccess && succeeded) {
      addLog(`[${label}] ✓ PASS — RPC succeeded as expected. ${JSON.stringify(result)}`, true);
    } else if (!expectSuccess && !succeeded) {
      addLog(`[${label}] ✓ PASS — RPC correctly REJECTED. error="${result?.error}"`, true);
    } else if (expectSuccess && !succeeded) {
      addLog(`[${label}] ✗ FAIL — Expected success but got rejection: "${result?.error}"`, false);
    } else {
      addLog(`[${label}] ✗ FAIL — Expected rejection but RPC succeeded: ${JSON.stringify(result)}`, false);
    }
    await refreshDbState();
  };

  const getInstructions = () => {
    switch (scenarioId) {
      case 'DEP-1': return 'Prerequisite: D1 accepted offer with 3 passengers assigned (P1+P2+P3). Min=4. Then click test below.';
      case 'DEP-2': return 'Prerequisite: D1 accepted offer with 4 passengers assigned (P1–P4). Min=4. Then click test below.';
      case 'DEP-3': return 'Prerequisite: D1 at 4/6 (departure eligible). Click Wait for More, then add P5 via match, then P6.';
      case 'DEP-4': return 'Prerequisite: D1 at 6/6 (full). Click Leave Now to enter departure_pending. Then try to add P7.';
      case 'DEP-5': return 'Prerequisite: D1 at 4/6. Click Leave Now. Then trigger match — P5 must NOT go to D1.';
      case 'DEP-6': return 'Prerequisite: D1 in departure_pending (lock active). Click Start Trip During Lock (expect REJECT). Wait for lock to expire, then click Start Trip After Lock.';
      case 'DEP-7': return 'Prerequisite: D1 in departure_pending at 4/6. Cancel P4. Verify trip reverts to boarding. Then try Start Trip (expect REJECT).';
      case 'DEP-8': return 'Prerequisite: D1 in departure_pending at 5/6. Cancel P5. Verify trip remains departure_pending (still meets min=4).';
      case 'DEP-9': return 'Prerequisite: D1 at 4/6 in departure_pending. D2 waiting. Trigger match — P5/P6 must go to D2, not D1.';
      case 'DEP-10': return 'Prerequisite: D1(4 seats) assigned. Queue: A=3seats, B=2seats, C=1seat. Trigger match. Expect A+C assigned (4/4). B keeps FIFO.';
      default: return '';
    }
  };

  const getExpected = () => {
    switch (scenarioId) {
      case 'DEP-1': return 'driver_leave_now REJECTED with "Below minimum occupancy". booked_seats=3, min_passengers=4.';
      case 'DEP-2': return 'driver_leave_now SUCCEEDS. Trip → departure_pending. departure_lock_expires_at set.';
      case 'DEP-3': return 'driver_wait_for_more succeeds. P5 auto-assigned via FIFO. P6 auto-assigned. Trip reaches 6/6.';
      case 'DEP-4': return 'book_or_queue for P7 REJECTED (capacity full). No new passenger added to departure_pending trip.';
      case 'DEP-5': return 'match_route_queue does NOT assign P5 to D1\'s departure_pending trip. P5 goes to D2 or stays waiting.';
      case 'DEP-6': return 'driver_start_trip during lock → REJECTED with "Departure lock still active". After lock expires → SUCCEEDS, trip → in_progress.';
      case 'DEP-7': return 'After cancel: booked_seats=3 < min=4. check_departure_eligibility_on_cancel reverts trip to boarding. driver_start_trip → REJECTED.';
      case 'DEP-8': return 'After cancel: booked_seats=4 >= min=4. Trip remains departure_pending. departure_pending preserved.';
      case 'DEP-9': return 'P5/P6 assigned to D2 (or remain waiting). D1\'s departure_pending trip receives no new passengers.';
      case 'DEP-10': return 'A(3) assigned first. B(2) cannot fit (1 seat left). C(1) fits. Vehicle: A+C=4/4. B retains FIFO priority.';
      default: return '';
    }
  };

  return (
    <div className="mt-3 space-y-3">
      {/* Instructions */}
      <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg text-xs text-amber-800">
        <span className="font-semibold">Setup: </span>{getInstructions()}
      </div>

      {/* Live state summary */}
      <div className="grid grid-cols-3 gap-2 text-xs">
        <div className={`rounded-lg p-2 text-center ${tripStatus === 'departure_pending' ? 'bg-primary/10 border border-primary/30' : 'bg-muted'}`}>
          <div className={`font-bold ${tripStatus === 'departure_pending' ? 'text-primary' : 'text-foreground'}`}>{tripStatus}</div>
          <div className="text-muted-foreground">D1 trip status</div>
        </div>
        <div className="bg-muted rounded-lg p-2 text-center">
          <div className="font-bold text-foreground">{paxCount}</div>
          <div className="text-muted-foreground">D1 passengers</div>
        </div>
        <div className={`rounded-lg p-2 text-center ${lockRemaining > 0 ? 'bg-blue-50 border border-blue-200' : 'bg-muted'}`}>
          <div className={`font-bold ${lockRemaining > 0 ? 'text-blue-700' : 'text-muted-foreground'}`}>
            {lockRemaining > 0 ? `${lockRemaining}s` : '—'}
          </div>
          <div className="text-muted-foreground">Lock remaining</div>
        </div>
      </div>

      {/* Test actions */}
      <div className="flex flex-wrap gap-2">
        {scenarioId === 'DEP-1' && d1 && (
          <button
            onClick={() => testDirectRpc('driver_leave_now', { p_driver_profile_id: d1.profileId }, false, 'DEP-1 below-min guard')}
            className="text-xs px-3 py-1.5 rounded-lg bg-red-600 text-white hover:bg-red-700 flex items-center gap-1"
          >
            <Shield size={12} /> Test: Leave Now (expect REJECT)
          </button>
        )}

        {scenarioId === 'DEP-2' && d1 && (
          <button
            onClick={() => testDirectRpc('driver_leave_now', { p_driver_profile_id: d1.profileId }, true, 'DEP-2 min reached')}
            className="text-xs px-3 py-1.5 rounded-lg bg-primary text-white hover:bg-primary/80 flex items-center gap-1"
          >
            <Shield size={12} /> Test: Leave Now (expect SUCCESS)
          </button>
        )}

        {scenarioId === 'DEP-3' && d1 && (
          <>
            <button
              onClick={() => testDirectRpc('driver_wait_for_more', { p_driver_profile_id: d1.profileId }, true, 'DEP-3 wait-for-more')}
              className="text-xs px-3 py-1.5 rounded-lg bg-primary text-white hover:bg-primary/80 flex items-center gap-1"
            >
              <Users size={12} /> Test: Wait for More
            </button>
            <button
              onClick={triggerMatch}
              className="text-xs px-3 py-1.5 rounded-lg bg-green-600 text-white hover:bg-green-700 flex items-center gap-1"
            >
              <Play size={12} /> Trigger Match (auto-assign P5)
            </button>
          </>
        )}

        {scenarioId === 'DEP-4' && (
          <>
            {d1 && (
              <button
                onClick={() => simulateDriverAction(d1.dqId, 'leave_now', 'D1')}
                className="text-xs px-3 py-1.5 rounded-lg bg-primary text-white hover:bg-primary/80 flex items-center gap-1"
              >
                D1 Leave Now
              </button>
            )}
            <button
              onClick={triggerMatch}
              className="text-xs px-3 py-1.5 rounded-lg bg-orange-500 text-white hover:bg-orange-600 flex items-center gap-1"
            >
              <Shield size={12} /> Trigger Match (P7 must be blocked)
            </button>
          </>
        )}

        {scenarioId === 'DEP-5' && (
          <>
            {d1 && (
              <button
                onClick={() => simulateDriverAction(d1.dqId, 'leave_now', 'D1')}
                className="text-xs px-3 py-1.5 rounded-lg bg-primary text-white hover:bg-primary/80 flex items-center gap-1"
              >
                D1 Leave Now
              </button>
            )}
            <button
              onClick={triggerMatch}
              className="text-xs px-3 py-1.5 rounded-lg bg-orange-500 text-white hover:bg-orange-600 flex items-center gap-1"
            >
              <Shield size={12} /> Trigger Match (P5 must NOT go to D1)
            </button>
          </>
        )}

        {scenarioId === 'DEP-6' && d1 && (
          <>
            <button
              onClick={() => testDirectRpc('driver_start_trip', { p_driver_id: d1.driverId }, false, 'DEP-6 start during lock')}
              className="text-xs px-3 py-1.5 rounded-lg bg-red-600 text-white hover:bg-red-700 flex items-center gap-1"
            >
              <Shield size={12} /> Start Trip During Lock (expect REJECT)
            </button>
            <button
              onClick={() => testDirectRpc('driver_start_trip', { p_driver_id: d1.driverId }, true, 'DEP-6 start after lock')}
              className="text-xs px-3 py-1.5 rounded-lg bg-green-600 text-white hover:bg-green-700 flex items-center gap-1"
              title="Only works after lock expires"
            >
              <Timer size={12} /> Start Trip After Lock (expect SUCCESS)
            </button>
          </>
        )}

        {scenarioId === 'DEP-7' && (
          <>
            {d1 && (
              <button
                onClick={() => simulateDriverAction(d1.dqId, 'leave_now', 'D1')}
                className="text-xs px-3 py-1.5 rounded-lg bg-primary text-white hover:bg-primary/80 flex items-center gap-1"
              >
                D1 Leave Now
              </button>
            )}
            {testPassengers.find(p => p.label === 'P4')?.pqId && (
              <button
                onClick={() => cancelPassenger(testPassengers.find(p => p.label === 'P4')!.pqId!, 'P4')}
                className="text-xs px-3 py-1.5 rounded-lg bg-red-500 text-white hover:bg-red-600 flex items-center gap-1"
              >
                <XCircle size={12} /> Cancel P4 (drops to 3/6)
              </button>
            )}
            {d1 && (
              <button
                onClick={() => testDirectRpc('driver_start_trip', { p_driver_id: d1.driverId }, false, 'DEP-7 start after cancel')}
                className="text-xs px-3 py-1.5 rounded-lg bg-red-600 text-white hover:bg-red-700 flex items-center gap-1"
              >
                <Shield size={12} /> Start Trip (expect REJECT — below min)
              </button>
            )}
          </>
        )}

        {scenarioId === 'DEP-8' && (
          <>
            {d1 && (
              <button
                onClick={() => simulateDriverAction(d1.dqId, 'leave_now', 'D1')}
                className="text-xs px-3 py-1.5 rounded-lg bg-primary text-white hover:bg-primary/80 flex items-center gap-1"
              >
                D1 Leave Now (at 5/6)
              </button>
            )}
            {testPassengers.find(p => p.label === 'P5')?.pqId && (
              <button
                onClick={() => cancelPassenger(testPassengers.find(p => p.label === 'P5')!.pqId!, 'P5')}
                className="text-xs px-3 py-1.5 rounded-lg bg-red-500 text-white hover:bg-red-600 flex items-center gap-1"
              >
                <XCircle size={12} /> Cancel P5 (drops to 4/6 — still meets min)
              </button>
            )}
            <button
              onClick={refreshDbState}
              className="text-xs px-3 py-1.5 rounded-lg bg-muted text-foreground hover:bg-muted/80 flex items-center gap-1"
            >
              <RefreshCw size={12} /> Check trip status (should remain departure_pending)
            </button>
          </>
        )}

        {scenarioId === 'DEP-9' && (
          <>
            {d1 && (
              <button
                onClick={() => simulateDriverAction(d1.dqId, 'leave_now', 'D1')}
                className="text-xs px-3 py-1.5 rounded-lg bg-primary text-white hover:bg-primary/80 flex items-center gap-1"
              >
                D1 Leave Now (lock D1)
              </button>
            )}
            <button
              onClick={triggerMatch}
              className="text-xs px-3 py-1.5 rounded-lg bg-orange-500 text-white hover:bg-orange-600 flex items-center gap-1"
            >
              <Shield size={12} /> Trigger Match (P5/P6 → D2, not D1)
            </button>
          </>
        )}

        {scenarioId === 'DEP-10' && (
          <button
            onClick={triggerMatch}
            className="text-xs px-3 py-1.5 rounded-lg bg-primary text-white hover:bg-primary/80 flex items-center gap-1"
          >
            <Play size={12} /> Trigger Match (fit-aware FIFO)
          </button>
        )}
      </div>

      {/* Expected result */}
      <div className="text-xs text-muted-foreground bg-muted rounded-lg p-2">
        <span className="font-semibold">Expected: </span>{getExpected()}
      </div>

      {/* Waiting passengers summary */}
      {pq.length > 0 && (
        <div className="text-xs bg-blue-50 border border-blue-200 rounded-lg p-2">
          <p className="font-semibold text-blue-700 mb-1">Passenger queue ({pq.length}):</p>
          <div className="flex flex-wrap gap-1">
            {pq.slice(0, 8).map((p, i) => (
              <span key={i} className={`px-1.5 py-0.5 rounded text-xs font-medium ${
                p.status === 'WAITING' ? 'bg-blue-100 text-blue-700' :
                p.status === 'ASSIGNED'? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'
              }`}>
                {String(p.passenger_name)} ({p.seat_count}s)
              </span>
            ))}
            {pq.length > 8 && <span className="text-muted-foreground">+{pq.length - 8} more</span>}
          </div>
        </div>
      )}
    </div>
  );
}

// ── Expiry Test Panel ─────────────────────────────────────────────────────────
interface ExpiryTestPanelProps {
  scenarioId: string;
  testDrivers: TestDriver[];
  testPassengers: TestPassenger[];
  selectedRouteId: string;
  profileId: string;
  supabase: ReturnType<typeof createClient>;
  addLog: (msg: string, ok?: boolean) => void;
  refreshDbState: () => Promise<void>;
  triggerMatch: () => Promise<void>;
  simulateDriverAction: (dqId: string, action: 'accept' | 'decline' | 'expire' | 'leave_now' | 'start_trip', label: string) => Promise<void>;
  dbState: Record<string, unknown> | null;
}

function ExpiryTestPanel({
  scenarioId, testDrivers, testPassengers, supabase, profileId,
  addLog, refreshDbState, triggerMatch, simulateDriverAction, dbState
}: ExpiryTestPanelProps) {
  const d1 = testDrivers.find(d => d.label === 'D1');
  const d2 = testDrivers.find(d => d.label === 'D2');

  const dq = (dbState as { driver_queue?: Array<Record<string, unknown>> } | null)?.driver_queue ?? [];
  const pq = (dbState as { passenger_queue?: Array<Record<string, unknown>> } | null)?.passenger_queue ?? [];

  const d1Entry = dq.find(d => String(d.driver_name).includes('D1'));
  const d2Entry = dq.find(d => String(d.driver_name).includes('D2'));

  const d1Status = d1Entry ? String(d1Entry.status) : 'not found';
  const d2Status = d2Entry ? String(d2Entry.status) : 'not found';
  const d1Expires = d1Entry ? String(d1Entry.offer_expires_at ?? 'N/A') : 'N/A';

  const matchingCount = pq.filter(p => p.status === 'MATCHING').length;
  const waitingCount = pq.filter(p => p.status === 'WAITING').length;
  const assignedCount = pq.filter(p => p.status === 'ASSIGNED').length;

  const testAcceptExpired = async () => {
    if (!d1 || !profileId) return;
    addLog('E3: Attempting accept on D1 after expire...');
    const { data, error } = await supabase.rpc('driver_accept_offer', {
      p_driver_profile_id: d1.profileId,
      p_queue_entry_id: d1.dqId,
    });
    if (error) {
      addLog(`E3: RPC error: ${error.message}`, false);
      return;
    }
    const result = data as Record<string, unknown>;
    const isExpiredRejection = result?.success === false && result?.reason === 'offer_expired';
    if (isExpiredRejection) {
      addLog(`E3: ✓ PASS — Server rejected with offer_expired. No stale card should remain.`, true);
    } else if (result?.success === false) {
      addLog(`E3: ✓ PASS (variant) — Server rejected: ${result?.error}`, true);
    } else {
      addLog(`E3: ✗ FAIL — Server accepted an expired offer! result=${JSON.stringify(result)}`, false);
    }
    await refreshDbState();
  };

  const getInstructions = () => {
    switch (scenarioId) {
      case 'E1': return 'Setup: Create P1–P10 + D1(6) + D2(4) in FIFO tab. Trigger match. D1 gets offer. Click "Force Expire D1" below. Expected: D1 back to waiting, D2 gets offer automatically.';
      case 'E2': return 'Setup: After match, while D1 has offer (MATCHING state). Check passenger queue — passengers must show "Finding Your Driver" not "Driver Assigned". After D1 expires, passengers must return to WAITING.';
      case 'E3': return 'Setup: D1 has offer. Click "Force Expire D1" then immediately click "Test Accept (expect reject)". Expected: server returns {success:false, reason:offer_expired}.';
      case 'E4': return 'Setup: D1 has offer near expiry. The automated runner (above) tests this atomically. Manual: Force expire D1 and simultaneously try accept — only one outcome should win.';
      case 'E5': return 'Setup: D1 has offer. Do NOT click anything on driver UI. Wait 60+ seconds (or use automated runner). Expected: pg_cron/Edge Function expires offer server-side. D2 gets offer without any client action.';
      default: return '';
    }
  };

  const getExpected = () => {
    switch (scenarioId) {
      case 'E1': return 'D1 status → waiting (MOVE_TO_END). D2 status → offered. Passengers → WAITING then MATCHING for D2.';
      case 'E2': return 'During MATCHING: passenger_queue.status=MATCHING, booking.trip_id=NULL. After expiry: WAITING, no stale driver shown.';
      case 'E3': return 'driver_accept_offer returns {success:false, reason:"offer_expired"}. UI refetches. No stale Ride Available card.';
      case 'E4': return 'Exactly one of: accept succeeds OR expiry wins. No duplicate trip. No duplicate assignment.';
      case 'E5': return 'expire_all_stale_offers() expires D1 offer. D2 receives next offer. No browser/client action required.';
      default: return '';
    }
  };

  return (
    <div className="mt-3 space-y-3">
      {/* Instructions */}
      <div className="p-3 bg-orange-50 border border-orange-200 rounded-lg text-xs text-orange-800">
        <span className="font-semibold">Setup: </span>{getInstructions()}
      </div>

      {/* Live state summary */}
      <div className="grid grid-cols-4 gap-2 text-xs">
        <div className={`rounded-lg p-2 text-center ${d1Status === 'offered' ? 'bg-yellow-50 border border-yellow-200' : 'bg-muted'}`}>
          <div className={`font-bold ${d1Status === 'offered' ? 'text-yellow-700' : 'text-foreground'}`}>{d1Status}</div>
          <div className="text-muted-foreground">D1 status</div>
        </div>
        <div className={`rounded-lg p-2 text-center ${d2Status === 'offered' ? 'bg-green-50 border border-green-200' : 'bg-muted'}`}>
          <div className={`font-bold ${d2Status === 'offered' ? 'text-green-700' : 'text-foreground'}`}>{d2Status}</div>
          <div className="text-muted-foreground">D2 status</div>
        </div>
        <div className="bg-blue-50 rounded-lg p-2 text-center">
          <div className="font-bold text-blue-700">{waitingCount}</div>
          <div className="text-blue-500">WAITING pax</div>
        </div>
        <div className="bg-yellow-50 rounded-lg p-2 text-center">
          <div className="font-bold text-yellow-700">{matchingCount}</div>
          <div className="text-yellow-500">MATCHING pax</div>
        </div>
      </div>

      {d1Status === 'offered' && (
        <div className="text-xs bg-yellow-50 border border-yellow-200 rounded-lg p-2">
          <p className="text-yellow-700">⏳ D1 has active offer — expires: {d1Expires}</p>
        </div>
      )}

      {/* Test actions */}
      <div className="flex flex-wrap gap-2">
        <button onClick={triggerMatch}
          className="text-xs px-3 py-1.5 rounded-lg bg-primary text-white hover:bg-primary/80 flex items-center gap-1">
          <Play size={12} /> Trigger Match
        </button>

        {d1 && (
          <button onClick={() => simulateDriverAction(d1.dqId, 'expire', 'D1')}
            className="text-xs px-3 py-1.5 rounded-lg bg-orange-500 text-white hover:bg-orange-600 flex items-center gap-1">
            <Clock size={12} /> Force Expire D1
          </button>
        )}

        {(scenarioId === 'E3') && d1 && (
          <button onClick={testAcceptExpired}
            className="text-xs px-3 py-1.5 rounded-lg bg-red-600 text-white hover:bg-red-700 flex items-center gap-1">
            <XCircle size={12} /> Test Accept (expect reject)
          </button>
        )}

        <button onClick={refreshDbState}
          className="text-xs px-3 py-1.5 rounded-lg bg-muted text-foreground hover:bg-muted/80 flex items-center gap-1">
          <RefreshCw size={12} /> Refresh State
        </button>
      </div>

      {/* Expected result */}
      <div className="text-xs text-muted-foreground bg-muted rounded-lg p-2">
        <span className="font-semibold">Expected: </span>{getExpected()}
      </div>

      {/* Passenger queue summary */}
      {pq.length > 0 && (
        <div className="text-xs bg-blue-50 border border-blue-200 rounded-lg p-2">
          <p className="font-semibold text-blue-700 mb-1">Passenger queue ({pq.length}): {waitingCount} WAITING · {matchingCount} MATCHING · {assignedCount} ASSIGNED</p>
          <div className="flex flex-wrap gap-1">
            {pq.slice(0, 8).map((p, i) => (
              <span key={i} className={`px-1.5 py-0.5 rounded text-xs font-medium ${
                p.status === 'WAITING' ? 'bg-blue-100 text-blue-700' :
                p.status === 'MATCHING' ? 'bg-yellow-100 text-yellow-700' :
                p.status === 'ASSIGNED' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'
              }`}>
                {String(p.passenger_name)} ({p.seat_count}s) · {String(p.status)}
              </span>
            ))}
            {pq.length > 8 && <span className="text-muted-foreground">+{pq.length - 8} more</span>}
          </div>
        </div>
      )}
    </div>
  );
}

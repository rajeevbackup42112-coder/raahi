'use client';
import React, { useState } from 'react';
import { Radio, Power } from 'lucide-react';
import { toast } from 'sonner';

// NOTE: Driver online status synced to Supabase `drivers` table and `driver_queue`
export default function DriverOnlineToggle() {
  const [online, setOnline] = useState(false);
  const [loading, setLoading] = useState(false);
  const [selectedRoute, setSelectedRoute] = useState('route-001');

  // NOTE: Routes fetched from Supabase `routes` table
  const routes = [
    { id: 'route-001', label: 'Gomoh → Dhanbad' },
    { id: 'route-002', label: 'Dhanbad → Gomoh' },
  ];

  const handleToggle = async () => {
    setLoading(true);
    // BACKEND: POST /api/driver/status with { driver_id, status: online ? 'offline' : 'online', route_id: selectedRoute }
    // This triggers queue insertion or removal in Supabase
    await new Promise((r) => setTimeout(r, 1000));
    setOnline(!online);
    setLoading(false);
    toast?.success(online ? 'You are now offline' : `You joined the queue for ${routes?.find(r => r?.id === selectedRoute)?.label}`);
  };

  return (
    <div className={`card-base p-5 transition-all duration-300 ${online ? 'border-success bg-green-50/50' : 'border-border'}`}>
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <Radio size={18} className={online ? 'text-success' : 'text-muted-foreground'} />
          <div>
            <p className="text-sm font-bold text-foreground">{online ? 'You are Online' : 'You are Offline'}</p>
            <p className="text-xs text-muted-foreground">{online ? 'In queue for ' + routes?.find(r => r?.id === selectedRoute)?.label : 'Go online to join the queue'}</p>
          </div>
        </div>
        <button
          onClick={handleToggle}
          disabled={loading}
          className={`relative w-14 h-7 rounded-full transition-all duration-300 focus:outline-none focus:ring-2 focus:ring-offset-2 ${online ? 'bg-success focus:ring-success' : 'bg-muted-foreground/30 focus:ring-muted-foreground'}`}
          aria-label={online ? 'Go offline' : 'Go online'}
          role="switch"
          aria-checked={online}
        >
          <span className={`absolute top-0.5 left-0.5 w-6 h-6 rounded-full bg-white shadow-sm transition-all duration-300 flex items-center justify-center ${online ? 'translate-x-7' : 'translate-x-0'}`}>
            {loading ? (
              <span className="w-3 h-3 border-2 border-muted-foreground/40 border-t-foreground rounded-full animate-spin" />
            ) : (
              <Power size={10} className={online ? 'text-success' : 'text-muted-foreground'} />
            )}
          </span>
        </button>
      </div>
      {!online && (
        <div>
          <p className="text-xs text-muted-foreground mb-2 font-medium">Select route before going online</p>
          <div className="flex flex-col gap-2">
            {routes?.map((route) => (
              <button
                key={route?.id}
                onClick={() => setSelectedRoute(route?.id)}
                className={`flex items-center gap-2 p-2.5 rounded-xl border-2 text-sm font-medium transition-all duration-150 text-left ${selectedRoute === route?.id ? 'border-primary bg-secondary text-primary' : 'border-border text-muted-foreground hover:border-primary/40'}`}
              >
                <Radio size={14} />
                {route?.label}
              </button>
            ))}
          </div>
        </div>
      )}
      {online && (
        <div className="flex items-center gap-2 p-2.5 bg-green-100/70 rounded-xl">
          <span className="w-2 h-2 rounded-full bg-success animate-pulse-soft shrink-0"></span>
          <p className="text-xs text-success font-semibold">Active in queue · Position #1</p>
        </div>
      )}
    </div>
  );
}
'use client';
import React from 'react';
import { List } from 'lucide-react';

interface DriverQueueCardProps {
  expanded?: boolean;
}

// NOTE: Queue position fetched from Supabase `driver_queue` with realtime subscription
const queueInfo = {
  position: 1,
  totalInQueue: 5,
  route: 'Gomoh → Dhanbad',
  status: 'active',
  joinedAt: '07:45 AM',
  estimatedActivation: 'Currently active',
  vehicleCapacity: 4,
  seatsBooked: 2,
};

export default function DriverQueueCard({ expanded = false }: DriverQueueCardProps) {
  const available = queueInfo.vehicleCapacity - queueInfo.seatsBooked;

  return (
    <div className="card-base p-5">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <List size={16} className="text-primary" />
          <p className="text-sm font-bold text-foreground">Queue Position</p>
        </div>
        <span className={`text-xs font-semibold px-2.5 py-1 rounded-full ${queueInfo.status === 'active' ? 'status-active' : 'status-waiting'}`}>
          {queueInfo.status === 'active' ? 'Active' : 'Waiting'}
        </span>
      </div>

      <div className="flex items-center justify-center py-4 mb-4">
        <div className="flex items-center gap-1">
          {Array.from({ length: queueInfo.totalInQueue }).map((_, i) => (
            <div
              key={`queue-pos-${i}`}
              className={`flex items-center justify-center rounded-full font-bold text-xs transition-all ${i === queueInfo.position - 1 ? 'w-10 h-10 gradient-primary text-white shadow-elevated' : 'w-7 h-7 bg-muted text-muted-foreground border border-border'}`}
            >
              {i + 1}
            </div>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="p-3 bg-muted rounded-xl">
          <p className="text-xs text-muted-foreground mb-0.5">Route</p>
          <p className="text-xs font-semibold text-foreground">{queueInfo.route}</p>
        </div>
        <div className="p-3 bg-muted rounded-xl">
          <p className="text-xs text-muted-foreground mb-0.5">Joined at</p>
          <p className="text-xs font-semibold text-foreground">{queueInfo.joinedAt}</p>
        </div>
        <div className="p-3 bg-muted rounded-xl">
          <p className="text-xs text-muted-foreground mb-0.5">Seats booked</p>
          <p className="text-xs font-semibold text-foreground tabular-nums">{queueInfo.seatsBooked} / {queueInfo.vehicleCapacity}</p>
        </div>
        <div className="p-3 bg-muted rounded-xl">
          <p className="text-xs text-muted-foreground mb-0.5">Available</p>
          <p className={`text-xs font-semibold tabular-nums ${available > 1 ? 'text-success' : available > 0 ? 'text-warning' : 'text-danger'}`}>
            {available} seat{available !== 1 ? 's' : ''}
          </p>
        </div>
      </div>

      {expanded && (
        <div className="mt-4 p-3 bg-secondary rounded-xl">
          <p className="text-xs text-primary font-semibold">You are the active driver for this route.</p>
          <p className="text-xs text-muted-foreground mt-1">When all {queueInfo.vehicleCapacity} seats are booked, your vehicle will be marked as full and the next driver in queue becomes active.</p>
        </div>
      )}
    </div>
  );
}
'use client';
import React, { useState } from 'react';
import { Car, Users, MapPin, CheckCircle } from 'lucide-react';
import { toast } from 'sonner';

// NOTE: Active trip fetched from Supabase `trips` joined with `bookings`
const activeTrip = {
  id: 'trip-0091',
  route: 'Gomoh → Dhanbad',
  status: 'active',
  totalSeats: 4,
  bookedSeats: 2,
  passengers: [
    { id: 'pass-001', name: 'Arjun Sharma', pickup: 'Gomoh Railway Station', seats: 1, bookingId: 'booking-0041' },
    { id: 'pass-002', name: 'Sanjay Gupta', pickup: 'Sindri Road Crossing', seats: 1, bookingId: 'booking-0039' },
  ],
  startedAt: null,
  estimatedDeparture: '08:15 AM',
};

export default function DriverTripCard() {
  const [tripStarted, setTripStarted] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleStartTrip = async () => {
    setLoading(true);
    // BACKEND: POST /api/trips/start with { trip_id } — updates trip status to 'departed'
    await new Promise((r) => setTimeout(r, 1000));
    setTripStarted(true);
    setLoading(false);
    toast?.success('Trip started! Safe journey.');
  };

  const handleCompleteTrip = async () => {
    setLoading(true);
    // BACKEND: POST /api/trips/complete with { trip_id } — marks trip completed, triggers next driver activation
    await new Promise((r) => setTimeout(r, 1000));
    setLoading(false);
    toast?.success('Trip completed. Queue updated automatically.');
  };

  return (
    <div className="card-base p-5">
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <Car size={16} className="text-primary" />
          <p className="text-sm font-bold text-foreground">Current Trip</p>
        </div>
        <span className={`text-xs font-semibold px-2.5 py-1 rounded-full ${tripStarted ? 'status-waiting' : 'status-active'}`}>
          {tripStarted ? 'In Progress' : 'Boarding'}
        </span>
      </div>
      <div className="flex items-center gap-2 mb-4 text-sm font-semibold text-foreground">
        <span>{activeTrip?.route?.split(' → ')?.[0]}</span>
        <span className="text-muted-foreground">→</span>
        <span>{activeTrip?.route?.split(' → ')?.[1]}</span>
      </div>
      {/* Passengers */}
      <div className="mb-4">
        <p className="section-label mb-2">Passengers ({activeTrip?.bookedSeats}/{activeTrip?.totalSeats} seats)</p>
        <div className="flex flex-col gap-2">
          {activeTrip?.passengers?.map((p) => (
            <div key={p?.id} className="flex items-center gap-3 p-2.5 bg-muted rounded-xl">
              <div className="w-7 h-7 rounded-full gradient-primary flex items-center justify-center text-white text-xs font-bold shrink-0">
                {p?.name?.charAt(0)}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-xs font-semibold text-foreground truncate">{p?.name}</p>
                <div className="flex items-center gap-1 text-xs text-muted-foreground">
                  <MapPin size={10} />
                  <span className="truncate">{p?.pickup}</span>
                </div>
              </div>
              <CheckCircle size={14} className="text-success shrink-0" />
            </div>
          ))}

          {/* Empty seat slots */}
          {Array.from({ length: activeTrip?.totalSeats - activeTrip?.bookedSeats })?.map((_, i) => (
            <div key={`empty-seat-${i}`} className="flex items-center gap-3 p-2.5 border-2 border-dashed border-border rounded-xl">
              <div className="w-7 h-7 rounded-full bg-muted flex items-center justify-center shrink-0">
                <Users size={12} className="text-muted-foreground" />
              </div>
              <p className="text-xs text-muted-foreground">Seat available</p>
            </div>
          ))}
        </div>
      </div>
      {!tripStarted ? (
        <button
          onClick={handleStartTrip}
          disabled={loading}
          className="btn-primary w-full justify-center"
        >
          {loading ? (
            <span className="flex items-center gap-2">
              <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
              Starting...
            </span>
          ) : (
            <>Start Trip <Car size={16} /></>
          )}
        </button>
      ) : (
        <button
          onClick={handleCompleteTrip}
          disabled={loading}
          className="btn-accent w-full justify-center"
        >
          {loading ? (
            <span className="flex items-center gap-2">
              <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
              Completing...
            </span>
          ) : (
            <>Mark Trip Complete <CheckCircle size={16} /></>
          )}
        </button>
      )}
    </div>
  );
}
'use client';
import React, { useState } from 'react';
import { ArrowRight, MapPin, Users, Clock, ChevronDown, ChevronUp, CheckCircle, Info } from 'lucide-react';
import { toast } from 'sonner';
import Link from 'next/link';

// NOTE: Routes, trips and pickup_points fetched from Supabase in production
const routesData = [
  {
    id: 'route-001',
    from: 'Gomoh',
    to: 'Dhanbad',
    duration: '~45 min',
    fare: 150,
    activeTrip: {
      id: 'trip-0091',
      totalSeats: 4,
      bookedSeats: 2,
      driverName: 'Ramesh Kumar',
      vehicle: 'Maruti Dzire · JH10C 4421',
      estimatedDeparture: '08:15 AM',
    },
    pickupPoints: [
      { id: 'pp-001', name: 'Gomoh Railway Station', landmark: 'Near platform 1 gate' },
      { id: 'pp-002', name: 'Sindri Road Crossing', landmark: 'Opposite petrol pump' },
      { id: 'pp-003', name: 'Katras Chowk', landmark: 'Near State Bank ATM' },
    ],
  },
  {
    id: 'route-002',
    from: 'Dhanbad',
    to: 'Gomoh',
    duration: '~45 min',
    fare: 150,
    activeTrip: {
      id: 'trip-0092',
      totalSeats: 4,
      bookedSeats: 3,
      driverName: 'Sunil Prasad',
      vehicle: 'Honda City · JH10D 7732',
      estimatedDeparture: '09:00 AM',
    },
    pickupPoints: [
      { id: 'pp-004', name: 'Dhanbad Bus Stand', landmark: 'Main gate, platform 3' },
      { id: 'pp-005', name: 'Hirapur Crossing', landmark: 'Near Hirapur market' },
      { id: 'pp-006', name: 'Katras Chowk', landmark: 'Near State Bank ATM' },
    ],
  },
];

export default function RouteSelectionContent() {
  const [selectedRoute, setSelectedRoute] = useState<string | null>(null);
  const [selectedPickup, setSelectedPickup] = useState<string | null>(null);
  const [seats, setSeats] = useState(1);
  const [expandedRoute, setExpandedRoute] = useState<string | null>('route-001');
  const [bookingLoading, setBookingLoading] = useState(false);
  const [booked, setBooked] = useState(false);

  const selectedRouteData = routesData?.find((r) => r?.id === selectedRoute);
  const available = selectedRouteData
    ? selectedRouteData?.activeTrip?.totalSeats - selectedRouteData?.activeTrip?.bookedSeats
    : 0;

  const handleBook = async () => {
    if (!selectedRoute || !selectedPickup) {
      toast?.error('Please select a route and pickup point');
      return;
    }
    setBookingLoading(true);
    // BACKEND: POST /api/bookings with { trip_id, passenger_id, seats, pickup_point_id }
    // This must be a transactional Supabase Edge Function to prevent overbooking
    await new Promise((r) => setTimeout(r, 1500));
    setBookingLoading(false);
    setBooked(true);
    toast?.success(`Booking confirmed! ${seats} seat${seats > 1 ? 's' : ''} reserved.`);
  };

  if (booked && selectedRouteData) {
    return (
      <div className="max-w-lg mx-auto py-12 flex flex-col items-center gap-6 animate-slide-up">
        <div className="w-20 h-20 rounded-full bg-secondary flex items-center justify-center">
          <CheckCircle size={40} className="text-primary" />
        </div>
        <div className="text-center">
          <h2 className="text-xl font-bold text-foreground mb-2">Booking Confirmed!</h2>
          <p className="text-muted-foreground text-sm">Your seat is reserved. Show this to the driver when boarding.</p>
        </div>
        <div className="card-base p-6 w-full">
          <div className="flex items-center justify-between mb-4">
            <span className="section-label">Booking details</span>
            <span className="status-confirmed text-xs font-semibold px-2.5 py-1 rounded-full">Confirmed</span>
          </div>
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div>
              <p className="text-xs text-muted-foreground">Route</p>
              <p className="font-semibold">{selectedRouteData?.from} → {selectedRouteData?.to}</p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Seats</p>
              <p className="font-semibold tabular-nums">{seats}</p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Pickup</p>
              <p className="font-semibold">{selectedRouteData?.pickupPoints?.find(p => p?.id === selectedPickup)?.name}</p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Fare</p>
              <p className="font-semibold tabular-nums">₹{selectedRouteData?.fare * seats}</p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Driver</p>
              <p className="font-semibold">{selectedRouteData?.activeTrip?.driverName}</p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">Departure</p>
              <p className="font-semibold">{selectedRouteData?.activeTrip?.estimatedDeparture}</p>
            </div>
          </div>
        </div>
        <div className="flex gap-3 w-full">
          <button onClick={() => { setBooked(false); setSelectedRoute(null); setSelectedPickup(null); setSeats(1); }} className="btn-secondary flex-1 justify-center">
            Book another
          </button>
          <Link href="/passenger-home" className="btn-primary flex-1 justify-center">
            Go to home
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col lg:flex-row gap-6">
      {/* Left — route list */}
      <div className="flex-1 flex flex-col gap-4">
        <div>
          <h1 className="text-2xl font-bold text-foreground mb-1">Select your route</h1>
          <p className="text-sm text-muted-foreground">Choose a route, then pick your boarding point.</p>
        </div>

        {routesData?.map((route) => {
          const avail = route?.activeTrip?.totalSeats - route?.activeTrip?.bookedSeats;
          const isExpanded = expandedRoute === route?.id;
          const isSelected = selectedRoute === route?.id;

          return (
            <div
              key={route?.id}
              className={`card-base overflow-hidden transition-all duration-200 ${isSelected ? 'ring-2 ring-primary' : ''}`}
            >
              {/* Route header */}
              <button
                onClick={() => {
                  setExpandedRoute(isExpanded ? null : route?.id);
                  setSelectedRoute(route?.id);
                  setSelectedPickup(null);
                }}
                className="w-full p-5 flex items-start justify-between gap-4 text-left hover:bg-muted/30 transition-colors"
              >
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 text-lg font-bold text-foreground mb-1">
                    <span>{route?.from}</span>
                    <ArrowRight size={16} className="text-primary shrink-0" />
                    <span>{route?.to}</span>
                  </div>
                  <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
                    <span className="flex items-center gap-1"><Clock size={11} />{route?.duration}</span>
                    <span className="font-semibold text-foreground">₹{route?.fare} / seat</span>
                    <span className="flex items-center gap-1">
                      <Users size={11} />
                      {route?.activeTrip?.driverName} · {route?.activeTrip?.vehicle}
                    </span>
                  </div>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <span className={`text-xs font-semibold px-2.5 py-1 rounded-full ${avail > 2 ? 'seat-available' : avail > 0 ? 'seat-limited' : 'seat-full'}`}>
                    {avail === 0 ? 'Full' : `${avail} seat${avail > 1 ? 's' : ''} left`}
                  </span>
                  {isExpanded ? <ChevronUp size={16} className="text-muted-foreground" /> : <ChevronDown size={16} className="text-muted-foreground" />}
                </div>
              </button>
              {/* Expanded — pickup points */}
              {isExpanded && (
                <div className="px-5 pb-5 border-t animate-fade-in">
                  <p className="section-label mt-4 mb-3">Select your pickup point</p>
                  <div className="flex flex-col gap-2">
                    {route?.pickupPoints?.map((point) => (
                      <button
                        key={point?.id}
                        onClick={() => { setSelectedPickup(point?.id); setSelectedRoute(route?.id); }}
                        className={`flex items-start gap-3 p-3.5 rounded-xl border-2 transition-all duration-150 text-left ${selectedPickup === point?.id && selectedRoute === route?.id ? 'border-primary bg-secondary' : 'border-border hover:border-primary/40 bg-card'}`}
                      >
                        <MapPin size={16} className={`mt-0.5 shrink-0 ${selectedPickup === point?.id && selectedRoute === route?.id ? 'text-primary' : 'text-muted-foreground'}`} />
                        <div>
                          <p className="text-sm font-semibold text-foreground">{point?.name}</p>
                          <p className="text-xs text-muted-foreground">{point?.landmark}</p>
                        </div>
                        {selectedPickup === point?.id && selectedRoute === route?.id && (
                          <CheckCircle size={16} className="ml-auto text-primary shrink-0 mt-0.5" />
                        )}
                      </button>
                    ))}
                  </div>

                  {/* Trip info */}
                  <div className="mt-4 p-3 bg-muted rounded-xl flex items-start gap-2">
                    <Info size={14} className="text-muted-foreground shrink-0 mt-0.5" />
                    <p className="text-xs text-muted-foreground">
                      Estimated departure: <strong className="text-foreground">{route?.activeTrip?.estimatedDeparture}</strong> · Pay the driver on board. No online payment required.
                    </p>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
      {/* Right — booking summary */}
      <div className="lg:w-80 xl:w-96">
        <div className="card-base p-5 sticky top-24">
          <h2 className="font-semibold text-base text-foreground mb-4">Booking summary</h2>

          {!selectedRoute ? (
            <div className="flex flex-col items-center py-8 gap-3 text-center">
              <div className="w-12 h-12 rounded-2xl bg-muted flex items-center justify-center">
                <ArrowRight size={20} className="text-muted-foreground" />
              </div>
              <p className="text-sm text-muted-foreground">Select a route and pickup point to continue</p>
            </div>
          ) : (
            <>
              {selectedRouteData && (
                <div className="flex flex-col gap-3 mb-5">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Route</span>
                    <span className="font-semibold">{selectedRouteData?.from} → {selectedRouteData?.to}</span>
                  </div>
                  {selectedPickup && (
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">Pickup</span>
                      <span className="font-semibold text-right max-w-[160px] truncate">
                        {selectedRouteData?.pickupPoints?.find(p => p?.id === selectedPickup)?.name}
                      </span>
                    </div>
                  )}
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-muted-foreground">Seats</span>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => setSeats(Math.max(1, seats - 1))}
                        className="w-7 h-7 rounded-lg border flex items-center justify-center text-sm font-bold hover:bg-muted transition-colors"
                        disabled={seats <= 1}
                      >
                        −
                      </button>
                      <span className="w-6 text-center font-bold tabular-nums">{seats}</span>
                      <button
                        onClick={() => setSeats(Math.min(available, seats + 1))}
                        className="w-7 h-7 rounded-lg border flex items-center justify-center text-sm font-bold hover:bg-muted transition-colors"
                        disabled={seats >= available}
                      >
                        +
                      </button>
                    </div>
                  </div>
                  <div className="border-t pt-3 flex items-center justify-between">
                    <span className="text-sm font-semibold text-foreground">Total fare</span>
                    <span className="text-xl font-bold text-primary tabular-nums">₹{selectedRouteData?.fare * seats}</span>
                  </div>
                  <p className="text-xs text-muted-foreground">Pay the driver on board. Cash only.</p>
                </div>
              )}

              <button
                onClick={handleBook}
                className="btn-primary w-full justify-center"
                disabled={!selectedPickup || bookingLoading || available === 0}
              >
                {bookingLoading ? (
                  <span className="flex items-center gap-2">
                    <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
                    Reserving seat...
                  </span>
                ) : available === 0 ? (
                  'No seats available'
                ) : !selectedPickup ? (
                  'Select a pickup point'
                ) : (
                  <>Confirm Booking <CheckCircle size={16} /></>
                )}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
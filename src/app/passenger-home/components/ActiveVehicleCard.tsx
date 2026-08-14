'use client';
import React, { useState } from 'react';
import Link from 'next/link';
import { ArrowRight, Users } from 'lucide-react';

// This component uses hardcoded mock data — it is part of the old passenger-home flow.
// The current MVP passenger flow goes: sign-up-login-screen → available-routes → book-ride → booking-confirmation
// This component is kept for reference but should not show fake vehicle/departure data.

export default function ActiveVehicleCard() {
  return (
    <div className="card-base p-5">
      <div className="flex items-center gap-2 mb-3">
        <Users size={16} className="text-primary" />
        <p className="font-semibold text-sm text-foreground">Your Queue</p>
      </div>
      <p className="text-sm text-muted-foreground mb-4">
        Join the queue for your route. You will be matched with a driver automatically when capacity is reached.
      </p>
      <Link href="/available-routes" className="btn-primary w-full justify-center">
        View Available Routes
        <ArrowRight size={16} />
      </Link>
    </div>
  );
}
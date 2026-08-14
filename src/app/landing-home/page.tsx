import React from 'react';
import { redirect } from 'next/navigation';

// Landing/Home is served at root (/) — redirect to keep route consistent
export default function LandingHomePage() {
  redirect('/');
}
import { requireDriver } from '@/lib/supabase/auth-helpers';
import React from 'react';
import DriverHomeContent from './components/DriverHomeContent';

export default async function DriverHomePage() {
  // requireDriver() is fail-closed:
  // - No session          → /sign-up-login-screen
  // - passenger/unknown   → /available-routes  (NEVER shows driver UI to passengers)
  // - admin               → /admin-dashboard
  // - driver              → renders DriverHomeContent
  await requireDriver();

  return <DriverHomeContent />;
}
import React from 'react';
import AdminTopbar from './AdminTopbar';
import AdminKpiGrid from './AdminKpiGrid';
import LiveQueueTable from './LiveQueueTable';
import RecentBookingsTable from './RecentBookingsTable';
import SystemStatusPanel from './SystemStatusPanel';

export default function AdminDashboardContent() {
  return (
    <div className="flex flex-col min-h-full">
      <AdminTopbar />
      <div className="flex-1 px-4 sm:px-6 lg:px-8 xl:px-10 2xl:px-12 py-6 max-w-screen-2xl mx-auto w-full">
        <div className="mb-6">
          <h1 className="text-2xl font-bold text-foreground">Operations Dashboard</h1>
          <p className="text-sm text-muted-foreground mt-0.5">Live data from Supabase</p>
        </div>

        <AdminKpiGrid />

        <div className="mt-6 grid grid-cols-1 xl:grid-cols-3 gap-6">
          <div className="xl:col-span-2">
            <LiveQueueTable />
          </div>
          <div>
            <SystemStatusPanel />
          </div>
        </div>

        <div className="mt-6">
          <RecentBookingsTable />
        </div>
      </div>
    </div>
  );
}
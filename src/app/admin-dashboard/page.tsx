
import { requireAdmin } from '@/lib/supabase/auth-helpers';
import AdminSidebar from '@/components/AdminSidebar';
import AdminDashboardContent from './components/AdminDashboardContent';

export default async function AdminDashboardPage() {
  // requireAdmin() is fail-closed: redirects on any error, missing profile, or non-admin role.
  // AdminSidebar and AdminDashboardContent never render unless this returns successfully.
  await requireAdmin();

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <AdminSidebar />
      <main className="flex-1 overflow-y-auto">
        <AdminDashboardContent />
      </main>
    </div>
  );
}
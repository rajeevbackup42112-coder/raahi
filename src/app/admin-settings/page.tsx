import { requireAdmin } from '@/lib/supabase/auth-helpers';
import AdminSidebar from '@/components/AdminSidebar';
import AdminTopbar from '../admin-dashboard/components/AdminTopbar';
import AdminSettingsContent from './components/AdminSettingsContent';

export default async function AdminSettingsPage() {
  await requireAdmin();

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <AdminSidebar />
      <main className="flex-1 overflow-y-auto">
        <AdminTopbar />
        <AdminSettingsContent />
      </main>
    </div>
  );
}

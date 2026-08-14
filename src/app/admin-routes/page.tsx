import { requireAdmin } from '@/lib/supabase/auth-helpers';
import AdminSidebar from '@/components/AdminSidebar';
import AdminTopbar from '../admin-dashboard/components/AdminTopbar';
import AdminRoutesContent from './components/AdminRoutesContent';

export default async function AdminRoutesPage() {
  await requireAdmin();

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <AdminSidebar />
      <main className="flex-1 overflow-y-auto">
        <AdminTopbar />
        <AdminRoutesContent />
      </main>
    </div>
  );
}

import { requireAdmin } from '@/lib/supabase/auth-helpers';
import AdminSidebar from '@/components/AdminSidebar';
import AdminTestHarnessContent from './components/AdminTestHarnessContent';

export default async function AdminTestHarnessPage() {
  await requireAdmin();

  return (
    <div className="flex h-screen bg-background overflow-hidden">
      <AdminSidebar />
      <main className="flex-1 overflow-y-auto">
        <AdminTestHarnessContent />
      </main>
    </div>
  );
}

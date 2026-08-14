import { requireAdmin } from '@/lib/supabase/auth-helpers';
import AdminSidebar from '@/components/AdminSidebar';
import AdminQueueDiagnosticContent from './components/AdminQueueDiagnosticContent';

export default async function AdminQueueDiagnosticPage() {
  await requireAdmin();

  return (
    <div className="flex h-screen bg-background overflow-hidden">
      <AdminSidebar />
      <main className="flex-1 overflow-y-auto">
        <AdminQueueDiagnosticContent />
      </main>
    </div>
  );
}

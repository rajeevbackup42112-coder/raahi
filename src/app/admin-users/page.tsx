import { requireAdmin } from '@/lib/supabase/auth-helpers';
import AdminUsersClient from './AdminUsersClient';

export default async function AdminUsersPage() {
  await requireAdmin();

  return <AdminUsersClient />;
}

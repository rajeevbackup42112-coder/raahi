'use client';

import React, { useEffect, useState } from 'react';
import { Bell, Search, Settings } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

export default function AdminTopbar() {
  const [adminName, setAdminName] = useState<string>('Admin');
  const [adminInitial, setAdminInitial] = useState<string>('A');

  useEffect(() => {
    const supabase = createClient();
    supabase?.auth?.getUser()?.then(async ({ data: { user } }) => {
      if (!user) return;
      const { data: profile } = await supabase?.from('profiles')?.select('name')?.eq('id', user?.id)?.single();
      if (profile?.name) {
        setAdminName(profile?.name);
        setAdminInitial(profile?.name?.charAt(0)?.toUpperCase());
      } else if (user?.email) {
        const emailName = user?.email?.split('@')?.[0];
        setAdminName(emailName);
        setAdminInitial(emailName?.charAt(0)?.toUpperCase());
      }
    });
  }, []);

  return (
    <div className="sticky top-0 z-40 w-full border-b bg-card/95 backdrop-blur-sm h-14 flex items-center px-4 sm:px-6 lg:px-8 xl:px-10 gap-4">
      <div className="flex-1 max-w-xs hidden sm:flex items-center gap-2 px-3 py-2 rounded-xl border bg-muted text-sm text-muted-foreground">
        <Search size={14} />
        <span>Search passengers, drivers...</span>
      </div>
      <div className="ml-auto flex items-center gap-2">
        <button className="relative p-2 rounded-xl hover:bg-muted transition-colors" aria-label="Notifications">
          <Bell size={18} className="text-muted-foreground" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-danger rounded-full"></span>
        </button>
        <button className="p-2 rounded-xl hover:bg-muted transition-colors" aria-label="Settings">
          <Settings size={18} className="text-muted-foreground" />
        </button>
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-muted ml-1">
          <div className="w-6 h-6 rounded-full gradient-primary flex items-center justify-center text-white text-xs font-bold">
            {adminInitial}
          </div>
          <span className="text-sm font-medium hidden sm:block">{adminName}</span>
        </div>
      </div>
    </div>
  );
}
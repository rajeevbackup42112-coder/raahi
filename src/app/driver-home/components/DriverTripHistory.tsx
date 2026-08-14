import React from 'react';
import { CheckCircle, XCircle, ArrowRight } from 'lucide-react';

// NOTE: Fetched from Supabase `trips` filtered by driver_id, ordered by created_at DESC
const tripHistory = [
  { id: 'trip-0090', route: 'Dhanbad → Gomoh', date: '08 Aug', passengers: 3, fare: '₹450', status: 'completed' },
  { id: 'trip-0089', route: 'Gomoh → Dhanbad', date: '08 Aug', passengers: 4, fare: '₹600', status: 'completed' },
  { id: 'trip-0088', route: 'Gomoh → Dhanbad', date: '07 Aug', passengers: 2, fare: '₹300', status: 'completed' },
  { id: 'trip-0087', route: 'Dhanbad → Gomoh', date: '07 Aug', passengers: 4, fare: '₹600', status: 'completed' },
  { id: 'trip-0086', route: 'Gomoh → Dhanbad', date: '06 Aug', passengers: 3, fare: '₹450', status: 'completed' },
  { id: 'trip-0085', route: 'Gomoh → Dhanbad', date: '05 Aug', passengers: 1, fare: '₹150', status: 'cancelled' },
];

export default function DriverTripHistory() {
  const totalThisWeek = tripHistory?.filter(t => t?.status === 'completed')?.reduce((acc, t) => acc + parseInt(t?.fare?.replace('₹', '')), 0);

  return (
    <div className="flex flex-col gap-4">
      <div className="card-base p-4 gradient-primary text-white">
        <p className="text-xs text-white/70 mb-1">Earnings this week</p>
        <p className="text-2xl font-bold tabular-nums">₹{totalThisWeek?.toLocaleString('en-IN')}</p>
        <p className="text-xs text-white/70 mt-1">{tripHistory?.filter(t => t?.status === 'completed')?.length} completed trips</p>
      </div>
      <div className="card-base overflow-hidden">
        <div className="px-4 py-3 border-b">
          <p className="text-sm font-semibold text-foreground">Recent trips</p>
        </div>
        <div className="divide-y">
          {tripHistory?.map((trip) => (
            <div key={trip?.id} className="flex items-center gap-3 px-4 py-3 hover:bg-muted/30 transition-colors">
              <div className={`w-8 h-8 rounded-xl flex items-center justify-center shrink-0 ${trip?.status === 'completed' ? 'status-active' : 'status-full'}`}>
                {trip?.status === 'completed' ? <CheckCircle size={14} /> : <XCircle size={14} />}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-1 text-xs font-semibold text-foreground">
                  {trip?.route?.split(' → ')?.map((segment, si, arr) => (
                    <React.Fragment key={`${trip?.id}-seg-${si}`}>
                      <span>{segment}</span>
                      {si < arr?.length - 1 && <ArrowRight size={10} className="text-muted-foreground" />}
                    </React.Fragment>
                  ))}
                </div>
                <p className="text-xs text-muted-foreground">{trip?.date} · {trip?.passengers} passenger{trip?.passengers !== 1 ? 's' : ''}</p>
              </div>
              <span className="text-sm font-bold text-foreground tabular-nums shrink-0">{trip?.fare}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
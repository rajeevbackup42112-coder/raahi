import { Suspense } from 'react';
import BookingConfirmationContent from './components/BookingConfirmationContent';

export default function BookingConfirmationPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-background flex items-center justify-center"><div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" /></div>}>
      <BookingConfirmationContent />
    </Suspense>
  );
}

import React from 'react';
import PassengerHeader from '@/components/PassengerHeader';
import RouteSelectionContent from './components/RouteSelectionContent';

export default function RouteSelectionPage() {
  return (
    <div className="min-h-screen bg-background pb-20 sm:pb-0">
      <PassengerHeader />
      <main className="max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-8 py-6 lg:py-8">
        <RouteSelectionContent />
      </main>
    </div>
  );
}
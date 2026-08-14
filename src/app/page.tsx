import React from 'react';
import PublicHeader from '@/components/PublicHeader';
import PublicFooter from '@/components/PublicFooter';
import HeroSection from './components/HeroSection';
import HowItWorksSection from './components/HowItWorksSection';
import RoutesPreviewSection from './components/RoutesPreviewSection';
import TrustSection from './components/TrustSection';

export default function LandingPage() {
  return (
    <div className="min-h-screen flex flex-col bg-background">
      <PublicHeader />
      <main className="flex-1">
        <HeroSection />
        <HowItWorksSection />
        <RoutesPreviewSection />
        <TrustSection />
      </main>
      <PublicFooter />
    </div>
  );
}
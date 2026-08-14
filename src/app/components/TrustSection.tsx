import React from 'react';
import { UserCheck, Lock, Clock, Headphones } from 'lucide-react';

const trustItems = [
  {
    id: 'trust-verified',
    icon: UserCheck,
    title: 'Verified drivers',
    description: 'Every driver is verified before joining the platform. No unverified vehicles.',
  },
  {
    id: 'trust-secure',
    icon: Lock,
    title: 'Secure bookings',
    description: 'Your seat is reserved instantly. Simultaneous booking conflicts are prevented at the server level.',
  },
  {
    id: 'trust-reliable',
    icon: Clock,
    title: 'Fair queue system',
    description: 'Passengers are matched to drivers in the order they joined — first in, first served. No favouritism, no hidden priority.',
  },
  {
    id: 'trust-support',
    icon: Headphones,
    title: 'Responsive support',
    description: 'Real help from a real team. Reach us Mon–Sat during operational hours.',
  },
];

export default function TrustSection() {
  return (
    <section className="py-20 bg-background">
      <div className="max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-12">
          <p className="section-label mb-2">Why Raahi</p>
          <h2 className="text-hero-md text-foreground">Built for daily commuters</h2>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6">
          {trustItems?.map((item) => (
            <div key={item?.id} className="card-base p-6 text-center card-hover">
              <div className="w-12 h-12 rounded-2xl bg-secondary flex items-center justify-center mx-auto mb-4">
                <item.icon size={22} className="text-primary" />
              </div>
              <h3 className="font-bold text-sm text-foreground mb-2">{item?.title}</h3>
              <p className="text-xs text-muted-foreground leading-relaxed">{item?.description}</p>
            </div>
          ))}
        </div>

        {/* CTA Banner */}
        <div className="mt-12 gradient-primary rounded-3xl p-8 md:p-12 flex flex-col md:flex-row items-center justify-between gap-6">
          <div>
            <h3 className="text-xl md:text-2xl font-bold text-white mb-2">Ready to start commuting smarter?</h3>
            <p className="text-white/70 text-sm">Join hundreds of daily commuters on the Gomoh–Dhanbad corridor.</p>
          </div>
          <a href="/sign-up-login-screen" className="btn-accent shrink-0 px-8 py-4 text-base font-bold rounded-2xl">
            Create Free Account
          </a>
        </div>
      </div>
    </section>
  );
}
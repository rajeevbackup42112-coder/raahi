import React from 'react';
import { Search, ListOrdered, Car } from 'lucide-react';

const steps = [
  {
    id: 'step-1',
    number: '01',
    icon: Search,
    title: 'Choose your route',
    description: 'Pick from available routes between nearby cities. See the fare per seat and how many passengers are currently waiting.',
  },
  {
    id: 'step-2',
    number: '02',
    icon: ListOrdered,
    title: 'Join the queue',
    description: 'Confirm your booking to join the FIFO queue for your route. Your position is reserved — first in, first served.',
  },
  {
    id: 'step-3',
    number: '03',
    icon: Car,
    title: 'Get matched',
    description: 'Once enough passengers are ready, Raahi automatically matches the first available driver in queue order.',
  },
];

export default function HowItWorksSection() {
  return (
    <section className="py-20 bg-background">
      <div className="max-w-screen-xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center mb-12">
          <p className="section-label mb-2">How it works</p>
          <h2 className="text-hero-md text-foreground">Three steps to your ride</h2>
          <p className="text-muted-foreground mt-3 max-w-md mx-auto text-sm leading-relaxed">
            Raahi uses a fair queue system. Join the queue for your route and get automatically matched to a driver when your vehicle is ready.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 lg:gap-8">
          {steps?.map((step, index) => (
            <div key={step?.id} className="relative">
              <div className="card-base p-6 h-full card-hover">
                <div className="flex items-start gap-4 mb-4">
                  <div className="w-12 h-12 rounded-2xl gradient-primary flex items-center justify-center shrink-0">
                    <step.icon size={22} className="text-white" />
                  </div>
                  <span className="text-4xl font-extrabold text-muted/80 tabular-nums leading-none mt-1">{step?.number}</span>
                </div>
                <h3 className="font-bold text-base text-foreground mb-2">{step?.title}</h3>
                <p className="text-sm text-muted-foreground leading-relaxed">{step?.description}</p>
              </div>
              {index < steps?.length - 1 && (
                <div className="hidden md:flex absolute top-1/2 -right-4 z-10 w-8 justify-center">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-muted-foreground"><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></svg>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
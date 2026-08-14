import React, { Suspense } from 'react';
import AuthScreen from './components/AuthScreen';

export default function SignUpLoginPage() {
  return (
    <Suspense fallback={<div className="min-h-screen bg-background" />}>
      <AuthScreen />
    </Suspense>
  );
}
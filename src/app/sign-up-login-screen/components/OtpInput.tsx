'use client';
import React, { useRef, useState, KeyboardEvent, ChangeEvent } from 'react';
import { ArrowRight } from 'lucide-react';

interface OtpInputProps {
  onComplete: (otp: string) => void;
  loading: boolean;
  onBack: () => void;
}

export default function OtpInput({ onComplete, loading, onBack }: OtpInputProps) {
  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const inputs = useRef<(HTMLInputElement | null)[]>([]);

  const handleChange = (index: number, e: ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value.replace(/\D/g, '').slice(-1);
    const next = [...otp];
    next[index] = val;
    setOtp(next);
    if (val && index < 5) {
      inputs.current[index + 1]?.focus();
    }
    if (next.every((d) => d !== '') && val) {
      onComplete(next.join(''));
    }
  };

  const handleKeyDown = (index: number, e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Backspace' && !otp[index] && index > 0) {
      inputs.current[index - 1]?.focus();
    }
  };

  const handlePaste = (e: React.ClipboardEvent) => {
    const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
    if (pasted.length === 6) {
      const arr = pasted.split('');
      setOtp(arr);
      inputs.current[5]?.focus();
      onComplete(pasted);
    }
  };

  return (
    <div className="flex flex-col gap-5">
      <div className="flex gap-2 justify-center" onPaste={handlePaste}>
        {otp.map((digit, i) => (
          <input
            key={`otp-digit-${i}`}
            ref={(el) => { inputs.current[i] = el; }}
            type="text"
            inputMode="numeric"
            maxLength={1}
            value={digit}
            onChange={(e) => handleChange(i, e)}
            onKeyDown={(e) => handleKeyDown(i, e)}
            className={`otp-input ${digit ? 'filled' : ''}`}
            aria-label={`OTP digit ${i + 1}`}
            disabled={loading}
          />
        ))}
      </div>

      <button
        onClick={() => onComplete(otp.join(''))}
        className="btn-primary w-full"
        disabled={loading || otp.some((d) => !d)}
      >
        {loading ? (
          <span className="flex items-center gap-2">
            <span className="w-4 h-4 border-2 border-white/40 border-t-white rounded-full animate-spin" />
            Verifying...
          </span>
        ) : (
          <>Verify & Sign In <ArrowRight size={16} /></>
        )}
      </button>

      <div className="flex items-center justify-between text-sm">
        <button onClick={onBack} className="text-muted-foreground hover:text-foreground transition-colors">
          ← Change number
        </button>
        <button className="text-primary hover:text-primary/80 font-semibold transition-colors">
          Resend OTP
        </button>
      </div>
    </div>
  );
}
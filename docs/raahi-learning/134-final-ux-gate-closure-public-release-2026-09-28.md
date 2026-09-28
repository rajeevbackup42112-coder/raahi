# Raahi Learning — Final UX Gate Closure and Public Release Evidence

Date: 2026-09-28
Repository: `rajeevbackup42112-coder/raahi`
Branch: `raahi-learning-implementation-v1`
Public: `https://learning.myraahi.co.in`

## Decision

The investor-grade UX redesign gate is **CLOSED**.

The intended controlled public launch / Gomoh-first promotion is approved from exact product SHA:

`7d99b69165df0de0ca02e7778fde995b302ff624`

The same release folder was deployed to Cloudflare preview first, hash-verified, promoted unchanged to `main`, and hash-verified again on the production custom domain.

## Production identity

Production build metadata reports:
- release mode: `CONTROLLED_PILOT`
- commit SHA: `7d99b69165df0de0ca02e7778fde995b302ff624`
- origin: `https://learning.myraahi.co.in`
- project ref: `iiwwmqokaeflaenhlyip`

Every packaged release file matched its SHA-256 hash on preview and production.

The release package scan found zero forbidden DEV/secret references and zero direct browser operational-table DML patterns.

## Qualification

Exact-SHA local qualification:
- 5,349,572 model/property cases — 0 failures
- source/focused regressions — 35/35
- responsive shell — 5/5
- Notifications UX — 9/9
- mobile actions — 32/32
- Settings UX — 8/8
- conversation UX — 16/16
- Teacher workspace — 11/11
- Institute workspace — 16/16
- Local Manager workspace — 21/21
- Platform workspace — 19/19
- Ads workspace — 19/19
- human-language browser audit — 168/168
- sealed interactions — 27/27

Independent GitHub qualification:
- Model Tests #796 — success
- Browser Contract #49 — success on first attempt

## Final visual evidence

The exact release candidate passed the full persistent-browser visual audit:
- 9/9 profiles completed
- 14 role contexts
- 527 rendered screens
- 6,998 visible controls
- 0 issue screens
- 0 audit errors

The last residual defect was the mobile Platform Audit disclosure target. On the released SHA every `Technical details` disclosure measures 44px at 390×844.

## Post-deploy continuity

The production release was rechecked with the persistent real Google sessions.

Raahi-01, 02, 04, 05, 06, 07 and 09 all settled into their expected role-aware workspaces with the V15 shell, private avatar fallback, no horizontal overflow and no onboarding regression.

Raahi-03 was separately verified after OAuth settlement:
- original Account preserved
- self learner preserved
- managed dependent preserved
- learner/student/parent contexts preserved
- Gomoh preserved
- Parent Home restored

Raahi-08 was separately verified after account-context settlement:
- Platform Admin authority preserved
- Local Manager / Platform / Ads contexts present
- Platform Audit reached on mobile
- all disclosure targets are 44px
- Ads Home reached
- no horizontal overflow

The earlier Raahi-03/Raahi-08 anomalies were timing/boot observations, not lost identity or authority.

## Remaining work classification

The **product/UX go-live gate is complete** for the current controlled launch scope.

The following remain separate operational-hardening tracks for materially larger scale:
- production-scale soak/load testing
- operational alert-delivery drill
- DB + Storage restore drill

These are not blockers for the controlled Gomoh-first launch.

## Next state

Do not restart speculative redesign.

Continue with real-user observation and launch operations. Open new product work only for a demonstrated user problem, failed invariant, measured production evidence, or deliberate new product decision.


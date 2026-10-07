# AdVise Digital Progress

Current branch: `wip/codex-product-redesign-2026-10-05`
Current HEAD at revision start: `d82ef4e49147142880bbced726f790698c2177cc`
Last good baseline commit: `a12ca3e` (revision baseline docs and required media test fixture).
Binding request: `C:/Users/ANL/Downloads/ADVISE_CODEX_MASTER_FINAL_REVISION_2026-10-07.txt`

Canonical branding: `icon.jpeg` = APP ICON; `logo.jpeg` = FULL LOGO. New revision overrides older branding descriptions and older no-commit instructions. Phases are tested and committed separately; no production deploy/main merge/live Meta spending.

## Phase status

- FAZ 0 Audit: ✅
- EK FAZ 1A/1B Ads / AI strategy / preflight: ✅
- FAZ 1 Reels Cover: ⬜
- FAZ 2 Branding: ⬜
- FAZ 3 Theme Contrast: ⬜
- Gemini quality / hashtag engine: ⬜
- FAZ 4 Scheduler: ⬜
- FAZ 5 Dual Memory Palace / Copy Style / Performance: ⬜
- FAZ 6 Gemini Independence: ⬜
- FAZ 7 Memory DB / Scale: ⬜
- FAZ 8 AI Studio UX: ⬜
- FAZ 9 Tests / release builds: ⬜
- FAZ 10 Final handoff / rollout: ⬜

## FAZ 0 — focused audit

- Status: baseline regression passed; implementation next is EK FAZ 1A/1B.
- Files changed: this progress file, handoff and rollout documents; existing untracked source-only test helpers must be included explicitly where required by baseline tests.
- Commit: pending green baseline.
- Tests: backend 41/41 and Flutter 48/48 passed; Flutter analyze: no issues.
- Working architecture: Express/JSON tenant persistence, Graph/Interactions, Flutter shared Android/Web/Windows, durable publish phases, tenant/account file locks.
- Source findings: Gemini has per-attempt timeout but no overall budget; strategy includes several unbounded aggregate Graph reads before generation. Tenant write lock may wait up to 10 minutes. Sequential ad creation + cleanup can exceed the 90s client timeout. No persisted ad creation idempotency/saga state. Provider 502 errors are reduced to generic AppError text. UI finally exists for create but strategy cleanup is not in finally.
- Risk boundaries: no runtime JSON/uploads/.env in commits; partial Graph creates must not be blindly replayed; preserve existing tenant/account locks and user changes.
- Remote reference: origin/WIP has four additional commits; inspected names/diff, not merged. Current local HEAD remains the baseline. No force push.
- Rollback: use phase source commits to revert source on this WIP branch; never restore/reset runtime files. Production rollout requires separate human authorization.
- Next exact task: add bounded operation/error contracts, a single Meta preflight and persisted staged ad creation with stable client request IDs; test failure/partial/retry/timeout/disposal.

## EK FAZ 1A/1B — ads and strategy root causes

- Status: implemented and regression verified. Provider fixture tests only; no live ads or spending.
- Files changed: backend src operation-budget.js, ad-operations.js, persistence.js, automation-safety.js, meta.js, ai.js, product.js, server.js; mobile lib api.dart, app_error.dart, social_ads_page.dart; backend/test/ad-operations.test.js, mobile/test/ads_flow_test.dart.
- Commit: phase commit `fix(ads): bound strategy requests and persist preflighted creation saga` (resolve with git log).
- Tests: backend 52/52; new targeted backend 11/11; Flutter 53/53 (including new 5/5); Flutter analyze no issues.
- Root causes fixed: no Gemini aggregate deadline, optional report latency, long tenant lock waits, long sequential cleanup after a create failure, missing persisted partial IDs/idempotency, success loading retained while dialog open, strategy cleanup outside finally, generic provider 502 handling.
- Contracts: strategy 55s total/40s maximum Gemini/8s optional reporting, client 65s; create 70s provider budget, HTTP tenant/account waits 5s each, client 90s. Meta transports inherit remaining budget. Strategy no longer occupies the tenant write lock during read-only generation.
- Durable saga: ad_operations.json is runtime-only and tenant scoped. Persist STARTED and each returned ID; known rejection can resume without recreating earlier entities. Timeout/network/crash/partial activation requires RECONCILE and cannot blindly retry. Successful duplicate returns the same result. Default status PAUSED; ad activated last only on explicit true.
- Preflight: fresh account status/currency/timezone/task permission, granted scopes, Page publication/access, linked Instagram and WhatsApp evidence; unknown prerequisites fail closed. Based on Meta's official SDK Page and AdAccount field definitions. No fake permissions or actual production check claimed.
- UI: finally cleanup, actionable safe stage errors, preflight check action, persisted request identity scoped to API/account/payload, operation status lookup, duplicate create disabled after success. No raw provider JSON in API exceptions.
- Known limits: true Meta account permissions/WhatsApp support still need read-only smoke with authorized credentials; RECONCILE requires manual remote ID verification before any new creation; partial activation may need manual pause. JSON persistence scales in a later phase. No new release build claimed yet.
- Next exact task: FAZ 1 cover bytes/decoder validation and multipart consistency, then canonical branding, themes, quality and memory in the master order.

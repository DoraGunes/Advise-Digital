# AdVise Digital Progress

Current branch: `wip/codex-product-redesign-2026-10-05`
Current HEAD at revision start: `d82ef4e49147142880bbced726f790698c2177cc`
Current tested source checkpoint: `19ceb7795211ed726f3ead3a579f04938d116391` (cover phase).
Last good baseline commit: `a12ca3e` (revision baseline docs and required media test fixture).
Binding request: `C:/Users/ANL/Downloads/ADVISE_CODEX_MASTER_FINAL_REVISION_2026-10-07.txt`

Canonical branding: `icon.jpeg` = APP ICON; `logo.jpeg` = FULL LOGO. New revision overrides older branding descriptions and older no-commit instructions. Phases are tested and committed separately; no production deploy/main merge/live Meta spending.

## Phase status

- FAZ 0 Audit: ✅
- EK FAZ 1A/1B Ads / AI strategy / preflight: ✅
- FAZ 1 Reels Cover: ✅
- FAZ 2 Branding: ✅
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

## FAZ 1 — Reels cover

- Status: implementation, regressions and Web release build passed.
- Files changed: backend cover-image.js and server.js, sharp dependency plus synchronized package-lock.json; backend cover-image.test.js and HTTP cover tests; Flutter api.dart/media_access.dart, explicit http_parser dependency/lock, media/API tests.
- Root cause: http.MultipartFile without Content-Type produces application/octet-stream; backend cover route rejected it despite a valid filename/image. Shared generic fileFilter also rejected extensionless browser blobs before byte validation.
- Implementation: dedicated 10 MB cover upload; actual JPEG/PNG/WebP magic + sharp pixel decode with 40M pixel cap; EXIF rotate, alpha flatten, proportional resize, strip metadata, true JPEG encode and .jpg URL. Ignore misleading filename/MIME, normalize to actual bytes. Persist new cover before removing old cover. Rejection keeps the prior cover unchanged.
- Frontend: XFile bytes on all platforms, magic-derived multipart MIME/extension, size/read/format errors, timeout includes response body. Server error codes map to readable cover messages.
- Tests: targeted backend 18/18 (incl progressive JPEG, alpha, corrupt/truncated, EXIF, HTTP jpg/jpeg/uppercase/extensionless/wrong MIME/WebP/PNG/size); full backend 59/59; Flutter targeted 16/16 and full 54/54; analyze no issues. package/lock dependency equality verified.
- Commit: phase commit `fix(media): decode and normalize Reels cover uploads` (resolve with git log).
- Build: `flutter build web --release --no-pub` succeeded (267.5s). Wasm dry run succeeded. Build emitted a Cupertino font-family warning; direct source contains no CupertinoIcons references, no missing-font visual claim is made.
- Known issues: physical Android/Windows file chooser and installed PWA picker require later manual smoke. CI needs sharp's platform native optional packages. npm install reported 2 moderate vulnerabilities; no forced upgrade performed.
- Push: normal WIP push rejected non-fast-forward; remote commits preserved, no force push or blind merge. Local phase commits remain safe.
- Next exact task: canonical branding conversion and platform icons; preserve manifest identity and test/build before commit.

## FAZ 2 — canonical branding

- Status: source assets, true PNG/ICO derivatives and all platform builds passed; targeted backend 3/3, full backend 62/62, targeted Flutter 8/8 and full Flutter 57/57 passed; analyze no issues.
- Files changed: backend/scripts/generate-branding.mjs, backend/test/branding.test.js; mobile/assets/branding canonical JPEG/PNG/hash metadata and compatibility JPEG, Android density/adaptive/splash assets, PWA icons/favicon, Windows ICO, Flutter main/product_shell branding, pubspec assets, branding widget tests.
- Canonical: Downloads icon.jpeg = APP ICON; logo.jpeg = FULL LOGO. Source SHA-256 values preserved in assets/branding/canonical.json. Logo proportion retained; no stretching/cropping. Main login uses full logo, navigation uses app icon. Existing compatibility JPEG contains canonical full logo for media fixtures.
- Identity: mobile/web/manifest.json unchanged byte-for-byte (id/start_url remain '.', scope absent), Android application ID/Windows identity unchanged.
- Tests: backend validates actual PNG dimensions/encoding, exact canonical source hashes, ICO frame offsets/decoding, Android/adaptive resource references, manifest hash. Windows System.Drawing.Icon also opened ICO successfully.
- Test repairs: larger login logo initially exposed 2.4px overflow at 320px/1.4 text scale; fixed by constraining brand text. PNG decode fixture required tester.runAsync to avoid fake-clock hang; only owned test sessions interrupted and rerun.
- Commit: phase commit `feat(branding): apply canonical AdVise logo and platform icons` (resolve with git log).
- Builds: Android release APK succeeded 508.5s, 58.9 MB; Windows release succeeded 155.3s; Web release succeeded 115.8s with --no-wasm-dry-run (cover-phase Wasm dry run had passed). APK Flutter PNG hashes and all launcher density/adaptive/splash pixel matches verified. Windows EXE icon pixels and bundled PNG hashes match. Web manifest, PWA/favicon and bundled PNG hashes match. Existing Cupertino font warning recorded for theme-phase follow-up.
- APK delivery: C:/Users/ANL/Downloads/AdVise-Digital-2026-10-07-branding.apk; SHA-256 494C4C197E5F368A982B82B8CE163BE235AECB4D04057B7EF29CF7467673B48C. Uses existing debug signing configuration; no signing/keystore secrets changed.
- Next exact task: FAZ 3 semantic theme tokens and Light/Dark/Colorful persistence/contrast tests. Then Gemini quality/hashtags, scheduler, dual memory/copy style/performance/timing, independence, scalable DB, AI Studio UX and final regression/manual rollout readiness. Those phases are NOT complete.
- Live health read only: configured API domain returned HTTP 200 / version 16.0.0, old build marker, new ads capabilities absent. Cloudflare-routed API remains reachable; this does not claim Wrangler login or a live backend upgrade.

# AdVise Digital Progress

Current branch: `wip/codex-product-redesign-2026-10-05`
Current HEAD at revision start: `d82ef4e49147142880bbced726f790698c2177cc`
Current continuation source checkpoint: `feat(ai): validate professional content packages with one regeneration`; exact committed HEAD is returned by git rev-parse HEAD. See continuation FAZ 5 below for the latest test/STOP record.
Previous tested source commit: `904aa1cd0d81c2cfd39fe6d107ca40bd90bc60eb` (theme phase); continuation started at docs checkpoint `c9ee1fff0cb2e031f9a885098ce0bda0956e3324`.
Binding request: `C:/Users/ANL/Downloads/ADVISE_CODEX_MASTER_FINAL_REVISION_2026-10-07.txt`

Continuation request: `C:/Users/ANL/.codex/attachments/8a66d740-bca3-4d70-a370-f8872e9a9fcd/Yapıştırılan metin.txt`. Latest steering: user reports 21% credit remaining and requests STOP after a safe checkpoint of the current phase; no new phase, full build or push.

Canonical branding: `icon.jpeg` = APP ICON; `logo.jpeg` = FULL LOGO. New revision overrides older branding descriptions and older no-commit instructions. Phases are tested and committed separately; no production deploy/main merge/live Meta spending.

## Phase status

- FAZ 0 Audit: ✅
- EK FAZ 1A/1B Ads / AI strategy / preflight: ✅
- FAZ 1 Reels Cover: ✅
- FAZ 2 Branding: ✅
- FAZ 3 Theme Contrast: ✅
- Gemini quality / hashtag engine: 🟡 (quality checkpoint complete; hashtag engine not started)
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
- Commit: `a12ca3e`.
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
- Commit: `fa6c333e74d80853342e84f33e7482770ec0555d` — `fix(ads): bound strategy requests and persist preflighted creation saga`.
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
- Commit: `19ceb7795211ed726f3ead3a579f04938d116391` — `fix(media): decode and normalize Reels cover uploads`.
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
- Commit: `ceec0715bfbd3f0b7d8bee73bf71146d4c59389f` — `feat(branding): apply canonical AdVise logo and platform icons`.
- Builds: Android release APK succeeded 508.5s, 58.9 MB; Windows release succeeded 155.3s; Web release succeeded 115.8s with --no-wasm-dry-run (cover-phase Wasm dry run had passed). APK Flutter PNG hashes and all launcher density/adaptive/splash pixel matches verified. Windows EXE icon pixels and bundled PNG hashes match. Web manifest, PWA/favicon and bundled PNG hashes match. Existing Cupertino font warning recorded for theme-phase follow-up.
- APK delivery: C:/Users/ANL/Downloads/AdVise-Digital-2026-10-07-branding.apk; SHA-256 494C4C197E5F368A982B82B8CE163BE235AECB4D04057B7EF29CF7467673B48C. Uses existing debug signing configuration; no signing/keystore secrets changed.
- Next exact task: FAZ 3 semantic theme tokens and Light/Dark/Colorful persistence/contrast tests. Then Gemini quality/hashtags, scheduler, dual memory/copy style/performance/timing, independence, scalable DB, AI Studio UX and final regression/manual rollout readiness. Those phases are NOT complete.
- Live health read only: configured API domain returned HTTP 200 / version 16.0.0, old build marker, new ads capabilities absent. Cloudflare-routed API remains reachable; this does not claim Wrangler login or a live backend upgrade.

## FAZ 3 — semantic theme contrast

- Status: implemented; backend 62/62, Flutter 79/79 and analyze clean. Android release passed 340.6s / 59.0 MB; Web release passed 157.1s; Windows release passed 156.1s; no provider/runtime/production changes.
- Files changed: mobile product_ui.dart, main.dart, product_more.dart, social_ads_page.dart, v14_ai.dart, content_queue_page.dart, v13_pro.dart, v78_pages.dart; contrast, real-module smoke and ads-flow tests.
- Root causes: fixed light-colored preview/card/pill backgrounds remained in dark mode; fixed grey secondary labels became unreadable on dark surfaces. Some textTheme styles replaced applied foreground colors. Two promotional gradient stops/alpha combinations did not meet 4.5:1 text contrast.
- Implementation: shared ColorScheme text/surface/control/navigation/dialog/dropdown/tooltip/snackbar colors; preserve text foreground after typography overrides. Form outlines at least 3:1, active text/control pairs at least 4.5:1. Keep intentionally dark promotional panels and verify their translucent text at the lightest stop.
- Renkli/Colorful: warm yellow canvas, white cards, indigo primary, teal secondary and rose tertiary; light semantic mode with readable foregrounds. New ProductThemeMode retains existing productTheme system/light/dark values and adds colorful; selection persists across restart. Failed preference write preserves old mode and shows a safe error.
- Tests: 27 contrast/persistence/form/dropdown/dialog/snackbar/gradient tests; real Studio/Ads Center/Queue/Memory/Reports across all three themes; campaign generation error/retry in all three themes. Full Flutter 79/79; backend 62/62; analyze no issues. Tests use isolated fixtures; no live provider success inferred.
- Commit: `904aa1cd0d81c2cfd39fe6d107ca40bd90bc60eb` — `fix(theme): normalize contrast and persist colorful appearance`.
- APK: C:/Users/ANL/Downloads/AdVise-Digital-2026-10-07-theme.apk; SHA-256 4BC1DB282EE61465240B7201A63868882192249937D6CDD8E2A8A9063DC6FEAD. Packaged canonical PNG hashes/all five launcher density/adaptive/splash pixel matches verified. Existing signing configuration preserved. Requires matching backend for secure ad creation; not a production deployment.
- Web: mobile/build/web, main.dart.js SHA-256 e00ebabef587929752f03750c2f5e23436a38e369b4e5d5d64eff22ab5ba87a8. Source/output manifest/PWA/favicon/canonical bundled PNG hashes match. --no-wasm-dry-run used; prior cover-phase Wasm dry run remains the latest Wasm evidence.
- Windows: mobile/build/windows/x64/runner/Release, 156.1s build; canonical bundled PNG hashes and embedded EXE icon pixels match. Deliver the whole folder, including updated data/app.so; native EXE hash remains unchanged when only Dart/UI changes.
- Windows AOT data/app.so SHA-256: 6BD6551F8B67AE4F40FF58327251779AAFCB8FE3DC522DD32E1AA5DEB3953D43.
- Push: attempted normal WIP push after 904aa1c; rejected non-fast-forward. Phase commits remain local. Remote work preserved; no force push or blind merge.
- Known limits: installed Android/PWA/Windows visual smoke remains manual. Existing Web Cupertino font-family warning is recorded; no missing glyph observed or claimed. Colorful quick-toggle switches to dark; use More > Görünüm > Renkli to select colorful explicitly.
- Next exact task: EK FAZ 5A/5B/5C professional content package schema, deterministic quality gate with one bounded regeneration, relevant grouped hashtag engine and safe response telemetry; preserve WhatsApp destination, tenant isolation and truthful fallback source. Start with ai.js generateContentPack/normalizePack/OUTPUT_SCHEMA, server content-pack input/output, v14_ai.dart editor and existing isolated AI tests. Memory/scheduler/DB phases remain incomplete.

## Continuation FAZ 5 — Gemini quality checkpoint

- Status: implemented, targeted tests green, STOP requested by user at 21% credit. No next phase started and no new builds.
- Files: backend/src/content-quality.js, ai.js, server.js; backend/test/content-quality.test.js; mobile/lib/v14_ai.dart and mobile/test/product_modules_smoke_test.dart.
- Commit: feat(ai): validate professional content packages with one regeneration (exact SHA in git log after checkpoint commit).
- Output: headline/primaryText/description/visualAngle/publish time/style recipe/rationale plus three distinct hook/angle/caption/CTA alternatives; old fields retained for existing clients. Short rationale only, no chain-of-thought.
- Gate: recursive required-field/type/enum checks, length/generic/repetition/encoding/destination/tag duplicates, evidence checks for explicit price/discount/guarantee/technical-unit claims, media-text relation and supplied memory near-copy checks. At most one controlled quality regeneration; explicit GEMINI/GEMINI_REGENERATED/FALLBACK sources. Rejected packs are not silently normalized into Gemini success.
- Integration: regenerated packs recognized by existing server memory/create flows and Studio status. Media upload still rejects fallback as verified visual analysis. No success claim for unverified media.
- Safe telemetry: correlation ID, tenant digest, model, duration, source outcome, regeneration/fallback flags, counts and enum-only style recipe; no raw provider error/prompt/user text. Retrieval count remains null when not measurable; no fabricated zero count.
- Tests: latest targeted backend 7/7; Flutter module smoke 15/15 including both GEMINI and GEMINI_REGENERATED to scheduled queue. Earlier in this phase full backend 69/69, full Flutter 79/79 and analyze clean. After final claim-boundary/time-alias checks the repeated full backend run was interrupted on the user's credit instruction; latest targeted tests pass. Do not report a new completed full regression or an 80-test full Flutter run.
- Limits: fixtures only; real Gemini output quality not yet provider-smoked. Deterministic text checks cannot prove every vision fact/location/property. Conservative high-risk claim checks complement prompt grounding. New professional fields are not yet preserved by the old v2 memory storage; that extension is FAZ 7. Hashtag strategy still uses the prior logic until FAZ 6. UI details/alternatives controls and measured timing remain later phases.
- Exact next task on resume: FAZ 6 separate Hashtag Strategy Engine (broad/niche/local/branded/intent; Minimal/Balanced/Discovery; organic vs paid; relevance, dedupe, competitor/spam filtering, controlled variety), wired into generated packs and Studio inputs; isolated tests then phase regressions/analyze and a separate commit.
- Remaining order: FAZ 7 Content Memory + original/final edits + retrieval + Copy Style + assisted/hybrid/AdVise-first; FAZ 8 real Performance/Timing + organic/paid separation/provenance/confidence; FAZ 9 campaign recommendation quality + Studio explainability; FAZ 10 additive DB/migration rehearsal; FAZ 11 targeted scheduler validation; FAZ 12 safe remote reconciliation + full tests/build. No final APK before completion.
- Runtime/production/.env/uploads untouched and excluded from commits. Remote reconciliation not performed; no push/main merge/force push/deploy/real ad creation or spend.

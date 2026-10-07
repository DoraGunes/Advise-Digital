# AdVise Digital Handoff

Revision: 7 October 2026. Binding user TXT: `C:/Users/ANL/Downloads/ADVISE_CODEX_MASTER_FINAL_REVISION_2026-10-07.txt`.

- Current branch: `wip/codex-product-redesign-2026-10-05`.
- Revision start: `d82ef4e49147142880bbced726f790698c2177cc`; last committed good source: `ceec0715bfbd3f0b7d8bee73bf71146d4c59389f`. Run `git rev-parse HEAD` for the authoritative current value.
- Completed phases in this revision: FAZ 0, EK FAZ 1A/1B, FAZ 1 cover, FAZ 2 canonical branding, FAZ 3 themes (see progress and git log for phase SHA).
- Partial phase: none. Remaining Gemini quality/hashtags and later master phases have not been implemented in this revision.
- Files being worked on: checkpoint docs only. Theme source, tests and all three platform builds are green; remaining dirty runtime JSON/uploads and untracked fixture/evidence files predate this revision and remain unstaged.
- Migrations created: none.
- Backend tests: 62/62; targeted branding 3/3, cover/ads 18/18, isolated Graph/SDK/HTTP fixtures (no real provider writes).
- Flutter tests: 79/79; targeted branding/layout 8/8 in branding phase; contrast/persistence 27 tests plus all-three-theme module and campaign retry coverage in theme phase.
- Analyze/build: analyze no issues. Android release 508.5s / 58.9 MB; Windows release 155.3s; Web release 115.8s (prior cover Wasm dry run passed). Bundled image hashes/PWA manifest identity/Android launcher pixels/Windows EXE icon pixels verified. Cupertino font warning remains for theme-phase follow-up.
- Exact next task: EK FAZ 5A/5B/5C professional content schema + deterministic validation/one bounded regeneration + relevant grouped hashtag engine + safe telemetry. Focus backend/src/ai.js OUTPUT_SCHEMA, generateContentPack, normalizePack; server content-pack inputs, mobile v14_ai.dart editor, isolated AI tests. Preserve WhatsApp destination and truthful fallback source. Then scheduler, dual memory/copy style/performance/timing, independence, DB and UX in TXT order; no broad repo re-audit.

APK: C:/Users/ANL/Downloads/AdVise-Digital-2026-10-07-branding.apk; SHA256 494C4C197E5F368A982B82B8CE163BE235AECB4D04057B7EF29CF7467673B48C. Existing debug signing preserved. Matching new backend required for secure ad creation. Web: mobile/build/web. Windows: mobile/build/windows/x64/runner/Release (copy the whole folder, not EXE alone).

Latest theme APK: C:/Users/ANL/Downloads/AdVise-Digital-2026-10-07-theme.apk; SHA256 4BC1DB282EE61465240B7201A63868882192249937D6CDD8E2A8A9063DC6FEAD; 340.6s / 59.0 MB. Canonical packaged assets and all Android launcher/adaptive/splash pixels verified. Android app version/application ID/signing unchanged. Latest Web rebuild 157.1s; Windows rebuild 156.1s; canonical bundled PNGs/manifest/icon pixels verified. Windows requires the entire Release folder including updated data/app.so, not the unchanged native EXE alone.

Branding generator: `node backend/scripts/generate-branding.mjs --icon "C:/Users/ANL/Downloads/icon.jpeg" --logo "C:/Users/ANL/Downloads/logo.jpeg"`. Canonical copies also exist in mobile/assets/branding if Downloads files are missing later. Do not replace them with old A/globe artwork.

## Commands to continue

From repo root: `git status`, `git branch --show-current`, `git rev-parse HEAD`, `git log --oneline -15`.

From `backend`: `npm test`.

From `mobile`: `flutter analyze --no-fatal-infos --no-pub`, `flutter test --no-pub`.

Read ADVISE_PROGRESS.md for phase acceptance and SHA history. Never add all files indiscriminately: pre-existing dirty runtime JSON and uploads must remain unstaged.

## Known risks / constraints

- Local and origin/WIP histories diverge: the remote had four additional reference commits and local has this revision's separate phase commits. No automatic merge/reset/force push; inspect before any integration. Commit authority is now explicit, replacing previous no-commit instructions.
- Normal push was attempted and rejected non-fast-forward; no remote mutation occurred. Continue on local source-of-truth; integration must be reviewed separately.
- Ads now use a bounded, tenant/account-locked saga in runtime ad_operations.json. Keep its partial IDs and STARTED checkpoints on rollout/rollback. Never blindly replay RECONCILE. Failed activation may leave active remote ancestors; inspect/pause on the provider before reconciliation.
- Preflight fails closed on unavailable permission/asset evidence. System-user tokens that cannot report /me/permissions may need a separately verified token-debug path in future; do not silently bypass permission checks.
- Identical ads payload on the same API/account reuses the saved local request ID after app restart. Intentionally creating another identical ad will need an explicit new-operation UX; never auto-clear a pending key.
- Actual Meta permission/OAuth/WhatsApp validation and real ad spend cannot be tested on production in this task; use isolated provider fixtures and explicit read-only preflight contracts.
- Prior Gemini image and synthetic AVI smoke succeeded on lite fallback; primary model quota was restricted. This revision must not silently call fallback a fresh Gemini result.
- Follow-up in quality/error phase: 2xx strategy unavailable GEMINI_* messages still pass through generic string-based AppError in UI; preserve safe structured category/message instead. Move Random.secure request ID generation inside create try/finally and fail closed if stable request identity preference storage returns false before remote creation. No real provider validation inferred from isolated tests.
- Canonical APP ICON is the user's `icon.jpeg`; canonical FULL LOGO is `logo.jpeg`. Preserve originals, use real PNG/ICO encoding for platform derivatives.
- Production/runtime/main/Cloudflare are untouched by this revision. .env is never displayed, edited or staged. No deployment or real spending.
- Manual verification still needed: physical Android picker, PWA visual smoke when browser tools are available, native Windows visual smoke without altering an existing production session, genuine Meta permissions and controlled test-account creation after later authorization.
- Live public health read-only check: https://advisedigital.poyrazteknikservis.com.tr/health returned 200, version 16.0.0 / ADVISE_PRODUCT_V16_2026_10_05. It does not advertise adCreateSaga/adsPreflight yet. New APK will explicitly require matching backend for secure ad creation; no production backend upgrade performed.

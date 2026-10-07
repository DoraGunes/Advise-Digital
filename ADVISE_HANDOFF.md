# AdVise Digital Handoff

Revision: 7 October 2026. Binding user TXT: `C:/Users/ANL/Downloads/ADVISE_CODEX_MASTER_FINAL_REVISION_2026-10-07.txt`.

- Current branch: `wip/codex-product-redesign-2026-10-05`.
- Revision start: `d82ef4e49147142880bbced726f790698c2177cc`; last committed good source: `19ceb7795211ed726f3ead3a579f04938d116391`. Run `git rev-parse HEAD` for the authoritative current value.
- Completed phases in this revision: FAZ 0, EK FAZ 1A/1B, FAZ 1 cover, FAZ 2 canonical branding (see progress and git log for phase SHA).
- Partial phase: none. Remaining FAZ 3 and later master phases have not been implemented in this revision.
- Files being worked on: progress/handoff/rollout docs; next EK FAZ 1A/1B targeted files are backend `server.js`, `meta.js`, `ai.js`, `product.js`, `persistence.js` and new ad operation/preflight helpers; Flutter `api.dart`, `app_error.dart`, `social_ads_page.dart`.
- Migrations created: none.
- Backend tests: 62/62; targeted branding 3/3, cover/ads 18/18, isolated Graph/SDK/HTTP fixtures (no real provider writes).
- Flutter tests: 57/57; targeted branding/layout 8/8.
- Analyze/build: analyze no issues. Android release 508.5s / 58.9 MB; Windows release 155.3s; Web release 115.8s (prior cover Wasm dry run passed). Bundled image hashes/PWA manifest identity/Android launcher pixels/Windows EXE icon pixels verified. Cupertino font warning remains for theme-phase follow-up.
- Exact next task: FAZ 3 tokens + Light/Dark/Colorful persistence and contrast. Then all remaining master phases in TXT order. Read focused files mobile/lib/product_ui.dart, main.dart, product_more.dart, product_contrast_test.dart first; no broad repo re-audit.

APK: C:/Users/ANL/Downloads/AdVise-Digital-2026-10-07-branding.apk; SHA256 494C4C197E5F368A982B82B8CE163BE235AECB4D04057B7EF29CF7467673B48C. Existing debug signing preserved. Matching new backend required for secure ad creation. Web: mobile/build/web. Windows: mobile/build/windows/x64/runner/Release (copy the whole folder, not EXE alone).

Branding generator: `node backend/scripts/generate-branding.mjs --icon "C:/Users/ANL/Downloads/icon.jpeg" --logo "C:/Users/ANL/Downloads/logo.jpeg"`. Canonical copies also exist in mobile/assets/branding if Downloads files are missing later. Do not replace them with old A/globe artwork.

## Commands to continue

From repo root: `git status`, `git branch --show-current`, `git rev-parse HEAD`, `git log --oneline -15`.

From `backend`: `npm test`.

From `mobile`: `flutter analyze --no-fatal-infos --no-pub`, `flutter test --no-pub`.

Read ADVISE_PROGRESS.md for phase acceptance and SHA history. Never add all files indiscriminately: pre-existing dirty runtime JSON and uploads must remain unstaged.

## Known risks / constraints

- Local branch is behind origin/WIP by four reference commits. No automatic merge/reset/force push; inspect before any integration. Commit authority is now explicit, replacing previous no-commit instructions.
- Normal push was attempted and rejected non-fast-forward; no remote mutation occurred. Continue on local source-of-truth; integration must be reviewed separately.
- Ads now use a bounded, tenant/account-locked saga in runtime ad_operations.json. Keep its partial IDs and STARTED checkpoints on rollout/rollback. Never blindly replay RECONCILE. Failed activation may leave active remote ancestors; inspect/pause on the provider before reconciliation.
- Preflight fails closed on unavailable permission/asset evidence. System-user tokens that cannot report /me/permissions may need a separately verified token-debug path in future; do not silently bypass permission checks.
- Identical ads payload on the same API/account reuses the saved local request ID after app restart. Intentionally creating another identical ad will need an explicit new-operation UX; never auto-clear a pending key.
- Actual Meta permission/OAuth/WhatsApp validation and real ad spend cannot be tested on production in this task; use isolated provider fixtures and explicit read-only preflight contracts.
- Prior Gemini image and synthetic AVI smoke succeeded on lite fallback; primary model quota was restricted. This revision must not silently call fallback a fresh Gemini result.
- Canonical APP ICON is the user's `icon.jpeg`; canonical FULL LOGO is `logo.jpeg`. Preserve originals, use real PNG/ICO encoding for platform derivatives.
- Production/runtime/main/Cloudflare are untouched by this revision. .env is never displayed, edited or staged. No deployment or real spending.
- Manual verification still needed: physical Android picker, PWA visual smoke when browser tools are available, native Windows visual smoke without altering an existing production session, genuine Meta permissions and controlled test-account creation after later authorization.
- Live public health read-only check: https://advisedigital.poyrazteknikservis.com.tr/health returned 200, version 16.0.0 / ADVISE_PRODUCT_V16_2026_10_05. It does not advertise adCreateSaga/adsPreflight yet. New APK will explicitly require matching backend for secure ad creation; no production backend upgrade performed.

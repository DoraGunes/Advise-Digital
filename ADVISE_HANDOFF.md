# AdVise Digital Handoff

Revision: 7 October 2026. Binding user TXT: `C:/Users/ANL/Downloads/ADVISE_CODEX_MASTER_FINAL_REVISION_2026-10-07.txt`.

- Current branch: `wip/codex-product-redesign-2026-10-05`.
- Revision start / last good commit: `d82ef4e49147142880bbced726f790698c2177cc`. Run `git rev-parse HEAD` for the authoritative current value.
- Completed phases in this revision: FAZ 0 and EK FAZ 1A/1B (see progress and git log for phase SHA).
- Partial phase: none; next FAZ 1 cover validation.
- Files being worked on: progress/handoff/rollout docs; next EK FAZ 1A/1B targeted files are backend `server.js`, `meta.js`, `ai.js`, `product.js`, `persistence.js` and new ad operation/preflight helpers; Flutter `api.dart`, `app_error.dart`, `social_ads_page.dart`.
- Migrations created: none.
- Backend tests: 52/52; new targeted ad flow 11/11, isolated Graph/SDK fixtures (no real provider writes).
- Flutter tests: 53/53 including new 5/5 ads tests.
- Analyze/build: Flutter analyze no issues; release builds remain pending, old artifacts do not count for this revision.
- Exact next task: FAZ 1 cover bytes/decoder validation in backend/src/server.js and Flutter media upload, tests for JPEG/PNG/WebP/extensionless/corrupt/mismatch. Then canonical branding conversions and themes.

## Commands to continue

From repo root: `git status`, `git branch --show-current`, `git rev-parse HEAD`, `git log --oneline -15`.

From `backend`: `npm test`.

From `mobile`: `flutter analyze --no-fatal-infos --no-pub`, `flutter test --no-pub`.

Read ADVISE_PROGRESS.md for phase acceptance and SHA history. Never add all files indiscriminately: pre-existing dirty runtime JSON and uploads must remain unstaged.

## Known risks / constraints

- Local branch is behind origin/WIP by four reference commits. No automatic merge/reset/force push; inspect before any integration. Commit authority is now explicit, replacing previous no-commit instructions.
- Ads now use a bounded, tenant/account-locked saga in runtime ad_operations.json. Keep its partial IDs and STARTED checkpoints on rollout/rollback. Never blindly replay RECONCILE. Failed activation may leave active remote ancestors; inspect/pause on the provider before reconciliation.
- Preflight fails closed on unavailable permission/asset evidence. System-user tokens that cannot report /me/permissions may need a separately verified token-debug path in future; do not silently bypass permission checks.
- Identical ads payload on the same API/account reuses the saved local request ID after app restart. Intentionally creating another identical ad will need an explicit new-operation UX; never auto-clear a pending key.
- Actual Meta permission/OAuth/WhatsApp validation and real ad spend cannot be tested on production in this task; use isolated provider fixtures and explicit read-only preflight contracts.
- Prior Gemini image and synthetic AVI smoke succeeded on lite fallback; primary model quota was restricted. This revision must not silently call fallback a fresh Gemini result.
- Canonical APP ICON is the user's `icon.jpeg`; canonical FULL LOGO is `logo.jpeg`. Preserve originals, use real PNG/ICO encoding for platform derivatives.
- Production/runtime/main/Cloudflare are untouched by this revision. .env is never displayed, edited or staged. No deployment or real spending.
- Manual verification still needed: physical Android picker, PWA visual smoke when browser tools are available, native Windows visual smoke without altering an existing production session, genuine Meta permissions and controlled test-account creation after later authorization.

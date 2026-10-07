# AdVise Digital Handoff

Revision: 7 October 2026. Binding user TXT: `C:/Users/ANL/Downloads/ADVISE_CODEX_MASTER_FINAL_REVISION_2026-10-07.txt`.

- Current branch: `wip/codex-product-redesign-2026-10-05`.
- Revision start / last good commit: `d82ef4e49147142880bbced726f790698c2177cc`. Run `git rev-parse HEAD` for the authoritative current value.
- Completed phases in this revision: none yet; baseline Flutter 48/48.
- Partial phase: FAZ 0 baseline backend/analyzer pending.
- Files being worked on: progress/handoff/rollout docs; next EK FAZ 1A/1B targeted files are backend `server.js`, `meta.js`, `ai.js`, `product.js`, `persistence.js` and new ad operation/preflight helpers; Flutter `api.dart`, `app_error.dart`, `social_ads_page.dart`.
- Migrations created: none.
- Backend tests: running isolated `npm test` (no real provider writes).
- Flutter tests: 48/48 baseline passed.
- Analyze/build: analyzer running; old release artifacts do not count for this revision.
- Exact next task: finish FAZ 0 green baseline and commit; implement ads/strategy bounded request + preflight + idempotent staged creation.

## Commands to continue

From repo root: `git status`, `git branch --show-current`, `git rev-parse HEAD`, `git log --oneline -15`.

From `backend`: `npm test`.

From `mobile`: `flutter analyze --no-fatal-infos --no-pub`, `flutter test --no-pub`.

Read ADVISE_PROGRESS.md for phase acceptance and SHA history. Never add all files indiscriminately: pre-existing dirty runtime JSON and uploads must remain unstaged.

## Known risks / constraints

- Local branch is behind origin/WIP by four reference commits. No automatic merge/reset/force push; inspect before any integration. Commit authority is now explicit, replacing previous no-commit instructions.
- Provider/lock aggregate latency exceeds client timeout; ad create has no persisted saga/key, so retry can duplicate partial remote resources. This is the first implementation priority.
- Actual Meta permission/OAuth/WhatsApp validation and real ad spend cannot be tested on production in this task; use isolated provider fixtures and explicit read-only preflight contracts.
- Prior Gemini image and synthetic AVI smoke succeeded on lite fallback; primary model quota was restricted. This revision must not silently call fallback a fresh Gemini result.
- Canonical APP ICON is the user's `icon.jpeg`; canonical FULL LOGO is `logo.jpeg`. Preserve originals, use real PNG/ICO encoding for platform derivatives.
- Production/runtime/main/Cloudflare are untouched by this revision. .env is never displayed, edited or staged. No deployment or real spending.
- Manual verification still needed: physical Android picker, PWA visual smoke when browser tools are available, native Windows visual smoke without altering an existing production session, genuine Meta permissions and controlled test-account creation after later authorization.

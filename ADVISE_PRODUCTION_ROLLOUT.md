# AdVise Digital — production rollout plan (not executed)

Source branch: `wip/codex-product-redesign-2026-10-05`.
Exact release source commit: pending completed phase/build evidence; do not deploy revision start `d82ef4e` as the completed new revision.

This is a partial development checkpoint: ads/strategy/preflight, decoded Reels covers, canonical branding and themes are implemented. Gemini content quality/hashtags, new dual memory/copy style/performance/timing, independence, scale and final UX/readiness gates remain pending. Do not treat passing current regression tests as completion of the master revision.

## Latest development artifacts

- Android theme APK: `C:/Users/ANL/Downloads/AdVise-Digital-2026-10-07-theme.apk`, SHA-256 `4BC1DB282EE61465240B7201A63868882192249937D6CDD8E2A8A9063DC6FEAD`; 59.0 MB, 340.6s build. Packaged canonical PNG hashes/launcher/adaptive/splash pixels verified. Existing debug signing retained; not a newly configured production signing release.
- Web theme build: `mobile/build/web`, 157.1s; main.dart.js SHA-256 `e00ebabef587929752f03750c2f5e23436a38e369b4e5d5d64eff22ab5ba87a8`; manifest/PWA/favicon/canonical image hashes match. Prior Wasm dry run passed; this rebuild uses --no-wasm-dry-run. Existing Cupertino font warning/manual glyph smoke remains noted.
- Colorful is stored in the existing productTheme preference; legacy system/light/dark values remain valid. Unknown preference values safely select system. No backend settings or runtime migration required for themes.
- Production health remains the older build without adCreateSaga/adsPreflight. Secure creation in the new APK requires a separately authorized matching backend rollout. No real Meta permission success or real Gemini quality acceptance claimed.

## Added runtime contracts — 7 October revision

- `ad_operations.json` is runtime state, not source. Back it up with runtime data; retain STARTED, partial Meta IDs and RECONCILE states on upgrade and rollback. Deleting it could permit duplicate remote creation.
- New client ad creation requires `adCreateSaga` and `adsPreflight` health capabilities. Upgrade backend/client together. Old clients without a request ID receive REQUEST_ID_REQUIRED.
- Preflight reads actual scopes/account tasks/Page/IG/WhatsApp evidence and fails closed. Verify authorized token type in read-only smoke before claiming readiness. No live Meta permissions checked in this development run.
- Cover processing requires sharp and its native platform package. Run clean `npm ci` on the deployment OS and decode JPEG/PNG/WebP before switching traffic. Dependency/lock synchronization verified locally.
- Reconcile failed activation before retry: the ad activates last; campaign/adset ancestors may already be active. Never blindly replay an ambiguous create/activation.

## Preconditions

Human production authorization is mandatory. This task only prepares source, tests, local build artifacts and this plan; no production/main/Cloudflare change is authorized.

1. Record exact source SHA, passing phase/regression tests and artifact hashes.
2. Back up production data/uploads and verify recovery independently. Keep .env/secrets in their current runtime location; exclude them from source commits, artifacts and logs.
3. Apply any explicitly documented, idempotent memory migration on a backup first. No migration exists yet for this revision.
4. Deploy/restart only the authorized matching backend; avoid mixed old/new schedulers over the same data directory. Preserve existing Cloudflare DNS/routes/secrets unless separately authorized.
5. Verify unauthenticated `/health` version and precise capabilities, then authenticated tenant isolation/role checks without printing credentials.
6. Read-only Meta/Instagram preflight, Gemini source/model/failure status, valid Reels cover JPG/PNG/WebP, queue UTC/local conversion, scheduler restart/idempotency and Memory Palace writes.
7. Deploy matching Web/PWA only after authorization; preserve manifest identity/scope/start_url and check refresh/install/cache. Distribute exact Android/Windows artifacts.
8. Any actual ad creation/activation or publish smoke uses a separately authorized test account/budget. Preflight/dry-run alone is not proof of a successful live publish.

## Rollback

Pause the authorized new scheduler before switching runtime source. Restore the previous known-good source/runtime artifact and its dependency lock. Keep data and durable provider operation IDs: never reset JSON or delete partial ad/publish state to hide failures. If a data migration exists, use its verified backup/rollback procedure; do not apply source git reset to runtime data. Recheck health, tenant auth, scheduler claim safety and existing Cloudflare routing. Record rollback source SHA and result in handoff.

# Manual content and local history

This branch changes preparation to manual mode. No production files, OAuth connections, secrets, runtime JSON or uploads are included in this change. It is not deployed.

- Content Studio explicitly selects a photo or Reels, user-written caption and optional future time.
- Saving uploads media with useAI=false and autoPublish=false. Future-time records are READY; unscheduled records are MANUAL.
- Saving never publishes to Instagram. Existing queue publication remains a separate confirmed action.
- Old AI routes return HTTP 410 AI_REMOVED before multipart processing. The Gemini SDK dependency is removed.
- Old automatic ad and publication flags are disabled in effective settings. Existing records remain intact. Scheduled hours are stored, but no timer publishes in manual mode.
- Manual ad creation retains preflight, budget caps, idempotency and PAUSED by default. Activation still requires explicit user action.
- Local Memory reads tenant-owned posts, explicit times, manual ad logs and previously measured performance. No metrics are fabricated and missing measurements remain unavailable.
- Reusing a caption copies text only. It does not requeue or republish its source post.
- New ad logs retain the user-selected budget, destination, geography and resulting initial status. This is creation history, not a substitute for measured ad results.

## Validation

The manual-content-verify workflow runs Node syntax, new manual-mode tests, the active backend regression suite, Flutter analysis and the active Flutter suite. It has no APK, EXE, Web build, deployment or provider-write job. All provider writes in retained regression tests are fixture mocks.

SDK/generation-only test suites are retired with the removed provider. Mixed regression suites are migrated to manual mode while retaining publication, storage, tenant, budget, request identity and UI safety checks. Historical AI memory fixtures remain valid read-only data.

## Rollout and rollback

Review the commit and passing checks first. Backend and client must both be updated through a separately approved release; an old client can otherwise still display retired AI controls. No production update is authorized by committing this branch.

Before an approved transition, take a fresh verified code/runtime backup and check the exact running PID, directory and environment. Preserve .env, active runtime data, uploads and OAuth. Deploy code/dependencies only, keep cron disabled, and verify authenticated GETs and record hashes before any upload.

Rollback restores code/dependencies only. Never overwrite current runtime data with an older snapshot. The old automatic flags may still exist in preserved settings, so the rollback process must keep cron disabled and must not run automation or publication. Confirm the restored process and record integrity before reopening clients.

Real file uploads, Instagram publication and Meta ad creation require separately approved smoke tests. Fixture MP4 transport acceptance does not prove codec or real Instagram publishing compatibility.

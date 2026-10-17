# AdVise Digital — Codex continuation, 17 October 2026

## Purpose
Continue the EXISTING AdVise Digital app from the latest GitHub branch feat/consented-ad-optimization. This continuation branch is codex/advise-v5-mobile-continuation-2026-10-17. The user is away from the Windows PC for 2 days; prefer Codex Cloud and GitHub Actions rather than local desktop access. Inspect the code before changing it.

## Product policy
- Main product: Meta advertisement management, measurement and permission-gated optimization. Keep Reklam Merkezi visible and useful on Android.
- Ad automation defaults OFF. ONE_TIME and CONTINUOUS consent are separate, account-scoped, bounded by spend/budget limits; CONTINUOUS evaluations every 12 hours, no manually paused ad ever reopened automatically.
- Manual-first content studio; the user pastes their own copy. Gemini text/media/prompt generation ONLY on explicit user request. Never auto-create ad copy.
- Instagram scheduled publishing permission is separate from ad optimization. When OFF, choosing a time cannot publish. When enabled by explicit user request, honor schedules without backlog floods or duplicate posts.
- Persist decisions and reasons in audit and performance memory; do not fabricate metrics.

## Prior verified checkpoints
- Windows V4: Flutter analyze PASS; Flutter tests 97/97 PASS; packaged locally without touching V3.
- Consented optimization backend tests previously reported 138/138 PASS on feat/consented-ad-optimization, but feature was NOT deployed to production.
- GitHub Actions android-test-apk.yml successfully built an internal/test-signed Android APK on feature branch (green 6m43s run, one artifact), after CI change d5bb257.
- Existing production Meta WhatsApp ad 6993882140081 was verified PAUSED/PAUSED and zero measured spend at last read. Do not activate or modify.
- AdVise production API historically https://advisedigital.poyrazteknikservis.com.tr, local port 3001 at work PC. Production/version/backend and feature branch differ.
- 3 READY and 3 PUBLISHED posts appeared in Android screenshots. Preserve tenant data.

## Android APK V4 problems directly confirmed in remote GitHub source and on user's phone
- mobile/lib/product_shell.dart: enum has ads but third tab is labeled Hafıza Sarayı; _root(2) loads ManualMemoryPage, hiding Reklam Merkezi.
- mobile/lib/content_home.dart: manual-content-first homepage 'Hazırla. Sıraya koy. Paylaş.' with no advertisement dashboard.
- mobile/lib/product_more.dart: sends users to Meta Ads Manager rather than AdVise ad management.
- mobile/lib/content_queue_page.dart: oversized cards/buttons on narrow mobile; scheduled READY posts actually require manual publishing.
- mobile/lib/manual_memory.dart: mostly word counts, limited performance insight; no invented metrics.
- Material NavigationBar five multiline labels on a narrow phone, overly large text/padding and wasted space.
- Build/test passing did not verify business-correct mobile navigation or realistic small-screen UI.

## Work plan: Android V5 repair
1. Check exact Git SHA and current routes and find the existing working Ads Center/Meta account and opt-in optimization components. Do not wholesale restore old branches.
2. Reconnect mobile Reklam Merkezi and account/campaign/performance/consent views, with honest compatibility feedback if production API lacks staging features.
3. Mobile-first 360 / 393 / 412dp responsive UI: compact and accessible navigation, typography, spacing, safe areas and queue cards. Keep themes, studio, Reels cover, queue, memory.
4. Investigate safe opt-in scheduled content publishing separately; existing users have 3 READY queued posts, avoid accidentally publishing elapsed slots.
5. Add widget/golden tests for phone sizes and functional navigation, run Flutter analyze/test and backend-relevant regression tests. Only report actual results.
6. Trigger safe GitHub Actions Android TEST APK from this continuation branch (adjust CI branch trigger if needed), provide exact artifact URL, SHA256, Android installation guidance. Do not build or deploy Windows binary while away.

## Strict rules
- DO NOT TOUCH Poyraz Teknik (port 3000 / PostgreSQL / repository / services).
- Do not touch production AdVise runtime, OAuth, tokens, secrets, .env, uploaded media, or database.
- No main merge, no prod deploy/restart, no active Meta ads, no ad state/budget changes, no new ad, no live Instagram post or automatic scheduler enable.
- Do not delete Windows V3/V4, do not replace real user data, do not claim local Windows GUI tests from cloud.
- Commit small scoped changes to codex/advise-v5-mobile-continuation-2026-10-17; never force-push. Report any divergence from feature branch before reconciling.

## Report format
Show actual code changes and commit, tests, Android screenshot evidence (or say unavailable), GitHub Actions run/artifact link, and any missing production backend API features. Start by reading this handoff and verifying current source.
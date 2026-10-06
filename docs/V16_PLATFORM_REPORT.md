# AdVise Digital V16 platform and client verification

Audit date: 2026-10-05. Final client verification: 2026-10-06; release builds are being recorded below.

## Shared client

- One Flutter codebase serves Android, browser/PWA and Windows.
- Version: `16.0.0+16`.
- The default API remains `https://advisedigital.poyrazteknikservis.com.tr`; release builds do not override it with localhost or a LAN address.
- API URL preferences survive restarts and reject embedded credentials, query strings and fragments. Changing the API origin (host, scheme or non-default port) clears the client session before any request goes to that origin; path changes on the same origin preserve it.
- Remembered sessions use the existing SharedPreferences storage. Session-only login keeps the token in memory and removes its persisted copy.
- Authenticated 401 responses notify the app to return to login, including multipart uploads.
- Network retries apply only to GET. POST, PUT, PATCH and DELETE are never retried automatically.
- Caption editing uses PATCH, now explicitly supported by the central request dispatcher.
- AppError converts infrastructure errors to Turkish messages and excludes raw HTML, JSON, stacks and credential-bearing diagnostics from display.

## Compatibility protections

The client checks `/health` for version 16 or newer and the real `productExperience` capability. Health results used by action guards expire after 60 seconds; changing the API URL or logging out clears that cache. An explicit compatibility refresh reads health again.

The root task checked public and local `/health` on 2026-10-06 at 06:45 UTC: both running backends reported `14.0.0` without capabilities. Cloudflare access is working, while that running backend has not loaded the V16 source. No restart or deploy was performed.

- Precise-time upload/queue mutations require `scheduledPublishing` before any file upload or mutation occurs.
- Gemini ad review requires `geminiAdReview`.
- Applying Gemini decisions requires `safeAutomationV16`.
- AI campaign strategy requires the actual `campaignStrategy` endpoint capability.
- An older backend gets a clear server-update message. The client cannot silently confirm a timestamp that an older server ignored.

## Media selection

`MediaAccess` uses the installed image_picker implementation: Android gallery/photo picker, native Windows file_selector dialog and browser file input. `XFile` survives through the upload path; all multipart uploads use file bytes and the selected filename. MediaPreview reads image bytes, avoids reading videos and caps preview-source size at 24 MiB. Video selection remains supported; its preview shows a video-ready indicator rather than an invented playback feature.

Existing branding is reused for Android density icons, Windows multi-resolution ICO and browser regular/maskable icons. `mobile/tool/package_brand_assets.ps1` reproduces those assets from the existing logo.

## Windows

- Existing native scaffold preserved.
- Product window title and executable metadata use AdVise Digital.
- Initial window: 1360×820 logical pixels.
- Minimum: approximately 1100×700, adjusted for DPI and capped to the monitor work area so smaller laptop displays can still contain the full window.
- Native picker and external-browser URL launcher remain existing installed plugins.
- No installer/signing/MSIX infrastructure was added.
- Ship the complete Release directory with its DLLs and data directory; the executable alone is insufficient.

## PWA

- Manifest name, description, language, colors and orientation match the product and permit desktop use.
- Initial HTML loading state uses existing branding.
- A small network-first service worker caches only public app files.
- API responses, uploaded media, requests with Authorization, POST requests and other origins are never intercepted or cached.
- This caches an application shell; it does not create offline analytics, offline login or fake offline mutations.
- No production hosting, DNS, Worker, route or secret was changed.

## Android

- Existing manifest permissions and photo-picker dependencies are preserved.
- Production URL is HTTPS. The pre-existing cleartext flag remains for development/local configuration compatibility.
- No connected Android device/emulator was found at the initial audit, so APK compilation does not establish a real-device end-to-end pass.
- The existing release Gradle configuration uses the debug signing configuration. No production signing setup or keystore was added or changed; the generated APK remains a local verification build.

## Toolchain

Initial read-only doctor audit found Flutter 3.47.5, Dart 3.13.4, Visual Studio Community 2026 18.10.2 with the Windows C++ toolchain and SDK, Chrome and Edge. Android SDK 36 exists; doctor warns that cmdline-tools are missing and license status is unknown. Previous APK builds completed, but this warning remains a setup limitation.

## Verification results

- Initial focused AppError/API/media suite: 15 passed, 2026-10-05.
- Focused analyzer: no issues, 2026-10-05.
- PWA worker contract: passed again on 2026-10-06. It checks exclusion of API/upload/auth/cross-origin/mutation requests and caching of public files only.
- Final full Flutter suite: 48/48 passed on 2026-10-06. Coverage includes old-backend action blocking, API-origin session isolation, capability-cache invalidation, PATCH caption edits, responsive layouts, read-only roles, queue reconciliation, account currency, light/dark contrast and the Studio-to-Planner flow with an isolated API fixture.
- Final `flutter analyze --no-fatal-infos --no-pub`: no issues, 2026-10-06.
- Web release build: passed on 2026-10-06, exit 0 (333.7 seconds). Wasm compatibility dry run also passed. The compiler emitted a CupertinoIcons font warning, although the application source contains no CupertinoIcons references; the used MaterialIcons font was packaged.
- Windows release build/archive: pending. Native executable startup is intentionally skipped.
- Android release build: pending.

## Expected artifact paths

- Web directory: `C:\Users\ANL\Desktop\AdVise AI-FINAL\mobile\build\web`
- Windows directory: `C:\Users\ANL\Desktop\AdVise AI-FINAL\mobile\build\windows\x64\runner\Release`
- Windows executable: `C:\Users\ANL\Desktop\AdVise AI-FINAL\mobile\build\windows\x64\runner\Release\advise_digital.exe`
- APK: `C:\Users\ANL\Desktop\AdVise AI-FINAL\mobile\build\app\outputs\flutter-apk\app-release.apk`

These are expected paths until the final build result and fresh output timestamps are recorded.

## Remaining limits

- Desktop drag and drop is optional and has not been added; native file selection is available.
- Native encrypted session-token storage remains a future improvement. Existing SharedPreferences storage is retained for compatibility; no real token was inspected or displayed.
- Browser refresh/session behavior is covered by client tests and shared session restore; production authenticated flows, real Meta writes, spending, OAuth authorization and public publishing are excluded from these local checks.
- Local browser visual smoke was attempted after the web build, but CUA reported every configured browser unavailable (`browsers=[]`; in-app, Chrome and Edge each returned `Browser is not available`). No browser screenshot or visual pass is claimed. Shared interface behavior is covered by the widget/layout tests.
- Native Windows startup is intentionally excluded: a pre-existing branded SharedPreferences file was found by an existence check. Launching the normal app could restore that session and make an authenticated production request. That file was not opened, altered or removed. No additional smoke mode was added. Native UI automation is also unavailable; layout/widget tests cover the shared interface within that limit.
- Production must load the matching V16 backend before the new product capabilities are enabled. This task does not deploy or restart production.

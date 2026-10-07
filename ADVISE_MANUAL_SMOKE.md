# AdVise checkpoint manual smoke — pending

This is a development checkpoint, not completion of the entire master revision. No production deployment, real ad creation/spending or real Instagram publishing was performed. Automated fixture tests do not count as live provider success.

## Completed automated evidence

- Backend 62/62; Flutter 79/79; analyze clean.
- Android APK, Windows release and Web release built locally.
- Canonical PNG hashes match packaged outputs; Android launcher/adaptive/splash pixels and Windows embedded icon match; PWA manifest identity unchanged.
- Public production health returned HTTP 200; new adCreateSaga/adsPreflight capabilities absent. Matching backend rollout requires separate authorization.

## Manual checks (not yet checked)

- [ ] Login on a physical Android device with the checkpoint APK.
- [ ] Launcher/adaptive/splash/full logo display and aspect ratio.
- [ ] Light theme and large text on the device.
- [ ] Dark theme and dialogs/forms on the device.
- [ ] Colorful theme: More > Görünüm > Renkli; restart and check selection/contrast on device.
- [ ] AI Studio real image analysis with an authorized matching backend.
- [ ] Caption quality (quality-contract phase pending).
- [ ] Hashtag relevance/quantity (hashtag-engine phase pending).
- [ ] AI campaign suggestion success/quota/unavailable messages.
- [ ] Ad form validation, duplicate click, error retry and success state.
- [ ] Read-only Meta preflight with the actual authorized token/assets.
- [ ] Controlled provider sandbox creation only after explicit authorization; no real spend.
- [ ] Reels JPG and uppercase JPEG picker/upload on Android, Web and Windows.
- [ ] Reels PNG with alpha and misleading MIME/filename.
- [ ] Reels WebP; corrupt and oversize rejection preserves old cover.
- [ ] Queue/schedule with Istanbul local time, restart and duplicate protection.
- [ ] Memory preserves AI original and final edits (new dual-memory phase pending).
- [ ] Performance metrics/provenance/timing samples (new phase pending).
- [ ] Explicit Gemini vs fallback source and confidence.
- [ ] Tenant isolation under two genuine test accounts.

Use the production rollout plan only after completing all remaining master phases and obtaining production authorization. Never delete ad operation state or replay RECONCILE to make a smoke check appear successful.

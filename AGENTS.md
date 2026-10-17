# Codex working agreement — AdVise V5 continuation

Before editing, read CODEX_CONTINUATION_2026-10-17.md in this branch. This is an existing product, not a new app.

- Primary goal: restore premium, mobile-first Meta Reklam Merkezi and consented ad-optimization UX in Android; fix cramped five-tab navigation and oversized queue cards.
- Keep manual-first Content Studio; AI generation only upon direct user action. Publishing and advertisement-optimization permissions remain separate and OFF by default.
- Work only in this continuation branch, do not merge to main or deploy production without explicit user approval.
- Preserve Meta OAuth, PAUSED advertising states, all runtime content and user data. No live publishing, no ad budget/state changes, no background jobs enabled.
- Never touch Poyraz Teknik, port 3000 or PostgreSQL.
- Use Flutter tests and mobile viewport tests (360, 393, 412dp); do not fake passing tests; run Android GitHub Actions TEST artifact workflow and report exact URLs.
- Treat any local Windows-only production state as unavailable in Codex Cloud. Do not copy secrets/.env/runtime data into GitHub.
- If a change needs a matching backend API not present in live production, deliver staged code and label the feature not live-ready.

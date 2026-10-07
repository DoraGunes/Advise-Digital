# Database migration policy

AdVise currently keeps its live runtime/user state in the existing JSON persistence layer. The SQL files in this folder are **preparation only** until a production migration is explicitly approved.

Rules:

- Migrations must be additive and idempotent.
- Never drop, truncate, rename, or overwrite existing runtime tables as part of automatic startup.
- Never convert missing provider metrics to zero. Unknown values remain explicit in JSON/JSONB payloads.
- Every learning table is tenant-aware and should be queried with `tenant_id` in the predicate.
- The application must continue to work with JSON persistence until an explicit cutover plan is executed.
- Production migration execution is a separate operational step and is not performed by this repository change.

Prepared migration: `migrations/20261007_ai_memory_scale.sql`.

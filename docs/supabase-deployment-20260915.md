# Band Practice database deployment — September 15, 2026

The availability/practice reliability migration is deployed to **Heavy Band Manager** (`vjjwrkyxudgiihjgyqtd`), the project configured by the app. Remote migration version: `20260915152617`, name: `harden_availability_and_practices`. The local migration filename matches that history entry.

## Verification

- Preflight found zero duplicate practice windows; no existing records needed correction or removal.
- All **30 maintained pgTAP assertions** in `supabase/tests/database/availability_and_practice_races.test.sql` passed inside the deployment transaction using the project's actual schema, grants, RLS, and authenticated/anonymous roles.
- Coverage: successful calendar/weekly replacements, stale revision rejection, manual-mode and practice-window changes, member ownership, anonymous denial, duplicate practice rejection, and restoration of prior data/revision after injected insert failures.
- Test output was collected and checked by a PL/pgSQL assertion gate. Any failed assertion or a passing count other than 30 would raise an exception and abort deployment.
- Test-only changes lived inside a savepoint rolled back before commit: two synthetic Auth users, a synthetic band and memberships, availability and practice records, temporary pgTAP installation, and failure-injection triggers/function. No Auth sign-up or outbound messaging API was used.
- A separate post-commit query confirmed zero remaining test users/bands/functions/triggers and no remaining pgTAP extension. Existing production counts stayed at 39 memberships and 15 practices.
- All four RPCs exist with their expected argument signatures, `SECURITY INVOKER`, empty search paths, authenticated execute grants, and anonymous execute denial. The non-null revision column defaults to zero and has the required authenticated column-update grant. The unique practice-window constraint is present. PostgREST schema reload was requested.

These are real database integration checks with simulated JWT claims, not a signed-in device-to-API walkthrough. Earlier mock Simulator tests and production-conditional builds are recorded in [the reliability report](bug-fixes-20260915.md). This follow-up deployed the backend; it did not create or submit a new App Store build. Older app versions that write availability tables directly still bypass the revision contract until upgraded.

## Security advisor comparison

No new findings appeared. Existing findings remain: two RLS-enabled internal tables without policies, eight authenticated-callable security-definer helper functions, and disabled leaked-password protection. These were not changed by this migration. Reference guidance: [RLS policy lint](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [security-definer execution lint](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [leaked-password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Reproduction and provenance

The repository migration contains only the reusable schema changes. The deployment envelope additionally installed pgTAP temporarily, ran the maintained test suite without its outer BEGIN/ROLLBACK, asserted its results, and rolled the test savepoint back. On a local Supabase test database, run the maintained suite normally through `supabase test db` after applying migrations.

- Schema SQL SHA-256: `054eb9eccd5a696c4bf3e21d9e69353ad4ffb1b97b5d89cdd4a82f902044ee9b`
- Maintained test SHA-256: `30109aebeb5f0fffe58e6a19bea8ef03b6a6a690d3a8974e33e5967c6ffa4cfa`
- Applied envelope SHA-256: `087b6a3d740e38fc80cd9ea501adb979b181a0826b562def2173c31676f08fa9`
- Local deployment envelope and preparation script: `/private/tmp/band-supabase-deploy-20260915/` (temporary evidence; this report preserves the outcome).

No credentials or personal record contents are included in this report.

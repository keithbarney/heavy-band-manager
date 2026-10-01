# Development checkpoint — October 1, 2026

The accumulated practice editing, widgets, calendar reconciliation and push implementation is committed on `codex/current-design-availability-tab`; the branch is pushed with a matching upstream. This is a development checkpoint, not a claim of live notification delivery.

Fresh checks: five worker transport tests passed; credential-pattern scan found no embedded secret tokens/private keys in changed files; staged diff check passed. Repaired the pinned DialKit 0.2.0 revision in the ignored phone build cache without changing the dependency version. Phone build-settings inspection then succeeded. Keith’s saved iPhone is available.

Installed local provisioning profiles for the Band Practice app still lack `aps-environment`; they are not usable for the current push entitlement. No new phone build was installed. Need a compatible APNs key, push-enabled signing/profile configuration, worker/Vault activation, and physical notification/calendar verification. The APNs key setup question is pending with Keith. Full Supabase-local testing remains unverified as documented in practice-push.md. Earlier 30-unit-test/Release/native-flow evidence remains in that document. The older detached design worktree remains preserved locally and was not merged.

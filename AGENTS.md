# AGENTS.md (project-local)

Supplements the global AGENTS.md with rules specific to terraform-provider-neon.

## Project Context

**Contract**: Justin is contracted for Neon (Aug 2026 onward) to migrate terraform-provider-neon off the deprecated SDK v2 onto the Plugin Framework and to add three new resources: `neon_bucket`, `neon_functions`, `neon_triggers`. The repo is a fork of `neondatabase/terraform-provider-neon` at `randoneering/terraform-provider-neon`.

**Upstream tracking**: migration progress tracked in `neondatabase/terraform-provider-neon` issue #28.

## Team and Timezones

- Justin (contractor, owns neon_functions): Boise, UTC-7
- Dmitry (peer reviewer, previous provider maintainer): Berlin, UTC+1/+2
- Andre (gates merges, Neon): San Francisco, UTC-8

## Operating Model

- **Trunk-based development.** Short-lived feature branches, frequent merges to main.
- **Async.** Real-time overlap across the three timezones is minimal. Status updates go in openspec change artifacts and PR descriptions, not chat.
- **Peer review.** Dmitry reviews Justin's PRs and vice versa.
- **Merge gate.** Ping Andre when a PR is ready to merge. He has the final say.

## SDK Constraint

`github.com/kislerdm/neon-sdk-go` is the only Go SDK for Neon. New resources may require SDK additions. Coordinate with Dmitry (he is the upstream SDK maintainer) before adding raw HTTP calls in `internal/provider/`.

### Polymorphism gotcha (trigger, future oneOf types)

`Trigger`, `TriggerCreateRequest`, `TriggerUpdateRequest` at v0.24.0+ use an embedded-struct layout (`Type` outer string + `ScheduleTrigger` + `StorageObjectCreatedTrigger` embedded). v0.26.0 added a custom `MarshalJSON` (request bodies serialize correctly) but no matching `UnmarshalJSON` (response bodies silently unmarshal to all-zero values because Go's `encoding/json` drops overlapping promoted fields). Result: apply succeeds at the API, terraform reports `unknown value` for `enabled`, `function_path`, `inherited`, `next_run_at`, `version`. Same shape for any future oneOf discriminator the SDK adds.

v0.24.0 was retracted by Dmitry for the same polymorphism class. v0.22.0 used a fundamentally different API (`map[string]any`); no clean downgrade exists. Until the SDK adds `UnmarshalJSON`, any apply that creates polymorphic resources will leave the resource on Neon with broken state tracking. Manual cleanup of orphans is required after failed applies.

## Conventions Refined Through This Contract

Three resource-design rules confirmed with Dmitry while building `neon_trigger`. Apply them to every new resource, not just trigger:

- **Flatten single-field nested blocks.** A `SingleNestedAttribute` wrapping one field forces a pointer-to-struct model (e.g. `*scheduleModel`) and a code-only type. Prefer flat `StringAttribute` (e.g. `cron = "* * * * *"` instead of `schedule { cron = ... }`). Reserve nested blocks for 2+ semantically-grouped fields where the grouping carries meaning (e.g. `storage_object_created { bucket_name, prefix }`). When in doubt, flatten.

- **Avoid client-side validators on free-text fields.** Don't add `LengthBetween`, `RegexMatches`, or similar to fields like cron expressions, slugs, bucket names, or prefixes. The server validates these and returns a clearer error than a client-side check can. Reserve validators for type discriminators and known enum values where the SDK exposes an explicit constructor (e.g. `neon.NewScheduleTriggerType`).

- **State-based Check reads in acceptance tests.** Inside `Check` blocks, every assertion reads `state.RootModule().Resources["neon_<name>.this"].Primary.Attributes["<attr>"]`. Round-tripping through `client.ListProjects` to find a project we just created is the pattern to avoid. The `t.Cleanup` SDK sweep stays for project teardown after the test.

These rules are also encoded in `.agents/skills/neon-tf/adding-neon-resource/SKILL.md` (Common Mistakes section) and the migration skill. AGENTS.md is the quick reference; the skill files have the rationale.

## Local Provider Testing

- **`dev_overrides` requires `neondatabase/neon` source format**, not `local/...`. The `local/` namespace triggers Terraform's registry discovery at `https://local/.well-known/terraform.json`, which doesn't exist in newer Terraform versions. Use `source = "neondatabase/neon"` in `required_providers` and match it in `~/.terraformrc` (`dev_overrides "neondatabase/neon" = "..."`).
- **Provider binary lives at `~/.terraform.d/plugins/neondatabase/neon/dev/linux_amd64/terraform-provider-neon_vdev`.** Build from repo root with `go build -o terraform-provider-neon_vdev .` then move/overwrite.
- **Clean state when changing provider source.** If the state file references an old provider source, delete `terraform.tfstate*` before re-running `terraform init`; otherwise init fails with the discovery error.

## Current Deadline

Two weeks from 2026-08-31 for `neon_functions`, `neon_bucket`, possibly `neon_triggers` go-live. Scope and cutting decisions belong to the team, not to assumptions.

---
name: migrating-neon-sdkv2-to-framework
description: Use when porting an SDK v2 resource to terraform-plugin-framework on this fork. Triggers on requests like "port neon_<x> to framework", "migrate <resource> off SDK v2", "convert the SDK v2 schema", "ship the framework version of <resource>", or any task that reads `provider/resource_*.go` on the legacy randoneering fork alongside `provider/` on the sync fork.
---

# migrating-neon-sdkv2-to-framework

## Overview

A migration is a net-new framework resource plus three new failure modes the net-new recipe does not cover: schema-compat (the framework schema must be a superset of the SDK v2 schema), state-compat (an existing SDK v2 state JSON must apply cleanly to the framework resource without forced re-plan), and side-by-side registration (the SDK v2 resource stays registered until the framework version is proven, because real users have existing state). Skip any of the three and you break downstream consumers.

## When to Use

- Porting an SDK v2 resource from the legacy fork to framework on this fork.
- Pilot candidates: lowest-traffic SDK v2 resources first (lowest blast radius if state-compat fails).

Not for: net-new resources (use `adding-neon-resource`), bug fixes in shipped framework resources, or schema additions that don't change the SDK v2 reference.

## Core Pattern

Eleven steps, in this order. Skip nothing.

1. **Pick the lowest-traffic SDK v2 resource.** Use `git log --oneline -- provider/resource_<x>.go` on the legacy fork to estimate churn. Lowest churn = lowest blast radius if state-compat fails.
2. **Open the migration openspec change.** `openspec/changes/migrate-neon-<x>-to-framework/` with `proposal.md`, `design.md` (with explicit rollback section), `tasks.md`, `specs/neon-<x>-framework/spec.md`. The rollback section names the SDK v2 release that contained the resource and the procedure to revert.
3. **Pre-flight read of the SDK v2 source.** Open `provider/resource_<x>.go` on the legacy fork. Capture: schema attributes, CRUD shape, ForceNew set, sensitive fields, composite ID format, Import path, helpers used (especially `parseComplexID`), any FSM wrapping (likely absent in SDK v2).
4. **Author `provider/resource_<x>.go` on the sync fork.** Same ten-file shape as `adding-neon-resource`: framework wiring, FSM wrapping, ImportState, ModifyPlan, out-of-band deletion tolerance. Every attribute from the SDK v2 schema MUST appear on the framework schema (compat). New attributes are allowed.
   - **REQUIRED BACKGROUND: `adding-neon-resource`** for the schema design rule on `types.String` (model struct only) vs. Go standard types (helpers, SDK wrappers, FSM callbacks, `tflog` payloads). The same rule applies when porting: SDK v2 `*string` and `*time.Time` fields map to `types.String` on the model struct and Go-standard types in helper structs and FSM inputs.
5. **Author the compat tests.** Two files, both required to merge:
   - `provider/resource_<x>_schema_compat_test.go` — asserts the framework schema's attribute set is a superset of the SDK v2 schema's attribute set. Type and Required/Optional/Computed must match exactly for any attribute that exists in both.
   - `provider/resource_<x>_state_compat_test.go` — loads a fixture SDK v2 state JSON, calls the framework resource's `Schema`/`Configure`/`Read`, asserts the resulting state equals the input (no forced re-plan).
6. **Author `provider/acc_<x>_test.go`.** Same four-subtest minimum as `adding-neon-resource`: create+read, forced-replace, import, out-of-band deletion. State-based `Check` reads.
7. **Register framework resource alongside SDK v2.** Both `Resources(...)` entries remain in `provider/provider.go` during the migration window. The framework version uses `TypeName = "neon_<x>"`; the SDK v2 entry stays registered only until step 11. **Do not collide `TypeName` values — Terraform plugin protocol rejects duplicates.**
8. **Verify.** `go vet ./...`, `go build ./...`, `go test ./provider/... -short`, `make testacc` with `TF_ACC=1` and `NEON_API_KEY`. Compat tests run as part of the short suite.
9. **Run `make docu`.** Generated doc replaces `docs/resources/<x>.md`.
10. **Update `CHANGELOG.md`** with the migration note. SDK bump flag if `go.mod` changed.
11. **Remove the SDK v2 entry from `provider/provider.go` only after** `make testacc` is green AND the state-compat test is green AND the openspec change's rollback section has been reviewed. The deprecation window is one minor version; users have that long to migrate their state.

## Quick Reference

| Concept | Value |
|---|---|
| SDK v2 reference location | `provider/resource_<x>.go` on legacy fork |
| Compat test schema location | `provider/resource_<x>_schema_compat_test.go` |
| Compat test state location | `provider/resource_<x>_state_compat_test.go` |
| Compat test fixture state | committed JSON next to the test file |
| Migration openspec path | `openspec/changes/migrate-neon-<x>-to-framework/` |
| Rollback procedure location | `design.md` of the migration openspec |
| SDK v2 resource removal timing | After `make testacc` green AND one minor version deprecation window |

## Common Mistakes

- **Writing the framework resource without the compat tests.** Real users have existing SDK v2 state. A schema change that drops or renames an attribute forces a destructive re-plan for every consumer. Compat tests catch this in CI before merge.
- **Dropping the SDK v2 entry from `provider/provider.go` the moment the framework resource ships.** Without the deprecation window, a user who upgrades their provider version gets a hard state loss. The SDK v2 entry stays for one minor version.
- **Picking the highest-traffic SDK v2 resource as the pilot.** State-compat failures on a high-traffic resource break the most users. Pilot on the lowest-traffic first.
- **Forgetting sensitive attributes that are read-back.** SDK v2 resources like `neon_role` return secrets on Create and never on Read. The framework version must mirror that: `Sensitive: true` on the schema, `tflog` payloads never include the value, and `Read` returns `types.StringNull()` (not the original value).
- **Forgetting `parseComplexID` shape differences.** The SDK v2 `parseComplexID` returns a struct with named fields. Framework resources hand-roll the parse inline because the framework's `ImportState` has a different return shape. Don't import the SDK v2 helper.
- **Inheriting "no FSM" from the SDK v2 source.** The SDK v2 resources largely skip `projectReadiness.Retry`. The framework pilot always uses it. Migration is the right moment to add FSM wrapping, not preserve the gap.
- **Treating the SDK v2 resource catalog spec as optional without verifying it exists.** Grep `openspec/` for `sdk-v2-resource-catalog` first. If found, mark `neon_<x>` as "framework-only" once step 11 completes. If not found, record the absence in the migration openspec change's `tasks.md` so the team can decide whether to create one. Do not assume the spec exists.
- **Skipping the openspec change entirely.** The migration is non-trivial and benefits from explicit proposal, design (with rollback), and spec. Treat it as a first-class change, not a code edit.

---
name: sdk-version-gate-check
description: Use when deciding whether to bump `go.mod` to a new `kislerdm/neon-sdk-go` release. Triggers on requests like "should we bump the SDK", "evaluate v0.X.0", "is v0.X.0 safe", "plan the SDK upgrade", "audit SDK impact", or any task that reads `go.mod` and `provider/resource_*.go` against a candidate SDK version.
---

# sdk-version-gate-check

## Overview

A SDK bump is a risk analysis, not a version chase. The v0.22.0 release shipped a broken `CreateProjectBranchFunctionDeployment` method; v0.23.0 fixed it. Downstream users who upgraded lost state. A bump that touches more than two resources, or any method that has been broken in a prior release, is a multi-PR effort and probably a "wait" decision. The recipe below produces a documented decision in the openspec archive either way.

## When to Use

- Considering a `go.mod` bump against a new `kislerdm/neon-sdk-go` release.
- Auditing which resources are affected by a candidate SDK version.
- Writing a rollback plan before a bump lands.

Not for: net-new resource work (use `adding-neon-resource`), SDK v2 to framework porting (use `migrating-neon-sdkv2-to-framework`), or patching a resource for a single method bug.

## Core Pattern

Eight steps, in this order. The decision lands in the openspec change regardless of "bump" or "wait".

1. **Open the bump openspec change.** `openspec/changes/bump-neon-sdk-go-v<X>/` with `proposal.md`, `design.md` (with explicit Rollback section), `tasks.md`, and `specs/sdk-bump-decision/spec.md`. Do this even if the decision ends up being "wait" — the decision record is the artifact.
2. **Read the canonical release notes.** `https://github.com/kislerdm/neon-sdk-go/releases/tag/v<X>` for the candidate version. Quote the relevant Added/Changed/Deprecated/Removed sections in the openspec change's `design.md`. Do NOT rely on the README or go.sum hashes — the GitHub releases page is the only canonical source.
3. **Enumerate every SDK call site on this fork.** Run `grep -rE "r\.client\.\w+\(" provider/` and `grep -rE "client\.\w+\(" provider/`. Capture the per-resource list in the openspec change's `design.md`. This is the surface area of the bump.
4. **Cross-reference the call sites against the new SDK source.** Read `kislerdm/neon-sdk-go/<new-version>/client.go` (or the regenerated OpenAPI client) for each called method. Identify which methods have signature changes, return-type changes, or removals. For each affected method, name the resource file and the line range that needs to change.
5. **Cite the v0.22.0/v0.23.0 historical lesson.** Read `openspec/changes/add-neon-functions/` and identify the specific commit hash or upstream issue that documented the `CreateProjectBranchFunctionDeployment` regression. Quote it in the openspec change's `design.md`. Any candidate bump that touches a method that has been broken in a prior release is a red flag; the openspec change must call this out explicitly.
6. **Decide: bump, wait, or partial.** Bump = every affected resource has a code PR ready. Wait = state the trigger for re-evaluation ("re-evaluate when v0.X.1 ships" or "re-evaluate when upstream issue #N closes"). Partial = bump now for the additive-only changes, defer the breaking changes; this requires two openspec changes (one for the bump, one for each deferred breaking change).
7. **Update CHANGELOG.md and `go.mod`.** For a bump decision: update CHANGELOG with `### Changed` and the new SDK version. Run `go mod tidy`. For a wait decision: do NOT modify `go.mod`. Update CHANGELOG with `### Deprecated` and the wait reason.
8. **Document the rollback plan.** In the openspec change's `design.md` Rollback section, name the specific PRs to revert, the specific commands to run (`git revert <sha>`, `go mod edit -require=...`, `go mod tidy`), and the specific communication channels (GitHub release note, Discord/Slack, GitHub issue thread). Reference the v0.22.0/v0.23.0 rollback procedure as a worked example.

## Quick Reference

| Concept | Value |
|---|---|
| Canonical release notes URL | `https://github.com/kislerdm/neon-sdk-go/releases/tag/v<X>` |
| SDK method call site grep | `grep -rE "r\.client\.\w+\(" provider/` and `grep -rE "client\.\w+\(" provider/` |
| Bump openspec path | `openspec/changes/bump-neon-sdk-go-v<X>/` |
| Decision spec path | `openspec/changes/bump-neon-sdk-go-v<X>/specs/sdk-bump-decision/spec.md` |
| Historical lesson reference | `openspec/changes/add-neon-functions/` — Functions resource migration |
| Team consultation | Per `AGENTS.md`: Dmitry reviews SDK-affecting PRs, Andre gates merges on the sync fork |
| Re-evaluation trigger | Required field in the wait decision record |
| Rollback timing target | 24 hours from regression confirmation to revert commit |

## Common Mistakes

- **Inventing release notes rather than reading the canonical source.** The bump decision is only as good as the audit of the new SDK. Read the GitHub releases page. Quote it in the openspec change. Rationalizations to refuse: "v0.25.0 is the latest, just bump" (latest doesn't mean safe; the audit is what justifies the bump), "the SDK handles backward compat" (typed methods break at compile time, not at runtime — there is no graceful backward compat here), and "the release notes are too short to matter" (short release notes are a red flag, not a green light).
- **Doing the per-method audit by mental enumeration rather than grep.** Every method call site must be enumerated. The grep pattern is in Quick Reference. Run it; paste the output into the openspec change. Rationalizations to refuse: "mental enumeration is faster" (faster ≠ correct; missed call sites = silent runtime breakage), "the grep is noisy" (filter the grep, but run it), and "the SDK is small" (small SDKs still surprise you; the v0.22.0 regression was on a single method).
- **Skipping the openspec change because the decision is "wait".** A wait decision is still a decision. The openspec change is the record that lets a future agent re-evaluate without re-doing the work. Rationalizations to refuse: "the bump is small" (small in code change ≠ small in user impact; the openspec is a 30-minute effort), "no one will re-evaluate" (the openspec is the artifact that makes future re-evaluation cheap), and "I'll just keep the decision in my head" (decisions in heads don't survive handoffs).
- **Skipping the CHANGELOG entry for a wait decision.** Downstream readers of the CHANGELOG need to know that v0.X.0 was evaluated and deferred, with the trigger for re-evaluation. Rationalizations to refuse: "wait decisions don't appear in CHANGELOG" (they do; under `### Deprecated`), "the trigger is obvious" (a trigger is rarely obvious to the next person), and "users don't care about deferred bumps" (users care about which versions were evaluated and rejected, and why).
- **Citing the v0.22.0/v0.23.0 lesson without naming the specific commit or issue.** "There was a regression once" is not a citation. Read `openspec/changes/add-neon-functions/` and pull the commit hash. Rationalizations to refuse: "the lesson is widely known" (cite it anyway; citations are how known things stay known), "the SDK has been fixed since" (the relevant question is whether the SAME method is touched again, not whether the SDK is generally healthier), and "Dmitry remembers" (Dmitry's memory is not a citation).
- **Producing a generic rollback plan.** "Revert the PR and run go mod tidy" is not enough. Name the specific PRs (or the single PR if it's a one-PR bump), the specific revert commands, and the specific communication channels.
- **Deciding "wait" without specifying the re-evaluation trigger.** A wait decision without a trigger is a decision to never bump. State the trigger explicitly: the next patch release, an upstream issue closing, or a specific SDK milestone.
- **Skipping team consultation for a multi-resource bump.** Per `AGENTS.md`, SDK-affecting PRs are reviewed by Dmitry (SDK maintainer) and gated by Andre (merge gate on sync fork). A multi-resource bump without that sign-off is a process violation.
- **Running `go mod tidy` against the new version before the audit.** Tidy can pull indirect dependency changes that mask the direct SDK impact. Audit first, tidy second.

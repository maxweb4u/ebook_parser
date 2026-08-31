---
title: FT-XXX Feature Template - Implementation Plan
doc_kind: feature
doc_function: template
purpose: Governed wrapper template for an implementation plan. Defines how to instantiate an execution document without redefining canonical problem or solution facts and without mixing the wrapper with target `implementation-plan.md`.
derived_from:
  - ../../feature-flow.md
  - ../../../dna/frontmatter.md
  - ../../../engineering/testing-policy.md
status: active
audience: humans_and_agents
template_for: feature
template_target_path: ../../../features/FT-XXX/implementation-plan.md
---

# Implementation Plan

This file describes the wrapper template. The instantiated `implementation-plan.md` lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

Requirements, blocker-state, and acceptance criteria are defined in sibling `brief.md`. If `brief.md` records `Design required: yes`, selected design, accepted local decisions, and solution-level contracts are defined in sibling `design.md` or ADR. This document defines only work sequencing and execution checkpoints.
In the created feature package, sibling `brief.md` is always instantiated from the canonical template in `memory_bank/flows/templates/feature/`; `design.md` is instantiated only when required.

Create this document only when sibling `brief.md` records `Plan required: yes` and after upstream owners are ready: sibling `brief.md` has `status: active`, and required sibling `design.md` has been moved to `status: active`. A feature with `Plan required: no` follows the no-plan lifecycle and never instantiates this template. When a v2 brief has no Plan Requirement Decision, current plan presence follows V2 Missing Plan Decision Compatibility; current work adds an explicit decision before intentionally changing that topology. While the plan is still being formed, `implementation-plan.md` itself may remain in `status: draft`; before planned execution moves to `delivery_status: in_progress`, the plan must become `status: active`.

Instantiating this document expands the package: create or update package-level `README.md` and the feature registry route according to `feature-flow.md`.

Evaluate closed stages first: any new Design or Plan trigger discovered after `Done` or `Cancelled` becomes follow-up work and must not mutate the closed package. During active work, a new Plan trigger stops downstream work, sets `brief.md` to `Plan required: yes`, moves this plan to `status: draft`, and requires `Plan Ready` before resuming. A new Design trigger also moves this plan and `design.md` to `status: draft`, sets Design Requirement to `yes`, and requires `Solution Ready` before the plan is updated and re-approved.

When the feature moves to `delivery_status: done` or `delivery_status: cancelled`, `implementation-plan.md` is archived if it is no longer used as a working execution document.

The document must be executable without additional interpretation. If a step cannot be linked to canonical IDs, existing solution refs, an artifact, a check, or an explicit manual procedure, the step is underspecified.
The plan must be grounded in the current repository state: first record relevant modules, local patterns, open questions, and execution environment, and only then write the change sequencing.
The plan must explicitly record which automated tests will be added or updated for the change surface, which suites must be green locally and in CI, and which coordinated manual gaps require sequencing, rollback/cleanup, handoff, or plan-owned approval. One bounded no-plan gate belongs in `brief.md` instead.

If the feature changes visible UI, markup, or styles, keep design-system grounding lightweight: link or mention the relevant frontend/design-system owner only when it affects the plan, and record a brief reuse note only when adding a new local visual pattern or rejecting an obvious existing component.

For a compact feature package, keep the execution plan to the smallest executable set: current goal, grounding / reference points, test strategy, preconditions, work order, and ready-for-acceptance. Add open questions, environment contracts, workstreams, approval gates, parallelization, checkpoints, risks, stop conditions, or plan-local evidence only when they are real execution controls. Delete unused placeholder sections instead of preserving the whole template.

For references inside the plan, use stable identifiers according to the taxonomy in [../../feature-flow.md#stable-identifiers](../../feature-flow.md#stable-identifiers).

If an unknown changes scope, acceptance criteria, or evidence contract, it is first raised upstream in sibling `brief.md`. If an unknown changes selected design, C4 architecture model, accepted local decisions, contracts, or rollout/backout semantics, it is first raised in required sibling `design.md` or ADR and only then appears in the plan.

## Instantiated Frontmatter

```yaml
title: "FT-XXX: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution plan for implementing FT-XXX. Records discovery context, steps, risks, and test strategy without redefining canonical problem and solution facts."
derived_from:
  - brief.md
  # Required only when brief.md says "Design required: yes":
  # - design.md
  # Optional support refs:
  # - runtime-surfaces.md
  # - ui-reference/README.md
  # - use-cases/README.md
status: draft
audience: humans_and_agents
must_not_define:
  - ft_xxx_scope
  - ft_xxx_selected_design
  - ft_xxx_acceptance_criteria
  - ft_xxx_blocker_state
```

## Instantiated Body

```markdown
# Implementation Plan

## Current Plan Goal

Which delivery outcome this plan must produce given `brief.md` and, if present, the already accepted solution.

## Grounding / Support References

Which upstream canonical and support docs are used as the execution baseline. Support docs do not redefine canonical facts: on conflict, update the owner document before continuing.

| Document | Role in this plan | Facts reused | Conflict action |
| --- | --- | --- | --- |
| `brief.md` | canonical problem / verify owner | `REQ-*`, `SC-*`, `CHK-*`, `EVID-*` | Update `brief.md` first |
| `design.md` / `none` | conditional solution owner | `SOL-*`, `C4-*`, `SD-*`, `CTR-*`, `INV-*`, `FM-*`, `RB-*` | Update `design.md` or ADR first; if design is absent, promote new design facts before planning |
| `runtime-surfaces.md` / `none` | optional grounding | `SURF-*`, `MAP-*`, context matrix | Promote changed design facts to `design.md` if design is required |
| `ui-reference/README.md` / `none` | optional interface reference | `UI-*`, mockups, states | Promote changed requirements to `brief.md` or design facts to `design.md` if required |
| `use-cases/README.md` / `none` | optional scenario companion | `FUC-*`, `TC-*` candidates | Keep canonical acceptance in `brief.md` |

## Current State / Reference Points

Which existing files, modules, commands, or documents the agent must study before starting changes. This section records grounding in the current repository state and local patterns that must not be ignored.

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `path/to/module` | What this artifact already does | Why correct planning is impossible without it | Which pattern, helper, command, or contract must be mirrored |

For user-visible surfaces (screens, messages, extension popup, HTTP contracts), one concise row is enough when reuse of an existing surface affects the plan, for example: existing notification shape reused, new field needed, or no matching surface found.

## Test Strategy

Which test surfaces must be updated during implementation. This section records expected automated coverage, required local/CI gates, and manual-only exceptions for the change surface, without redefining canonical test cases from `brief.md`.

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites / commands | Required CI suites / jobs | Manual-only gap / justification | Manual-only approval ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `path/or/behavior` | `REQ-01`, `SC-01`, `NEG-01`, `CHK-01`, `SOL-01 if design exists` | What is covered now | Which suite, test type, or deterministic check must be added or updated | Which commands or suites must be green locally | Which jobs or suites must be green in CI | What temporarily remains manual-only and why | `AG-01` / review link / `none` |

## Open Questions / Ambiguities

Which unknowns remain after discovery. If a question changes upstream semantics, it must not be silently resolved inside an execution step.

| Open Question ID | Question | Why unresolved | Blocks | Default action / escalation owner |
| --- | --- | --- | --- | --- |
| `OQ-01` | What exactly is unknown | Why this has not been proven yet | `STEP-02` / `WS-1` / whole plan | What we do by default and who decides on escalation |

## Environment Contract

Which execution environment is acceptable for the plan: setup, test commands, env vars, permissions, mocks, external dependencies, and other operational assumptions.

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| setup | Which environment preparation is required | `STEP-01`, `STEP-02` | Which symptom shows that the environment is invalid |
| test | Which command or procedure is the reference verify for this stage | `CHK-01` | What counts as unreliable verify |
| access / network / secrets | Which accesses, domains, keys, or sandbox assumptions are needed | `STEP-03` | When work must stop and escalate |

## Preconditions

What must be ready before work starts: data, access, ADR, environment, agreements. Each row links to a canonical ref and does not retell its meaning in new words.

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-01` | `CON-01` / `DEC-01` / `SD-01 if design exists` / ADR path / design-not-required decision | Which upstream state is acceptable for starting | `STEP-01`, `STEP-02` | yes / no |

## Workstreams

Split the work into independent streams with an explicit result for each.

| Workstream | Implements | Result | Owner | Dependencies |
| --- | --- | --- | --- | --- |
| `WS-1` | `REQ-01`, `SOL-01 if design exists`, `CTR-01 if design exists` | What must appear | human / agent / either | What blocks start or completion |

## Approval Gates

Which actions must not be performed without explicit human confirmation. Use this section for risky, irreversible, costly, or externally effective operations.

| Approval Gate ID | Trigger | Applies to | Why approval is required | Approver / evidence |
| --- | --- | --- | --- | --- |
| `AG-01` | Which step or symptom requests approval | `STEP-03` / `WS-2` | Why autonomous continuation is not allowed | Who confirms and how it is recorded |

## Work Order

Describe execution as atomic steps. Each step must be small enough to verify and, if necessary, roll back or stop without spreading the change surface.

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command / procedure | Blocked by | Needs approval | Escalate if |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-01` | human / agent / either | `REQ-01`, `SOL-01 if design exists`, `CTR-01 if design exists` | What we do in this step | Which files, services, or data we touch | What must exist after the step | `CHK-01` | `EVID-01` | How completion is confirmed | `PRE-01`, `OQ-01` | `AG-01` / `none` | When continuation requires escalation |

## Parallelizable Work

Which steps or workstreams can be executed in parallel without conflict over change surface.

- `PAR-01` What can happen in parallel.
- `PAR-02` What must not be parallelized because of shared write surface.

## Checkpoints

Which intermediate points must be passed before rollout or handoff.

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-01`, `CHK-01`, `SOL-01 if design exists` | Which intermediate state must be proven | `EVID-01` |

## Execution Risks

Which practical risks can break schedule or require rebuilding the plan.

| Risk ID | Risk | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- |
| `ER-01` | What can go wrong | What this breaks | What we do ahead of time | Which signal activates mitigation |

## Stop Conditions / Fallback

When the plan must stop or roll back to a safe state.

| Stop ID | Related refs | Trigger | Immediate action | Safe fallback state |
| --- | --- | --- | --- | --- |
| `STOP-01` | `DEC-01`, `RJ-01`, `SD-01 if design exists` | Which symptom makes us stop | What we do immediately | Which state we roll back to or freeze at |

## Plan-local Evidence

Which evidence artifacts belong to the execution plan itself and are not the canonical evidence contract from `brief.md`.

| Evidence ID | Artifact | Producer | Path contract | Reused by checkpoints |
| --- | --- | --- | --- | --- |
| `EVID-09` | For example, simplify-review verdict, discovery note, or manual approval note | implementer / reviewer / human approver | Where it lives or how it is recorded | `CP-01` |

## Ready For Acceptance

Which conditions must hold before the plan is considered exhausted and the final acceptance from sibling `brief.md` `Verify` is used.

- All workstreams are completed or explicitly stopped through `STOP-*`.
- All checkpoints have evidence.
- Required local suites are green, and CI does not contradict local verify.
- Manual-only gaps are closed through approved `AG-*` or remain blockers for `delivery_status: done`.
- Support docs, if any, do not contradict canonical `brief.md`, existing `design.md`, ADR, and this plan.
- Final acceptance uses `brief.md` `Verify`, not this checklist.
```

---
title: "FT-XXX: Design Template"
doc_kind: feature
doc_function: template
purpose: 'Governed wrapper template for feature-local `design.md`. Defines the solution-space layer: selected approach, rationale, contracts, failure modes, and design-pack routing without mixing with problem space or execution contract.'
derived_from:
  - ../../feature-flow.md
  - ../../../dna/frontmatter.md
status: active
audience: humans_and_agents
template_for: feature
template_target_path: ../../../features/FT-XXX/design.md
canonical_for:
  - feature_design_template
---

# FT-XXX: Design

This file describes the wrapper template. The instantiated `design.md` lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

Create `design.md` when the feature introduces or materially changes solution semantics: architecture, a shared contract/protocol/data flow/trust model, approach selection, trade-offs, invariants, failure modes, rollout/backout, new or feature-specifically interpreted ADR/C4 dependencies, or a multi-document design pack. Reusing an established integration pattern or accepted ADR for another consumer does not require this document when those semantics stay unchanged; bounded owner/application notes remain in `brief.md`.

Instantiating this document expands the package: create or update package-level `README.md` and the feature registry route according to `feature-flow.md`.

If a Design trigger is discovered during active work, pause planning or execution, update sibling `brief.md` to `Design required: yes`, retain its Plan Requirement unless a separate Plan trigger applies, ensure this design and any existing implementation plan have `status: draft`, and pass or re-pass `Solution Ready`. If Plan Requirement is `yes`, update the draft plan and re-pass `Plan Ready`; if it is `no`, keep the plan absent and resume through No-plan Execution.

During analysis, always fill the C4 applicability decision. A C4 artifact is required only when a trigger from [feature-flow.md#c4-analysis-requirements](../../feature-flow.md#c4-analysis-requirements) requires C1/C2/C3/C4; for a local feature, `C4-00 not required` with a reason is enough.

`design.md` does not replace `brief.md`: requirements, acceptance criteria, evidence contract, and any bounded no-design pattern notes remain in `brief.md`. `design.md` is also not an execution carrier: file-level touchpoints, atomic steps, test commands, and checkpoints belong to required `implementation-plan.md`; on the no-plan path, bounded gates remain in `brief.md` and transient implementation notes/results stay in the issue / PR.

For a compact feature package, keep only sections that own real solution facts. The minimum useful shape is Design Pack, Context, C4 Applicability, Selected Solution, and Traceability. Add alternatives, trade-offs, contracts, invariants, failure modes, rollout/backout, or ADR dependencies only when they materially affect implementation or review. Delete unused placeholder sections instead of leaving empty tables.

If the solution space is split across several artifacts, `design.md` becomes the design-pack index and records the owner of each design fact. Do not duplicate canonical facts from ADR, C4, data-flow, or other design docs; link to them.

## Instantiated Frontmatter

```yaml
title: "FT-XXX: Design"
doc_kind: feature
doc_function: canonical
purpose: "Solution-space document for FT-XXX. Records the selected approach, rationale, contracts, failure modes, and design-pack routing without redefining problem space or execution contract."
derived_from:
  - brief.md
status: draft
audience: humans_and_agents
must_not_define:
  - ft_xxx_scope
  - ft_xxx_acceptance_criteria
  - ft_xxx_evidence_contract
  - implementation_sequence
```

## Instantiated Body

```markdown
# FT-XXX: Design

## Design Pack

If the design-pack consists only of this file, leave one row for `design.md`. If there are ADRs, C4, data-flow, diagrams, or contract notes, add them to the table and name the canonical owner.

| Artifact | Role | Owns |
| --- | --- | --- |
| `design.md` | Feature-local solution owner | `SOL-*`, `ALT-*`, `TRD-*`, `C4-*`, feature-local `CTR-*`, `INV-*`, `FM-*`, `RB-*` |
| `../../adr/ADR-<id>-short-decision-name.md` | Architecture decision | Which design choice belongs to the ADR |

## Context

Briefly describe the design problem: why the requirements from `brief.md` require an explicit decision, and which upstream docs or constraints matter for the choice.

## C4 Applicability

The decision is made before `Solution Ready`. Choose the minimum C4 level or explicitly record that C4 is not needed.

| C4 ID | Decision | Trigger / reason | Artifact |
| --- | --- | --- | --- |
| `C4-00` | `not required` / `C1` / `C2` / `C3` / `C4` | Why C4 is not needed or which trigger requires the selected level | `none` / link to diagram |

### C4 Artifact

If `C4-00` is not `not required`, add a diagram or link to a design-pack artifact. Use the lowest sufficient level:

- `C1` - System Context: actors/external systems/trust boundaries.
- `C2` - Container: deployable/runtime nodes, queues, stores, protocols.
- `C3` - Component: modules/services/state machines inside a container.
- `C4` - Code: only when class/interface-level structure is an architecture decision.

## Selected Solution

- `SOL-01` Selected solution element and why it covers `REQ-*`.
- `SOL-02` Second solution element, if needed.

## Optional Design Detail

Use only the subsections below that carry real feature-local design facts. Delete this section and any unused subsections for compact packages.

## Alternatives Considered

| Alternative ID | Option | Why not selected |
| --- | --- | --- |
| `ALT-01` | Alternative approach | Reason it was rejected or deferred |

## Trade-offs

| Trade-off ID | Decision | Benefit | Cost / Risk |
| --- | --- | --- | --- |
| `TRD-01` | Which compromise we accept | What we gain | What we pay or monitor |

## Accepted Local Decisions

Only accepted feature-local decisions live here. Decisions at reusable, architectural, or cross-feature level are moved into ADR.

- `SD-01` Which local decision was accepted and why it does not require an ADR.

## Contracts

Describe contracts at the shape/semantics level. Do not add realistic secrets, production IDs, or file-level implementation steps.

| Contract ID | Input / Output | Producer / Consumer | Semantics / Constraints |
| --- | --- | --- | --- |
| `CTR-01` | What changes | Who writes / who reads | What must remain true |

## Invariants

- `INV-01` What must remain true regardless of implementation path.

## Failure Modes

- `FM-01` What can go wrong and how the solution must limit it.

## Rollout / Backout

| Stage ID | Stage | Entry condition | Backout |
| --- | --- | --- | --- |
| `RB-01` | How the change is enabled | What must be proven before entry | How to return to a safe state |

## ADR / External Design Dependencies

| Artifact | Current status | Used for | Rule |
| --- | --- | --- | --- |
| `../../adr/ADR-<id>-short-decision-name.md` | `proposed` / `accepted` | Which choice or baseline it defines | `proposed` does not count as finalized design |

## Traceability

| Requirement ID | Solution refs | Contracts / invariants | Failure / rollout refs |
| --- | --- | --- | --- |
| `REQ-01` | `SOL-01`, `TRD-01`, `C4-00`, `SD-01` | `CTR-01`, `INV-01` | `FM-01`, `RB-01` |
```

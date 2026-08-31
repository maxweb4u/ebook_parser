---
title: "FT-XXX: Runtime Surfaces Template"
doc_kind: feature-support
doc_function: template
purpose: Governed wrapper template for optional `runtime-surfaces.md`. Read this when a feature needs grounding in current runtime surfaces, semantic mappings, context variants, fallback/error paths, or adjacent boundaries.
derived_from:
  - ../../../feature-flow.md
  - ../../../../dna/frontmatter.md
status: active
audience: humans_and_agents
template_for: feature-support
template_target_path: ../../../../features/FT-XXX/runtime-surfaces.md
canonical_for:
  - feature_support_template_runtime_surfaces
---

# FT-XXX: Runtime Surfaces Template

This file describes the wrapper template. The instantiated `runtime-surfaces.md` lives inside the feature package as an optional support/reference doc.

## Wrapper Notes

Create `runtime-surfaces.md` if it is hard to understand current entrypoints, concrete surfaces, semantic mappings, context availability, or fallback/error behavior without separate grounding.

Instantiating this support document expands the package: create or update package-level `README.md` and the feature registry route according to `feature-flow.md`.

`runtime-surfaces.md` does not own requirements, selected design, acceptance criteria, checks, evidence contract, or implementation sequence. If runtime mapping changes scope or selected design, update sibling `brief.md`, required `design.md`, or ADR.

## Instantiated Frontmatter

```yaml
title: "FT-XXX: Runtime Surfaces"
doc_kind: feature-support
doc_function: reference
purpose: "Grounding reference for FT-XXX. Records current runtime surfaces, semantic mapping, adjacent boundaries, and context notes without redefining canonical problem or solution facts."
derived_from:
  - brief.md
  # Required only when design.md exists:
  # - design.md
status: draft
audience: humans_and_agents
must_not_define:
  - ft_xxx_scope
  - ft_xxx_selected_design
  - ft_xxx_acceptance_criteria
  - implementation_sequence
```

## Instantiated Body

```markdown
# FT-XXX: Runtime Surfaces

## Role

This document records grounding. Canonical owners:

- `brief.md` owns problem space and verify inventory.
- `design.md`, if present, owns selected design, target architecture, and contracts.
- required `implementation-plan.md` owns execution sequencing; on the no-plan path, bounded controls stay in `brief.md` and transient execution notes stay in the issue / PR.

## Current Surface Inventory

| Surface ID | Current entrypoint / trigger | Current concrete surface | Current guaranteed context | Notes |
| --- | --- | --- | --- | --- |
| `SURF-01` | How the surface is reached today | Route / handler / job / screen / process | Which data is guaranteed to be available | What matters for the feature |

## Adjacent Out-of-Scope Surfaces

| Surface | Why adjacent | Why excluded |
| --- | --- | --- |
| `adjacent-surface` | Why it is near the feature | Which `NS-*`, ADR, or solution boundary excludes it |

## Semantic Mapping

| Mapping ID | Semantic unit | Current reachable surfaces | Why semantic unit is stable |
| --- | --- | --- | --- |
| `MAP-01` | Stable business/runtime unit | `SURF-01`, `SURF-02` | Why we must not bind only to a specific route/file/template |

## Target Mapping Reference

| Semantic unit | To-be owner / responsibility | Covered surfaces | Related solution refs |
| --- | --- | --- | --- |
| `semantic-unit` | Who owns the unit after changes | `SURF-01` | `SOL-01`, `C4-L2-01`, `CTR-01` |

## Context Matrix

| Surface / semantic unit | Always available | Optional | Must not assume | Related refs |
| --- | --- | --- | --- | --- |
| `SURF-01` | Which data is always present | Which data may be present | What must not be considered guaranteed | `CTR-01` |

## Resolution / Decision Table

| Condition | Decision | Result | Observability expectation | Related refs |
| --- | --- | --- | --- | --- |
| Which state/mode/input | What runtime chooses | What happens | How this is visible in logs/UI/evidence | `SOL-01`, `FM-01` |

## Notes For Execution

- Which paths/modules must be considered in required `implementation-plan.md` or in no-plan issue / PR execution notes; do not turn this support doc into a sequence.
- Which ambiguities force `Plan required: yes` and must become `OQ-*`.
- Which stop conditions must be included in the required plan if mapping is not confirmed.
```

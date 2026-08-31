---
title: "FT-XXX: Feature Use Cases Template"
doc_kind: feature-support
doc_function: template
purpose: Governed wrapper template for optional feature-local `use-cases/README.md`. Read this when a feature needs review-friendly scenarios and derived test case candidates without moving canonical acceptance out of `brief.md`.
derived_from:
  - ../../../feature-flow.md
  - ../../../../dna/frontmatter.md
status: active
audience: humans_and_agents
template_for: feature-support
template_target_path: ../../../../features/FT-XXX/use-cases/README.md
canonical_for:
  - feature_support_template_use_cases
---

# FT-XXX: Feature Use Cases Template

This file describes the wrapper template. The instantiated `use-cases/README.md` lives inside the feature package as an optional derived companion.

## Wrapper Notes

Create feature-local `use-cases/README.md` if the scenario set becomes hard to review: many happy/edge/error cases, several user roles, or a convenient `FUC -> REQ -> CHK` mapping is needed.

Instantiating this support document expands the package: create or update package-level `README.md` and the feature registry route according to `feature-flow.md`.

This document does not replace canonical `SC-*`, `NEG-*`, `CHK-*`, and `EVID-*` from `brief.md`.

## Instantiated Frontmatter

```yaml
title: "FT-XXX: Feature Use Cases"
doc_kind: feature-support
doc_function: reference
purpose: "Derived use-case companion for FT-XXX. Packages scenarios and test case candidates for review without redefining canonical acceptance inventory."
derived_from:
  - ../brief.md
  # Required only when design.md exists:
  # - ../design.md
status: draft
audience: humans_and_agents
must_not_define:
  - ft_xxx_scope
  - ft_xxx_acceptance_criteria
  - canonical_checks
  - implementation_sequence
```

## Instantiated Body

```markdown
# FT-XXX: Feature Use Cases

## Role

This document provides a review-friendly projection of canonical facts from `brief.md` and existing `design.md`.

Canonical acceptance / test inventory remains in `brief.md` through `SC-*`, `NEG-*`, `CHK-*`, and `EVID-*`.

## Happy Path

| ID | Use case | Description | Primary refs |
| --- | --- | --- | --- |
| `FUC-H01` | Scenario name | What the user does and what result is expected | `REQ-01`, `SC-01` |

## Edge Cases

| ID | Use case | Description | Primary refs |
| --- | --- | --- | --- |
| `FUC-E01` | Edge case name | Which acceptable edge case must work | `REQ-01`, `SC-01` |

## Error Cases

| ID | Use case | Description | Primary refs |
| --- | --- | --- | --- |
| `FUC-ER01` | Error case name | How the system behaves on error | `NEG-01`, `FM-01` |

## Interface Use Cases

Fill this only if the feature changes interface. Screen design details remain in `ui-reference/README.md`.

| ID | Use case | Description | Primary refs |
| --- | --- | --- | --- |
| `FUC-UI01` | User goes through interface flow | Which interface outcome is needed | `REQ-02`, `UI-01`, `SC-02` |

## Derived Test Case Candidates

`TC-*` here are candidates for planning/review and must link to canonical `CHK-*`, not create new checks.

| Test Case ID | Covers | Preconditions | Steps | Expected result | Automation candidate |
| --- | --- | --- | --- | --- | --- |
| `TC-01` | `FUC-H01`, `SC-01`, `CHK-01` | What must be ready | Short procedure | Which outcome is expected | automated / manual / mixed |

## Traceability Matrix

| Use case ID | Requirements | Acceptance refs | Check IDs | Notes |
| --- | --- | --- | --- | --- |
| `FUC-H01` | `REQ-01` | `SC-01` | `CHK-01` | What matters during review |

## Test Ownership

### Automated

- Which use cases must be covered by automated checks.

### Manual

- Which use cases remain manual-only and why; each row must link to canonical `CHK-*`, `EVID-*`, and `AG-*` from compact `brief.md` or the required plan when approval is needed.
```

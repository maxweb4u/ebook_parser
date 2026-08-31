---
title: "FT-XXX: Feature Template - Short Legacy"
doc_kind: feature
doc_function: template
purpose: Legacy v1 wrapper template for a short canonical `feature.md`. Read this only when maintaining an existing v1 feature package; new packages use `brief.md`.
derived_from:
  - ../../feature-flow.md
  - ../../../dna/frontmatter.md
  - ../../../engineering/testing-policy.md
status: active
audience: humans_and_agents
template_for: feature
template_target_path: ../../../features/FT-XXX/feature.md
canonical_for:
  - feature_template_short
---

# FT-XXX: Feature Name

This file describes the wrapper template. The instantiated `feature.md` lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

This is a legacy v1 template kept for compatibility with existing `feature.md` packages. New memory bank v2 packages must start from `brief.md`; see [../../feature-flow.md#version-boundary](../../feature-flow.md#version-boundary).

Use this template only when maintaining or migrating an existing v1 feature package that already uses `feature.md`, and only if the feature fits in one local slice and can be described through `REQ-*`, `NS-*`, one `SC-*`, at most one `CON-*`, one `EC-*`, one `CHK-*`, and one `EVID-*`.

If you need `ASM-*`, `DEC-*`, `CTR-*`, `FM-*`, feature-specific negative cases, more than one acceptance scenario, more than one `CHK-*` / `EVID-*`, or explicit ADR-dependent design logic, upgrade to `large.md` before continuing. Prefix meanings are defined in [../../feature-flow.md](../../feature-flow.md#stable-identifiers).

### Frontmatter Quick Ref

The full schema is in [../../../dna/frontmatter.md](../../../dna/frontmatter.md). For a standard feature, this is enough:

| Field | Required | Values / default |
|---|---|---|
| `title` | required | `"FT-XXX: Name"` |
| `doc_kind` | required | `feature` |
| `doc_function` | required | `canonical` |
| `purpose` | required | 1-2 sentences |
| `status` | required | `draft` -> `active` -> `archived` |
| `derived_from` | required for active | upstream documents |
| `delivery_status` | required for feature | `planned` -> `in_progress` -> `done` / `cancelled` |
| `audience` | recommended | `humans_and_agents` |
| `must_not_define` | recommended | what the document does NOT define |

## Instantiated Frontmatter

```yaml
title: "FT-XXX: Feature Name"
doc_kind: feature
doc_function: canonical
purpose: "Short canonical feature document for a small and local delivery unit."
derived_from:
  - ../../product/context.md
  # Optional:
  # - ../../prd/PRD-<id>-short-name.md
  # - ../../use-cases/UC-XXX-short-name.md
  # - ../../domain/rules.md
status: draft
delivery_status: planned
audience: humans_and_agents
must_not_define:
  - implementation_sequence
```

## Instantiated Body

```markdown
# FT-XXX: Feature Name

## What

### Problem

Which specific problem or opportunity the feature addresses.

If an upstream PRD exists, do not rewrite the whole product context here; focus on the slice-specific problem statement.

If an upstream use case exists, record only how the current delivery unit implements or changes that scenario.

If the feature changes a shared domain rule, state, event, or context boundary, add the relevant `../../domain/` document to `derived_from`.

### Scope

- `REQ-01` What is required.
- `REQ-02` What else is required.

### Non-Scope

- `NS-01` What we definitely do not do.

### Constraints

- `CON-01` Which constraint sets solution boundaries.

## How

### Solution

One short paragraph: the main approach and key trade-off.

### Change Surface

| Surface | Why |
| --- | --- |
| `path/or/component` | Why it changes |

### Flow

1. Input.
2. Processing.
3. Output.

## Verify

### Exit Criteria

- `EC-01` What must be true after implementation.

### Acceptance Scenarios

- `SC-01` Main happy path and canonical positive test case for this delivery unit.

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `CON-01` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-02` | `CON-01` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |

### Checks

Verify must be executable and define at least one explicit test case through `SC-01`.

| Check ID | Covers | How to check | Expected |
| --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `SC-01` | Command or procedure | Expected result |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-xxx/verify/chk-01/` |

### Evidence

- `EVID-01` Which artifact must remain after verification.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | Minimal verification artifact | verify-runner / human | `artifacts/ft-xxx/verify/chk-01/` | `CHK-01` |
```

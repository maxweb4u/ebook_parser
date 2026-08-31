---
title: FT-XXX Feature README Template
doc_kind: feature
doc_function: template
purpose: Governed wrapper template for conditional feature-level `README.md`. Read this when a feature package expands beyond its single canonical brief and needs a routing layer.
derived_from:
  - ../../feature-flow.md
  - ../../../dna/frontmatter.md
status: active
audience: humans_and_agents
template_for: feature
template_target_path: ../../../features/FT-XXX/README.md
---

# FT-XXX Feature Template

This file describes the template wrapper itself. The instantiated feature README lives below as an embedded contract and is copied into the feature package without wrapper frontmatter and history.

## Wrapper Notes

The `memory_bank/flows/templates/feature/` directory stores wrapper templates for a feature package: this conditional README template, the canonical `brief.md` template, the conditional `design.md` template, and the conditional derived template for `implementation-plan.md`. New packages start with only `brief.md` and are registered by a direct link from `memory_bank/features/README.md`.

Do not instantiate this README while `brief.md` is the only content document. Create it together with the first design, plan, or support document, route every document that remains in the package, and update `memory_bank/features/README.md` to point to this README instead of directly to `brief.md`.

Downstream routes for a living feature package are added as lifecycle stages are passed. A typical example of such post-bootstrap routes:

- [`design.md`](design.md)
  Read when you need: after `Problem Ready`, to record or verify selected design, to-be C4 architecture model, accepted local decisions, contracts, and local rollout/backout semantics.
  Answers the question: how exactly the feature is implemented without mixing solution space with problem space.

- [`implementation-plan.md`](implementation-plan.md)
  Read when you need: after upstream owners are ready, to decompose implementation into steps, workstreams, checkpoints, and traceability to canonical IDs.
  Answers the question: how to move feature implementation from current state to acceptance.

- `../../adr/ADR-<id>-short-decision-name.md`
  Read when you need: if a related ADR exists for the feature, to create or verify it with correct `decision_status`.
  Answers the question: why a specific architecture or engineering decision is selected for the feature and what stage it is in.

## Instantiated Frontmatter

```yaml
title: "FT-XXX: Feature Package"
doc_kind: feature
doc_function: index
purpose: "Navigation for an expanded feature package. Read this to route to the canonical brief and every live or historical package document."
derived_from:
  - ../../dna/governance.md
  - brief.md
status: active
audience: humans_and_agents
```

## Instantiated Body

```markdown
# FT-XXX: Feature Package

## About This Section

This package has expanded beyond its canonical `brief.md`, so this README is its routing layer. Read `brief.md` first, then use only routes for documents that currently exist.

## Annotated Index

- [`brief.md`](brief.md)
  Read when you need: to open the canonical feature owner.
  Answers the question: where the problem space, canonical verify contract, and stable IDs for this feature live.

Add routes for every conditional `design.md`, `implementation-plan.md`, support document, and related ADR that remains in the package. Keep archived documents routed as historical evidence; remove a route only when its file is removed or moved and the destination index is updated. On a package that has always followed the no-plan path, keep `implementation-plan.md` absent.
```

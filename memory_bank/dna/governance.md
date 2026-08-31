---
doc_kind: governance
doc_function: canonical
purpose: SSoT implementation and dependency tree rules. Answers which fact is owned by whom.
derived_from:
  - principles.md
status: active
---
# Document Governance

A `Governed document` is a Markdown file in `memory_bank/` with valid YAML frontmatter. The SSoT principle is defined in [principles.md](principles.md). This document describes how it is enforced.

## SSoT Implementation

1. Only `active` documents are authoritative. `draft` does not override `active`.
2. Among documents allowed by status, upstream wins: first `canonical_for`, then the dependency tree.
3. Publication status (`status`) is separate from entity lifecycle status (`delivery_status`, `decision_status`).

## Document Language

All documents in `memory_bank/` must be written in English. This includes frontmatter values, headings, body text, tables, examples, and template content.

## Source Dependency Tree

1. The `derived_from` field lists direct upstream documents. Authority flows upstream → downstream.
2. The root document is `principles.md`; it has no `derived_from`. Every `active` non-root document must define `derived_from`.
3. Cyclic dependencies are forbidden. Upstream changes may require downstream updates.

## Governance-specific Frontmatter Fields

Governance documents (DNA, flows) use additional fields that are not part of the shared schema (`frontmatter.md`):

| Field | Values | Purpose |
|-|-|-|
| `doc_kind` | `governance`, `project`, `product`, `domain`, `prd`, `use_case`, `feature`, `feature-support`, `epic`, `process`, `prompt`, `engineering`, `ops`, `adr` | Document type or artifact layer |
| `doc_function` | `canonical`, `index`, `template`, `reference`, `derived`, `roadmap`, `risk_register`, `decision_log`, `subissue_registry` | Role: canonical owner of a fact, navigation index, template, a reference that owns nothing, or a document derived from a canonical owner. The last four are the epic registries, each of which owns its own register rather than a fact |

These fields are required for governance documents and recommended for product, domain, ops, engineering, and project documents so agents can distinguish the knowledge layer and file role.

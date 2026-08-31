---
doc_kind: governance
doc_function: canonical
purpose: Rules for two-way navigation between code and documentation.
derived_from:
  - principles.md
status: active
---
# Cross-references (code ↔ docs)

Goal: maintain two-way navigation:

- from code to the architecture or feature spec;
- from documentation to implementation and tests.

## Code → docs

A module that implements documented logic includes a comment linking to the canonical document.

Minimum contract:
1. The link uses a path relative to the repository root.
2. The annotation explains which aspect of the document is relevant to this module.

## Docs → code (target)

Documentation may link to files and lines after the code exists. Every link must be annotated: what is behind the link and why to read it.

---
title: "Process Documentation Index Template"
doc_kind: process
doc_function: template
purpose: Governed wrapper template for `processes/README.md`. Read this to assemble a project process-document catalog without mixing wrapper metadata and future index-document frontmatter.
derived_from:
  - ../../../dna/governance.md
  - ../../../dna/frontmatter.md
  - ../../workflows.md
status: active
audience: humans_and_agents
template_for: process
template_target_path: ../../../processes/README.md
canonical_for:
  - process_template_index
---

# Process Documentation Index Template

This file describes the wrapper template. The instantiated `processes/README.md` lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

The `processes/` catalog is for reusable process documents that live between an ad-hoc note and a feature package. It helps keep process separate from product scope: repeated workflows, session handoff, lifecycle protocols, and other governed action sequences live here.

This index template is intended for navigation across the three-level process line:

- a compact process card;
- session handoff for continuing work between sessions;
- lifecycle protocol for long delivery processes with gates and verification.

If the project needs only one process, still keep `README.md` as the routing layer: it records which process documents exist, what they cover, and when to open them.

## Instantiated Frontmatter

```yaml
title: "Process Documentation Index"
doc_kind: process
doc_function: index
purpose: "Navigation for reusable project process documents and selection of the right template for a concrete workflow."
derived_from:
  - ../flows/workflows.md
status: active
audience: humans_and_agents
```

## Instantiated Body

```markdown
# Process Documentation Index

## About The Catalog

The `processes/` catalog stores reusable process documents: compact process cards, session handoff for continuing work between sessions, and lifecycle protocol for complex delivery flows with checks and gates.

## Annotated Index

- [`process-card.md`](process-card.md)
  Read when a compact, repeatable process is needed without a large state machine.
  Answers the question: how to record a short workflow that can be executed from one card.

- [`session-handoff.md`](session-handoff.md)
  Read when work moves between sessions or computers and current state, assumptions, risks, and next checks must be preserved.
  Answers the question: how to safely continue an already started process without losing context.

- [`lifecycle-protocol.md`](lifecycle-protocol.md)
  Read when a process consists of phases, human gates, verification, and rollback and must survive a long delivery cycle.
  Answers the question: how to manage the full lifecycle of a change from start to handoff or closure.
```

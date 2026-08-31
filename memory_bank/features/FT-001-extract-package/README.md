---
title: 'FT-001: Feature Package'
doc_kind: feature
doc_function: index
purpose: Navigation for the FT-001 package. Read this to route to the canonical brief and the execution plan.
derived_from:
  - ../../dna/governance.md
  - brief.md
status: active
audience: humans_and_agents
---

# FT-001: Feature Package

## About This Section

This package has expanded beyond its canonical `brief.md`, so this README is its
routing layer. Read `brief.md` first.

## Annotated Index

- [`brief.md`](brief.md)
  Read when you need: to open the canonical feature owner.
  Answers the question: what the extraction must deliver, what is out of scope,
  and how it is verified — `REQ-*`, `NS-*`, `SC-*`, `CHK-*`, `EVID-*`, `EC-01`.

- [`implementation-plan.md`](implementation-plan.md)
  Read when you need: to execute the work.
  Answers the question: in what order the seven steps run, what blocks what, and
  which conditions stop execution.

- [`../../adr/ADR-20260830T161251Z-package-name-ebook-parser.md`](../../adr/ADR-20260830T161251Z-package-name-ebook-parser.md)
  Read when you need: to know why the package is named `ebook_parser`.
  Answers the question: which alternatives were rejected and what the name
  commits the package to.

- [`../../adr/ADR-20260830T161443Z-single-document-model.md`](../../adr/ADR-20260830T161443Z-single-document-model.md)
  Read when you need: to know why both formats return one model.
  Answers the question: what was traded away for convergence.

`design.md` is absent by decision: `brief.md` records `Design required: no`
because architecture, the exported surface, and both decisions are owned
upstream and only applied here.

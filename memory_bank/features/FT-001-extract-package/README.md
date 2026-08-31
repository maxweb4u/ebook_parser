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

The nine decisions taken on 2026-08-31, all of which change what `STEP-01`
writes or what TeaderBook must be refactored to accept at `STEP-07`:

- [`ADR-20260831T134825Z`](../../adr/ADR-20260831T134825Z-own-epub-reader.md) —
  the package reads EPUB itself instead of depending on `epubx`. Answers: what
  that costs and why the `archive` pin decided it.
- [`ADR-20260831T134925Z`](../../adr/ADR-20260831T134925Z-script-driven-segmentation.md) —
  segmentation is script-driven and replaceable. Answers: which writing systems
  are served and where the honest ceiling is.
- [`ADR-20260831T135025Z`](../../adr/ADR-20260831T135025Z-language-resolution.md) —
  languages validated against all of ISO-639-1. Answers: why the app's catalog
  does not come along and who narrows it.
- [`ADR-20260831T135125Z`](../../adr/ADR-20260831T135125Z-raw-cover-bytes.md) —
  covers returned as stored. Answers: why the cheap metadata path was not cheap.
- [`ADR-20260831T135225Z`](../../adr/ADR-20260831T135225Z-model-excludes-pagination.md) —
  pagination state leaves the model. Answers: why a consumer wraps rather than
  extends.
- [`ADR-20260831T135325Z`](../../adr/ADR-20260831T135325Z-optional-serialization-library.md) —
  serialization behind a second import. Answers: who versions the encoded shape.
- [`ADR-20260831T135425Z`](../../adr/ADR-20260831T135425Z-archive-layer-is-public.md) —
  the archive layer is exported. Answers: why `REQ-04` depends on it.
- [`ADR-20260831T140218Z`](../../adr/ADR-20260831T140218Z-parse-result-type.md) —
  expected failures are returned, not thrown. Answers: why the cases are prefixed
  and what `kind` carries that `message` must not.
- [`ADR-20260831T144622Z`](../../adr/ADR-20260831T144622Z-inline-images-are-extracted.md) —
  both readers emit inline images. Answers: why a sealed model may not ship a
  variant nothing produces.

`design.md` is absent by decision: `brief.md` records `Design required: no`
because architecture, the exported surface, and both decisions are owned
upstream and only applied here.

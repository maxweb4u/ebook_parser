---
title: Engineering Documentation Index
doc_kind: engineering
doc_function: index
purpose: 'Navigation for implementation documentation: architecture, conventions, testing policy, and known traps.'
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---
# Engineering Documentation Index

Read when you need architecture, coding and testing conventions, or gotchas.

## Registry

- [`Testing Policy`](testing-policy.md) — What must have automated tests, what is verified manually, and the simplify review the closure gate requires. Seeded as a draft — fill it in first.
- [`Public API Surface`](public-api.md) — What ebook_parser exports and what stays in src/ — the format-detection entry point, the IBookParser port, and the sample-text utility.
- [`Package Layout`](architecture.md) — How the package is laid out on disk — the single export file, what each src/ unit owns, and why test/, example/, and the metadata files are not optional.
- [`Format Mapping`](format-mapping.md) — What each EPUB and FB2 construct becomes in the shared model, and what is deliberately not extracted — the source of the README's format support table.
- [`Corpus Findings`](corpus-findings.md) — What real EPUB and FB2 files actually contain, measured over the local collection — the evidence STEP-00b exists to produce, and what the collection still does not cover.

---
title: Product Context
doc_kind: product
doc_function: canonical
purpose: The problem the project solves, who it is for, and the constraints everything else inherits.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
canonical_for:
  - product_problem_statement
  - product_constraints
---
# Product Context

## Problem

Book parsing for EPUB and FB2 currently lives inside TeaderBook, spread over
four locations rather than one — roughly 900 lines in total:

- `lib/src/data/book_parsing/` — archive handling, format detection, both parsers;
- `lib/src/data/models/` — `book_document.dart` (the model plus `sampleTextOf`)
  and `book_metadata.dart`;
- `lib/src/core/interfaces/book_parser.dart` — the port;
- `lib/src/core/utils/sentence_segmenter.dart` — sentence and word segmentation.

It works, but it is reachable only by that one application: it imports
`package:readtolearn/...`, returns the app's own `Result<T>`, resolves a book's
declared language against the app's 59-language translation catalog, and its
comments cite TeaderBook feature IDs and ADR paths.

Outside TeaderBook the situation is worse. FB2 parsers on Dart are effectively
absent, and the EPUB packages that exist each return their own model, so anyone
handling both formats writes the same reconciliation layer again. The work to
close that gap is already done — it is just not extractable.

This project extracts it into a standalone pub.dev package. See
[value-proposition.md](value-proposition.md) for what makes the result worth
depending on.

## Who It Is For

Dart and Flutter developers who need to read EPUB or FB2 and want one model
back regardless of which arrived. Roughly half of them are expected to be
outside Flutter entirely — server and CLI code — which is why the no-Flutter
constraint below is not negotiable.

TeaderBook is the second consumer, not the first. It switches to the package
once published; until it does, the package is a dead fork and any divergence
surfaces at the worst possible moment.

## Constraints

- **No Flutter dependency.** Every dependency must be pure Dart. A `flutter`
  dependency would lock out server and CLI callers, which is roughly half of
  them. The constraint is the absence of the Flutter SDK, not a fixed package
  count. The extracted code arrived with seven and the package ships five:
  `archive` (zip), `xml`, `path`, `html` (chapter XHTML, which real books do not
  guarantee is valid XML), and `enough_convert` (windows-1251/1250/1252 and
  koi8-r/u, without which FB2 from public catalogues is unreadable). `epubx` and
  `image` are gone by decision, not by accident — the package reads EPUB itself
  and never decodes a cover.
- **No foreign result type.** The package defines its own `ParseResult<T>` and
  `ParseFailure`. Pulling in another project's `Result` is not acceptable, and
  throwing on expected errors would be a regression against current behaviour.
- **No references back to TeaderBook.** App feature IDs and `memory_bank/adr/`
  paths are stripped; the reasoning stays, the dangling pointer goes. A comment
  citing a path that does not resolve is worse than no comment.
- **pub.dev conventions bind the name.** `ebook_parser` — `lowercase_with_underscores`,
  free on pub.dev, searchable on the words people actually search, and it
  survives adding a third format. The alternatives and why they lost are
  recorded in
  [ADR-20260830T161251Z](../adr/ADR-20260830T161251Z-package-name-ebook-parser.md).
- **Publishing implies migration.** Switching TeaderBook onto the package is
  part of the work, not a follow-up; it is the proof the extraction was correct.

## Non-Goals

- Formats beyond EPUB and FB2. The name leaves room for MOBI or TXT later; this
  scope does not include them.
- Rendering, pagination, or any reader UI. The package returns a document model
  and stops there.
- Dictionary- or model-based word segmentation. Segmentation is rule-based and
  driven by script, not by language. Rules carry sentences in every writing
  system the package claims and words in every space-separated one, but Thai,
  Khmer, Lao and Burmese words need a dictionary the package will not ship. A
  caller who needs one supplies a segmenter instead of forking; the package
  states the boundary per writing system rather than implying uniform quality.

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

Book parsing for EPUB and FB2 currently lives inside TeaderBook, at
`lib/src/data/book_parsing/`. It works, but it is reachable only by that one
application: it imports `package:readtolearn/...`, returns the app's own
`Result<T>`, and its comments cite TeaderBook feature IDs and ADR paths.

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

- **No Flutter dependency.** Dependencies stay at `archive`, `xml`, and `path`.
  A `flutter` dependency would lock out server and CLI callers.
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
- Language-specific segmentation guarantees. How language-agnostic
  `sentence_segmenter.dart` actually is remains open and must be settled before
  publication — a package that cuts Russian well and English poorly says so in
  its README rather than implying uniform quality.

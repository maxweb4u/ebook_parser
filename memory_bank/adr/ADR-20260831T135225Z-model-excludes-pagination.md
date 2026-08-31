---
title: 'ADR-20260831T135225Z: Pagination State Stays Out Of The Document Model'
doc_kind: adr
doc_function: canonical
purpose: 'Records why ParagraphBlock sheds the reader''s spillBefore/spillAfter/wholeSentence, and why a consumer that needs them wraps the block instead of extending it.'
derived_from:
  - ../domain/model.md
  - ADR-20260830T161443Z-single-document-model.md
canonical_for:
  - pagination_boundary_decision
must_not_define:
  - document_model
  - public_api_surface
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T135225Z: Pagination State Stays Out Of The Document Model

## Context

`ParagraphBlock` in TeaderBook carries three things that are not properties of a
paragraph in a book: `spillBefore`, `spillAfter`, and `wholeSentence()`. They
exist because the reader's paginator cuts a page in the middle of a sentence and
must still translate the sentence the reader meant, so the two halves are
carried on the block and rejoined on demand.

They are written by `book_paginator.dart`, persisted by `page_disk_cache.dart`,
and read by `reader.dart` and `reader_paragraph.dart`. No parser ever sets them.

This contradicts `NS-02` — the package does no rendering and no pagination — and
it puts a screen-shaped concept inside the model that both formats are supposed
to converge on.

The exit that would normally exist is closed: `Block` is sealed, so a consumer
cannot subclass `ParagraphBlock` from outside the package's library to add the
fields back.

## Decision Drivers

- pagination is a property of a viewport, not of a book, and two consumers
  paginating differently would need different fields on the same model;
- `Block` being sealed is deliberate ([domain/model.md](../domain/model.md)), and
  the fact that it blocks subclassing is the mechanism working, not a defect to
  route around;
- `NS-02` in [FT-001/brief.md](../features/FT-001-extract-package/brief.md)
  states the package returns a document model and stops there;
- the cost is not theoretical: four TeaderBook files change either way.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Keep the fields in the package | No app-side refactor; `STEP-07` is a pure import swap | The public model permanently carries a concept the package disclaims; every consumer sees two fields only a paginator can fill; the sealed hierarchy makes the mistake permanent | Rejected — a published model is the hardest thing to take a field out of |
| Generalise them into a neutral pair, e.g. leading/trailing context | Sounds format-agnostic | The same fields with a vaguer name; nothing in the package can ever populate them | Rejected — renaming does not relocate a concern |
| Open the hierarchy so consumers can subclass | Consumers extend the model freely | Gives up exhaustive switching, which is the whole reason `Block` is sealed | Rejected — trades a guarantee for a convenience |
| **Remove them; consumers wrap the block** | The model contains only what a parser can produce; the sealed guarantee is kept intact | Four files change in TeaderBook, and its page cache format changes | **Accepted** |

## Decision

`ParagraphBlock` in the package carries paragraph text and its lazily segmented
sentences. It carries no pagination state and no `wholeSentence`.

A consumer that paginates composes rather than extends: it defines its own type
holding the block alongside whatever its layout produced, and puts the rejoining
logic there. TeaderBook gains such a type in its reader layer, holding the
`ParagraphBlock` together with the two spill strings and the `wholeSentence`
method that reads them.

Composition rather than inheritance is not a workaround for the sealed class; it
is the arrangement the sealed class exists to force. A field only one consumer's
layout can fill does not belong on a type every consumer switches over.

## Consequences

### Positive

- The model contains only what a parser can produce, so `Block` stays a faithful
  description of a book rather than of one reader's screen.
- A second consumer paginating differently is unaffected; it brings its own
  wrapper.
- The sealed guarantee survives untouched: adding a block variant still breaks
  every consumer loudly.
- The package's serialization has nothing viewport-shaped to encode.

### Negative

- Four TeaderBook files change: the paginator, the page disk cache, the reader
  screen, and the paragraph widget.
- The app's page cache format changes, so its version must be bumped and cached
  pages are re-laid-out once.
- Call sites that used `block.wholeSentence(s)` become
  `pageParagraph.wholeSentence(s)`, which is one more indirection in reader code
  that is already dense.

### Neutral / Organizational

- [domain/model.md](../domain/model.md) owns the resulting shape of
  `ParagraphBlock`; this ADR only removes the fields.
- `NS-02` and `NS-03` in
  [FT-001/brief.md](../features/FT-001-extract-package/brief.md) — this is one of
  the named deviations from "no behaviour change".
- The app-side refactor is part of `STEP-07`, not a follow-up.

## Risks And Mitigation

The risk is that the app-side rejoining logic is subtly wrong after the move and
the reader translates a truncated sentence — the exact defect the spill fields
were introduced to fix. Mitigated by moving `paginator_test.dart`'s existing
assertion onto the new wrapper type rather than rewriting it, so the behaviour is
pinned before the refactor and re-checked after.

Secondary risk: the refactor is done together with the segmenter reference
landing on `ParagraphBlock`
([ADR-20260831T134925Z](ADR-20260831T134925Z-script-driven-segmentation.md)), so
two changes touch the same type at once. Accepted deliberately — doing them
separately means refactoring the same four files twice.

## Follow-up

- TeaderBook gains a reader-layer wrapper type carrying the block and its spills.
- `page_disk_cache.dart` serialises the wrapper, reusing the package's block
  codec ([ADR-20260831T135325Z](ADR-20260831T135325Z-optional-serialization-library.md)).
- The app's page cache version is bumped in `STEP-07`.

## Related Links

- [domain/model.md](../domain/model.md) — the model and why `Block` is sealed.
- [ADR-20260830T161443Z](ADR-20260830T161443Z-single-document-model.md) — the
  pressure to widen the model for one consumer, named there as the main risk.
- [ADR-20260831T134925Z](ADR-20260831T134925Z-script-driven-segmentation.md) —
  the other change landing on `ParagraphBlock`.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) — `DEC-05`.

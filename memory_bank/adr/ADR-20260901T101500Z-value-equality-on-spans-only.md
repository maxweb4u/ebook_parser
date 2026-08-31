---
title: 'ADR-20260901T101500Z: Value Equality On Sentence And Word Only'
doc_kind: adr
doc_function: canonical
purpose: 'Records which exported model types define ==, why every type above a sentence keeps identity, and why the answer had to be chosen before 0.1.0 rather than defaulted.'
derived_from:
  - ../domain/model.md
  - ../engineering/public-api.md
canonical_for:
  - model_equality_decision
must_not_define:
  - document_model
  - public_api_surface
  - current_system_state
status: active
decision_status: accepted
date: '2026-09-01'
audience: humans_and_agents
---
# ADR-20260901T101500Z: Value Equality On Sentence And Word Only

## Context

[domain/model.md](../domain/model.md) settles equality for `ImageData` and for
nothing else. Every other exported type — `Sentence`, `Word`, `Chapter`,
`ParagraphBlock`, `HeadingBlock`, `ImageBlock`, `BookMetadata`, `BookDocument` —
has no stated position, which in Dart means identity. That is a default nobody
chose, and it was opened as `OQ-16`.

The source has the same default, and it is worth stating rather than assuming:
neither `lib/src/data/models/book_document.dart` nor
`lib/src/data/models/book_metadata.dart` in TeaderBook declares an `operator ==`
or a `hashCode` on any type. So identity is what the application relies on today,
and every option here is a departure from it — the question is only which
departure is worth its cost.

The cost of deferring is asymmetric. Equality cannot be added quietly in a later
version: it changes how `Set` and `Map` behave for every consumer already written
against identity, so the second version silently does something different from
the first rather than failing to compile. A missing `==` is a nuisance; a `==`
that appears is a behaviour change nobody sees.

## Decision Drivers

- `Sentence` and `Word` are spans of text and nothing else, which is what a value
  type looks like, and they are the types a consumer is likeliest to hold in a
  `Set` or compare directly;
- `ImageData` has no `==` by decision, because walking several megabytes behind
  an operator is a cost the caller cannot see — and that reasoning propagates
  upward to everything holding one;
- `ParagraphBlock` carries a `TextSegmenter`, a consumer-supplied interface with
  no equality contract of its own, and two paragraphs of identical text with
  different segmenters are already documented as not interchangeable;
- `Block` is sealed, so its three variants are compared together as often as
  separately — a `List<Block>` comparison that mixed value and identity
  semantics would be indefensible;
- `SC-13` compares `parse().metadata` against `parseMetadata()` field by field,
  which is a test-side cost, not a reason to publish an operator.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| No `==` anywhere | Uniform; matches the source exactly | Leaves the two genuine value types unusable in a `Set`, which is the one case consumers actually hit | Rejected — uniformity bought by making the leaf types worse |
| **`==` on `Sentence` and `Word` only** | The types that are values behave as values; nothing that holds bytes, a segmenter, or a whole book acquires a hidden cost | The model is not uniform, and that has to be documented rather than discovered | **Accepted** |
| Deep `==` on everything | Nothing to explain; every comparison "just works" | `BookDocument ==` walks the whole book, and `BookMetadata ==` has to either compare cover bytes — the exact cost `ImageData` rejects — or compare them by identity and call two different books equal | Rejected on both counts |
| `equatable` or a code generator | Removes the boilerplate | Adds a dependency to a package whose selling point is a small pure-Dart tree, and does not answer the question — it only makes the wrong answer easier to write | Rejected |

## Decision

`Sentence` and `Word` define `==` and `hashCode` over their fields. `Sentence`
compares `text`, `start`, `end` and its `words` element-wise; `Word` compares
`text`, `start` and `end`. Both are bounded by the length of one sentence, so the
operator has no cost the caller cannot predict from the value in front of it.

No other exported type defines `==`. Each keeps identity, and this table records
the reason for each so it reads as a decision rather than an omission:

| Type | Why identity |
| --- | --- |
| `ImageData` | Already decided — the bytes are unbounded and the walk is invisible |
| `ImageBlock` | Holds an `ImageData`; a `==` would have to compare it by identity, which is a comparison that looks like a value comparison and is not |
| `ParagraphBlock` | Holds a `TextSegmenter` supplied by the consumer, which has no equality contract. Any `==` must decide whether the segmenter is part of identity, and both answers are wrong for someone |
| `HeadingBlock` | It is a pure value and could have one — withheld for uniformity across the sealed family, so `List<Block>` comparison has one semantics rather than three |
| `BookMetadata` | Holds the cover. Comparing it walks megabytes; skipping it makes two books with different covers equal |
| `Chapter`, `BookDocument` | A deep `==` walks the whole book, which is the mirror image of the `ImageData` cost |

`HeadingBlock` is the one entry where the answer is uniformity rather than a
property of the type, and it is written down that way rather than dressed up.

## Consequences

### Positive

- `Sentence` and `Word` work in a `Set`, as a `Map` key, and in a test
  assertion — which is what a consumer reaches for them to do.
- No exported operator hides an unbounded cost.
- Comparing two `List<Block>` has one meaning, not a per-variant one.
- The position is now recorded for every type, so a later request for
  `BookDocument ==` is answered by a document rather than re-argued.

### Negative

- The model is deliberately not uniform, and a consumer who finds `Sentence ==`
  working will reasonably expect `ParagraphBlock ==` to work too. This has to be
  in the doc comments and the README, not left to be discovered.
- `SC-13` keeps comparing `BookMetadata` field by field, with the cover asserted
  separately. That awkwardness is accepted rather than removed.

### Neutral / Organizational

- [domain/model.md](../domain/model.md) owns the model and is updated to state
  the outcome; this ADR must not restate the field lists.
- `OQ-16` closes in the
  [implementation plan](../features/FT-001-extract-package/implementation-plan.md).
- No `NS-03` deviation to record on the application side: TeaderBook defines no
  `==` today and none of its call sites compares these types.

## Risks And Mitigation

The risk is a consumer assuming value semantics where there are none — most
plausibly putting `ParagraphBlock`s in a `Set` to deduplicate them and getting
every one back. Mitigated by doc comments on each type that keeps identity,
saying so and pointing at the reason, rather than by silence.

## Follow-up

- Doc comments on `ImageData`, `ImageBlock`, `ParagraphBlock`, `HeadingBlock`,
  `BookMetadata`, `Chapter` and `BookDocument` state that they compare by
  identity and why.
- A test asserts `Sentence` and `Word` behave as values in a `Set`, and that the
  paragraph-level types do not — so the asymmetry is pinned rather than assumed.

## Related Links

- [domain/model.md](../domain/model.md) — the model and the `ImageData` position
  this decision extends.
- [engineering/public-api.md](../engineering/public-api.md) — the exported names.
- [FT-001/implementation-plan.md](../features/FT-001-extract-package/implementation-plan.md) — `OQ-16`.

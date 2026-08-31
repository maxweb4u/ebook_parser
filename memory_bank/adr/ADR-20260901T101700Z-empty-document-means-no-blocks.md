---
title: 'ADR-20260901T101700Z: emptyDocument Means No Blocks, Not No Text'
doc_kind: adr
doc_function: canonical
purpose: 'Defines the emptyDocument failure, records that a chapter with no blocks is dropped, and says why an image-only book is a valid document rather than an error.'
derived_from:
  - ../engineering/public-api.md
  - ../engineering/format-mapping.md
canonical_for:
  - empty_document_definition
must_not_define:
  - public_api_surface
  - document_model
  - parse_failure_kind_set
status: active
decision_status: accepted
date: '2026-09-01'
audience: humans_and_agents
---
# ADR-20260901T101700Z: emptyDocument Means No Blocks, Not No Text

## Context

`emptyDocument` has been in the failure enum since `DEC-08` and defined nowhere,
which was opened as `OQ-17`. It is observable behaviour — the difference between
a book that opens and a book that is refused — so leaving it to whoever writes
the reader is leaving the contract to be discovered.

The source answers two adjacent questions and is worth quoting rather than
paraphrased. A chapter whose block list is empty is dropped and does not consume
an index:

```dart
if (blocks.isNotEmpty) {
  out.add(Chapter(index: index, title: title, blocks: blocks));
  index++;
}
```

— `frontend/lib/src/data/book_parsing/epub_parser.dart:133`. And a document whose
chapter list comes out empty is an error:

```dart
if (chapters.isEmpty) {
  return err(const Failure(FailureKind.bookParse,
      'This EPUB has no readable text content.'));
}
```

— the same file, lines 67–73.

Two things have changed underneath that message since it was written. `DEC-10`
made `ImageBlock` a variant both readers produce, so a chapter can now carry
content that is not text; and
[ADR-20260831T184812Z](ADR-20260831T184812Z-unnavigated-spine-items.md) keeps
unnavigated spine items as untitled chapters, which increases how many
near-empty chapters a book yields. Fixed-layout EPUB — comics, children's books,
textbooks, named as a gap in
[corpus-findings.md](../engineering/corpus-findings.md) — is exactly the shape
where "no readable text" and "nothing to read" stop being the same statement.

## Decision Drivers

- refusing a valid book is worse than returning one a caller finds thin: a
  `ParseErr` on a comic is a bug report, an empty `bodySample` is a fallback;
- `Chapter.index` is the chapter's identity and the model states it is stable for
  the same bytes, so index density is not a free choice;
- the rule has to be stated in terms of the model, not in terms of the formats,
  or each reader will draw its own line;
- whatever is decided is visible to every consumer on the first malformed file
  they meet.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Copy the source literally — no **text** means `emptyDocument` | Zero deviation from current behaviour | Refuses every fixed-layout book, every comic, and any book whose content is entirely images — a whole category, not an edge case, and one `DEC-10` deliberately made representable | Rejected |
| **No `Block` at all, in any chapter, means `emptyDocument`** | An image-only book is a document; the rule is stated in model terms and both readers can apply it identically | `bodySample` returns an empty string for such books, and the caller's language detection has to cope | **Accepted** |
| Never fail; return a document with no chapters | Simplest rule of all | Hands every consumer a book-shaped object with nothing in it and no reason why — the failure kind exists precisely so a truncated download can be told apart from a thin one | Rejected |

## Decision

**`emptyDocument` is returned when parsing succeeded structurally but produced no
`Block` of any variant, in any chapter.** Not "no text": a chapter holding a
single `ImageBlock` is content, and a book made entirely of them is a valid
document.

**A chapter whose block list is empty is dropped**, which preserves current
behaviour and keeps `Chapter.index` dense and equal to the chapter's position in
the list. This does not conflict with unnavigated spine items being kept: that
rule decides which documents become chapters, and this one decides that a chapter
with nothing in it is not worth an entry in the contents. A spine item holding a
full-page image has an `ImageBlock` and survives both rules.

One exception, added 2026-09-01 when `OQ-26` composed this rule with rule 4 of
[ADR-20260831T173725Z](ADR-20260831T173725Z-chapter-per-navigation-entry.md): a
chapter produced by a navigation entry is kept even when splitting leaves it
without blocks. An NCX part and its first chapter routinely anchor to the same
spot, and dropping the emptied fragment would delete an entry from the table of
contents this model keeps nowhere else. The drop rule aims at junk structure —
unnavigated empties, pre-anchor slivers — not at navigation. `Chapter.index`
stays dense either way.

The `NS-03` deviation is recorded rather than buried: an image-only book is
refused by TeaderBook today and parses successfully here.

## Consequences

### Positive

- Comics, fixed-layout books and picture books parse, which is what `DEC-10` was
  for.
- One rule, expressed in the model, applies unchanged to both readers.
- `Chapter.index` stays dense, so it remains usable as identity.

### Negative

- `bodySample` returns `''` for an image-only book, so a caller detecting
  language from it falls back to `fallbackLanguageCode` with no signal that
  anything unusual happened. The package invents nothing here, and the
  consequence belongs in the README beside `bodySample` rather than in a
  surprised bug report.
- A book of blank chapters — a broken conversion that yields structure and no
  content — now parses to a document with zero chapters rather than failing,
  unless *every* chapter is empty. That middle ground is accepted: partial
  emptiness is a quality judgement the package does not make.

### Neutral / Organizational

- [public-api.md](../engineering/public-api.md) gains the definition beside the
  enum; [format-mapping.md](../engineering/format-mapping.md) gains the
  empty-chapter rule in Chapters And Navigation.
- `OQ-17` closes in the
  [implementation plan](../features/FT-001-extract-package/implementation-plan.md);
  `STEP-01a` implements it.
- Fixed-layout EPUB stays a named corpus gap. This decision means such a file is
  *parsed* rather than refused, which raises the value of finally getting one.

## Risks And Mitigation

The risk is that a fixed-layout book parses into hundreds of one-block chapters
and a consumer treats it as prose. Mitigated only by documentation in `0.1.0` —
the package does not detect or label fixed layout, and pretending otherwise
without a single such file in the corpus would be a guess dressed as a feature.

## Follow-up

- A test asserts an image-only book parses and that `bodySample` returns `''`
  for it, so the consequence is pinned rather than incidental.
- A test asserts a document with no blocks anywhere returns `emptyDocument`.
- `bodySample`'s doc comment and the README state the empty-string case.
- `brief.md` records the `NS-03` deviation.

## Related Links

- [ADR-20260831T144622Z](ADR-20260831T144622Z-inline-images-are-extracted.md) —
  `ImageBlock`, without which this question has an obvious answer.
- [ADR-20260831T184812Z](ADR-20260831T184812Z-unnavigated-spine-items.md) — the
  rule that decides which documents become chapters.
- [engineering/corpus-findings.md](../engineering/corpus-findings.md) —
  fixed-layout EPUB as a named gap.

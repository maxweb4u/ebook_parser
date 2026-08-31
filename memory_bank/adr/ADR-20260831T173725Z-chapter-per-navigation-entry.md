---
title: 'ADR-20260831T173725Z: An EPUB Chapter Is A Navigation Entry, Not A Spine Item'
doc_kind: adr
doc_function: canonical
purpose: 'Records the corpus evidence that closed OQ-11, the rule that splits a spine item at its navigation anchors, and what happens to anchors that are missing, inline, or out of order.'
derived_from:
  - ../domain/model.md
  - ADR-20260831T162751Z-flat-chapter-list.md
  - ../engineering/corpus-findings.md
canonical_for:
  - chapter_granularity_decision
must_not_define:
  - document_model
  - chapter_structure_decision
  - real_world_format_variance
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T173725Z: An EPUB Chapter Is A Navigation Entry, Not A Spine Item

## Context

[ADR-20260831T162751Z](ADR-20260831T162751Z-flat-chapter-list.md) settled the
*shape* of the chapter list — flat, ordered, carrying a navigation depth — and
deliberately left the *granularity* open as `OQ-11`, because how many chapters an
EPUB yields depends on how real producers lay their books out, and nothing in the
bank knew that.

`STEP-00b` now knows it. Measured over three producers
([corpus-findings.md](../engineering/corpus-findings.md)), counting navigation
entries that point into a document which already has one — the entries a
spine-granularity reader collapses away:

| Book | Spine items | Navigation entries | Lost at spine granularity |
| --- | --- | --- | --- |
| Standard Ebooks, *Pride and Prejudice* | 65 | 65 | 0 |
| Gutenberg, *Alice* | 15 | 16 | 2 |
| Gutenberg, *War and Peace* | 368 | 385 | 17 |
| Gutenberg, *Московия* | 3 | 17 | 15 |
| Standard Ebooks, *Leaves of Grass* | 44 | 718 | **674** |
| Local collection (177 books, one producer) | — | — | 21% of books lose at least one; 8 lose 20 or more |

The producers disagree, which is the finding. Standard Ebooks splits one file per
navigation entry, so for its prose editions spine granularity is exactly right
and loses nothing at all. Its own poetry edition is the opposite: each poem is an
anchor inside a collection file, and spine granularity turns 718 table-of-contents
entries into 44.

This matters more here than it would in another model, because
[ADR-20260831T162751Z](ADR-20260831T162751Z-flat-chapter-list.md) made the
chapter list the only place navigation survives. There is no separate table of
contents in the model, and `Block` carries no anchors, so an entry the reader
collapses is not recoverable by any consumer. It is deleted.

## Decision Drivers

- The chapter list is the table of contents. What it drops, nothing else holds.
- `index` is the chapter identity
  ([ADR-20260831T162751Z](ADR-20260831T162751Z-flat-chapter-list.md)), so
  granularity is a compatibility surface: changing it after publication shifts
  every index and is a major version. It settles now or it settles expensively.
- `NS-03` asks for no behaviour change. Verified in the source after this ADR
  was first written: `epub_parser.dart` builds chapters from `book.Chapters` —
  epubx's navigation-derived tree, flattened through `SubChapters` — not from the
  spine. Navigation granularity is therefore what the source already does, and a
  spine item carrying no navigation entry produces no chapter there at all.
- The failure is not confined to an exotic producer. It appears in a conversion
  pipeline, in Project Gutenberg, and in the most carefully produced source
  available.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| One chapter per spine item | Cheapest; no XHTML partitioning to write | An anthology or poetry collection loses most of its table of contents, silently and unrecoverably; 21% of one producer's books are degraded | Rejected — it deletes navigation the model has nowhere else to keep |
| **One chapter per navigation entry, splitting the document at its anchors** | The table of contents survives every producer measured; where a file already holds one entry the output is identical, so the common case is unchanged | New partitioning code in `STEP-01a`, with rules needed for missing, inline and out-of-order anchors; chapter counts change, so `NS-03` is deviated from | **Accepted** |
| Chapters by spine, plus a separate navigation structure in the model | Most faithful — reading order and navigation stop competing | A new exported type, and it reopens chapter identity: pointing at a position inside a chapter needs the anchors `ADR-20260831T162751Z` decided not to carry | Rejected — it buys fidelity by undoing a decision taken two hours earlier, for a use nobody has asked for |

## Decision

One chapter per navigation entry. A spine item holding several entries is split at
its anchors; a spine item holding one entry, or none, is not split at all.

The rules, in the order they apply:

1. **Reading order is the spine, then document order.** Navigation order never
   determines chapter order — a navigation document may legitimately list entries
   out of order, and the spine is what the format defines as reading order.
2. **A spine item with no navigation entry** is one chapter, `title: null`, at the
   level of the nearest preceding entry. This is unchanged from
   [ADR-20260831T162751Z](ADR-20260831T162751Z-flat-chapter-list.md).
3. **A spine item with exactly one entry** is one chapter, whether or not that
   entry carries a fragment. No splitting. This is the common case, and it is
   byte-identical to spine granularity.
4. **A spine item with several entries** splits before the block containing each
   anchor, in document order. Each resulting chapter takes its `title` and `level`
   from its entry.
5. **An anchor on an inline element** splits before its nearest enclosing block. A
   chapter never begins mid-paragraph, so `Sentence` and `Word` offsets stay
   paragraph-relative exactly as
   [domain/model.md](../domain/model.md) requires.
6. **Content before the first anchor** becomes an untitled chapter, by rule 2 —
   the same treatment as a spine item nobody navigated to. If it holds no blocks,
   no chapter is emitted, which is the usual case where the first anchor sits on
   the document's own heading.
7. **An anchor that resolves to nothing** drops its entry and produces no split.
   The parse does not fail, for the same reason an unresolvable image does not
   ([ADR-20260831T144622Z](ADR-20260831T144622Z-inline-images-are-extracted.md)).
8. **An entry pointing outside the spine** is ignored. It is not in reading order,
   so it cannot become a chapter.

FB2 is unaffected: its sections are already the navigation, and nothing there
needs splitting.

## Consequences

### Positive

- The table of contents survives for every producer in the corpus, including the
  case that loses 94% of it under the rejected option.
- Standard Ebooks prose is unchanged — 65 entries in, 65 chapters out — so the
  decision costs nothing on books that were already laid out well.
- Granularity is settled before publication, which is exactly the mitigation
  [ADR-20260831T162751Z](ADR-20260831T162751Z-flat-chapter-list.md) promised when
  it scoped `index` stability to a major version.

### Negative

- `STEP-01a` grows. Partitioning a parsed XHTML document at anchor positions is
  more than reading it, and rules 5 through 8 each need a test.
- An `NS-03` deviation, though a narrower one than first recorded. Navigation
  granularity matches the source; what changes is rule 2. The source visits only
  navigation entries, so a spine item nobody navigated to yields no chapter,
  while rule 2 emits an untitled one. Measured on a retail Baen file, that is 30
  chapters in the source against 37 here
  ([corpus-findings.md](../engineering/corpus-findings.md)). Whether rule 2
  should exist at all is reopened as `OQ-13`.
- TeaderBook's stored reading positions are keyed by chapter index, so they are
  invalidated at `STEP-07` either way; the cache version bump that `DEC-04` and
  `DEC-06` already require absorbs it.
- The source also *injects* a `HeadingBlock` built from the navigation title at
  the top of each chapter, unless the label is front matter or the content
  already opens with it (`DEC-11`). This package emits no such synthetic heading,
  which is why a book whose headings are all styled `<p>` yields none at all.
- More chapters means more `Chapter` objects and a larger encoded form —
  *Leaves of Grass* goes from 44 to 718. Each is small, and the blocks are the
  same blocks, so the growth is in structure rather than content.

### Neutral / Organizational

- [format-mapping.md](../engineering/format-mapping.md) replaces "one spine item,
  pending `OQ-11`" with these rules.
- `OQ-11` moves to Closed in
  [implementation-plan.md](../features/FT-001-extract-package/implementation-plan.md),
  and `STEP-01a` carries the partitioning work.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) records this as
  `DEC-17` and a seventh `NS-03` deviation, with `SC-16`.

## Risks And Mitigation

The risk is the edge cases, since splitting is new code rather than copied code:
anchors inside a table, anchors on inline elements mid-sentence, anchors that
appear before any content, duplicate ids. Rules 5 through 8 exist to make each of
them a defined outcome rather than a surprise, and each gets a test built from a
constructed document rather than waiting for a real book to expose it.

The second risk is that the corpus is still three producers, and a retail or
publisher toolchain might lay books out in a fourth way. Mitigated by `STOP-04`,
which already stops the work if a whole producer's output fails, and by the
manual corpus pass in
[testing-policy.md](../engineering/testing-policy.md) — a person reading the
chapter list of a real anthology notices a wrong split immediately.

## Follow-up

- `STEP-01a` implements rules 1 through 8; `SC-16` asserts an anthology's
  navigation entries all become chapters, and `SC-15` gains the split case.
- `format-mapping.md` updated before `STEP-01a` begins.
- The README states that chapters follow the table of contents rather than the
  file layout, since it is a difference from other EPUB packages.
- `STEP-07` invalidates TeaderBook's stored reading positions along with its
  parse cache.

## Related Links

- [ADR-20260831T162751Z](ADR-20260831T162751Z-flat-chapter-list.md) — the chapter
  shape this fills in, and the open question it left.
- [corpus-findings.md](../engineering/corpus-findings.md) — the measurements, and
  how to reproduce them.
- [ADR-20260831T134825Z](ADR-20260831T134825Z-own-epub-reader.md) — the reader
  that gains this work.

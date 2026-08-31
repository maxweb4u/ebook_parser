---
title: 'ADR-20260831T184812Z: Unnavigated Spine Items Are Kept, Except A Declared Table Of Contents'
doc_kind: adr
doc_function: canonical
purpose: 'Records why a spine item with no navigation entry still becomes a chapter, and why the single exception is a table-of-contents page the format itself declares.'
derived_from:
  - ADR-20260831T173725Z-chapter-per-navigation-entry.md
  - ../engineering/corpus-findings.md
canonical_for:
  - unnavigated_spine_item_decision
must_not_define:
  - chapter_granularity_decision
  - document_model
  - format_extraction_boundary
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T184812Z: Unnavigated Spine Items Are Kept, Except A Declared Table Of Contents

## Context

Rule 2 of
[ADR-20260831T173725Z](ADR-20260831T173725Z-chapter-per-navigation-entry.md) says
a spine item with no navigation entry becomes an untitled chapter. That rule was
written before any file in the corpus exercised it. The retail Baen file does,
and reading the source to check the rule turned up that the source does the
opposite.

*Witchy Eye* has 37 spine items and 30 navigation entries. The seven unnavigated
documents are `titlepage.xhtml`, `contents.xhtml`, and five unlabelled
front-matter splits carrying the half-title, the dedication and similar
([corpus-findings.md](../engineering/corpus-findings.md)).

The source keeps none of them. `epub_parser.dart` iterates `book.Chapters` —
epubx's navigation-derived tree, flattened through `SubChapters` — and never
reads the spine, so a document nobody navigated to produces no chapter. On this
book the application shows 30 chapters where rule 2 would produce 37.

Six of the seven are ordinary text. The seventh is not: `contents.xhtml` is a
generated table-of-contents page, thirty links and 591 characters, and the
package keeps link text while dropping targets, so it would arrive as an untitled
chapter restating the table of contents as prose. The format declares it — the
OPF carries `<reference type="toc" href="contents.xhtml"/>` in its `<guide>`.

## Decision Drivers

- The package's central promise is that nothing is lost quietly: malformed input
  is reported rather than thrown, and an unresolvable image is skipped rather
  than failing a parse. Deleting a dedication because no one linked to it is the
  same class of failure, and it is invisible.
- A table-of-contents page is the one document whose content the package already
  returns by another route — as `Chapter.title` on every chapter.
- `DEC-11` already accepts suppressing *duplicated* navigation while keeping
  content. This is the same principle with a stronger signal: a declaration in
  the format rather than a match on label text.
- `NS-03` prefers the source's behaviour, and the source drops all seven.
- [testing-policy.md](../engineering/testing-policy.md) warns against rules added
  on a consumer's behalf. This adds one rule, not an option, and it is driven by
  a file in the corpus rather than by anticipation.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Drop every unnavigated spine item, as the source does | `NS-03` holds; no untitled chapters at all; the table-of-contents page disappears for free | Silently deletes the title page, the half-title and the dedication — text the book contains and the reader paid for; the loss is invisible to the consumer and unrecoverable | Rejected — it buys tidiness with the exact failure the package is built against |
| Keep every unnavigated spine item | One rule, no exceptions; nothing is lost | A chapter that restates the table of contents as prose sits in the reading flow of any book that ships a contents page | Rejected — it keeps a document whose only content is a duplicate of what the model already carries |
| **Keep them, except a spine item the format declares to be the table of contents** | Real front matter survives; the one genuinely redundant document goes; the exception rests on a declaration rather than a guess | A second rule in the reader, and books whose contents page is undeclared keep it | **Accepted** |

## Decision

Rule 2 stands: a spine item with no navigation entry becomes an untitled chapter,
at the level of the nearest preceding entry.

One exception. A spine item that the format itself identifies as the table of
contents is not emitted as a chapter. Three declarations count:

- EPUB 2 — `<guide><reference type="toc" href="…"/></guide>`;
- EPUB 3 — the manifest item carrying `properties="nav"`, when it also appears in
  the spine;
- EPUB 3 — a `<nav epub:type="landmarks">` entry whose link carries
  `epub:type="toc"`.

Only a declaration counts. A document is never skipped because it looks like a
table of contents — no matching on titles, no counting links. A book that ships a
hand-made contents page without declaring it keeps that page as a chapter, and
that is the intended outcome: the alternative is a heuristic that eventually
deletes a real chapter.

`type="cover"` is deliberately not part of this. The Baen title page is declared
`type="cover"` and still carries text — title, subtitle, author, imprint — which
`BookMetadata.cover` does not duplicate, because that field carries an image. A
cover page stays.

FB2 is unaffected: it has no spine and no guide.

## Consequences

### Positive

- *Witchy Eye* yields 36 chapters: six front-matter documents preserved, the
  declared contents page removed.
- Nothing is dropped that the model does not already carry by another route.
- The rule cannot misfire on a real chapter, because it acts only on an explicit
  declaration.
- The gap to the source narrows in the direction of keeping more, not less: the
  application gains six documents it has never displayed.

### Negative

- Two books can behave differently for a reason the reader cannot see — one
  declares its contents page and loses it, the other does not and keeps it. This
  is accepted rather than papered over with a heuristic.
- One more branch in the EPUB reader, with three declaration forms to read and
  test.
- Untitled chapters are now a normal occurrence rather than an edge case, so
  every consumer handles `Chapter.title == null`. That was already true from
  [ADR-20260831T162751Z](ADR-20260831T162751Z-flat-chapter-list.md); this makes
  it common.

### Neutral / Organizational

- [format-mapping.md](../engineering/format-mapping.md) records the three
  declarations and the cover exclusion.
- `OQ-12` and `OQ-13` close together in
  [implementation-plan.md](../features/FT-001-extract-package/implementation-plan.md);
  `STEP-01a` implements the exception.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) records `DEC-18`
  and `SC-17`.

## Risks And Mitigation

The risk is a producer that declares `type="toc"` on something that is not a
contents page — a first chapter, or a combined front-matter document. The
mitigation is that the declaration is what the format defines the element for, so
misuse is a defect in the book rather than a limitation here; and `SC-17` asserts
the skip on a file whose declaration is known good, so a regression shows up as a
chapter count rather than as silently missing text.

The second risk is EPUB 3, where `<guide>` is deprecated and the nav document is
usually outside the spine, so the exception rarely fires. That is the correct
outcome — there is nothing to skip — and the landmarks form covers the case where
a producer does put its contents page in the reading order.

## Follow-up

- `STEP-01a` implements the exception alongside rule 2.
- `SC-17` asserts that a book declaring a contents page yields chapters without
  it, and that a book with an undeclared contents page keeps it.
- The README notes that front matter appears as untitled chapters, since a
  consumer building a table of contents will filter on `title != null`.

## Related Links

- [ADR-20260831T173725Z](ADR-20260831T173725Z-chapter-per-navigation-entry.md) —
  rule 2, which this qualifies.
- [corpus-findings.md](../engineering/corpus-findings.md) — the Baen file that
  produced both the rule's first workout and its exception.
- [ADR-20260831T162951Z](ADR-20260831T162951Z-non-prose-flattens-to-paragraphs.md) —
  why a kept contents page would read as prose.

---
title: 'ADR-20260831T162751Z: Chapters Are A Flat Ordered List With A Depth'
doc_kind: adr
doc_function: canonical
purpose: 'Records why the table of contents is flattened into an ordered chapter list carrying a nav depth rather than a tree, and why Chapter has no identifier beyond its index.'
derived_from:
  - ../domain/model.md
canonical_for:
  - chapter_structure_decision
must_not_define:
  - document_model
  - public_api_surface
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T162751Z: Chapters Are A Flat Ordered List With A Depth

## Context

`BookDocument` carries an ordered `List<Chapter>`, and a `Chapter` carries its
`index`, a title, and its blocks. Every source of chapters is a tree:

- EPUB 2 `toc.ncx` nests `navPoint` inside `navPoint`;
- EPUB 3 `nav[epub:type=toc]` nests `<ol>` inside `<li>`;
- FB2 nests `<section>` inside `<section>` to arbitrary depth.

Nothing in the bank records what happens to that nesting. The model is flat, so
the trees are being flattened, and the depth is being discarded silently — which
means a consumer cannot render an indented table of contents, the single most
visible use a table of contents has.

A second question sits underneath: a `Chapter` has no identity beyond its
position. Three things normally want one — resolving a link from a table of
contents entry, storing a reading position, and resolving an internal link such
as a footnote reference.

## Decision Drivers

- Reading the book in order is the dominant traversal, and the one every
  consumer performs. Anything that makes it recursive is paid for on every call
  site.
- Depth is *lost* information, not deferred information. Once the parser
  flattens without recording it, no consumer can recover it; adding the field
  later means writing the same parser code anyway.
- `HeadingBlock.level` is not this. It is the level of a heading inside a
  chapter's content; navigation depth is a property of the chapter's place in the
  book.
- `Chapter` is constructed only by the package, so adding a field later is not a
  breaking change. The asymmetry argues for adding only what cannot be recovered.
- How many chapters a book has — one per spine item, or one per navigation entry
  with content split at anchors — is deliberately still open (`OQ-11`), pending
  the real-book corpus at `STEP-00b`.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| `Chapter` gains `children`, mirroring the source tree | Faithful to both formats; an indented table of contents falls out | Reading the book in order becomes a recursive flatten every consumer writes; the codec becomes recursive; two orderings exist (tree order and reading order) and they can disagree | Rejected — it taxes the common traversal to serve the rare one |
| Flat list, depth discarded | Simplest possible model | An indented table of contents becomes impossible, and the information cannot be recovered downstream | Rejected — it throws away something only the parser can produce |
| **Flat ordered list plus `int level`** | Reading order stays linear and non-recursive; a consumer can render a proper table of contents; both formats map into it the same way | One `int` per chapter that most consumers ignore; a tree must be rebuilt by a consumer that genuinely wants one | **Accepted** |
| Flat, plus `level`, plus an opaque `Chapter.id` | Link targets and stable bookmark keys | Nothing in the model can hold a link to resolve; `index` already keys a bookmark; a published identifier is a stability promise the open `OQ-11` cannot yet support | Rejected for `0.1.0` — adding it later is not breaking |

## Decision

A `BookDocument` holds an ordered, flat `List<Chapter>` in reading order. A
`Chapter` carries:

- `index` — dense, zero-based, its position in reading order;
- `title` — nullable, because a spine item with no navigation entry and an FB2
  `<section>` with no `<title>` both occur, and the package does not invent one;
- `level` — depth in the source navigation, `0` for a top-level entry. A chapter
  with no navigation entry of its own takes the level of the nearest preceding
  chapter that has one, and `0` when there is none;
- `blocks`.

`Chapter` has no identifier. Its identity is `index`, and that identity is stable
for the same input bytes within one major version of the package. This is stated
as a bounded promise rather than implied, because the chapter granularity
question (`OQ-11`) can still change how many entries the list has.

This decision is independent of how `OQ-11` resolves: both candidate answers
produce an ordered list with a depth, and differ only in how many entries it
holds.

## Consequences

### Positive

- Iterating a book stays a single loop, in every consumer, for both formats.
- An indented table of contents is possible without the parser being rewritten.
- FB2 section nesting and EPUB navigation depth land in the same field, so the
  symmetry rule in [testing-policy.md](../engineering/testing-policy.md) can be
  asserted on it directly.
- The codec stays flat: a list of chapters, not a recursive structure.

### Negative

- A consumer that genuinely wants a tree rebuilds one from `level`, which is
  straightforward but is work the package could have done.
- `level` is a field most consumers never read, on a model whose selling point
  includes being small.
- `title` becomes nullable, so every consumer handles the absent case.
- `index` as identity is a weaker promise than an identifier would be, and it is
  scoped to a major version rather than being unconditional.

### Neutral / Organizational

- [domain/model.md](../domain/model.md) records `level`, the nullable `title`,
  and the identity statement.
- [format-mapping.md](../engineering/format-mapping.md) records how each format's
  navigation produces `title` and `level`.
- `OQ-11` is added to
  [implementation-plan.md](../features/FT-001-extract-package/implementation-plan.md)
  with `STEP-00b` as its input.
- The README's table of contents section states that the list is flat and what
  `level` means.

## Risks And Mitigation

The risk is the identity promise: a consumer storing `index`-keyed reading
positions is exposed if chapter granularity changes, because every index after
the change shifts.

Mitigated by ordering, not by wording. `OQ-11` is resolved from the corpus at
`STEP-00b`, before `STEP-05` and therefore before publication, so if granularity
changes it changes while nobody depends on it. After publication, a granularity
change is a major version, which is what the stability promise already says.

The second risk is that `level` is filled inconsistently by the two readers —
the exact divergence class this package exists to prevent. Mitigated by the
symmetry requirement: any assertion about `level` is written for both formats.

## Follow-up

- [domain/model.md](../domain/model.md) updated before `STEP-01`.
- [format-mapping.md](../engineering/format-mapping.md) records the per-format
  derivation of `title` and `level`.
- `OQ-11` recorded in the plan, with `STOP` behaviour if the corpus shows
  single-file EPUBs are common enough to make spine granularity useless.
- A test per format asserting `level` on a book with nested navigation.

## Related Links

- [domain/model.md](../domain/model.md) — the model this shapes.
- [ADR-20260831T134825Z](ADR-20260831T134825Z-own-epub-reader.md) — the reader
  that must produce `level` from NCX and from EPUB 3 nav.
- [ADR-20260831T135225Z](ADR-20260831T135225Z-model-excludes-pagination.md) — the
  same reasoning applied to fields the model refuses.

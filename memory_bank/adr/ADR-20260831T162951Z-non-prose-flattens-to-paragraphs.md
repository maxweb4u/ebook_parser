---
title: 'ADR-20260831T162951Z: Everything Outside Prose Flattens Into Paragraphs'
doc_kind: adr
doc_function: canonical
purpose: 'Records how tables, lists, verse, quotations, inline markup and links map onto the three block variants, and why FB2 note bodies become trailing chapters instead of being dropped.'
derived_from:
  - ../domain/model.md
  - ../engineering/format-mapping.md
canonical_for:
  - non_prose_mapping_decision
must_not_define:
  - document_model
  - format_extraction_boundary
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T162951Z: Everything Outside Prose Flattens Into Paragraphs

## Context

`Block` has exactly three variants — paragraph, heading, image — and is sealed on
purpose ([domain/model.md](../domain/model.md)). Real books contain a great deal
that is none of the three: bulleted and numbered lists, tables, verse, epigraphs,
block quotations, figures with captions, inline emphasis, hyperlinks, footnote
references, and in FB2 a whole second `<body name="notes">` holding the footnote
texts.

Nothing in the bank says what becomes of any of it. `STEP-05` requires a README
table listing "what is **not** extracted from each format", and there is no
decision for that table to describe.

The gap has a deadline that the others do not. `Block` is sealed, so adding a
fourth variant breaks every consumer's switch — deliberately
([domain/model.md](../domain/model.md)). Whatever vocabulary the model is going
to have must be settled before publication, or it costs a major version.

## Decision Drivers

- The package returns a document model and stops there. Rendering, pagination
  and reader UI are non-goals (`NS-02`), and layout fidelity is a rendering
  concern.
- What the package is chosen for is a single model plus sentence and word
  segmentation ([value-proposition.md](../product/value-proposition.md)). That
  points at text.
- Losing text is not the same as losing layout. A reader that never sees a
  table's contents has lost content; one that sees it unformatted has lost
  formatting.
- The two formats do not carry the same structural information. FB2 marks verse,
  epigraphs and subtitles explicitly; EPUB carries XHTML whose meaning often
  lives in CSS the package never reads. A rich vocabulary would be filled
  asymmetrically, which is the failure
  [testing-policy.md](../engineering/testing-policy.md) is written against.
- `ParagraphBlock` is constructed only by the package, so a field added to it
  later is not a breaking change. A `Block` variant added later is.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Extend the vocabulary — `ListBlock`, `TableBlock`, `VerseBlock`, `QuoteBlock` | Structural fidelity; a renderer gets what it needs | Doubles a sealed hierarchy every consumer switches over; doubles the per-format parity matrix; several variants would be reliably filled from FB2 and unreliably from EPUB; the package disclaims rendering | Rejected — it buys fidelity for a use case that is a stated non-goal, at a cost every consumer pays |
| Flatten prose, drop tables | Avoids the junk that a flattened table becomes | Silently deletes content the book contains, in a package whose contract is that malformed input is reported rather than guessed at | Rejected — silent loss of text is the one outcome nothing here tolerates |
| **Flatten everything into paragraphs, tables row by row** | Nothing textual is lost; the sealed hierarchy stays at three; both formats map the same way | Tables read poorly and segment poorly; structure is unrecoverable downstream | **Accepted** |
| Flatten, plus an `origin` marker on `ParagraphBlock` so consumers can skip tables | The escape hatch for the accepted option's worst case | An option on a published API added for a consumer who has not asked; and adding it later is not breaking, so waiting costs nothing | Rejected for `0.1.0` — deliberately left available |

## Decision

One rule, which generalises to constructs nobody enumerated: **text is
preserved, structure is not.** Every textual construct becomes paragraphs,
headings or images; nothing textual is dropped; no structural marker survives.

Applied:

- Inline markup — emphasis, strong, strikethrough, superscript, subscript, FB2
  `<emphasis>` and `<strong>` — contributes its text and nothing else.
- Hyperlinks keep their text and lose their target. Footnote references keep
  their marker text, so a reference reads as `[1]` in the paragraph.
- Lists produce one paragraph per item. Nesting depth is not marked.
- Tables produce one paragraph per row, cells joined by a single space, in
  row-major order.
- Line breaks become a newline character *inside* the paragraph text and never
  split a paragraph. FB2 `<stanza>` is one paragraph whose `<v>` lines are joined
  by newlines; EPUB `<br>` is the same newline. Verse therefore survives
  identically in both formats without a block variant, and segmentation treats
  the newline as whitespace.
- Epigraphs, citations and block quotations become paragraphs with no marker.
- FB2 `<subtitle>` becomes a `HeadingBlock` one level below its section.
- FB2 `<empty-line>` is dropped; it is typography, not text.
- Figures become an `ImageBlock` followed by a paragraph for the caption.
- Ruby annotations keep the base text and drop the reading. MathML, SVG
  illustrations, and embedded audio or video are dropped.
- CSS is never consulted, so a heading that is only a styled `<p>` stays a
  paragraph.

FB2 `<body name="notes">`, and any additional `<body>`, become chapters appended
after the main body in document order, taking their title from the body's
`<title>` and `null` otherwise. Nothing is lost: the note texts are reachable,
the reading order is sane, and the links into them were already gone. In EPUB the
equivalent is free — footnote sections are spine items and are already chapters.

The per-construct table lives in
[format-mapping.md](../engineering/format-mapping.md), which this decision
governs.

## Consequences

### Positive

- No textual content is silently discarded by either reader.
- `Block` stays at three variants, so exhaustive switching stays cheap and the
  sealed hierarchy keeps the property it was sealed for.
- Both formats map through the same rule, so the parity tests
  [testing-policy.md](../engineering/testing-policy.md) requires are writable for
  every construct.
- Verse survives in both formats without a fourth variant, because the newline
  carries it.
- The README's "not extracted" table has a source, and `CHK-05` becomes a review
  against a document rather than against the code's opinion of itself.

### Negative

- A flattened table reads as a run of short unrelated paragraphs, and sentence
  segmentation over it produces sentences that are not sentences. A
  table-dense technical book is served badly.
- List nesting, quotation attribution and emphasis are unrecoverable downstream:
  a consumer cannot restore what the parser did not record.
- Dropping MathML and SVG *is* textual loss in a mathematics or diagram-heavy
  book, and is the one place the "nothing textual is lost" rule is bounded rather
  than absolute. It is stated here so the README states it too.

### Neutral / Organizational

- [format-mapping.md](../engineering/format-mapping.md) holds the full
  per-construct table and is the source for the README.
- [domain/model.md](../domain/model.md) records that paragraph text may contain
  newlines and what they mean.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) records this as
  `DEC-14` with `SC-14` covering note bodies and flattened constructs.

## Risks And Mitigation

The risk is that the corpus contradicts the premise — that verse, tables or
footnotes turn out to be common enough in real books that flattening produces
output a reader would call broken.

Mitigated by sequence: the corpus is collected at `STEP-00b`, before the readers
are written, and [testing-policy.md](../engineering/testing-policy.md) already
requires a manual pass over real books where "the text reads like the book" is
judged by a person. Both happen before `STEP-05`, so the finding, if it comes,
arrives while a fourth `Block` variant is still free.

The second risk is the flattened-table cost landing on a consumer with no way
out. The `origin` marker on `ParagraphBlock` is the mitigation held in reserve:
it is not breaking to add, so it can be shipped in a minor release the first time
someone asks, rather than guessed at now.

## Follow-up

- [format-mapping.md](../engineering/format-mapping.md) completed before
  `STEP-01a` and `STEP-01c`, since it is what those steps implement.
- `DEC-14`, `SC-14` added to the brief; the Test Strategy table gains a row for
  flattened constructs and note bodies.
- The README's format support table derives from `format-mapping.md`, and
  `CHK-05` reviews it against this decision.
- The manual corpus pass explicitly looks at a book with verse, one with tables,
  and an FB2 with footnotes.

## Related Links

- [format-mapping.md](../engineering/format-mapping.md) — the table this governs.
- [domain/model.md](../domain/model.md) — why `Block` is sealed at three.
- [ADR-20260831T144622Z](ADR-20260831T144622Z-inline-images-are-extracted.md) —
  the third variant, and the reason a variant nothing produces cannot ship.
- [ADR-20260831T134925Z](ADR-20260831T134925Z-script-driven-segmentation.md) —
  the segmentation that flattened tables degrade.

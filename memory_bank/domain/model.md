---
title: Document Model
doc_kind: domain
doc_function: canonical
purpose: 'The canonical model both EPUB and FB2 converge on — document, chapter, block, sentence, word — and why Block is sealed.'
derived_from:
  - ../product/value-proposition.md
canonical_for:
  - document_model
status: active
---
# Document Model

Both EPUB and FB2 parse into this one structure. Nothing above the parsing
layer needs to know which format a book came from.

## The Structure

A book is a `BookDocument`. It carries a `BookMetadata` and an ordered list of
chapters, and holds no metadata fields of its own
([ADR-20260831T162651Z](../adr/ADR-20260831T162651Z-document-carries-metadata.md)).
Nesting rather than repeating is what makes the cheap metadata path honest: for
the same bytes and the same fallback, `parse(b).metadata` equals
`parseMetadata(b)`, and that is a test rather than a promise.

A `BookMetadata` carries:

- `title` — nullable. Both formats can omit it and the package invents nothing.
  A caller that needs a display string supplies its own fallback, the way it
  already supplies `fallbackLanguageCode`.
- `authors` — a `List<String>`, empty when the file declares none. Both formats
  allow several, and joining them into one string is a loss that a published
  signature would make permanent.
- `sourceLanguageCode` — an ISO-639-1 code: the value the file declared when it
  is one, and `fallbackLanguageCode` otherwise
  ([ADR-20260831T135025Z](../adr/ADR-20260831T135025Z-language-resolution.md)).
- `cover` — a nullable `ImageData`.

An `ImageData` is the `bytes` the file stored plus the `mediaType` it declared.
The package never decodes or re-encodes either
([ADR-20260831T135125Z](../adr/ADR-20260831T135125Z-raw-cover-bytes.md)), so a
caller that needs a thumbnail makes one, and both formats behave identically. A
cover and an inline image are the same thing, so the model carries one type for
them rather than two. `ImageData` has no `==`: a cover can be several megabytes,
and an equality operator that walks it is a cost hidden behind a symbol.

A `Chapter` carries its `index`, a nullable `title`, a `level`, and a list of
blocks. The chapter list is flat and in reading order; `level` is the depth the
source navigation gave the chapter, `0` at the top
([ADR-20260831T162751Z](../adr/ADR-20260831T162751Z-flat-chapter-list.md)). A
chapter has no identifier: its identity is `index`, stable for the same input
bytes within one major version of the package.

A `Block` is one of exactly three variants:

- `ParagraphBlock` — `text`, plus `sentences` resolved lazily on first access
  through the `TextSegmenter` the paragraph was built with. `text` may contain
  newlines: a line break inside a paragraph is preserved rather than splitting
  the paragraph, which is how verse survives without a variant of its own
  ([ADR-20260831T162951Z](../adr/ADR-20260831T162951Z-non-prose-flattens-to-paragraphs.md));
- `HeadingBlock` — `text` and a `level`;
- `ImageBlock` — an `ImageData`. Both readers produce it
  ([ADR-20260831T144622Z](../adr/ADR-20260831T144622Z-inline-images-are-extracted.md));
  an image that cannot be resolved is skipped rather than failing the parse.

Everything a format holds that is none of the three becomes paragraphs: text is
preserved, structure is not. The construct-by-construct table is
[engineering/format-mapping.md](../engineering/format-mapping.md).

Below a paragraph sit two segmentation types. A `Sentence` carries `text`,
`start`, `end`, and its `words`; a `Word` carries `text`, `start`, and `end`.
For the scripts the built-in rules deliberately carry no word rule for — Thai,
Khmer, Lao, Burmese
([ADR-20260831T134925Z](../adr/ADR-20260831T134925Z-script-driven-segmentation.md)) —
`words` is the empty list: no rule means no words, not one sentence-wide word
pretending to be one (`OQ-25`, closed 2026-09-01). The distinction is
contract-relevant because `Sentence.==` compares `words` element-wise, and the
doc comment states it so an empty list reads as honesty rather than as a bug.

## A Paragraph Holds Its Segmenter

Segmentation is lazy, per paragraph, and configurable — the rules depend on
writing system and sometimes on a language hint
([ADR-20260831T134925Z](../adr/ADR-20260831T134925Z-script-driven-segmentation.md)).
Something therefore has to carry the chosen `TextSegmenter` down to the point
where `sentences` is first touched, and that something is the paragraph itself.

The cost is that `ParagraphBlock` is not a pure value: two paragraphs with equal
text but different segmenters are not interchangeable. The alternative — moving
segmentation to a document-level call — keeps the paragraph pure but replaces
`block.sentences` with a lookup through the document at every reading call site,
which is the ergonomics the lazy design exists to provide.

### The Segmenter Must Be Sendable

Parsing a large book is CPU-bound, so callers run it in an isolate and the whole
`BookDocument` crosses the isolate boundary on the way back. Every object inside
it must therefore be sendable — including the segmenter each paragraph holds.

This makes one rule binding on any `TextSegmenter` implementation, the built-in
one included: **it may hold plain data only** — strings, sets, numbers, enums. In
particular a compiled `RegExp` is not sendable, so pattern objects live in
top-level or static finals, or are built on demand inside `segment`, never in
instance fields.

Break the rule and nothing fails at the segmenter. It fails at the caller's
`Isolate.run`, with an error that names neither the segmenter nor the paragraph.
That is why the constraint is recorded on the model rather than left to whoever
writes an implementation.

## Equality Is Settled For Every Type

`Sentence` and `Word` define `==` and `hashCode` over their fields — `Sentence`
comparing `text`, `start`, `end` and its `words` element-wise, `Word` comparing
`text`, `start` and `end`. Both are bounded by one sentence, so the operator
costs what the value in front of the caller suggests it costs.

**No other exported type defines `==`.** Each compares by identity, and the
reason differs per type rather than being one blanket rule
([ADR-20260901T101500Z](../adr/ADR-20260901T101500Z-value-equality-on-spans-only.md)):

| Type | Why identity |
| --- | --- |
| `ImageData` | The bytes are unbounded and the walk would be invisible |
| `ImageBlock` | Holds an `ImageData`, so any `==` would compare it by identity — a value-looking comparison that is not one |
| `ParagraphBlock` | Holds a consumer-supplied `TextSegmenter`, which has no equality contract of its own |
| `HeadingBlock` | Could have one; withheld so `List<Block>` comparison has a single semantics across the sealed family |
| `BookMetadata` | Holds the cover: comparing it walks megabytes, skipping it calls two different books equal |
| `Chapter`, `BookDocument` | A deep `==` walks the whole book |

`HeadingBlock` is the one row where the answer is uniformity rather than a
property of the type, and it is written that way rather than dressed up.

The asymmetry is deliberate and has to be documented rather than discovered: a
consumer who finds `Sentence ==` working will reasonably expect
`ParagraphBlock ==` to work too. Every type that keeps identity says so in its
doc comment.

Settling this before `0.1.0` was the point. Equality cannot be added quietly
later — it changes how `Set` and `Map` behave for every consumer already written
against identity, so the second version would silently do something different
from the first rather than failing to compile.

## What A Paragraph Does Not Hold

No pagination state. A paragraph carries its text and its segmentation, never
where a viewport happened to cut it
([ADR-20260831T135225Z](../adr/ADR-20260831T135225Z-model-excludes-pagination.md)).
A consumer that paginates wraps the block in a type of its own rather than
extending it — which the sealed hierarchy below makes the only option, on
purpose.

## Offsets Are Paragraph-Relative

`start` and `end` on both `Sentence` and `Word` are positions within the text of
the owning paragraph, not within the book. That locality is what makes lazy
segmentation possible: a paragraph can be segmented alone, on demand, without
any knowledge of what precedes it.

## Block Is Sealed, Deliberately

`Block` is a sealed class. A consumer switching over it must handle every
variant, and adding a fourth variant breaks the build at every call site that
has not been updated.

This is the intended behaviour, not incidental strictness. The alternative — an
open hierarchy with a default branch — would let a new block type be silently
dropped by existing consumers, which is exactly the failure a single shared
model is meant to prevent.

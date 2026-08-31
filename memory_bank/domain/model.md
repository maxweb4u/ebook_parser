---
title: Document Model
doc_kind: domain
doc_function: canonical
purpose: 'The canonical model both EPUB and FB2 converge on — document, chapter, block, sentence, word — and why Block is sealed.'
derived_from:
  - ../product/value-proposition.md
canonical_for:
  - document_model
status: draft
---
# Document Model

Both EPUB and FB2 parse into this one structure. Nothing above the parsing
layer needs to know which format a book came from.

## The Structure

A book is a `BookDocument`. It carries `title`, `author`, `sourceLanguageCode`,
an optional `coverImage`, and an ordered list of chapters.

A `Chapter` carries its `index`, a `title`, and a list of blocks.

A `Block` is one of exactly three variants:

- `ParagraphBlock` — `text`, plus `sentences` resolved lazily on first access;
- `HeadingBlock` — `text` and a `level`;
- `ImageBlock` — raw `bytes`.

Below a paragraph sit two segmentation types. A `Sentence` carries `text`,
`start`, `end`, and its `words`; a `Word` carries `text`, `start`, and `end`.

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

---
title: Value Proposition
doc_kind: product
doc_function: canonical
purpose: 'Why ebook_parser is worth extracting as a package: the FB2 gap on Dart, the single document model both formats converge on, and the four capabilities analogues lack.'
derived_from:
  - context.md
canonical_for:
  - product_value_proposition
status: draft
---
# Value Proposition

## The Gap

FB2 parsers on Dart are effectively absent — this is a real gap, not another
wrapper over solved work. EPUB packages do exist, but each one returns its own
model.

## The Core Value

Both formats converge on a single document model. Everything written above the
parsing layer is written once and does not branch by format. This convergence,
not the parsing of either format alone, is what the package is for.

## What Analogues Lack

Already built in TeaderBook and typically missing elsewhere:

- format detection by magic bytes, for when the extension lies or is absent;
- `.fb2.zip` — the normal distribution form for FB2 — unpacked transparently;
- a cheap metadata-only path: title, author, language, cover without walking chapters;
- lazy segmentation into sentences and words — per paragraph, on first access,
  rather than over the whole book up front.

The last point is why a multi-megabyte book opens fast, and it belongs in the
README as a stated feature rather than an implementation detail.

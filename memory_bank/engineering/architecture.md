---
title: Package Layout
doc_kind: engineering
doc_function: canonical
purpose: 'How the package is laid out on disk — the single export file, what each src/ unit owns, and why test/, example/, and the metadata files are not optional.'
derived_from:
  - ../domain/model.md
  - ../product/value-proposition.md
canonical_for:
  - package_layout
must_not_define:
  - public_api_surface
  - document_model
status: draft
---
# Package Layout

Where each file sits and what it owns. The list of exported names belongs to
[public-api.md](public-api.md); the types those names return belong to
[domain/model.md](../domain/model.md). This document covers the layout only.

## Tree

```
ebook_parser/
  lib/
    ebook_parser.dart          # the only public export
    src/
      book_document.dart
      book_metadata.dart
      parse_result.dart
      book_parser.dart          # the IBookParser interface
      book_parser_factory.dart
      epub_parser.dart
      fb2_parser.dart
      book_archive.dart
      sentence_segmenter.dart
  test/
    fixtures/                   # small books of both formats + corrupt files
  example/
    main.dart                   # open a file, print the table of contents
  README.md
  CHANGELOG.md
  LICENSE                       # MIT
  pubspec.yaml
```

## One Export File

`lib/ebook_parser.dart` is the single entry point. Everything under `lib/src/`
is private to the package by Dart convention, so the export file is the whole
contract: a symbol not named there is not part of the API, and moving a file
inside `src/` is never a breaking change.

## What Each Unit Owns

- `book_document.dart`, `book_metadata.dart` — the model types.
- `parse_result.dart` — `ParseResult<T>` and `ParseFailure`, defined here rather
  than imported, so the package carries no foreign result type.
- `book_parser.dart` — the port; `book_parser_factory.dart` — format detection
  and parser selection.
- `epub_parser.dart`, `fb2_parser.dart` — one implementation per format. They
  are the only files that know a format exists; everything above them sees the
  shared model.
- `book_archive.dart` — zip handling, so `.fb2.zip` unpacks before the FB2
  parser is reached and the parser itself never learns about archives.
- `sentence_segmenter.dart` — moves into the package rather than staying
  behind. Without it `ParagraphBlock.sentences` does not work, and lazy
  segmentation is a stated selling point, not an internal convenience.

## test/ And example/ Are Not Optional

`test/fixtures/` holds small books of both formats **and deliberately corrupt
files**. Malformed input returning `Err` instead of throwing is part of the
contract, so it needs fixtures that are actually broken.

`example/main.dart` is not a formality either — pub.dev scores it, and it
affects the package's pub points.

## Repository Naming

pub.dev requires `lowercase_with_underscores`, so the repository directory is
named `ebook_parser` to match the package. This differs from the neighbouring
`react-native-matrix` directory; the convention here follows pub.dev, not the
sibling projects.

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
  - package_metadata
must_not_define:
  - public_api_surface
  - document_model
status: active
---
# Package Layout

Where each file sits and what it owns. The list of exported names belongs to
[public-api.md](public-api.md); the types those names return belong to
[domain/model.md](../domain/model.md). This document covers the layout only.

## Tree

```
ebook_parser/
  lib/
    ebook_parser.dart           # the parsing contract — the default import
    serialization.dart          # opt-in JSON codec; a caller that only parses never imports it
    src/
      book_document.dart        # the model + the bodySample extension
      book_metadata.dart
      parse_result.dart
      book_parser.dart          # the IBookParser interface
      book_parser_factory.dart
      book_archive.dart
      language_codes.dart       # the ISO-639-1 set + normalization
      segmentation/
        text_segmenter.dart     # the port
        rule_based_segmenter.dart
        script_rules.dart       # terminators and script classes
      epub/
        epub_parser.dart        # OPF/spine/TOC to the shared model
        container_reader.dart   # META-INF/container.xml to the OPF path
        package_reader.dart     # OPF: metadata, manifest, spine
        navigation_reader.dart  # NCX navMap and EPUB 3 nav
        xhtml_blocks.dart       # chapter XHTML to blocks
      fb2/
        fb2_parser.dart
        fb2_encoding.dart       # XML prolog sniffing and legacy codecs
      codec/
        book_document_codec.dart
  test/
    fixtures/                   # golden books; corrupt inputs are generated
  example/
    main.dart                   # open a book, print the contents and a sentence
  .github/workflows/ci.yaml   # analyze, test, publish --dry-run
  README.md
  CHANGELOG.md
  LICENSE                       # MIT
  pubspec.yaml
```

The package sits at the repository root: `lib/`, `test/` and `pubspec.yaml` are
siblings of `memory_bank/`. That is what pub.dev expects and what
`dart pub publish` looks at without configuration.

## Two Export Files, One Contract

`lib/ebook_parser.dart` is the entry point. Everything under `lib/src/` is
private to the package by Dart convention, so the export file is the whole
contract: a symbol not named there is not part of the API, and moving a file
inside `src/` is never a breaking change.

`lib/serialization.dart` is the second, opt-in library
([ADR-20260831T135325Z](../adr/ADR-20260831T135325Z-optional-serialization-library.md)).
It exists so persistence is available to callers who want it and invisible to
callers who do not. Its encoded shape is a compatibility promise like any
exported symbol, versioned by the schema constant it exports.

## What Each Unit Owns

- `book_document.dart`, `book_metadata.dart` — the model types.
- `parse_result.dart` — `ParseResult<T>` and `ParseFailure`, defined here rather
  than imported, so the package carries no foreign result type.
- `book_parser.dart` — the port; `book_parser_factory.dart` — format detection,
  parser selection, and the unwrapping decorator a wrapped book is routed through
  ([ADR-20260831T162851Z](../adr/ADR-20260831T162851Z-zip-routing-decorator.md)).
- `epub/`, `fb2/` — one directory per format. They are the only places that know
  a format exists; everything above them sees the shared model. `epub/` is the
  package's own reader rather than a wrapper
  ([ADR-20260831T134825Z](../adr/ADR-20260831T134825Z-own-epub-reader.md)), which
  is why it is several files: container lookup, OPF, navigation, and XHTML each
  fail in their own way and are worth isolating. Both directories resolve inline
  images into the model
  ([ADR-20260831T144622Z](../adr/ADR-20260831T144622Z-inline-images-are-extracted.md)),
  and both keep the metadata path from touching chapter content.
- `book_archive.dart` — zip handling, and **public**, not internal: a zip holding
  no book or several books is an outcome the caller must decide about
  ([ADR-20260831T135425Z](../adr/ADR-20260831T135425Z-archive-layer-is-public.md)).
  The line it draws is between a format container and a transport wrapper. An
  EPUB container *is* a zip, so `epub/` reads one and always will; a `.fb2.zip`
  wraps a file that is not itself an archive, and no format parser learns that
  such a wrapper exists — it is unwrapped by the decorator in
  `book_parser_factory.dart` before the FB2 parser sees anything
  ([ADR-20260831T162851Z](../adr/ADR-20260831T162851Z-zip-routing-decorator.md)).
- `language_codes.dart` — the ISO-639-1 set and BCP-47 normalization, so no
  consumer's supported-language list is baked into a parser
  ([ADR-20260831T135025Z](../adr/ADR-20260831T135025Z-language-resolution.md)).
- `codec/` — the JSON codec behind `serialization.dart`, kept out of the parsing
  path entirely.
- `segmentation/` — moves into the package rather than staying behind. Without it
  `ParagraphBlock.sentences` does not work, and lazy segmentation is a stated
  selling point, not an internal convenience. It is a directory rather than one
  file because the port, the default rules, and the per-script data are three
  separate things
  ([ADR-20260831T134925Z](../adr/ADR-20260831T134925Z-script-driven-segmentation.md)).
- The `bodySample` extension lives in `book_document.dart` beside the model it
  walks. It needs no file of its own: it is a read-only traversal of
  `BookDocument` with no state and no dependencies.

## test/ And example/ Are Not Optional

`test/fixtures/` holds a small golden book per real-world variant — EPUB 2 with
an NCX, EPUB 3 with a nav document, FB2 in windows-1251 — because a synthetic
sample only ever confirms what we already believe about the format.

Everything else is built in code: the contract tests construct their inputs with
small builders, and the corrupt inputs are produced by mutating those bytes.
Malformed input returning `Err` instead of throwing is part of the contract, and
generated corruption covers it more thoroughly than a handful of broken files
could. If the golden files grow past roughly 150 KB they move behind
`.pubignore`, since `dart pub publish` ships `test/` to every consumer.

`example/main.dart` is not a formality either — pub.dev scores it, and it
affects the package's pub points.

## Package Metadata

`pubspec.yaml` facts that are decisions rather than defaults:

| Field | Value | Why |
| --- | --- | --- |
| `name` | `ebook_parser` | [ADR-20260830T161251Z](../adr/ADR-20260830T161251Z-package-name-ebook-parser.md) |
| `version` | `0.1.0` | Below 1.0.0 breaking changes are expected, and there will be some — the EPUB reader and the segmenter are both new code |
| `environment: sdk` | the lowest bound that compiles, expected around `^3.0.0` | Sealed classes and pattern matching need Dart 3; nothing here needs more. A higher bound copied from a consuming app would exclude users for no reason |
| `description` | 60-180 characters | Outside that range pub.dev deducts points |
| `topics` | `epub`, `fb2`, `ebook`, `parser`, `reader` | How the package is found by search; five is the maximum |
| dependencies | `archive` ^4, `xml`, `path`, `html`, `enough_convert` | Owned by [public-api.md](public-api.md) |

`dart pub publish` ships `test/` to every consumer, so golden fixtures move
behind `.pubignore` if they grow past roughly 150 KB.

Public API elements are documented: pub.dev scores the proportion that carry doc
comments, and the exported surface here is small enough to cover completely.

CI runs `dart analyze`, `dart test`, and `dart pub publish --dry-run` on every
push. For a package other people install, "it worked on my machine" is not a
state worth reaching.

## Repository Naming

pub.dev requires `lowercase_with_underscores`, so the repository directory is
named `ebook_parser` to match the package. This differs from the neighbouring
`react-native-matrix` directory; the convention here follows pub.dev, not the
sibling projects.

---
title: Public API Surface
doc_kind: engineering
doc_function: canonical
purpose: 'What ebook_parser exports and what stays in src/ — the format-detection entry point, the IBookParser port, and the sample-text utility.'
derived_from:
  - ../domain/model.md
canonical_for:
  - public_api_surface
status: draft
---
# Public API Surface

Exactly this is exported from `lib/ebook_parser.dart`. Everything else lives in
`src/` and is not part of the contract. The model these calls return is owned by
[domain/model.md](../domain/model.md).

## Entry Point

```dart
IBookParser? bookParserFor(String filePath, Uint8List bytes);
const supportedBookExtensions;    // ['epub', 'fb2']
const importableBookExtensions;   // + 'zip'
```

`bookParserFor` takes both the path and the bytes because format detection does
not trust the extension — magic bytes decide. It returns `null` rather than
throwing when no parser matches; an unrecognised file is an expected outcome,
not an error.

The two constant lists differ on purpose: `zip` is importable but not a format.
It is the `.fb2.zip` distribution wrapper, unpacked before parsing.

## The Port

```dart
abstract interface class IBookParser {
  Future<ParseResult<BookDocument>> parse(Uint8List bytes,
      {required String fallbackLanguageCode});
  Future<ParseResult<BookMetadata>> parseMetadata(Uint8List bytes,
      {required String fallbackLanguageCode});
}
```

Two methods, not one with a flag. `parseMetadata` is the cheap path — title,
author, language, cover — and must not walk chapters; that separation is the
point, and collapsing it into an option would make the cost invisible at the
call site.

`fallbackLanguageCode` is required, not defaulted. A book that declares no
language is common, and the caller is the only party that knows what to assume.

Both methods return `ParseResult<T>` and never throw on malformed input.
Corrupt files are an expected result, so they arrive as `Err` with a
`ParseFailure` kind: `corrupt`, `unsupportedFormat`, `encoding`, or
`emptyDocument`.

## Utility

```dart
String sampleTextOf(BookDocument document, {int maxChars = 4000});
```

## No Flutter

The package depends only on `archive`, `xml`, and `path`. A `flutter`
dependency would make it unusable from server and CLI code, which is roughly
half the potential callers.

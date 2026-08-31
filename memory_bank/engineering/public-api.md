---
title: Public API Surface
doc_kind: engineering
doc_function: canonical
purpose: 'What ebook_parser exports and what stays in src/ — the format-detection entry point, the IBookParser port, and the sample-text utility.'
derived_from:
  - ../domain/model.md
canonical_for:
  - public_api_surface
status: active
---
# Public API Surface

Exactly this is exported. Everything else lives in `src/` and is not part of the
contract. The model these calls return is owned by
[domain/model.md](../domain/model.md); where each file sits is owned by
[architecture.md](architecture.md).

## Entry Point

```dart
IBookParser? bookParserFor(String filePath, Uint8List bytes);
const List<String> supportedBookExtensions;    // ['epub', 'fb2']
const List<String> importableBookExtensions;   // + 'zip'
```

`bookParserFor` takes both the path and the bytes because format detection does
not trust the extension — magic bytes decide. It returns `null` rather than
throwing when no parser matches; an unrecognised file is an expected outcome,
not an error.

The two constant lists differ on purpose: `zip` is importable but not a format.
It is the `.fb2.zip` distribution wrapper, unpacked before parsing.

A caller always passes the bytes it holds — to `bookParserFor`, and then to
`parse`. For a zip holding exactly one book, `bookParserFor` returns an
unwrapping decorator over the parser for the inner file rather than that parser
itself, so no format parser acquires transport responsibilities and the caller
unwraps nothing
([ADR-20260831T162851Z](../adr/ADR-20260831T162851Z-zip-routing-decorator.md)).
The decorator is not a named export: it is an `IBookParser` like any other.
Unwrapping is one level deep, and the decorator caches nothing, so
`parseMetadata` followed by `parse` decompresses twice.

An EPUB is passed as the zip it is — its container is part of the format. A zip
holding nothing readable, or several books, yields `null`; telling those two
apart is what `inspectBookArchive` is for.

## The Archive Layer

```dart
bool isZipArchive(Uint8List bytes);
ArchiveContent inspectBookArchive(Uint8List bytes);

sealed class ArchiveContent {}
class NotAnArchive       extends ArchiveContent {}
class EpubArchive        extends ArchiveContent {}
class WrappedBook        extends ArchiveContent { final String name; final Uint8List bytes; }
class NoBookInside       extends ArchiveContent {}
class SeveralBooksInside extends ArchiveContent { final List<String> names; }
```

Exported rather than hidden
([ADR-20260831T135425Z](../adr/ADR-20260831T135425Z-archive-layer-is-public.md)).
An unambiguous `.fb2.zip` is still routed transparently by `bookParserFor`, so
the simple case needs none of this. A caller reaches for `inspectBookArchive`
when it must tell the ambiguous cases apart: a zip with nothing readable in it
and a zip with three books in it are import decisions, not parse failures, and
`SeveralBooksInside` is refused rather than guessed because picking the first
imports a book nobody chose.

`ArchiveContent` is sealed, so a sixth outcome would break every consumer's
switch. That is intended, for the same reason it is intended on `Block`.

## The Port

```dart
abstract interface class IBookParser {
  Future<ParseResult<BookDocument>> parse(Uint8List bytes,
      {required String fallbackLanguageCode, TextSegmenter? segmenter});
  Future<ParseResult<BookMetadata>> parseMetadata(Uint8List bytes,
      {required String fallbackLanguageCode});
}
```

Two methods, not one with a flag. `parseMetadata` is the cheap path — title,
author, language, cover — and must not walk chapters; that separation is the
point, and collapsing it into an option would make the cost invisible at the
call site. Nothing on that path decodes an image
([ADR-20260831T135125Z](../adr/ADR-20260831T135125Z-raw-cover-bytes.md)).

`fallbackLanguageCode` is required, not defaulted. A book that declares no
language is common, and the caller is the only party that knows what to assume.

`segmenter` is optional: omitted, paragraphs get the rule-based default, seeded
with the document's own resolved language.

Both methods are `Future`-returning but do no I/O — the work is CPU-bound from
start to finish. Awaiting `parse` on a large book therefore blocks the isolate it
runs on, and callers with a user interface should run it through `Isolate.run`.
That works only while everything inside the returned document is sendable, which
is why `TextSegmenter` implementations are constrained
([domain/model.md](../domain/model.md)).

Both methods return `ParseResult<T>` and never throw on malformed input.

## Result Type

```dart
sealed class ParseResult<T> {
  const ParseResult();
  T? get valueOrNull;
}
final class ParseOk<T>  extends ParseResult<T> { const ParseOk(this.value);   final T value; }
final class ParseErr<T> extends ParseResult<T> { const ParseErr(this.failure); final ParseFailure failure; }

enum ParseFailureKind { corrupt, unsupportedFormat, encoding, emptyDocument }

final class ParseFailure {
  const ParseFailure(this.kind, this.message, {this.cause});

  /// What went wrong. Branch on this to produce user-facing text.
  final ParseFailureKind kind;

  /// Diagnostic detail for logs and bug reports: which reader, which stage,
  /// what was expected. English, never localised — not a string to display.
  final String message;

  final Object? cause;
}
```

`ParseOk` and `ParseErr`, not `Ok` and `Err`. These names land in every
consumer's namespace, and `Ok` is a name applications commonly already hold —
TeaderBook does, in its own `Result<T>`. The prefix also makes the migration
incremental: the app's `Ok` and the package's `ParseOk` coexist while call sites
move one at a time.

Corrupt files are an expected result, so they arrive as `ParseErr`.

`kind` and `message` serve different audiences and are not interchangeable
([ADR-20260831T140218Z](../adr/ADR-20260831T140218Z-parse-result-type.md)). A
consumer switches on `kind` to say something in its own language; `message`
carries the detail a raw wrapped exception does not — which format, which
reader, which stage — and belongs in a log.

`ParseFailureKind` is an enum rather than a sealed hierarchy, and `ParseFailure`
is not sealed: a consumer branching on the cause usually wants a default case,
and a fifth cause should not break every call site the way a new `Block` variant
deliberately does.

## Model Types

The model is exported in full. Its semantics are owned by
[domain/model.md](../domain/model.md); the names that form the contract are:

```dart
class BookDocument { final BookMetadata metadata; final List<Chapter> chapters; }

class BookMetadata { final String? title;
                     final List<String> authors;
                     final String sourceLanguageCode;
                     final ImageData? cover; }

class ImageData { final Uint8List bytes; final String mediaType; }

class Chapter { final int index; final String? title;
                final int level;  final List<Block> blocks; }

sealed class Block {}
final class ParagraphBlock extends Block { final String text;
                                           List<Sentence> get sentences; }
final class HeadingBlock   extends Block { final String text; final int level; }
final class ImageBlock     extends Block { final ImageData image; }

class Sentence { final String text; final int start, end;
                 final List<Word> words; }
class Word     { final String text; final int start, end; }
```

`BookMetadata` is both what `parseMetadata` returns and what `parse` puts on the
document, so the cheap path cannot answer differently from the full one
([ADR-20260831T162651Z](../adr/ADR-20260831T162651Z-document-carries-metadata.md)).
`title` is nullable and `authors` may be empty: the package declares what the
file declared and invents nothing.

`ImageData` covers both the cover and every inline image, and has no `==` — a
cover can be several megabytes, and walking it behind an operator is a cost the
caller cannot see.

`Chapter.level` is navigation depth, not heading depth, and the chapter list is
flat and in reading order
([ADR-20260831T162751Z](../adr/ADR-20260831T162751Z-flat-chapter-list.md)). What
each format contributes to each of these is
[format-mapping.md](format-mapping.md).

## Segmentation

```dart
abstract interface class TextSegmenter {
  List<Sentence> segment(String paragraphText);
}

class RuleBasedSegmenter implements TextSegmenter {
  const RuleBasedSegmenter({String? languageCode, Set<String> abbreviations});
}
```

Exported so a caller who needs dictionary-quality segmentation for an unspaced
script supplies one instead of forking the package
([ADR-20260831T134925Z](../adr/ADR-20260831T134925Z-script-driven-segmentation.md)).
`languageCode` exists for the cases rules cannot infer from the text — modern
Greek's ASCII `;` question mark being the standing example.

An implementation must hold plain data only. It travels inside every paragraph it
segments, so a non-sendable field — a compiled `RegExp` most of all — stops the
whole document from crossing an isolate boundary. Keep patterns in top-level or
static finals. The rule and its failure mode are in
[domain/model.md](../domain/model.md).

## Languages

```dart
String normalizeLanguageCode(String? declared, {required String fallback});
```

Takes the primary subtag of a BCP-47 value, lower-cases it, and returns it when
it is in ISO-639-1; otherwise returns `fallback`. The package validates against
the whole standard and holds no application's supported-language list; narrowing
is the caller's, at the call site where its own catalog already lives
([ADR-20260831T135025Z](../adr/ADR-20260831T135025Z-language-resolution.md)).

## Serialization — A Second Import

```dart
import 'package:ebook_parser/serialization.dart';

const int kBookDocumentSchemaVersion;

Map<String, dynamic> bookDocumentToJson(BookDocument document);
BookDocument? bookDocumentFromJson(Map<String, dynamic> json, {TextSegmenter? segmenter});

Map<String, dynamic> blockToJson(Block block);
Block blockFromJson(Map<String, dynamic> json, {TextSegmenter? segmenter});
```

A separate library, so a caller that only parses never sees it
([ADR-20260831T135325Z](../adr/ADR-20260831T135325Z-optional-serialization-library.md)).
`kBookDocumentSchemaVersion` describes the shape of the model, not a cache
policy: a consumer stores it beside its own cache version and treats a mismatch
in either as a miss.

Sentence spans are not encoded. They are re-segmented lazily on access, which is
what keeps the file small and the load cheap.

Decoding takes a `segmenter` for that reason: a segmenter cannot be represented
in JSON, so without it a document restored from cache would segment differently
from the same document straight out of the parser — silently, and only in the
languages where the rules diverge. Pass the same one `parse` was given.

`blockToJson`/`blockFromJson` are exported separately so a consumer that stores
something block-shaped of its own — a paginated wrapper, for instance — composes
with them instead of writing a second block serialiser.

## Body Sampling

```dart
extension BookDocumentSample on BookDocument {
  String bodySample({int maxChars = 4000});
}
```

Collects text from the start of the body forward, paragraphs only, until the
limit is reached. Headings are skipped deliberately: chapter titles are short and
often stylised, and a table of contents is the least representative text in a
book.

It exists because callers detecting a book's language need exactly this, and the
two non-obvious parts — skip headings, read forward from the body rather than
sampling the whole book — are what people get wrong writing it themselves.

Shipped as an extension on `BookDocument` rather than the free function
`sampleTextOf` it was in TeaderBook. As a free function it read as a utility
bolted onto a parsing contract; as an extension it is part of the model, which is
what it actually is — a read-only traversal with no state and no dependencies.

## No Flutter

Every dependency is pure Dart; a `flutter` dependency would make the package
unusable from server and CLI code, which is roughly half the potential callers.

The dependency set after the extraction decisions:

| Package | Why |
| --- | --- |
| `archive` (major 4) | zip: EPUB containers and `.fb2.zip` |
| `xml` | FB2, OPF, NCX, container |
| `path` | extension handling and relative-path resolution inside EPUB |
| `html` | chapter XHTML, which real books do not guarantee is valid XML |
| `enough_convert` | windows-1251/1250/1252 and koi8-r/u, without which FB2 from public catalogues is unreadable |

`epubx` is gone, because the package reads EPUB itself
([ADR-20260831T134825Z](../adr/ADR-20260831T134825Z-own-epub-reader.md)), and
`image` is gone, because covers are never decoded
([ADR-20260831T135125Z](../adr/ADR-20260831T135125Z-raw-cover-bytes.md)).

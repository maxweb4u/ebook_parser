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
Unwrapping is one level deep, and the decorator caches nothing.

The cost of that is three decompressions, not the two recorded here previously:
`bookParserFor` must already look inside the archive to tell an EPUB from a
`.fb2.zip` and choose a parser, and then `parseMetadata` and `parse` each open it
again. Corpus measurement makes this the normal path rather than an edge case —
94% of the local FB2 collection is distributed as `.fb2.zip`
([corpus-findings.md](corpus-findings.md)) — and the shape that pays for it is a
library import, which calls `parseMetadata` across many books in a row. Recorded
rather than optimised in `0.1.0`; a caller that minds can inspect once with
`inspectBookArchive` and hand the inner bytes straight to the format parser.

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

It is cheap for **both** formats, which took a decision to make true. EPUB reads
the container, the OPF and one manifest entry. FB2 is a single XML document whose
`<binary>` elements sit at the end, so a DOM parse would read the whole book to
reach the cover — the metadata reader therefore streams, capturing
`<description>` and then skipping to the one `<binary>` the coverpage names
([ADR-20260901T101900Z](../adr/ADR-20260901T101900Z-streaming-fb2-metadata.md)).
`parseMetadata` means the same thing whichever format it is given.

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

Two things about that guidance are easy to read as more than they promise, and
both belong in the README rather than in a surprised bug report.

Segmentation is not moved into the isolate by moving the parse into it. It is
lazy, so it runs when `sentences` is first touched — which is on whichever
isolate is doing the reading, normally the one with the user interface. Per
paragraph that is small, and across a book it is not nothing. A caller who wants
the whole cost paid inside the isolate touches `sentences` there before returning
the document; the package offers no eager mode in `0.1.0`.

And the document is copied on its way out, not shared. `ImageData.bytes` is an
ordinary `Uint8List`, so an illustrated book — the corpus holds an FB2 with 660
binaries — is duplicated at the port for as long as the transfer takes. The
laziness in this model is about sentences; images are eager and resident, which
is the opposite trade and worth knowing before parsing a picture book on a phone.

Both methods return `ParseResult<T>` and never throw on malformed input.

## Result Type

```dart
sealed class ParseResult<T> {
  const ParseResult();
  T? get valueOrNull;
}
final class ParseOk<T>  extends ParseResult<T> { const ParseOk(this.value);   final T value; }
final class ParseErr<T> extends ParseResult<T> { const ParseErr(this.failure); final ParseFailure failure; }

enum ParseFailureKind {
  corrupt, unsupportedFormat, encoding, emptyDocument, drmProtected,
}

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
is not sealed: a consumer branching on the cause usually wants a default case.

The second half of that reasoning used to read "and a fifth cause should not
break every call site the way a new `Block` variant deliberately does". That is
wrong, and is corrected here rather than quietly deleted. In Dart 3 an enum is an
exhaustive type exactly as a sealed class is: a `switch` expression over one must
cover every constant, and adding a constant breaks any consumer who wrote the
idiomatic form. Enum and sealed differ in ergonomics, not in what they cost to
extend. **The set is therefore closed at five for the major version**
([ADR-20260901T101600Z](../adr/ADR-20260901T101600Z-parse-failure-kinds-closed-at-five.md)).

| Kind | Returned when |
| --- | --- |
| `corrupt` | The bytes are not a readable file of the format they claim, at any stage |
| `unsupportedFormat` | The bytes are recognisable and not a format this package reads |
| `encoding` | The declared or sniffed encoding cannot decode the bytes |
| `emptyDocument` | Parsing succeeded and produced no `Block` of any variant, in any chapter ([ADR-20260901T101700Z](../adr/ADR-20260901T101700Z-empty-document-means-no-blocks.md)) |
| `drmProtected` | An EPUB container declares encryption over its content — `META-INF/encryption.xml` covering publication resources, or `META-INF/rights.xml` |

Two of those carry a distinction worth reading before implementing.

`emptyDocument` is **not** "no text". A chapter holding a single `ImageBlock` is
content, so a fixed-layout book or a comic parses successfully; only a document
with no blocks at all is refused. TeaderBook today does the opposite, and that
deviation is recorded.

`drmProtected` is **not** "an `encryption.xml` exists". The same file carries
font obfuscation, which is not DRM — the package reads neither fonts nor CSS, so
such a book parses normally with nothing missing. Testing for the file's presence
rather than for what it encrypts would refuse well-produced books. FB2 has no
encryption concept, so this kind is EPUB-only.

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
  const RuleBasedSegmenter({String? languageCode,
                            Set<String> abbreviations = const {}});
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
it is in ISO-639-1; otherwise returns `fallback`.

One consequence is worth weighing before `0.1.0`: a file declaring an ISO-639-2
code — `eng`, `deu`, `rus`, which older conversion toolchains do emit — is not in
ISO-639-1, so it silently becomes the caller's fallback instead of the language
the file actually declared. No file in the corpus does this, so the frequency is
unmeasured here and the risk is judged rather than counted; against that, a
639-2/B-to-639-1 table is about twenty lines and settles it permanently. Recorded
as a known limitation, not yet a decision. The package validates against
the whole standard and holds no application's supported-language list; narrowing
is the caller's, at the call site where its own catalog already lives
([ADR-20260831T135025Z](../adr/ADR-20260831T135025Z-language-resolution.md)).

## Serialization — A Second Import

```dart
import 'package:ebook_parser/serialization.dart';

const int kBookDocumentSchemaVersion;

({Map<String, dynamic> json, Map<String, ImageData> images})
    encodeBookDocument(BookDocument document);

BookDocument? decodeBookDocument(
    Map<String, dynamic> json, {
    Map<String, ImageData> images = const {},
    TextSegmenter? segmenter});

({Map<String, dynamic> json, Map<String, ImageData> images})
    encodeBlock(Block block);

Block? decodeBlock(
    Map<String, dynamic> json, {
    Map<String, ImageData> images = const {},
    TextSegmenter? segmenter});
```

A separate library, so a caller that only parses never sees it
([ADR-20260831T135325Z](../adr/ADR-20260831T135325Z-optional-serialization-library.md)).
`kBookDocumentSchemaVersion` describes the shape of the model, not a cache
policy: a consumer stores it beside its own cache version and treats a mismatch
in either as a miss.

Two things stay out of the json, for two different reasons.

**Sentence spans** are not encoded. They are re-segmented lazily on access, which
is what keeps the file small and the load cheap. Decoding takes a `segmenter` for
that reason: a segmenter cannot be represented in JSON, so without it a document
restored from cache would segment differently from the same document straight out
of the parser — silently, and only in the languages where the rules diverge. Pass
the same one `parse` was given.

**Image bytes** are not encoded either, and are handed back to the caller instead
([ADR-20260901T101800Z](../adr/ADR-20260901T101800Z-images-encoded-by-reference.md)).
Every `ImageData` in the document — inline blocks and the cover alike — becomes a
reference carrying a stable id and its `mediaType`, and the bytes arrive in the
`images` map for the caller to store as it likes. Measured over 247 local FB2
files, base64 binaries are a median 13.6% of the file and up to 95.7%, with one
book carrying 328 images and ~15 MB of base64: embedded, restoring such a
document costs more than re-parsing the original, which is not what a cache is
for.

The difference between the two is worth stating, because it decides what happens
to each. Spans are re-derived on access; image bytes cannot be regenerated from
anything. So they are returned rather than dropped, and **an unresolved reference
is a decode failure, not a hole** — `decodeBookDocument` returns `null` when the
json names an image the supplied map does not carry. The default empty map exists
for documents that have no images; it is not a way to restore an illustrated book
without its pictures. Ids are meaningful only within one encoded document, so a
consumer must not key long-lived storage on them across re-encodes.

`encodeBlock`/`decodeBlock` are exported separately so a consumer that stores
something block-shaped of its own — a paginated wrapper, for instance — composes
with them instead of writing a second block serialiser, and they carry the same
two-part shape for the same reason.

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
| `path` | extension handling, and — through the `p.url` context only — relative-path resolution inside EPUB ([architecture.md](architecture.md)) |
| `html` | chapter XHTML, which real books do not guarantee is valid XML |
| `enough_convert` | windows-1251/1250/1252 and koi8-r/u, without which FB2 from public catalogues is unreadable |

One property of that set is worth stating rather than discovering: `archive`
decompresses into memory, and the package sets no ceiling on how much. Every
caller feeds it files a user supplied, so a crafted archive can exhaust memory
before any parsing begins — and `ParseErr` is no help once the process is already
gone. No guard in `0.1.0`; a caller parsing genuinely hostile input runs the
parse in an isolate it can kill, which is the same isolate the size of these
books already justifies.

`epubx` is gone, because the package reads EPUB itself
([ADR-20260831T134825Z](../adr/ADR-20260831T134825Z-own-epub-reader.md)), and
`image` is gone, because covers are never decoded
([ADR-20260831T135125Z](../adr/ADR-20260831T135125Z-raw-cover-bytes.md)).

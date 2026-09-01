# ebook_parser

Parse EPUB and FB2 ebooks into one shared document model — with lazy sentence
and word segmentation, a cheap metadata-only path, and transparent `.fb2.zip`
handling. Pure Dart: no Flutter, so it runs in servers and CLI tools as well
as in apps.

## Why another ebook package

- **FB2, properly.** Full FB2 support — verse, epigraphs, notes bodies,
  legacy encodings (windows-1251/1250/1252, KOI8-R/U), and the `.fb2.zip`
  wrapper FB2 is actually distributed in — next to EPUB, converging on one
  model, so nothing above the parsing layer branches on format.
- **Lazy segmentation.** Every paragraph exposes `sentences` — sentence and
  word spans with paragraph-relative offsets — segmented on first access
  through a replaceable `TextSegmenter`. Nothing is segmented up front, and a
  tap-to-translate or per-word-lookup UI gets its spans for free.
- **A metadata path that is actually cheap.** `parseMetadata` returns title,
  authors, language and cover without reading any chapter — for both formats.
  The FB2 side streams XML events instead of building a DOM, so a library
  import over hundreds of books never decodes their bodies.
- **Chapters follow the table of contents, not the file layout.** A spine
  item holding several navigation entries is split at its anchors, so an
  anthology or poetry collection keeps all of its table of contents. (A
  spine-granularity reader turns the 718 entries of Standard Ebooks' *Leaves
  of Grass* into 44 chapters; this one returns 718.)
- **Expected failures are values.** Malformed input returns
  `ParseErr` with a `ParseFailureKind` — `corrupt`, `unsupportedFormat`,
  `encoding`, `emptyDocument`, `drmProtected` — and never throws.

## Usage

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:ebook_parser/ebook_parser.dart';

Future<void> main() async {
  final bytes = Uint8List.fromList(File('book.fb2.zip').readAsBytesSync());

  // Pass the path and the bytes you hold. Magic bytes decide the format;
  // a .fb2.zip is unwrapped transparently.
  final parser = bookParserFor('book.fb2.zip', bytes);
  if (parser == null) return; // not a supported book

  final result = await parser.parse(bytes, fallbackLanguageCode: 'en');
  switch (result) {
    case ParseErr(:final failure):
      // Branch on failure.kind for user-facing text; failure.message is
      // diagnostic English for logs.
      print('failed: ${failure.kind.name}');
    case ParseOk(value: final book):
      print(book.metadata.title);
      for (final chapter in book.chapters) {
        print('${'  ' * chapter.level}${chapter.title ?? '(untitled)'}');
      }
      final paragraph = book.chapters.first.blocks
          .whereType<ParagraphBlock>()
          .first;
      for (final sentence in paragraph.sentences) {
        print('${sentence.text} — ${sentence.words.length} words');
      }
  }
}
```

`fallbackLanguageCode` is required: books commonly declare no language, and
only you know what to assume. It must reduce to ISO-639-1 (`'en'`, `'en-US'`,
`'eng'` all work) or `ArgumentError` is thrown. A declared language is
normalized the same way — BCP-47 primary subtag, ISO-639-2 mapped to 639-1 —
and validated against the whole standard; narrowing to your app's supported
set is your call site's job.

### The model

```
BookDocument
├─ BookMetadata      title?, authors, sourceLanguageCode, cover?
└─ List<Chapter>     flat, in reading order; index, title?, level, blocks
   └─ List<Block>    sealed: ParagraphBlock | HeadingBlock | ImageBlock
      └─ ParagraphBlock.sentences → List<Sentence> → List<Word>   (lazy)
```

Things worth knowing before rendering:

- **Untitled chapters are normal.** Front matter nobody navigated to — a
  title page, a dedication — arrives as chapters with `title == null`. A
  table-of-contents view filters on `title != null`.
- **Heading blocks are rare in real EPUBs.** Publishers style headings with
  CSS classes on `<p>`, which this package never reads. Chapter titles
  arrive in `Chapter.title` — render that yourself; no synthetic heading
  block is injected.
- **`Chapter.level` is navigation depth** (0 at the top), not heading depth.
  `Chapter.index` is the chapter's position in the list, stable for the same
  bytes within one major version.
- **Only `Sentence` and `Word` define `==`.** Every other exported type
  compares by identity, deliberately — a deep `==` on a book or a cover
  walks megabytes behind a symbol.

### Metadata without parsing

```dart
final meta = await parser.parseMetadata(bytes, fallbackLanguageCode: 'en');
```

Same fields as `parse(...).metadata` — by contract and by test the two are
equal field for field. Covers are returned **as stored** (`ImageData`: bytes
plus declared media type, possibly SVG for EPUB); nothing is ever decoded or
re-encoded, so make your own thumbnail. A DRM-protected EPUB fails here too,
with `drmProtected` — the cheap path will not put an unopenable book into
your library.

### Large books and isolates

Both methods are `Future`-returning but CPU-bound: on a large book, `await
parser.parse(...)` blocks its isolate. Run it through `Isolate.run`:

```dart
final book = await Isolate.run(() async =>
    ((await parser.parse(bytes, fallbackLanguageCode: 'en'))
        as ParseOk<BookDocument>).value);
```

Everything in the document is sendable — including the segmenter each
paragraph holds, as long as a custom `TextSegmenter` keeps to plain data
(no compiled `RegExp` in instance fields). Two caveats:

- Segmentation is lazy, so it runs where `sentences` is first touched — on
  the reading isolate, unless you touch it inside the worker first.
- Images are eager and resident: an illustrated book's bytes are all in
  memory, and copied across the isolate boundary.

### Caching with the serialization library

```dart
import 'package:ebook_parser/serialization.dart';

final (:json, :images) = encodeBookDocument(book);
// Store BOTH halves: the json as text, the image bytes as files or blobs.
// Image ids are stable only within this one encoded document.

final restored = decodeBookDocument(json, images: images);
```

Sentence spans are not encoded — they re-segment lazily on load. Image bytes
are not embedded either; they come back in the `images` map, because a cache
that base64-encodes an illustrated book restores slower than re-parsing it.
`decodeBookDocument` returns `null` in exactly three cases: unreadable json,
a schema-version mismatch (`kBookDocumentSchemaVersion` is embedded and
checked), or an image reference the supplied map does not carry — a missing
image is a decode failure, not a hole. Store the schema version beside your
own cache version and treat a mismatch in either as a miss.

### The archive layer

An unambiguous `.fb2.zip` needs none of this — `bookParserFor` routes it
transparently. When a zip is ambiguous, `bookParserFor` returns `null` and
`inspectBookArchive` tells you why:

```dart
switch (inspectBookArchive(bytes)) {
  case NotAnArchive():        // not a zip: parse as-is
  case EpubArchive():         // the zip is the book
  case WrappedBook(:final name, :final bytes):  // one book inside
  case NoBookInside():        // nothing readable
  case SeveralBooksInside(:final names):        // ask the user
}
```

## Format support

**Text is preserved, structure is not.** Every textual construct becomes a
paragraph, a heading, or an image.

| Construct | EPUB | FB2 |
| --- | --- | --- |
| Paragraphs | `<p>`, text-bearing `<div>` | `<p>` |
| Headings | `<h1>`–`<h6>` (tag level) | section `<title>` (also `Chapter.title`), `<subtitle>` |
| Verse | not distinguishable without CSS | `<stanza>` → one paragraph, lines joined by newlines |
| Lists | one paragraph per `<li>`, nesting unmarked | — |
| Tables | one paragraph per row, cells joined by a space | same |
| Quotations, epigraphs | paragraphs, no marker | paragraphs, no marker |
| Inline markup, links | text kept, targets and styling dropped | same |
| Inline images | `<img>` / SVG `<image>`, via the manifest | `<image>` → `<binary>` |
| Line breaks | `<br>` → newline inside the paragraph | `<v>` lines |
| Footnotes / notes | ordinary spine items | `<body name="notes">` → trailing chapters |
| Cover | `cover-image` property, `meta name="cover"`, or image item `cover` | `<coverpage>` binary |
| Chapters | one per navigation entry; unnavigated spine items kept untitled, except a declared contents page | one per `<section>`, nested sections flattened with `level` |

**Not extracted, either format:** styling and CSS in any form; link targets
(so no working cross-references); list nesting and table geometry; MathML,
inline SVG art, audio and video; page-break hints and layout; EPUB 3 media
overlays. DRM-protected EPUBs are refused as `drmProtected`, not decrypted —
but an `encryption.xml` that only obfuscates fonts parses normally, because
fonts are not content. Not extracted from metadata in 0.1.0: EPUB
`dc:publisher`/`dc:identifier`/`dc:date`/`dc:subject`/`dc:description`; FB2
`<annotation>`, `<sequence>`, `<genre>`, `<document-info>`, `<publish-info>`.

## Segmentation, by writing system

The built-in segmenter is rule-based and decided by writing system, never by
language:

| Writing system | Sentences | Words |
| --- | --- | --- |
| Space-separated scripts (Latin, Cyrillic, Greek, Armenian, Hebrew, Arabic, Devanagari, …) | terminator rules, with suppression of false splits on initials (`J. R. R.`, `т. д.`), decimals, and lower-case continuations | letter/number runs with inner apostrophes and hyphens |
| Chinese | `。！？` and friends | one ideograph per word — an approximation that supports per-word lookup |
| Japanese | same | runs split at script transitions (kanji / hiragana / katakana) |
| Thai, Khmer, Lao, Burmese | script-specific terminators | **none** — `Sentence.words` is the empty list; these are sentence-level only |

Modern Greek's ASCII `;` question mark is honored when the resolved language
is `el`. Callers can pass `RuleBasedSegmenter(abbreviations: {'mr', 'dr'})`
for domain abbreviations, or implement `TextSegmenter` for
dictionary-quality segmentation of unspaced scripts — the ceiling is yours
to raise without forking.

With `segmenter` omitted, `parse` uses exactly
`RuleBasedSegmenter(languageCode: book.metadata.sourceLanguageCode)` — a
contract you can rely on when reconstructing a segmenter at decode time.

## Failure kinds

| Kind | Meaning |
| --- | --- |
| `corrupt` | Not a readable file of the format it claims |
| `unsupportedFormat` | Recognisable, but not EPUB or FB2 |
| `encoding` | The declared encoding has no codec here |
| `emptyDocument` | Parsed fine and produced no block at all — note this is *no blocks*, not *no text*: an image-only book parses |
| `drmProtected` | The EPUB container declares encryption over its content (EPUB-only) |

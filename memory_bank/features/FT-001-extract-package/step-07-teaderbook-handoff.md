---
title: 'STEP-07 Handoff: Switching TeaderBook Onto ebook_parser'
doc_kind: feature
doc_function: canonical
purpose: 'Read as the single input when starting the TeaderBook side of the extraction: a self-contained work order whose reasoning is inline, because the session doing this work cannot reach this bank.'
derived_from:
  - implementation-plan.md
  - brief.md
status: draft
---
# STEP-07 Handoff: Switching TeaderBook Onto ebook_parser

This document exists to be read from the other side. A session rooted at
`readtolearn/frontend` has no access to this memory bank — the app repository
configures no memory-bank server — so nothing here cites a decision by
identifier and expects the reader to look it up. Every reason is stated in
place. Read this instead of the implementation plan.

Inventory and call sites below were re-verified against the app on 2026-09-01,
not inherited from the plan's earlier survey. Where they differ from the plan,
this document is right and the plan is stale.

That survey was still wrong in three places, all of them facts only the app
repository holds — the departing dependency list, what a stored reading
position is keyed by, and whether the reader should render `Chapter.title`.
The corrections landed on 2026-09-02 and are marked in place. The shape is
worth keeping in mind for any future cross-repository inventory: the errors
were not in the reasoning, they were in the facts that could not be checked
from the side that wrote them down.

## Read This First: FT-001 Means Something Else Over There

TeaderBook's own bank holds 42 feature packages and its `FT-001` is
`FT-001-library-book-import`. The extraction is `FT-001` only in the package's
bank. In any TeaderBook session, say "the ebook_parser switch" and never the
bare token. This work needs a fresh identifier in that bank; the first free one
on 2026-09-01 was `FT-043`.

TeaderBook sits on branch `dev`, 25 commits ahead of `origin/dev`, and its git
root is `frontend` rather than `readtolearn`. Do not create a branch.

## The Goal

`ebook_parser 0.1.0` is published. TeaderBook must run on it and hold no second
copy of the parsing code. Until then the package is a fork, and the divergence
will surface at the worst possible moment. Deleting the app's copies is not
cleanup at the end — it is the deliverable.

```yaml
dependencies:
  ebook_parser: ^0.1.0
```

## What Gets Deleted

Verified present on 2026-09-01, line counts as found:

| Path | Lines |
| --- | --- |
| `lib/src/data/book_parsing/` — `book_archive.dart`, `book_parser_factory.dart`, `epub_parser.dart`, `fb2_parser.dart` | ~590 |
| `lib/src/data/models/book_document.dart` | 151 |
| `lib/src/data/models/book_metadata.dart` | 21 |
| `lib/src/core/interfaces/book_parser.dart` | 27 |
| `lib/src/core/utils/sentence_segmenter.dart` | 39 |
| `lib/src/data/models/book_document_codec.dart` | 86 |

`lib/src/core/consts/languages.dart` (132 lines) **stays**. The package holds no
application's language catalog, and three call sites outside parsing still use
`languageForCode`: `data/stores/library.dart`,
`presentation/screens/my_imported_files.dart`, and
`presentation/widgets/dictionary/dictionary_view.dart`.

## What Has To Change, And Why

Nine items. None is optional; each follows from a decision the package has
already frozen, and the reason is given so it can be judged rather than obeyed.

### 1. Pagination state leaves the model — wrap, do not extend

The package's `ParagraphBlock` has no `spillBefore`, `spillAfter`, or
`wholeSentence()`. Those describe where a paragraph sits on a rendered page,
which is a property of TeaderBook's reader and of nothing else; a parsing
library that carried them would be shipping one consumer's layout state to
every other consumer.

So the reader layer gets its own wrapper type holding a package
`ParagraphBlock` plus those three members, and the four files that read or
write them move onto it:

- `presentation/widgets/reader/book_paginator.dart` (6 uses)
- `presentation/widgets/reader/page_disk_cache.dart` (5)
- `presentation/screens/reader.dart` (2)
- `presentation/widgets/reader/reader_paragraph.dart` (1)

`presentation/widgets/reader/paginated_reader.dart` imports the model but
touches none of the three, so it needs an import swap only.

### 2. The disk cache is rewritten on the package codec, and inverted

The package ships JSON serialization behind a second import,
`package:ebook_parser/serialization.dart`, so a caller that only parses never
pays for it. TeaderBook drops `book_document_codec.dart` and uses
`encodeBlock`/`decodeBlock`.

The shape is the opposite of the app's current one, and this is the part most
likely to be got wrong. `encodeBlock` returns a record of `json` **and** a map
of image bytes, deliberately keeping bytes out of the json. The app's codec
today does the reverse: it base64-encodes images inline, at
`book_document_codec.dart:71`. The measurement behind the change, taken over
247 real FB2 files: base64 binaries are a median 13.6% of a file and up to
95.7%, and one book carried 328 images and ~15 MB of base64. Embedded, restoring
such a document costs more than re-parsing the original — the cache's hit path
becomes more expensive than its miss path, which is not what a cache is for.
So store image bytes as files beside the json.

Two further contracts on the codec:

- `decodeBlock` must be passed the document's segmenter. A lone block carries
  no metadata, so it cannot seed a default from the book's language; decoded
  without one it gets the unseeded default and a non-Latin book silently
  segments differently after a cache restore than it did on first parse. Build
  the same one the parser used: `RuleBasedSegmenter(languageCode: <the
  document's resolved language>)` — that expression is a documented contract,
  not an implementation detail.
- The cache version must be bumped. The encoded shape has changed, and the
  package also writes its own `kBookDocumentSchemaVersion` into the json and
  returns `null` from `decode` on a mismatch. A `null` decode has exactly three
  causes: unreadable json, a schema-version mismatch, and an image reference the
  supplied map does not carry.

### 3. Reading positions are user data — migrate them or reset them knowingly

**This is the one item on the list that is not a cache, and the only one that
can hurt a user.**

Chapter counts change. The package builds one chapter per navigation entry and
splits a spine item at its anchors, where the app's parser produced coarser
units; it also keeps unnavigated front matter that the app never showed. Every
stored reading position is therefore invalid after the switch.

Corrected 2026-09-02 from the app side: this section used to say "keyed by
chapter index" and offered title-matching as the first remedy. **TeaderBook
stores a flat block index, not a chapter index**, so title-matching is not on
the table at all — no chapter title recovers a position expressed in blocks,
and the block stream is renumbered by the same re-chaptering that invalidates
it.

A parse cache can be dropped silently. A reader that loses everyone's place in
every book on an update cannot. What remains available is to reset positions
behind a version marker and accept it deliberately, or to build a mapping the
app can actually compute — matching stored text against the new block stream,
say. What is not acceptable is discovering the answer by omission after
release.

### 4. Covers are resized at import, by the app

The package returns cover bytes exactly as the file stores them, plus a media
type, and never decodes or re-encodes them — decoding an image on the cheap
metadata path would make it not cheap, and re-encoding throws away the
publisher's own compression choices. The app therefore resizes at import using
the platform image codec, and bumps its parse-cache version because stored
covers change size. This is also why `image` leaves the app's dependencies.

### 5. The declared language is narrowed at the import call site

The package validates a book's declared language against the whole of ISO-639-1
and holds no application's supported-language list. TeaderBook's catalog is 59
entries tied to its translation engines, so the narrowing moves to the import
call site — `core/main/book_import_manager.dart`, which is where `parse` and
`parseMetadata` are called — where the app's own catalog already lives. Cover it
with a test: silently importing a book in a language the app cannot translate is
the failure mode.

Note also that `parseMetadata` on a DRM-protected EPUB now fails the same way
`parse` does, returning `drmProtected`. That is deliberate: a cheap path that
succeeded where the full path refuses would shelve books that will not open.

### 6. Metadata display moves onto the nested object

`BookDocument` now carries a `BookMetadata`, and it is the same object
`parseMetadata` returns, so the cheap path cannot answer differently from the
full one. Two shape changes at every display call site:

- `authors` is a `List<String>`, not a single `author`. Join for display.
- `title` is nullable, and `authors` may be empty. The package declares what the
  file declared and invents nothing, so supply the fallback the app wants to
  show.

### 7. Five failure kinds get localised strings

Parsing returns `ParseResult<T>` and never throws on malformed input. Failures
arrive as `ParseFailure` carrying a `kind` and a `message`, and the two are not
interchangeable: `kind` is what the app branches on to say something in the
user's language, `message` is English diagnostic detail for logs and bug
reports and must never be displayed.

The kinds are closed at five for the major version: `corrupt`,
`unsupportedFormat`, `encoding`, `emptyDocument`, `drmProtected`. TeaderBook's
parsers produce a single English string today; replace it with a switch on
`kind` into the app's own localised strings.

Two of them are easy to misread. `emptyDocument` means no block of any variant
in any chapter — **not** "no text", so a comic or a fixed-layout book parses
successfully. TeaderBook does the opposite today. And `drmProtected` is not "an
`encryption.xml` exists": the same file carries font obfuscation, which is not
DRM.

Note the package's result cases are named `ParseOk`/`ParseErr`, not `Ok`/`Err`,
precisely so they coexist with the app's own `Result<T>` in
`core/types/result.dart` while call sites move one at a time.

### 8. The chapter-list and reader UI meet two new shapes

- `Chapter.title` is nullable and untitled front matter is now normal, so the
  chapter list needs a fallback rather than an assumption.
- A chapter can have zero blocks. When several navigation entries share one
  anchor, each still yields a chapter — the shallower ones titled and empty —
  because deleting them would silently drop entries from the table of contents.
  The reader and the paginator must survive meeting one.
- The package emits no *synthetic* chapter heading. TeaderBook shows one at the
  top of most chapters today only because its own parser injected it. On a
  Calibre-produced novel that is thirty headings appearing or vanishing — a
  visible change, not a detail.

  Corrected 2026-09-02 from the app side: this used to say flatly that the UI
  "must now render `Chapter.title` itself", and obeying that literally prints
  every FB2 chapter heading **twice**. The two formats differ, and the rule
  has to be read per format:

  - **EPUB** — the navigation label lives outside the content, so it reaches
    the consumer as `Chapter.title` only. Whether a heading also appears in
    the blocks depends on the source XHTML carrying an `<h1>`; many do, and
    Standard Ebooks reliably does.
  - **FB2** — a section's `<title>` is *inside* the section, so it becomes
    `Chapter.title` **and** the chapter's first `HeadingBlock`. Rendering both
    duplicates it on every chapter of every FB2 book.

  So the reader decides per chapter, not per app: render `Chapter.title` only
  where the chapter's own blocks do not already open with a heading carrying
  the same text. The package documents this asymmetry deliberately — it is not
  a defect to report back.

### 9. Six dependencies leave, and three of them must leave in one commit

Corrected 2026-09-02 from the app side, which is the only side that can see
this: the first survey said five and missed `xml`.

`archive`, `epubx`, `image`, `html`, `enough_convert` and `xml` are imported
by **no** file outside the code being deleted — `fb2_parser.dart` was `xml`'s
only importer in the app. All six come out of `pubspec.yaml`.

The ordering constraint is real and will bite otherwise, and it covers two
packages rather than one:

- the app pins `archive: ^3.6.1`, `ebook_parser` requires `archive: ^4.0.0`,
  and `epubx` depends on the 3.x line;
- the app pins `xml: ^6.6.1` and `ebook_parser` requires `xml: ^7.0.0`.

So `epubx`, `archive` and `xml` must be removed in the same commit that adds
`ebook_parser`, or `flutter pub get` fails on the conflict rather than merely
carrying dead weight.

One more that no survey from this side could have predicted:
`flutter_launcher_icons` was pinned in the app *because of* `epubx`, and
became a blocker itself once that ceiling left.

## Tests

Three suites test the code being deleted and go with it, their assertions
ported to the package where they are not already covered there:
`test/book_parsing_test.dart`, `test/book_archive_test.dart`,
`test/book_document_codec_test.dart`.

Four more import the model and will need updating rather than deleting:
`test/language_detect_test.dart`, `test/page_disk_cache_test.dart`,
`test/paginator_test.dart`, `test/sample_books_test.dart`.

Two new tests are required by the items above: the language narrowing at import
(item 5), and whatever answer item 3 takes for reading positions.

## When It Is Done, Come Back

The extraction feature is owned by the package's bank, not TeaderBook's, and it
is not closed by finishing this work. Someone must return to the `ebook_parser`
repository and record the commit or PR that removed
`lib/src/data/book_parsing/` as this feature's closing evidence. Publication did
not close it; neither does the refactor until that is written down.

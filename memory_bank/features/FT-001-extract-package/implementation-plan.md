---
title: 'FT-001: Implementation Plan'
doc_kind: feature
doc_function: derived
purpose: 'Execution plan for FT-001. Records the extraction and publication sequence, its ordering constraints, and test strategy without redefining canonical problem facts.'
derived_from:
  - brief.md
must_not_define:
  - ft_001_scope
  - ft_001_selected_design
  - ft_001_acceptance_criteria
  - ft_001_blocker_state
status: active
audience: humans_and_agents
---

# FT-001: Implementation Plan

## Current Plan Goal

Move the parsing code out of TeaderBook, publish it as `ebook_parser`, and put
TeaderBook back on the published package — in that order, because the last step
is the proof the extraction was correct rather than a follow-up.

## Grounding / Support References

| Document | Role in this plan | Facts reused | Conflict action |
| --- | --- | --- | --- |
| `brief.md` | canonical problem / verify owner | `REQ-*`, `SC-*`, `NEG-01`, `CHK-*`, `EVID-*`, `DEC-01` | Update `brief.md` first |
| `design.md` | absent — `Design required: no` | none | Promote new design facts upstream before planning |
| `../../engineering/architecture.md` | package layout owner | file tree, unit ownership | Update the owner first |
| `../../engineering/public-api.md` | exported surface owner | export list, port shape, failure kinds | Update the owner first |
| `../../domain/model.md` | model owner | `BookDocument`, `BookMetadata`, `ImageData`, `Chapter`, `Block`, `Sentence`, `Word` | Update the owner first |
| `../../engineering/format-mapping.md` | extraction boundary owner | per-construct mapping, metadata sources, what is not extracted | Update the owner first |

## Current State / Reference Points

Paths are relative to `readtolearn/frontend/`. The input is not one directory:
it is four, verified against the source on 2026-08-31.

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `lib/src/data/book_parsing/` (4 files, ~590 lines) | archive handling, format detection, EPUB and FB2 parsers | the core of what is extracted | copied, then decoupled |
| `lib/src/data/models/book_document.dart` (151 lines) | the shared model plus `sampleTextOf` | the model the package returns | copied minus the pagination fields (`DEC-05`); metadata moves into a nested `BookMetadata` and `author` becomes `authors` (`DEC-13`); chapters gain `level` (`DEC-16`); paragraphs gain a segmenter (`DEC-01`); `sampleTextOf` becomes the `bodySample` extension (`DEC-09`) |
| `lib/src/data/models/book_metadata.dart` (21 lines) | the cheap metadata result | returned by `parseMetadata`, and now nested inside `BookDocument` | reshaped per `DEC-13`: `authors` list, nullable `title`, `cover` as `ImageData` |
| `lib/src/core/interfaces/book_parser.dart` (27 lines) | the `IBookParser` port | the package's central contract | copied, result type swapped |
| `lib/src/core/utils/sentence_segmenter.dart` (39 lines) | lazy segmentation | `ParagraphBlock.sentences` does not work without it | moves into the package; scope per `DEC-01` |
| `lib/src/core/types/result.dart` | the app's sealed `Result<T>` with `Ok`/`Err` | must not follow the code into the package | mirror its shape as a package-local `ParseResult<T>` |
| `lib/src/core/types/failure.dart` (`FailureKind.bookParse`) | the app's failure enum | replaced by package-local causes | `corrupt`, `unsupportedFormat`, `encoding`, `emptyDocument` |
| `lib/src/core/consts/languages.dart` (`languageForCode`, 59 entries) | the app's ML Kit translation catalog; pulls in `trans.dart` and `models/language.dart` | both parsers consult it to accept or reject a book's declared language | must not be copied; policy decided by `DEC-03` |
| `lib/src/data/models/book_document_codec.dart` (86 lines) | JSON codec for the parse cache | serialises package-owned types under an app-owned cache version | in or out per `DEC-06` |
| `lib/src/presentation/widgets/reader/book_paginator.dart`, `page_disk_cache.dart`, `screens/reader.dart`, `widgets/reader/reader_paragraph.dart` | the only writers and readers of `spillBefore`/`spillAfter`/`wholeSentence()` | they define the app-side refactor `DEC-05` implies | app keeps its own paginated block type |
| every TeaderBook call site of the parsers | current consumers | they define what the migration must keep working | switched to the package import in `STEP-07` |

## Test Strategy

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites | Manual-only gap |
| --- | --- | --- | --- | --- | --- |
| both parsers, happy path | `SC-01`, `CHK-01` | `test/book_parsing_test.dart` (149 lines), FB2 and factory only — builds its books inline, uses `flutter_test` | fixture-backed test per format, on `package:test` | `dart test` | none |
| archive handling | `SC-02`, `CHK-01` | `test/book_archive_test.dart` (131 lines), zips built inline | `.fb2.zip` vs unpacked `.fb2` equality | `dart test` | none |
| format detection | `SC-03`, `CHK-01` | none in package form | wrong / absent extension routed by magic bytes | `dart test` | none |
| failure paths | `NEG-01`, `CHK-01` | none in package form | corrupt fixture returns `Err`, never throws | `dart test` | none |
| lazy segmentation | `SC-05`, `CHK-01` | none | assert segmentation has not run before the getter is touched | `dart test` | none |
| inline images | `SC-09`, `NEG-02`, `CHK-01` | none — no parser emits `ImageBlock` today | illustrated book of each format yields typed image blocks in order; unresolvable image skipped, book still parses | `dart test` | none |
| metadata path stays cheap | `SC-10`, `CHK-01` | none — the guarantee came from `epubx.openBook` and is now ours | `parseMetadata` on a many-chapter book does not inflate chapter entries | `dart test` | none |
| isolate transport | `SC-11`, `CHK-01` | none | parse inside `Isolate.run`, including with a caller-supplied segmenter, and read the result back | `dart test` | none |
| cache round trip | `SC-12`, `CHK-01` | `test/book_document_codec_test.dart` (64 lines) | parse, encode, decode, assert segmentation matches the original | `dart test` | none |
| metadata invariant | `SC-13`, `CHK-01` | none — the two paths were never compared | `parse().metadata` equals `parseMetadata()` field by field, both formats, cover bytes asserted separately | `dart test` | none |
| flattened constructs, note bodies | `SC-14`, `CHK-01` | none | table, list, verse and quotation yield their text as paragraphs in order; FB2 `<body name="notes">` yields trailing chapters | `dart test` | whether the flattened text still reads like the book — the corpus pass |
| chapter list and depth | `SC-15`, `CHK-01` | none | nested navigation flattens to reading order with `level` set, both formats | `dart test` | none |
| pure-Dart resolution | `SC-06`, `CHK-02` | none | scratch project resolve + test | `dart pub get`, `dart test` | none |
| decoupling | `SC-07`, `CHK-03` | none | grep gate over `lib/` | `CHK-03` command | none |
| TeaderBook migration | `SC-08`, `CHK-06` | app suite exists | app suite green with local copy deleted | app test suite | none |

The lazy-segmentation test carries more weight than its size suggests: it is the
only guard on the package's main selling point, which would otherwise break
silently at the first refactor.

`test/fixtures/` in TeaderBook holds no books — only OPUS-MT tokenizer data. The
three inherited suites construct their EPUB, FB2 and zip inputs in code. Whether
the package keeps that style or ships real files is `OQ-07`; either way `EVID-01`
needs deliberately corrupt inputs, which do not exist today.

## Open Questions

| ID | Question | Why unresolved | Blocks | Default action |
| --- | --- | --- | --- | --- |
| `OQ-02` | Is `ebook_parser` still free on pub.dev at publish time? | Checked twice on 2026-08-31: `GET /api/packages/ebook_parser` returns 404, and a search for the name returns eight packages, none of them it. Free, but pub.dev does not reserve names (`CON-01`), so the answer holds for today and not for publication day | `STEP-06` | `dart pub publish --dry-run` in `STEP-05` re-confirms; a taken name reopens [ADR-20260830T161251Z](../../adr/ADR-20260830T161251Z-package-name-ebook-parser.md). |

### Closed

| ID | Question | Answer |
| --- | --- | --- |
| `OQ-01` | Segmenter scope | Expanded script-driven rules plus a replaceable port: [ADR-20260831T134925Z](../../adr/ADR-20260831T134925Z-script-driven-segmentation.md). |
| `OQ-03` | EPUB backend | The package reads EPUB itself in `0.1.0`; `epubx` is not a dependency: [ADR-20260831T134825Z](../../adr/ADR-20260831T134825Z-own-epub-reader.md). `archive` moves to major 4. |
| `OQ-04` | Language resolution | Full ISO-639-1, narrowing is the caller's: [ADR-20260831T135025Z](../../adr/ADR-20260831T135025Z-language-resolution.md). |
| `OQ-05` | Cover handling | Stored bytes plus media type, never re-encoded; `image` dropped: [ADR-20260831T135125Z](../../adr/ADR-20260831T135125Z-raw-cover-bytes.md). |
| `OQ-06` | Serialization | A separate opt-in library with its own schema version: [ADR-20260831T135325Z](../../adr/ADR-20260831T135325Z-optional-serialization-library.md). |
| `OQ-07` | Fixtures | Hybrid: builders in code for the contract tests and for generated corrupt inputs, plus three golden files — EPUB 2 with NCX, EPUB 3 with nav, FB2 in windows-1251. Behind `.pubignore` if they pass roughly 150 KB, since `dart pub publish` ships `test/`. |
| `OQ-08` | Archive layer visibility | Exported: [ADR-20260831T135425Z](../../adr/ADR-20260831T135425Z-archive-layer-is-public.md). |
| `OQ-09` | `ParseFailure` shape | `kind` + diagnostic English `message` + `cause`, with `ParseOk`/`ParseErr` as the case names: [ADR-20260831T140218Z](../../adr/ADR-20260831T140218Z-parse-result-type.md). |
| `OQ-12`, `OQ-13` | The table-of-contents page, and unnavigated spine items generally | Rule 2 stands — unnavigated documents become untitled chapters — with one exception for a spine item the format declares to be the table of contents: [ADR-20260831T184812Z](../../adr/ADR-20260831T184812Z-unnavigated-spine-items.md). Closed on the retail Baen file, where six of seven unnavigated documents are real front matter and the seventh is a declared contents page. |
| `OQ-11` | EPUB chapter granularity | One chapter per navigation entry, splitting a spine item at its anchors: [ADR-20260831T173725Z](../../adr/ADR-20260831T173725Z-chapter-per-navigation-entry.md). Closed from the `STEP-00b` corpus, where the producers disagreed — Standard Ebooks prose loses nothing at spine granularity and its own poetry edition loses 674 of 718 entries. |
| `OQ-10` | `sampleTextOf` | Stays exported as the extension `BookDocument.bodySample`; recorded in [public-api.md](../../engineering/public-api.md). |

## Work Order

- `STEP-00` (`DEC-01`..`DEC-07`) — **Done 2026-08-31.** Seven decisions recorded
  as ADRs before any code moves, because each changes what `STEP-01` writes or
  what the app must be refactored to accept. `DEC-08` and `DEC-09` remain open
  but are narrow enough not to block the copy.
- `STEP-00c` (`DEC-13`..`DEC-16`) — **Done 2026-08-31.** A second decision pass,
  after review found four facts crossing the public boundary with no owner:
  the shape of `BookMetadata`, how a navigation tree becomes a chapter list,
  which bytes a caller passes to `parse` for a wrapped book, and what happens
  to everything the three `Block` variants do not cover. Each had to be settled
  before `STEP-01`, because `Block` is sealed and `BookMetadata` is published.
- `STEP-00b` (`DEC-02`) — **Started 2026-08-31, incomplete.** Collect a corpus of
  real EPUB files from several producers before the reader is written. It is the
  only thing that exercises the variance `STEP-01a` takes on, and collecting it
  afterwards means discovering the variance in production. The local collection —
  177 EPUB, 211 FB2 — is surveyed in
  [corpus-findings.md](../../engineering/corpus-findings.md) and turned out to be
  effectively one producer: EPUB 2.0 with NCX throughout, not one EPUB 3
  navigation document, one writing system. Nine public-domain files were fetched
  from Project Gutenberg and Standard Ebooks to close that, adding EPUB 3
  navigation, `properties="cover-image"`, BCP-47 subtags, and Japanese and
  Chinese; an Arabic Wikisource export closed the sentence-terminator gap; four
  derived files cover windows-1251 and koi8-r; and a Baen retail purchase closed
  the publisher-toolchain gap and surfaced `OQ-12`. Five producers are now
  represented. Still missing: fixed-layout EPUB, and a non-linear spine item —
  the latter recorded rather than pursued, since `linear="no"` is ignored by
  decision. Golden fixtures come only from the public-domain files, since
  `dart pub publish` ships `test/` and the local collection's provenance does not
  support redistribution.
- `STEP-01` (`REQ-01`) — Copy the code from all four source locations named in
  Current State into the layout owned by
  [`../../engineering/architecture.md`](../../engineering/architecture.md), then clean imports:
  `package:readtolearn/...` becomes relative, the dependency on
  `core/consts/languages.dart` is removed per `DEC-03`, and references to
  `FT-001`/`FT-017`/`FT-019` and `memory_bank/adr/` paths go. Remove the path,
  keep the argument — a comment pointing nowhere is worse than no comment.
  Gate: `CHK-03`.
- `STEP-01a` (`REQ-01`, `DEC-02`, `DEC-16`) — Write the EPUB reader: container
  lookup, OPF metadata/manifest/spine, NCX and EPUB 3 nav, chapter XHTML, cover
  lookup. Navigation supplies `Chapter.title` and `level`; spine supplies reading
  order, and wins where the two disagree. Chapters follow the navigation rather
  than the file layout: a spine item holding several navigation entries is split
  before the block containing each anchor, with the rules for missing, inline
  and out-of-spine anchors in
  [ADR-20260831T173725Z](../../adr/ADR-20260831T173725Z-chapter-per-navigation-entry.md).
  Unnavigated documents become untitled chapters, except one the format declares
  to be the table of contents
  ([ADR-20260831T184812Z](../../adr/ADR-20260831T184812Z-unnavigated-spine-items.md)).
  Roughly 550-600 lines, the largest single piece of work in the feature. `epubx`
  stays available as a reference implementation to compare against while it is
  written, and is removed from the dependency list once it is not.
- `STEP-01b` (`REQ-01`, `DEC-01`, `DEC-12`) — Write the segmenter: terminator and
  script tables, the false-split suppression rules, the script-transition word
  rules, and the `TextSegmenter` port with its rule-based default. Patterns live
  in top-level finals, never instance fields, or the document stops crossing an
  isolate boundary.
- `STEP-01c` (`REQ-01`, `DEC-10`) — Emit `ImageBlock` from both readers: FB2
  `<image>` resolved to `<binary>`, EPUB `img` resolved through the manifest,
  each with its media type, unresolvable ones skipped.
- `STEP-01d` (`REQ-01`, `DEC-14`) — Apply the extraction boundary in both
  readers, against [format-mapping.md](../../engineering/format-mapping.md):
  tables row by row, lists item by item, line breaks as newlines inside a
  paragraph rather than as paragraph splits, and FB2 note bodies as trailing
  chapters. Check the note-bodies rule against what the source FB2 parser does
  today; if it differs, record the deviation in `brief.md` under `NS-03`.
- `STEP-02` (`REQ-02`) — Write `ParseResult<T>` and `ParseFailure` with the four
  causes, and switch the copied code onto them. Not a dependency on the app's
  `Result<T>`, and not exceptions on expected errors — the latter would be a
  regression against current behaviour.
- `STEP-03` (`REQ-01`) — Build the fixtures: builders in code for the contract
  tests and for generated corrupt inputs, plus three golden files (EPUB 2 with
  NCX, EPUB 3 with nav, FB2 in windows-1251) and one illustrated book per format.
  Write the suites from the Test Strategy table. Set up CI — `dart analyze`,
  `dart test`, `dart pub publish --dry-run` on push. Gate: `CHK-01`, evidence
  `EVID-01`, `EVID-06`.
- `STEP-04` (`REQ-03`) — Verify pure-Dart consumption in a scratch project with
  no Flutter SDK. Gate: `CHK-02`, evidence `EVID-02`.
- `STEP-05` (`REQ-01`, `DEC-01`) — Write the README: how the package differs from
  existing EPUB packages, a usage example, the format support table, the
  segmentation boundary per writing system, what is **not** extracted from each
  format, and the isolate guidance for large books. Add `example/main.dart`,
  which opens a book, prints the contents, and shows `sentences` — the reason
  people take the package, not just its table of contents. Document every public
  API element; pub.dev scores the proportion that carry doc comments. Then
  `dart pub publish --dry-run` and fix what it reports. Gates: `CHK-04`,
  `CHK-05`.
- `STEP-06` (`REQ-01`) — Publish. Evidence `EVID-04`.
- `STEP-07` (`REQ-04`) — Switch TeaderBook onto the published package and delete
  its copies: `lib/src/data/book_parsing/`, the two model files, the port, the
  segmenter, and `book_document_codec.dart`. The app-side work the accepted
  decisions imply, none of it optional:
  - a reader-layer wrapper type carrying the `ParagraphBlock` with its
    `spillBefore`/`spillAfter` and `wholeSentence` (`DEC-05`), and the four files
    that read or write them updated onto it;
  - `page_disk_cache.dart` rewritten on the package's block codec instead of its
    own (`DEC-06`), and its cache version bumped;
  - cover resizing at import with the platform image codec, and the parse-cache
    version bumped (`DEC-04`);
  - the declared language narrowed to the app's catalog at the import call site,
    with a test (`DEC-03`);
  - display call sites moved onto the nested metadata: `authors` joined for
    display and a fallback supplied where `title` is null (`DEC-13`);
  - five direct dependencies dropped from the app's `pubspec.yaml` — `archive`,
    `epubx`, `image`, `html`, `enough_convert` — because each is imported only by
    files that leave with the package. `epubx` and `archive` must go in the same
    commit that adds `ebook_parser`, or `dart pub get` fails on the `archive`
    major (`DEC-02`).

  Gate: `CHK-06`, evidence `EVID-05`.

## Ordering Constraints

`STEP-00` precedes `STEP-01`: `DEC-02` decides whether `STEP-01` copies an EPUB
parser or writes one, and `DEC-05` decides the shape of the model everything
downstream is built on.

`STEP-06` cannot precede `STEP-05`, and `STEP-07` cannot precede `STEP-06` —
TeaderBook cannot depend on a version that does not exist.

`STEP-07` is not optional and not deferrable. While the app keeps its own copy,
the package is a dead fork and the divergence between them surfaces at the worst
possible moment. This is recorded as `EC-01`: publication alone does not close
the feature.

## Stop Conditions

- `STOP-01` — `dart pub publish --dry-run` reports the name is taken:
  stop before `STEP-06`, reopen
  [ADR-20260830T161251Z](../../adr/ADR-20260830T161251Z-package-name-ebook-parser.md).
- `STOP-02` — A `flutter` dependency appears anywhere in the resolved tree:
  stop at `STEP-04`; `REQ-03` fails and no publication follows.
- `STOP-04` — The corpus of real EPUB files shows the reader failing on a whole
  producer's output (Calibre, a major catalogue, an old EPUB 2 toolchain): fix
  before `STEP-05`, since the README's differentiation claim rests on the reader
  being at least as good as what it replaced.
- `STOP-03` — TeaderBook's suite cannot go green against the package at
  `STEP-07`: do not delete the local copy and do not close the feature. A
  behaviour difference means `NS-03` was violated somewhere upstream, which is
  raised in `brief.md` first.

## Ready For Acceptance

Every `CHK-01`..`CHK-06` green with `EVID-01`..`EVID-05` attached, and
`delivery_status` moved to `done` only after `STEP-07`, not after `STEP-06`.

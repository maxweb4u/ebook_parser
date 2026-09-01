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

`readtolearn/frontend/` is not recorded anywhere else in this repository, which
holds no code and no reference to the app. Locally, verified 2026-08-31:

```
/Users/admin/Documents/docs/__projects/__my/readtolearn/frontend
```

This is a fact about one machine rather than about the project — it is written
here only because `STEP-01` cannot start without it, and it stops being true the
moment the work moves to another checkout. The four source locations above sit
under `lib/src/` and total 916 lines, counted rather than estimated.

## Test Strategy

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites | Manual-only gap |
| --- | --- | --- | --- | --- | --- |
| both parsers, happy path | `SC-01`, `CHK-01` | `test/book_parsing_test.dart` (149 lines), FB2 and factory only — builds its books inline, uses `flutter_test` | fixture-backed test per format, on `package:test`, with cover bytes asserted byte-identical to the bytes stored in the fixture — the round-trip-unmodified test [ADR-20260831T135125Z](../../adr/ADR-20260831T135125Z-raw-cover-bytes.md) promises (`DEC-04`) | `dart test` | none |
| archive handling | `SC-02`, `CHK-01` | `test/book_archive_test.dart` (131 lines), zips built inline | `.fb2.zip` vs unpacked `.fb2` equality | `dart test` | none |
| format detection | `SC-03`, `CHK-01` | none in package form | wrong / absent extension routed by magic bytes | `dart test` | none |
| failure paths | `NEG-01`, `CHK-01` | none in package form | corrupt fixture returns `Err`, never throws; hostile XML — deep nesting and entity-expansion bombs — either parses or returns `ParseErr` in bounded time, pinning what `package:xml` actually does with entities rather than assuming it | `dart test` | none |
| DRM and font obfuscation | `NEG-01`, `CHK-01` | none | generated fixtures: an `encryption.xml` naming a content document yields `drmProtected` from **both** `parse` and `parseMetadata` (`DEC-32`); one naming a font resource parses normally on both. An `encryption.xml` covering only images falls under the content rule — refused — and needs no third fixture unless a real file shows up | `dart test` | whether a real ADEPT file behaves the same — the corpus has none |
| empty and image-only documents | `SC-09`, `CHK-01` | none | a document with no blocks anywhere returns `emptyDocument`; an image-only book parses and its `bodySample` is `''` | `dart test` | none |
| `bodySample` behaviour | `CHK-01` | none — exported surface, so [testing-policy.md](../../engineering/testing-policy.md) requires it | collects paragraph text forward from the body start, skips headings, respects `maxChars`; the `''` case is the row above | `dart test` | none |
| lazy segmentation | `SC-05`, `CHK-01` | none | assert segmentation has not run before the getter is touched | `dart test` | none |
| equality | `SC-01`, `CHK-01` | none | `Sentence` and `Word` behave as values in a `Set`; the paragraph-level types and `BookMetadata` do not, so the asymmetry is pinned rather than assumed; a paragraph in an unruled script (Thai) yields sentences with empty `words` (`DEC-30`) | `dart test` | none |
| inline images | `SC-09`, `NEG-02`, `CHK-01` | none — no parser emits `ImageBlock` today | illustrated book of each format yields typed image blocks in order; unresolvable image skipped, book still parses | `dart test` | none |
| metadata path stays cheap | `SC-10`, `CHK-01` | none — the guarantee came from `epubx.openBook` and is now ours | instrumented, and now symmetric: `parseMetadata` builds no block content and materialises no manifest entry or `<binary>` but the cover, in **both** formats. For FB2 that means asserting the event reader never reaches the body | `dart test` | none |
| isolate transport | `SC-11`, `CHK-01` | none | parse inside `Isolate.run`, including with a caller-supplied segmenter, and read the result back | `dart test` | none |
| cache round trip | `SC-12`, `CHK-01` | `test/book_document_codec_test.dart` (64 lines) | parse, encode, decode with the returned image map, assert segmentation matches the original; plus an illustrated document decoded with an empty map returning `null` rather than a document with holes; plus a no-segmenter decode of a divergent-language fixture segmenting identically (`DEC-26`) and a version-mismatched json returning `null` (`DEC-25`) | `dart test` | none |
| metadata invariant | `SC-13`, `CHK-01` | none — the two paths were never compared | `parse().metadata` equals `parseMetadata()` field by field, both formats, cover bytes asserted separately. Carries more weight for FB2 than the row suggests: with a DOM path and an event path it is the only guard on the two agreeing, so it runs over the four derived encoding fixtures as well as the goldens, and over a reordered fixture whose binaries precede the `<description>` (`DEC-27`) | `dart test` | none |
| flattened constructs, note bodies | `SC-14`, `CHK-01` | none | table, list, verse and quotation yield their text as paragraphs in order; FB2 `<body name="notes">` yields trailing chapters | `dart test` | whether the flattened text still reads like the book — the corpus pass |
| chapter list and depth | `SC-15`, `CHK-01` | none | nested navigation flattens to reading order with `level` set, both formats | `dart test` | none |
| no synthetic headings | `SC-18`, `CHK-01` | none — the source does the opposite, and injects one | an EPUB with no heading tags yields no `HeadingBlock`; the navigation label appears only in `Chapter.title` | `dart test` | none |
| archive layer, all cases | `SC-19`, `CHK-01` | one case, in `test/book_archive_test.dart` | each of the five `ArchiveContent` cases produced and distinguished | `dart test` | none |
| language normalisation | `SC-20`, `CHK-01` | none | BCP-47 subtag reduction, ISO-639-1 acceptance, 639-2/B mapping (`DEC-29`), `ArgumentError` on a fallback that does not reduce to ISO-639-1 (`DEC-28`), fallback for anything else | `dart test` | none |
| encoded shape pinned | `SC-21`, `CHK-01` | none | golden encoded document asserted against `kBookDocumentSchemaVersion` | `dart test` | none |
| the whole corpus parses | `CHK-07`, `STOP-04` | none — the corpus has only ever been surveyed, never parsed | 188 EPUB (177 local + 11 fetched) and 211 FB2 parsed: no throw, no `ParseErr`, chapter and block counts recorded | local corpus runner, not CI | which files parse *well* rather than merely without error — spot-read against the survey's structure counts |
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
| `OQ-02` | Is `ebook_parser` still free on pub.dev at publish time? | Checked twice on 2026-08-31 and again on 2026-09-01: `GET /api/packages/ebook_parser` returns 404, and a search for the name returns eight packages, none of them it. Free, but pub.dev does not reserve names (`CON-01`), so the answer holds for today and not for publication day | `STEP-06` | `dart pub publish --dry-run` in `STEP-05` re-confirms; a taken name reopens [ADR-20260830T161251Z](../../adr/ADR-20260830T161251Z-package-name-ebook-parser.md). |

Confirmed 2026-08-31 against pub.dev's own policy: there is no reservation
mechanism at all, and publishing a placeholder to hold the name is prohibited
outright — "Packages may not be published solely to reserve a name for future
use." So the only instrument that would close `OQ-02` early is bringing
`STEP-06` forward onto a genuinely working `0.1.0`, which the Ordering
Constraints currently forbid. Left as it is by decision; the question is
recorded, not acted on.

This is again the only open question left. `OQ-26`, opened on 2026-09-01 by a
third review pass that read the chapter-splitting rules against the
empty-chapter rule, was settled the same day as `DEC-31`; `OQ-27`, opened by a
fifth pass that walked usage scenarios end to end, closed as `DEC-32`. Seven more
(`OQ-19`..`OQ-25`) were opened earlier that day by a second architecture
review — the parallel pass
[processes/review-decisions-against-each-other.md](../../processes/review-decisions-against-each-other.md)
prescribes, run over the accepted ADRs and the canonical engineering documents;
each sat in a seam between two documents rather than inside either one. All
seven were settled the same day as `STEP-00e` and are in the table below,
alongside the five the first review of 2026-08-31 raised and `STEP-00d`
settled.

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
| `OQ-14` | The complete set of `ParseFailureKind` | Closed at five, adding `drmProtected`: [ADR-20260901T101600Z](../../adr/ADR-20260901T101600Z-parse-failure-kinds-closed-at-five.md). `unsupportedVersion` rejected — no consumer action differs from `unsupportedFormat`. The load-bearing part is that an `encryption.xml` alone is not DRM: it also carries font obfuscation, and testing for the file rather than for what it encrypts would refuse readable books. |
| `OQ-15` | Does the JSON codec carry image bytes? | No. Images are encoded by reference and the bytes handed back to the caller: [ADR-20260901T101800Z](../../adr/ADR-20260901T101800Z-images-encoded-by-reference.md). Closed on measurement — 247 local FB2 files re-measured by byte, where base64 binaries are a median 13.6% of the file and up to 95.7%, and only 46% of books carry any inline image at all. For an illustrated book, embedding makes the cache's hit path more expensive than its miss path. |
| `OQ-16` | Do the model's value types define `==`? | `Sentence` and `Word` only; every other type keeps identity with a recorded reason: [ADR-20260901T101500Z](../../adr/ADR-20260901T101500Z-value-equality-on-spans-only.md). |
| `OQ-17` | What is an `emptyDocument`, and are empty chapters dropped? | No `Block` in any chapter, not "no text" — so an image-only book parses; empty chapters are dropped, keeping `Chapter.index` dense: [ADR-20260901T101700Z](../../adr/ADR-20260901T101700Z-empty-document-means-no-blocks.md). |
| `OQ-18` | Is the FB2 metadata path allowed to read the whole file? | No — it streams with `parseEvents` to `<description>` and then to the one `<binary>` the coverpage names, so `parseMetadata` is cheap for both formats: [ADR-20260901T101900Z](../../adr/ADR-20260901T101900Z-streaming-fb2-metadata.md). The cost accepted is a second FB2 reading path, guarded by `SC-13`. |
| `OQ-19` | Zip-native formats vs the sealed `ArchiveContent` | The five named cases stay; the additive-format promise is scoped to non-zip formats, and a future zip-native format (FB3, CBZ) costs a major version, knowingly. Generalising `EpubArchive` into a format-tagged case was considered and declined. Amendments in [ADR-20260830T161443Z](../../adr/ADR-20260830T161443Z-single-document-model.md) and [ADR-20260831T135425Z](../../adr/ADR-20260831T135425Z-archive-layer-is-public.md) (`DEC-24`). |
| `OQ-20` | Schema version in the encoded json | Written by `encode`, checked by `decode`, which returns `null` on a mismatch; the three causes of a `null` decode are documented. Recorded in [public-api.md](../../engineering/public-api.md) (`DEC-25`). |
| `OQ-21` | Default segmenter on decode | `decodeBookDocument` seeds the default from the decoded `metadata.sourceLanguageCode`, matching `parse`; `decodeBlock` cannot and its doc comment says so; `SC-12` gains a divergent-language, no-segmenter round trip. Recorded in [public-api.md](../../engineering/public-api.md) (`DEC-26`). |
| `OQ-22` | FB2 metadata reader vs element order | Order-agnostic: a named cover binary unseen after the first pass gets a second targeted pass — still no DOM; the ADR's earlier no-cover fallback for this case is corrected, and a reordered fixture joins the `SC-13` set. Recorded in [ADR-20260901T101900Z](../../adr/ADR-20260901T101900Z-streaming-fb2-metadata.md) (`DEC-27`). |
| `OQ-23` | Contract on `fallbackLanguageCode` | Normalized like a declared value; `ArgumentError` when it does not reduce to ISO-639-1 — a caller contract violation, not an expected failure. Recorded in [public-api.md](../../engineering/public-api.md) (`DEC-28`). |
| `OQ-24` | ISO-639-2 declarations | A 639-2/B→639-1 mapping table joins `normalizeLanguageCode`; `eng`/`deu`/`rus` resolve to the declared language, and the known limitation closes. Recorded in [public-api.md](../../engineering/public-api.md) (`DEC-29`). |
| `OQ-25` | `Sentence.words` with no word rule | The empty list — no rule means no words, not one sentence-wide word; contract-relevant because `Sentence.==` compares `words` element-wise. Recorded in [domain/model.md](../../domain/model.md) (`DEC-30`). |
| `OQ-26` | Navigation anchors sharing a split point | Every entry still yields a chapter: the shallower ones keep `title` and `level` with no blocks, exempt from the empty-chapter drop — that rule aims at junk structure, not at the table of contents. Rule 9 in [ADR-20260831T173725Z](../../adr/ADR-20260831T173725Z-chapter-per-navigation-entry.md), the exception in [ADR-20260901T101700Z](../../adr/ADR-20260901T101700Z-empty-document-means-no-blocks.md) (`DEC-31`). |
| `OQ-27` | Does `parseMetadata` detect DRM? | Yes — both methods check the container declaration and return `drmProtected`, so the cheap path cannot put an unopenable book into a consumer's library; one lookup in a container the metadata path already opens. Amendment in [ADR-20260901T101600Z](../../adr/ADR-20260901T101600Z-parse-failure-kinds-closed-at-five.md) (`DEC-32`). |

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
- `STEP-00d` (`OQ-14`..`OQ-18`) — **Done 2026-09-01.** A third decision pass,
  closing the five questions the architecture review found in the seams between
  accepted ADRs. Four were genuine compatibility promises that had to be settled
  before `0.1.0` — the failure enum, model equality, the encoded form, and what
  `emptyDocument` means. The fifth, the FB2 metadata cost, was not a contract and
  could have waited; it was taken now anyway rather than publishing a method whose
  name promises what it does not deliver for one of two formats.
- `STEP-00e` (`DEC-24`..`DEC-32`) — **Done 2026-09-01.** A fourth decision pass,
  closing the seven questions a second parallel review found — this time in the
  seams between ADRs and the canonical engineering documents rather than between
  ADR pairs. One (`OQ-19`) was resolved by scoping a promise instead of changing
  a type: `ArchiveContent` stays as it is and a zip-native format is accepted as
  a major-version event. The rest tightened contracts before they freeze: the
  codec's schema-version self-defence, decode-side segmenter seeding, an
  order-agnostic FB2 metadata reader, the `fallbackLanguageCode` contract, the
  639-2 mapping table, and empty `words` for unruled scripts. A third pass the
  same day added `DEC-31`: reading the chapter-splitting rules against the
  empty-chapter rule showed their composition silently deleting navigation
  entries that share an anchor, now rule 9 of the granularity ADR. A fifth
  pass walked usage scenarios end to end and added `DEC-32`: the DRM container
  check runs on `parseMetadata` as well as `parse`, so an import cannot shelve
  a book that will refuse to open.

- `STEP-01` (`REQ-01`) — **Done 2026-09-01.** Copy the code from all four source
  locations named in Current State into the layout owned by
  [`../../engineering/architecture.md`](../../engineering/architecture.md), then clean imports:
  `package:readtolearn/...` becomes relative, the dependency on
  `core/consts/languages.dart` is removed per `DEC-03`, and references to
  `FT-001`/`FT-017`/`FT-019` and `memory_bank/adr/` paths go. Remove the path,
  keep the argument — a comment pointing nowhere is worse than no comment.
  Gate: `CHK-03` — green, the grep over `lib/` returns nothing.
- `STEP-01a` (`REQ-01`, `DEC-02`, `DEC-16`) — **Done 2026-09-01.** The EPUB
  reader was written as four units under `lib/src/epub/`: container lookup with
  the DRM declaration check (`DEC-32`), OPF metadata/manifest/spine/guide, NCX
  and EPUB 3 nav, and chapter XHTML to blocks with anchor tracking. Navigation
  supplies `Chapter.title` and `level`; spine supplies reading order and wins
  where the two disagree. Splitting rules 1–9 of
  [ADR-20260831T173725Z](../../adr/ADR-20260831T173725Z-chapter-per-navigation-entry.md)
  and the declared-contents-page exception of
  [ADR-20260831T184812Z](../../adr/ADR-20260831T184812Z-unnavigated-spine-items.md)
  are implemented and unit-tested; on the corpus the reader reproduces the
  ADR-predicted counts exactly (*Witchy Eye* 36, *Leaves of Grass* 718).
  `epubx` was never added as a dependency. One find the corpus made that no
  fixture could: XHTML `<title/>` self-closing in a chapter head swallows the
  whole body under HTML parsing rules — 165 of the 178 local files do it — so
  raw-text elements are expanded before the HTML parser runs.
- `STEP-01b` (`REQ-01`, `DEC-01`, `DEC-12`) — **Done 2026-09-01.** The segmenter
  ships as `lib/src/segmentation/`: terminator and script tables
  (`script_rules.dart`), the three rule layers of
  [ADR-20260831T134925Z](../../adr/ADR-20260831T134925Z-script-driven-segmentation.md)
  in `RuleBasedSegmenter`, and the `TextSegmenter` port. Patterns live in
  top-level finals, never instance fields, and the isolate-transport test parses
  with a caller-supplied segmenter through `Isolate.run`.
- `STEP-01c` (`REQ-01`, `DEC-10`) — **Done 2026-09-01.** Both readers emit
  `ImageBlock` with media types: FB2 `<image>` resolved to `<binary>`, EPUB
  `img` and SVG-wrapped `image` resolved through the manifest (media type from
  the manifest entry, extension-guessed otherwise), unresolvable ones skipped.
- `STEP-01d` (`REQ-01`, `DEC-14`) — **Done 2026-09-01.** The extraction boundary
  of [format-mapping.md](../../engineering/format-mapping.md) is applied in both
  readers, including FB2 note bodies as trailing chapters and body-level content
  outside sections preserved as a preamble chapter. The event-based FB2 metadata
  reader ([ADR-20260901T101900Z](../../adr/ADR-20260901T101900Z-streaming-fb2-metadata.md))
  is a `parseEvents` state machine with the order-agnostic second pass
  (`DEC-27`); the work assertion is structural — a fixture whose body is
  malformed after the cover binary passes `parseMetadata` and fails `parse`.
- `STEP-02` (`REQ-02`) — **Done 2026-09-01.** `ParseResult<T>`/`ParseOk`/`ParseErr`
  and `ParseFailure` with the five closed causes are in `lib/src/parse_result.dart`;
  all parser paths return them and never throw on expected failures. The one
  deliberate throw is `ArgumentError` on a `fallbackLanguageCode` outside
  ISO-639-1 (`DEC-28`), asserted by test.
- `STEP-03` (`REQ-01`) — **Done 2026-09-01.** Fixtures: in-code builders
  (`test/support/builders.dart`) for EPUB 2/3 and FB2 plus generated corrupt and
  DRM inputs (content encryption, font obfuscation, image-only encryption,
  rights.xml — none existed in any corpus file); three golden files behind
  `.pubignore` (`alice-epub2-ncx.epub`, `sanzijing-epub3-nav.epub`,
  `chekhov-cp1251.fb2`, ~350 KB total, past the 150 KB budget). 139 tests across
  twelve suites cover the Test Strategy table; `SC-10` is asserted with a read
  probe on the EPUB container and structurally for FB2. CI
  (`.github/workflows/ci.yaml`) runs `dart analyze --fatal-infos`, `dart test`,
  `dart pub publish --dry-run`. The corpus runner is
  `corpus/parse_corpus.dart`; run over 652 files (178 local EPUB in
  `~/Downloads`, 11 fetched EPUB, 247 FB2 under `~/Documents/docs/shared/books`
  plus the 5 derived fixtures): **652 ok, 0 errors, 0 throws, 0 metadata-path
  mismatches**; report at `corpus/parse_report.json`. `STOP-04` was exercised
  for real: before the `<title/>` fix the whole `.fb2.epub` producer (172
  files) failed as `emptyDocument`. Gates: `CHK-01` green, `CHK-07` green;
  evidence `EVID-01`, `EVID-08` on disk, `EVID-06` pending the first push.
- `STEP-04` (`REQ-03`) — **Done 2026-09-01.** A scratch pure-Dart project
  (pubspec depending on the package by path, one consuming test) resolves and
  passes `dart test` with no `flutter` package anywhere in the resolved tree.
  Gate: `CHK-02` green, evidence `EVID-02` captured in the session log.
- `STEP-05` (`REQ-01`, `DEC-01`) — **Done 2026-09-01.** README written against
  `CHK-05`: differentiation, usage, the format support table from
  format-mapping, the per-writing-system segmentation table, what is not
  extracted, isolate guidance, and the two-part caching example.
  `example/main.dart` opens a book, prints the contents, and shows `sentences`.
  Every exported API element carries a doc comment (verified with
  `public_member_api_docs`). `dart pub publish --dry-run` passes with one
  advisory warning — no `homepage`/`repository` field, because the package has
  no public repository URL yet; the field must be added before `STEP-06`.
  Gates: `CHK-04` green (modulo that advisory), `CHK-05` written and reviewed
  against `DEC-01` and format-mapping.

- `STEP-06` (`REQ-01`) — Publish. Evidence `EVID-04`. Before publishing: add the
  `repository` field to `pubspec.yaml` once the public repository exists, and
  re-confirm the name is free (`OQ-02`).
- `STEP-07` (`REQ-04`) — Switch TeaderBook onto the published package and delete
  its copies: `lib/src/data/book_parsing/`, the two model files, the port, the
  segmenter, and `book_document_codec.dart`. The app-side work the accepted
  decisions imply, none of it optional:
  - a reader-layer wrapper type carrying the `ParagraphBlock` with its
    `spillBefore`/`spillAfter` and `wholeSentence` (`DEC-05`), and the four files
    that read or write them updated onto it;
  - `page_disk_cache.dart` rewritten on the package's block codec instead of its
    own (`DEC-06`), and its cache version bumped. It inherits the two-part shape:
    `encodeBlock` hands back image bytes separately, so the app stores them as
    files beside the json rather than base64 inside it, which is the opposite of
    what its current codec does at `book_document_codec.dart:71`. It also passes
    the document's segmenter to `decodeBlock`: a lone block carries no metadata
    to seed the default from (`DEC-26`), so a non-Latin book restored without
    one would segment differently;
  - cover resizing at import with the platform image codec, and the parse-cache
    version bumped (`DEC-04`);
  - the declared language narrowed to the app's catalog at the import call site,
    with a test (`DEC-03`);
  - display call sites moved onto the nested metadata: `authors` joined for
    display and a fallback supplied where `title` is null (`DEC-13`);
  - the five failure kinds mapped to the app's own localised strings, keyed by
    `kind`, replacing the single English string its parsers produce today
    (`DEC-20`). Promised "at `STEP-07`" by
    [ADR-20260831T140218Z](../../adr/ADR-20260831T140218Z-parse-result-type.md)
    and by the `DEC-20` entry in `brief.md`, but carried by no step until the
    review of 2026-09-01;
  - the chapter-list UI given a fallback for `title == null` — untitled front
    matter is now a normal occurrence (`DEC-18`) — and the reader and paginator
    taught to meet a chapter with zero blocks, which `DEC-31` makes possible
    where the source never produced one;
  - **reading positions migrated or deliberately reset** (`DEC-17`). The brief
    already records that chapter counts change and that index-keyed positions are
    invalidated, but no step owned it, and this is the one item on this list that
    is user data rather than a cache. A parse cache can be dropped silently; a
    reader that loses everyone's place in every book on an update cannot. Either
    map old index to new by matching chapter titles, or reset with a version
    marker and accept it knowingly — but not by omission;
  - the reader's chapter headings, if the UI renders blocks alone (`DEC-11`).
    The app shows a synthetic level-1 heading at the top of most chapters today
    because the source injects one; the package does not. Where the UI needs it,
    it renders `Chapter.title` itself. On a Calibre-produced novel this is thirty
    headings appearing or vanishing, so it is a visible change, not a detail;
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
  being at least as good as what it replaced. The mechanism is `CHK-07`: until
  the review of 2026-08-31 this stop condition had none, because the corpus was
  only ever read by a survey script that counts structure and never calls the
  parser. A stop condition nothing can trigger is decoration.
- `STOP-03` — TeaderBook's suite cannot go green against the package at
  `STEP-07`: do not delete the local copy and do not close the feature. A
  behaviour difference means `NS-03` was violated somewhere upstream, which is
  raised in `brief.md` first.

## Ready For Acceptance

Every `CHK-01`..`CHK-06` green with `EVID-01`..`EVID-05` attached, and
`delivery_status` moved to `done` only after `STEP-07`, not after `STEP-06`.

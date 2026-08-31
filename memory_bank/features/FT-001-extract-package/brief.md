---
title: 'FT-001: Extract Book Parsing Into ebook_parser'
doc_kind: feature
doc_function: canonical
purpose: 'Canonical brief for extracting TeaderBook''s book parsing into a published ebook_parser package and switching the app onto it. Records problem space, scope, and the verify contract.'
derived_from:
  - ../../flows/feature-flow.md
  - ../../engineering/architecture.md
must_not_define:
  - implementation_sequence
  - new_architecture_or_contract
status: active
delivery_status: planned
audience: humans_and_agents
---

# FT-001: Extract Book Parsing Into ebook_parser

Source task / ticket: `<link — not yet recorded>`

## What

Book parsing for EPUB and FB2 lives inside TeaderBook across four locations —
`lib/src/data/book_parsing/`, `lib/src/data/models/`,
`lib/src/core/interfaces/book_parser.dart`, and
`lib/src/core/utils/sentence_segmenter.dart` — and is reachable only from that
app. This delivery unit turns it into a published pub.dev package and puts
TeaderBook back on top of it. The full inventory is owned by
[product/context.md](../../product/context.md).

- `REQ-01` A published `ebook_parser` package that parses EPUB and FB2 into the
  shared model owned by [domain/model.md](../../domain/model.md), exposing the
  surface owned by [public-api.md](../../engineering/public-api.md).
- `REQ-02` No coupling back to TeaderBook: no `package:readtolearn/...`
  imports, own `ParseResult<T>` and `ParseFailure` instead of the app's
  `Result<T>` and `FailureKind.bookParse`, no dependency on the app's
  translation language catalog (`core/consts/languages.dart`, which itself
  pulls in localisation and the `Language` model), and no comments citing app
  feature IDs or `memory_bank/adr/` paths.
- `REQ-03` Every dependency is pure Dart, so the package resolves and its tests
  run in a plain Dart project with no Flutter SDK present. The extracted code
  arrived with seven — `archive`, `xml`, `path`, `epubx`, `html`, `image`,
  `enough_convert` — and ships with five: `epubx` goes because the package reads
  EPUB itself (`DEC-02`) and `image` goes because covers are never decoded
  (`DEC-04`). `archive` moves to major 4, which the `epubx` pin had blocked.
- `REQ-04` TeaderBook consumes the published package and its local copy of the
  parsing code is deleted.

- `NS-01` No formats beyond EPUB and FB2. MOBI and TXT stay out of scope.
- `NS-02` No rendering, pagination, or reader UI.
- `NS-03` No behaviour change by default. Parsing results after the switch match
  what TeaderBook produces today; this is an extraction, not an improvement.
  Eight accepted decisions cannot honour this literally — `DEC-03` (language
  resolution stops consulting the app's catalog), `DEC-04` (covers are no longer
  re-encoded), `DEC-05` (pagination fields leave the model), `DEC-10` (inline
  images start being extracted), `DEC-13` (metadata moves off `BookDocument` and
  `author` becomes a list), `DEC-14` (FB2 note bodies stop being skipped),
  `DEC-17` (EPUB chapter counts follow the navigation) and `DEC-18` (unnavigated
  front matter starts being returned) each change something the app observes.
  Each deviation is named in its ADR and the app side is adjusted deliberately at
  `STEP-07` rather than discovered there. `DEC-02`
  changes dependency resolution but not parsing behaviour, so it is not a
  deviation from `NS-03`.
- `NS-04` **Horizontal slice justification.** This is a refactoring and
  packaging unit, not a user-facing vertical slice, which Package Rule 2 allows
  only with explicit justification. It ships no new user-visible behaviour; its
  user value is that the capability becomes consumable outside TeaderBook, and
  `REQ-04` keeps the slice from ending at a published artifact nobody uses.

## Design Requirement Decision

`Design required: no` — Architecture, the exported surface, the package layout,
and the two decisions this feature rests on are already owned upstream and
accepted. This feature applies them; it introduces no new contract, trust
model, or rollout mechanics of its own.

## Design Notes

- Established owners: [engineering/architecture.md](../../engineering/architecture.md)
  (layout), [engineering/public-api.md](../../engineering/public-api.md)
  (exported surface), [domain/model.md](../../domain/model.md) (the model).
- Accepted decisions applied without change:
  [ADR-20260830T161251Z](../../adr/ADR-20260830T161251Z-package-name-ebook-parser.md)
  (the name) and
  [ADR-20260830T161443Z](../../adr/ADR-20260830T161443Z-single-document-model.md)
  (one model, not two type trees).
- Feature-local application only: `ParseResult<T>` and `ParseFailure` are
  written to replace the app's `Result<T>` and `FailureKind.bookParse`, with the
  failure kinds `corrupt`, `unsupportedFormat`, `encoding`, `emptyDocument`.

## Plan Requirement Decision

`Plan required: yes` — Execution carries a hard ordering constraint that is not
derivable from this brief: the package must be published before TeaderBook can
depend on it, and the migration step is the last one rather than an optional
follow-up. Sequencing lives in [implementation-plan.md](implementation-plan.md).

## Assumptions, Constraints, And Blocking Decisions

- `ASM-01` The existing parsing code is correct as it stands; extraction
  preserves behaviour rather than fixing it. Two exceptions are already known.
  Inline images are dropped by both parsers today, so `ImageBlock` is a variant
  nothing produces (`DEC-10`). And:
  the two parsers do not converge on `coverImage` — EPUB re-encodes the cover to
  JPEG at quality 80 via `image`, FB2 returns the raw bytes from `<binary>`.
  That is a divergence inside the shared model, so it is decided rather than
  copied (`DEC-04`).
- `CON-01` `ebook_parser` was verified free on pub.dev but is not reserved;
  availability must hold at publish time.
- `CON-02` A `flutter` dependency anywhere in the tree fails `REQ-03`
  outright — roughly half the potential callers are server or CLI code.
- `DEC-01` **Settled** — segmentation is script-driven, rule-based, and
  replaceable:
  [ADR-20260831T134925Z](../../adr/ADR-20260831T134925Z-script-driven-segmentation.md).
  Measured 2026-08-31, the inherited segmenter takes no language parameter at
  all, so its boundary was never linguistic. The package ships expanded
  terminators for every space-separated script plus CJK, suppression of the
  initials and lower-case false splits, script-transition words for Japanese and
  per-ideograph words for Chinese, and no word rule at all for Thai, Khmer, Lao
  and Burmese. A `TextSegmenter` port lets a caller do better without forking.
  `CHK-05` checks the README describes this per writing system, never per
  language.
- `DEC-02` **Settled** — the package reads EPUB itself, in `0.1.0`:
  [ADR-20260831T134825Z](../../adr/ADR-20260831T134825Z-own-epub-reader.md).
  `epubx` 4.0.0 is from 2023-06-30 and pins `archive: ^3.1.6`, a cap every
  consumer would inherit. Roughly 550-600 lines to write; `epubx` is MIT and may
  be used as a reference with its notice retained.
- `DEC-03` **Settled** — languages are validated against the whole of ISO-639-1,
  and narrowing is the caller's:
  [ADR-20260831T135025Z](../../adr/ADR-20260831T135025Z-language-resolution.md).
- `DEC-04` **Settled** — covers are returned as stored, with their media type,
  and never decoded or re-encoded:
  [ADR-20260831T135125Z](../../adr/ADR-20260831T135125Z-raw-cover-bytes.md).
  This closes the `ASM-01` divergence and removes the dominant cost from the
  cheap metadata path.
- `DEC-05` **Settled** — pagination state leaves the model; consumers wrap the
  block:
  [ADR-20260831T135225Z](../../adr/ADR-20260831T135225Z-model-excludes-pagination.md).
- `DEC-06` **Settled** — serialization ships as a separate opt-in library with
  its own schema version:
  [ADR-20260831T135325Z](../../adr/ADR-20260831T135325Z-optional-serialization-library.md).
- `DEC-07` **Settled** — the archive layer is public:
  [ADR-20260831T135425Z](../../adr/ADR-20260831T135425Z-archive-layer-is-public.md).
  Without it `REQ-04` could not be met: the app would keep the import half of
  the code it is meant to delete.
- `DEC-08` **Settled** — `ParseFailure` carries `kind`, a diagnostic English
  `message`, and `cause`:
  [ADR-20260831T140218Z](../../adr/ADR-20260831T140218Z-parse-result-type.md).
  The consumer switches on `kind` to produce its own localised text; `message` is
  for logs and carries what a raw wrapped exception cannot — which reader, which
  stage. The same ADR settles `ParseOk`/`ParseErr` over `Ok`/`Err`, which is what
  lets TeaderBook migrate call site by call site.
- `DEC-10` **Settled** — inline images are extracted by both readers and
  `ImageBlock` carries a media type:
  [ADR-20260831T144622Z](../../adr/ADR-20260831T144622Z-inline-images-are-extracted.md).
  Verified 2026-08-31, no parser constructs `ImageBlock` today, so the sealed
  model carries a variant nothing can produce — which cannot ship, because both
  removing and adding a variant later are breaking changes.
- `DEC-11` **Settled** — the EPUB front-matter heading heuristic stays as it is
  and is documented, not turned into a parameter. It suppresses only the
  *duplicate* inline heading for navigation labels such as "Title Page" and
  "Cover"; the section's content is kept in full and the label is kept in
  `Chapter.title`, so nothing is lost and the effect is cosmetic. An option would
  be a permanent API commitment with a doubled test matrix, taken on behalf of a
  consumer who has not asked; adding one later is non-breaking, removing one is
  not, so the asymmetry favours waiting.
- `DEC-12` **Settled** — the segmenter travels inside the document, so any
  `TextSegmenter` implementation must hold plain data only. Recorded on
  [domain/model.md](../../domain/model.md) with its failure mode: a compiled
  `RegExp` in an instance field stops the document crossing an isolate boundary,
  and the error surfaces at the caller's `Isolate.run`, naming neither the
  segmenter nor the paragraph.
- `DEC-09` **Settled** — body sampling stays exported, as the extension
  `BookDocument.bodySample` rather than the free function `sampleTextOf`. Recorded
  in [public-api.md](../../engineering/public-api.md), which owns the exported
  surface; no ADR, because nothing was traded away — the function is a read-only
  traversal of the model, and moving it onto the model is where it belonged.
- `DEC-13` **Settled** — `BookDocument` carries a `BookMetadata` instead of
  repeating its fields, `authors` is a list, `title` is nullable, and one
  `ImageData` type serves both the cover and inline images:
  [ADR-20260831T162651Z](../../adr/ADR-20260831T162651Z-document-carries-metadata.md).
  `BookMetadata` had no owner in the bank at all, and the two paths that fill it
  had nothing keeping them in step — the same shape as the `coverImage`
  divergence in `ASM-01`. Nesting makes `parse(b).metadata == parseMetadata(b)`
  testable (`SC-13`).
- `DEC-14` **Settled** — the extraction boundary is `text is preserved, structure
  is not`: tables, lists, verse, quotations and inline markup flatten into
  paragraphs, and FB2 note bodies become trailing chapters:
  [ADR-20260831T162951Z](../../adr/ADR-20260831T162951Z-non-prose-flattens-to-paragraphs.md),
  with the construct-by-construct table in
  [engineering/format-mapping.md](../../engineering/format-mapping.md). `Block`
  is sealed, so the vocabulary is settled before publication or it costs a major
  version. Most of this documents what the source already does; the note-bodies
  rule does not. Verified 2026-08-31 in
  `frontend/lib/src/data/book_parsing/fb2_parser.dart`, which reads
  `if (body.getAttribute('name') == 'notes') continue;` — the source skips the
  notes body outright, and 9% of the local FB2 collection has one
  ([corpus-findings.md](../../engineering/corpus-findings.md)). Extracting it is
  therefore a named `NS-03` deviation, and TeaderBook gains trailing chapters on
  those books at `STEP-07`.
- `DEC-15` **Settled** — a caller passes the bytes it holds and `bookParserFor`
  routes a wrapped book through an unwrapping decorator:
  [ADR-20260831T162851Z](../../adr/ADR-20260831T162851Z-zip-routing-decorator.md).
  The two upstream documents contradicted each other on which bytes reach
  `parse`, and `SC-02` could not be written until they agreed.
- `DEC-16` **Settled** — chapters are a flat ordered list carrying a navigation
  `level`, with no identifier beyond `index`:
  [ADR-20260831T162751Z](../../adr/ADR-20260831T162751Z-flat-chapter-list.md).
  How many chapters an EPUB yields was resolved from the corpus as `DEC-17`.
- `DEC-17` **Settled** — an EPUB chapter is a navigation entry, and a spine item
  holding several is split at its anchors:
  [ADR-20260831T173725Z](../../adr/ADR-20260831T173725Z-chapter-per-navigation-entry.md).
  This closes `OQ-11` on `STEP-00b` evidence: the producers disagree, and spine
  granularity costs Standard Ebooks' poetry edition 674 of its 718 navigation
  entries while costing its prose editions nothing
  ([corpus-findings.md](../../engineering/corpus-findings.md)). Chapter counts
  therefore change against the source, and TeaderBook's index-keyed reading
  positions are invalidated at `STEP-07` alongside its parse cache.
- `DEC-18` **Settled** — a spine item with no navigation entry becomes an
  untitled chapter, except one the format declares to be the table of contents:
  [ADR-20260831T184812Z](../../adr/ADR-20260831T184812Z-unnavigated-spine-items.md).
  Verified 2026-08-31 in `epub_parser.dart`, which iterates epubx's
  navigation-derived `book.Chapters` and never reads the spine: the app drops
  every unnavigated document today. On a retail Baen file that is a title page, a
  half-title and a dedication lost silently, against one declared contents page
  worth losing. Keeping them is a further `NS-03` deviation, in the direction of
  returning more content rather than less.

## Verify

- `SC-01` (`REQ-01`) — One valid book of each format parses: title, author,
  chapter count, and first paragraph match the fixture's known values.
- `SC-02` (`REQ-01`) — A `.fb2.zip` produces the same result as the same book
  unpacked as `.fb2`.
- `SC-03` (`REQ-01`) — A file whose extension is wrong or absent is routed by
  magic bytes to the correct parser.
- `SC-04` (`REQ-01`) — A book with no declared language receives
  `fallbackLanguageCode`.
- `SC-05` (`REQ-01`) — `sentences` are computed lazily: no segmentation runs
  before the getter is touched.
- `SC-09` (`REQ-01`, `DEC-10`) — An illustrated book of each format yields
  `ImageBlock`s in document order, each carrying its media type.
- `SC-10` (`REQ-01`) — `parseMetadata` on a book with many chapters does not
  inflate chapter entries; the cheap path stays cheap.
- `SC-11` (`REQ-01`, `DEC-12`) — A parsed document survives `Isolate.run`,
  including with a caller-supplied segmenter.
- `SC-12` (`REQ-01`, `DEC-06`) — parse, encode, decode: the restored document
  segments identically to the original.
- `SC-13` (`REQ-01`, `DEC-13`) — for the same bytes and the same
  `fallbackLanguageCode`, `parse(b).metadata` equals `parseMetadata(b)`, field by
  field, with cover bytes asserted separately.
- `SC-14` (`REQ-01`, `DEC-14`) — a book of each format containing a table, a
  list, verse and a quotation yields their text as paragraphs in document order;
  an FB2 with `<body name="notes">` yields its notes as trailing chapters.
- `SC-15` (`REQ-01`, `DEC-16`) — a book of each format with nested navigation
  yields a flat chapter list in reading order with `level` set from that nesting.
- `SC-16` (`REQ-01`, `DEC-17`) — an EPUB whose navigation entries point into
  shared documents yields one chapter per entry, in spine-then-document order; an
  anchor that resolves to nothing drops its entry without failing the parse.
- `SC-17` (`REQ-01`, `DEC-18`) — an EPUB with unnavigated front matter yields it
  as untitled chapters, while a spine item declared `type="toc"` yields no
  chapter; a contents page that is not declared is kept.
- `NEG-01` (`REQ-01`) — A corrupt file returns `ParseErr` and does not throw.
- `NEG-02` (`REQ-01`, `DEC-10`) — An image that cannot be resolved is skipped and
  the book still parses.
- `SC-06` (`REQ-03`) — The package resolves and its tests pass in a plain Dart
  project with no Flutter SDK present.
- `SC-07` (`REQ-02`) — No `package:readtolearn/...` import, app feature ID, or
  `memory_bank/` path remains anywhere in the package source.
- `SC-08` (`REQ-04`) — TeaderBook builds and its book-related tests pass against
  the published package, with `lib/src/data/book_parsing/` removed.

- `CHK-01` (`REQ-01`, `SC-01`..`SC-05`, `SC-09`..`SC-17`, `NEG-01`, `NEG-02`) —
  `dart test` in the package; all suites green.
- `CHK-02` (`REQ-03`, `SC-06`) — `dart pub get` and `dart test` in a scratch
  pure-Dart project depending on the package; no Flutter resolution.
- `CHK-03` (`REQ-02`, `SC-07`) — `grep -rE "readtolearn|FT-0|memory_bank|languageForCode" lib/`
  in the package returns nothing.
- `CHK-04` (`REQ-01`, `REQ-03`) — `dart pub publish --dry-run` reports no
  issues.
- `CHK-05` (`REQ-01`, `DEC-01`, `DEC-14`) — README states the supported formats,
  the actual segmentation boundary in terms of writing systems, and what is not
  extracted from each format; reviewed against `DEC-01`'s resolution and against
  [format-mapping.md](../../engineering/format-mapping.md).
- `CHK-06` (`REQ-04`, `SC-08`) — TeaderBook test suite green with the local
  parsing directory deleted.

- `EVID-01` (`CHK-01`) — `test/fixtures/` with valid books of both formats and
  deliberately corrupt files, plus the passing test run.
- `EVID-02` (`CHK-02`) — Output of the scratch-project resolution and test run.
- `EVID-03` (`CHK-04`) — `dart pub publish --dry-run` output.
- `EVID-06` (`CHK-01`, `CHK-04`) — A green CI run: `dart analyze`, `dart test`,
  and `dart pub publish --dry-run` on push.
- `EVID-04` (`CHK-01`, `CHK-04`) — The published pub.dev version page.
- `EVID-05` (`CHK-06`) — The TeaderBook pull request that removes
  `lib/src/data/book_parsing/` and adds the dependency.
- `EVID-07` (`CHK-05`, `DEC-14`, `DEC-16`) — The corpus survey behind
  [corpus-findings.md](../../engineering/corpus-findings.md): per-file structure
  counts over the EPUB and FB2 collections, and the producer-coverage gap it
  exposes.

## Exit Criteria

- `EC-01` (`REQ-04`) — The feature is not done at publication. It is done when
  TeaderBook runs on the package and holds no second copy of the parsing code;
  until then the package is a fork whose divergence surfaces at the worst
  possible moment.

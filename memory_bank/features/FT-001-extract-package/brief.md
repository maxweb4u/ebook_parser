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

Book parsing for EPUB and FB2 lives inside TeaderBook at
`lib/src/data/book_parsing/` and is reachable only from that app. This delivery
unit turns it into a published pub.dev package and puts TeaderBook back on top
of it.

- `REQ-01` A published `ebook_parser` package that parses EPUB and FB2 into the
  shared model owned by [domain/model.md](../../domain/model.md), exposing the
  surface owned by [public-api.md](../../engineering/public-api.md).
- `REQ-02` No coupling back to TeaderBook: no `package:readtolearn/...`
  imports, own `ParseResult<T>` and `ParseFailure` instead of the app's
  `Result<T>` and `FailureKind.bookParse`, and no comments citing app feature
  IDs or `memory_bank/adr/` paths.
- `REQ-03` Dependencies limited to `archive`, `xml`, and `path`; no Flutter, so
  the package installs into a plain Dart project.
- `REQ-04` TeaderBook consumes the published package and its local copy of the
  parsing code is deleted.

- `NS-01` No formats beyond EPUB and FB2. MOBI and TXT stay out of scope.
- `NS-02` No rendering, pagination, or reader UI.
- `NS-03` No behaviour change. Parsing results after the switch match what
  TeaderBook produces today; this is an extraction, not an improvement.
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
  preserves behaviour rather than fixing it.
- `CON-01` `ebook_parser` was verified free on pub.dev but is not reserved;
  availability must hold at publish time.
- `CON-02` A `flutter` dependency anywhere in the tree fails `REQ-03`
  outright — roughly half the potential callers are server or CLI code.
- `DEC-01` How language-agnostic `sentence_segmenter.dart` actually is remains
  unresolved. It does not block publication, but it blocks what the README may
  claim: a package that segments Russian well and English poorly must say so
  rather than imply uniform quality. Must be settled before `CHK-05`.

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
- `NEG-01` (`REQ-01`) — A corrupt file returns `Err` and does not throw.
- `SC-06` (`REQ-03`) — The package resolves and its tests pass in a plain Dart
  project with no Flutter SDK present.
- `SC-07` (`REQ-02`) — No `package:readtolearn/...` import, app feature ID, or
  `memory_bank/` path remains anywhere in the package source.
- `SC-08` (`REQ-04`) — TeaderBook builds and its book-related tests pass against
  the published package, with `lib/src/data/book_parsing/` removed.

- `CHK-01` (`REQ-01`, `SC-01`..`SC-05`, `NEG-01`) — `dart test` in the package;
  all fixture-backed suites green.
- `CHK-02` (`REQ-03`, `SC-06`) — `dart pub get` and `dart test` in a scratch
  pure-Dart project depending on the package; no Flutter resolution.
- `CHK-03` (`REQ-02`, `SC-07`) — `grep -r "readtolearn\|FT-0\|memory_bank" lib/`
  in the package returns nothing.
- `CHK-04` (`REQ-01`, `REQ-03`) — `dart pub publish --dry-run` reports no
  issues.
- `CHK-05` (`REQ-01`, `DEC-01`) — README states the supported formats and the
  actual segmentation-quality boundary; reviewed against `DEC-01`'s resolution.
- `CHK-06` (`REQ-04`, `SC-08`) — TeaderBook test suite green with the local
  parsing directory deleted.

- `EVID-01` (`CHK-01`) — `test/fixtures/` with valid books of both formats and
  deliberately corrupt files, plus the passing test run.
- `EVID-02` (`CHK-02`) — Output of the scratch-project resolution and test run.
- `EVID-03` (`CHK-04`) — `dart pub publish --dry-run` output.
- `EVID-04` (`CHK-01`, `CHK-04`) — The published pub.dev version page.
- `EVID-05` (`CHK-06`) — The TeaderBook pull request that removes
  `lib/src/data/book_parsing/` and adds the dependency.

## Exit Criteria

- `EC-01` (`REQ-04`) — The feature is not done at publication. It is done when
  TeaderBook runs on the package and holds no second copy of the parsing code;
  until then the package is a fork whose divergence surfaces at the worst
  possible moment.

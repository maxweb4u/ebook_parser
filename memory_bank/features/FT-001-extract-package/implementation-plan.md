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
status: draft
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
| `../../domain/model.md` | model owner | `BookDocument`, `Chapter`, `Block`, `Sentence`, `Word` | Update the owner first |

## Current State / Reference Points

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `TeaderBook lib/src/data/book_parsing/` | the code being extracted | it is the entire input to this plan | copied wholesale, then decoupled |
| `TeaderBook core/types/result.dart` | the app's `Result<T>` | must not follow the code into the package | mirror its shape as a package-local `ParseResult<T>` |
| `TeaderBook FailureKind.bookParse` | the app's failure enum | replaced by package-local causes | `corrupt`, `unsupportedFormat`, `encoding`, `emptyDocument` |
| `sentence_segmenter.dart` | lazy segmentation | `ParagraphBlock.sentences` does not work without it | moves into the package, not left behind |
| every TeaderBook call site of the parsers | current consumers | they define what the migration must keep working | switched to the package import in `STEP-07` |

## Test Strategy

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites | Manual-only gap |
| --- | --- | --- | --- | --- | --- |
| both parsers, happy path | `SC-01`, `CHK-01` | inherited from TeaderBook, if any | fixture-backed test per format | `dart test` | none |
| archive handling | `SC-02`, `CHK-01` | none in package form | `.fb2.zip` vs unpacked `.fb2` equality | `dart test` | none |
| format detection | `SC-03`, `CHK-01` | none in package form | wrong / absent extension routed by magic bytes | `dart test` | none |
| failure paths | `NEG-01`, `CHK-01` | none in package form | corrupt fixture returns `Err`, never throws | `dart test` | none |
| lazy segmentation | `SC-05`, `CHK-01` | none | assert segmentation has not run before the getter is touched | `dart test` | none |
| pure-Dart resolution | `SC-06`, `CHK-02` | none | scratch project resolve + test | `dart pub get`, `dart test` | none |
| decoupling | `SC-07`, `CHK-03` | none | grep gate over `lib/` | `CHK-03` command | none |
| TeaderBook migration | `SC-08`, `CHK-06` | app suite exists | app suite green with local copy deleted | app test suite | none |

The lazy-segmentation test carries more weight than its size suggests: it is the
only guard on the package's main selling point, which would otherwise break
silently at the first refactor.

## Open Questions

| ID | Question | Why unresolved | Blocks | Default action |
| --- | --- | --- | --- | --- |
| `OQ-01` | How language-agnostic is `sentence_segmenter.dart`? | never measured outside Russian-language use | `STEP-05` README claims, `CHK-05` | Inspect before publication; if quality is uneven, state the boundary in the README rather than implying uniformity. Owner: `DEC-01` in `brief.md`. |
| `OQ-02` | Is `ebook_parser` still free on pub.dev at publish time? | availability was checked, not reserved (`CON-01`) | `STEP-06` | `dart pub publish --dry-run` in `STEP-05` answers it; a taken name reopens `ADR-20260830T161251Z`. |

## Work Order

- `STEP-01` (`REQ-01`) — Copy the code into the layout owned by
  `architecture.md`, then clean imports: `package:readtolearn/...` becomes
  relative, references to `FT-001`/`FT-017`/`FT-019` and `memory_bank/adr/`
  paths are removed. Remove the path, keep the argument — a comment pointing
  nowhere is worse than no comment. Gate: `CHK-03`.
- `STEP-02` (`REQ-02`) — Write `ParseResult<T>` and `ParseFailure` with the four
  causes, and switch the copied code onto them. Not a dependency on the app's
  `Result<T>`, and not exceptions on expected errors — the latter would be a
  regression against current behaviour.
- `STEP-03` (`REQ-01`) — Build `test/fixtures/`: small valid books of both
  formats and deliberately corrupt files. Write the suites from the Test
  Strategy table. Gate: `CHK-01`.
- `STEP-04` (`REQ-03`) — Verify pure-Dart consumption in a scratch project with
  no Flutter SDK. Gate: `CHK-02`, evidence `EVID-02`.
- `STEP-05` (`REQ-01`, `DEC-01`) — Write the README: how the package differs
  from existing EPUB packages, a usage example, the format support table, and
  the segmentation boundary once `OQ-01` is answered. Add `example/main.dart` —
  it is scored by pub.dev, not decorative. Then `dart pub publish --dry-run`
  and fix what it reports. Gates: `CHK-04`, `CHK-05`.
- `STEP-06` (`REQ-01`) — Publish. Evidence `EVID-04`.
- `STEP-07` (`REQ-04`) — Switch TeaderBook onto the published package and delete
  `lib/src/data/book_parsing/`. Gate: `CHK-06`, evidence `EVID-05`.

## Ordering Constraints

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
- `STOP-03` — TeaderBook's suite cannot go green against the package at
  `STEP-07`: do not delete the local copy and do not close the feature. A
  behaviour difference means `NS-03` was violated somewhere upstream, which is
  raised in `brief.md` first.

## Ready For Acceptance

Every `CHK-01`..`CHK-06` green with `EVID-01`..`EVID-05` attached, and
`delivery_status` moved to `done` only after `STEP-07`, not after `STEP-06`.

---
title: 'ADR-20260831T135425Z: The Archive Layer Is Part Of The Public Surface'
doc_kind: adr
doc_function: canonical
purpose: 'Records why inspectBookArchive and the sealed ArchiveContent are exported rather than hidden behind transparent unwrapping, because a zip holding several books is a caller decision.'
derived_from:
  - ../engineering/public-api.md
  - ../product/value-proposition.md
canonical_for:
  - archive_layer_visibility_decision
must_not_define:
  - public_api_surface
  - package_layout
  - current_system_state
status: draft
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T135425Z: The Archive Layer Is Part Of The Public Surface

## Context

`book_archive.dart` was described upstream as internal — zip handling that runs
before the FB2 parser is reached, so "the parser itself never learns about
archives".

The code does not work that way. It exposes `inspectBookArchive`, returning a
sealed `ArchiveContent` with five cases: `NotAnArchive`, `EpubArchive`,
`WrappedBook`, `NoBookInside`, and `SeveralBooksInside`. TeaderBook's
`book_import_manager.dart` calls it directly and switches over all five, because
several of them are not parsing outcomes at all — a zip containing no readable
book, or containing several, is something the person importing has to be told
about. `SeveralBooksInside` is refused rather than guessed, on the grounds that
silently picking the first imports a book nobody chose.

So if the package keeps this private, `REQ-04` cannot be met: TeaderBook would
have to rebuild the layer it is supposed to be deleting.

## Decision Drivers

- `REQ-04` requires TeaderBook to hold no second copy of this code;
- the five cases are import outcomes, and only the caller can decide what to do
  about the ambiguous ones;
- `.fb2.zip` handling is one of the four capabilities the package claims
  analogues lack ([value-proposition.md](../product/value-proposition.md)), and a
  capability nobody can call is not a capability;
- exporting a sealed type is a compatibility commitment: adding a sixth case
  later breaks every consumer's switch.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Keep it internal, unwrap transparently inside `bookParserFor` | Smallest surface; matches the original description | Loses the distinction between "no book here" and "several books here"; forces the caller to guess or to reimplement; `REQ-04` fails | Rejected — it deletes information the caller needs |
| Internal, but surface the ambiguous cases as parse failures | No new exported types | An import-time question arrives dressed as a parse error, and `SeveralBooksInside` has names to report that a failure kind cannot carry | Rejected — it flattens a decision into an error |
| **Export `inspectBookArchive` and the sealed `ArchiveContent`** | The caller decides; `REQ-04` is satisfiable; a genuine differentiator becomes usable | A sealed public type is a compatibility commitment | **Accepted** |

## Decision

`inspectBookArchive` and the sealed `ArchiveContent` with its five cases are part
of the package's public surface.

The transparent path stays as well: `bookParserFor` continues to route an
unambiguous `.fb2.zip` without the caller doing anything, so the simple case
stays simple. Inspecting explicitly is what a caller reaches for when it wants to
tell the ambiguous cases apart and report them.

Exporting the sealed type is accepted as a compatibility commitment: a sixth case
would break consumers' exhaustive switches, and that is the intended behaviour
here for the same reason it is intended on `Block` — a new import outcome that
existing callers silently ignore is worse than a build failure.

The layer stays a transport concern. It does not know about book formats beyond
recognising which entries could be one, and no parser learns that archives exist.

## Consequences

### Positive

- `REQ-04` becomes satisfiable: TeaderBook deletes its copy instead of keeping
  the import half.
- The `.fb2.zip` capability is usable by other consumers, not just visible in the
  README.
- The distinction between an empty archive and an ambiguous one reaches the
  caller, which is the only party that can resolve it.
- Callers who want no part of this keep using `bookParserFor` unchanged.

### Negative

- A sealed public type constrains the package: any new archive outcome is a
  breaking change.
- The public surface grows by six names, on a package whose selling point
  includes a small surface.
- `ArchiveContent` describes a transport concern, so the exported API is no
  longer purely about documents.

### Neutral / Organizational

- [engineering/public-api.md](../engineering/public-api.md) records the exported
  names; the unsettled note there is replaced by this decision.
- [engineering/architecture.md](../engineering/architecture.md) describes
  `book_archive.dart` as internal and must be corrected.
- `DEC-07` in [FT-001/brief.md](../features/FT-001-extract-package/brief.md) is
  settled here.

## Risks And Mitigation

The risk is committing to a sealed shape before real-world archives have been
seen — a sixth case appearing after publication forces a breaking release.
Mitigated by publishing at `0.1.0`, where breaking changes are expected, and by
the fact that the five cases are drawn from production use rather than guessed.

## Follow-up

- `engineering/architecture.md` corrects the "never public" description of
  `book_archive.dart`.
- The README lists archive inspection among the package's capabilities, since it
  is one of the four differentiators.
- Tests cover all five cases, including the several-books refusal.

## Related Links

- [engineering/public-api.md](../engineering/public-api.md) — the exported
  surface this extends.
- [product/value-proposition.md](../product/value-proposition.md) — `.fb2.zip`
  handling as a stated differentiator.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) — `REQ-04` and
  `DEC-07`.

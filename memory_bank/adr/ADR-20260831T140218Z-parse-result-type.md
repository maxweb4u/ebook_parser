---
title: 'ADR-20260831T140218Z: Expected Failures Are Returned As ParseResult, Never Thrown'
doc_kind: adr
doc_function: canonical
purpose: 'Records the package-local result type, why its cases are named ParseOk and ParseErr rather than Ok and Err, and why ParseFailure carries a diagnostic message alongside its kind.'
derived_from:
  - ../product/context.md
  - ../engineering/public-api.md
canonical_for:
  - result_type_decision
must_not_define:
  - public_api_surface
  - document_model
  - current_system_state
status: draft
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T140218Z: Expected Failures Are Returned As ParseResult, Never Thrown

## Context

A corrupt book is not an exceptional condition. Users import files from public
catalogues, and truncated downloads, wrong extensions and broken encodings are
ordinary daily input. The code being extracted already treats them that way: it
returns TeaderBook's sealed `Result<T>` with `Ok` and `Err`, and throws only on
what it did not expect.

That type cannot come along. Depending on another project's `Result` would drag
an application's error vocabulary into a published package, and switching to
exceptions on expected input would be a regression against behaviour that
already works ([product/context.md](../product/context.md)).

So the package defines its own, and two details are worth deciding rather than
copying. The case names land in every consumer's namespace. And the failure
value has to serve two audiences at once — a log that needs detail, and a user
interface that needs a message in a language the package cannot know.

## Decision Drivers

- malformed input is expected, so it must be a value, not a throw — this is what
  `NEG-01` verifies;
- a published package's exported names compete with every consumer's own, and
  `Ok`/`Err` are names applications commonly already hold;
- the package cannot localise, so any string it ships is English and reaches
  whatever screen the consumer puts it on;
- a bare wrapped exception (`XmlParserException: Expected name at 1:2`) does not
  say which parser failed or at what stage, which is exactly what a bug report
  needs;
- migration is incremental: TeaderBook's own `Ok`/`Err` must coexist with the
  package's while call sites move one at a time.

## Options Considered

Naming of the cases:

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| `Ok` / `Err` | Short; conventional in Rust-influenced Dart code | Collides with names consumers already have — TeaderBook among them — so the migration cannot be incremental | Rejected |
| **`ParseOk` / `ParseErr`** | No collision; the prefix says which library the value came from; both types coexist during migration | Longer at every pattern match | **Accepted** |

Shape of the failure:

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| `kind` + `cause` only | Nothing English can leak to a screen | Log loses the stage and parser that failed; the raw exception has to carry meaning it does not have | Rejected — it protects the UI by degrading the log |
| `kind` + `cause` + a technical `context` label | Diagnostic detail that disqualifies itself as UI text | An extra field to fill by discipline, with the same leak risk if anyone formats it | Rejected — the discipline cost is the same as a documented `message` |
| **`kind` + `cause` + a documented diagnostic `message`** | Full context at the point of failure; the consumer switches on `kind` for anything it shows | An English string exists and can be displayed by a careless consumer | **Accepted** |

## Decision

`ParseResult<T>` is a sealed type with two cases, `ParseOk<T>` carrying a value
and `ParseErr<T>` carrying a `ParseFailure`. Both parse methods return it, and
neither throws on malformed input.

The cases are prefixed. `ParseOk` and `ParseErr` do not collide with the result
types consumers already have, which is what lets TeaderBook migrate call site by
call site instead of in one commit.

`ParseFailure` carries three things: a `kind` from a closed enum — `corrupt`,
`unsupportedFormat`, `encoding`, `emptyDocument` — a diagnostic `message`, and an
optional `cause` holding whatever was caught.

The division of labour is explicit and belongs in the doc comments: **`kind` is
what a consumer branches on to produce its own user-facing text, in its own
language. `message` is English, is for logs and bug reports, and is not a string
to display.** It exists because a wrapped `XmlParserException` alone does not say
which format, which reader, or which stage failed, and that is the first thing
anyone debugging a rejected book needs.

`ParseFailure` is not sealed and `ParseFailureKind` is an enum rather than a
sealed hierarchy: a consumer branching on it usually wants a default case, and
adding a fifth cause should not break every call site the way a new `Block`
variant deliberately does.

## Consequences

### Positive

- Expected failures stay values, so the current behaviour is preserved rather
  than traded for exceptions.
- No name collision, and the migration can proceed incrementally.
- A rejected book produces a log line that names the format and the stage,
  without the package inventing a localisation story it cannot support.
- Consumers that want good messages get a closed enum to switch over, which is a
  better basis for translation than parsing an English string.

### Negative

- An English string is exported and someone will eventually show it to a user.
  Accepted knowingly: the alternative degrades every bug report to protect
  against a mistake the doc comment names explicitly.
- `ParseOk`/`ParseErr` are more verbose than `Ok`/`Err` at every match.
- A closed `kind` enum means a genuinely new failure cause has to be squeezed
  into an existing value or wait for a minor release.

### Neutral / Organizational

- [engineering/public-api.md](../engineering/public-api.md) owns the exported
  shape; this ADR must not restate it.
- `REQ-02` in [FT-001/brief.md](../features/FT-001-extract-package/brief.md)
  names the removal of `Result<T>` and `FailureKind.bookParse`; `DEC-08` is
  settled here.
- TeaderBook maps `kind` to its own localised strings at `STEP-07`, replacing
  the English text its parsers produce today.

## Risks And Mitigation

The risk is `message` reaching a screen. Mitigated by the doc comment stating it
outright, by `kind` being an enum that makes the correct path the easy one, and
by TeaderBook doing it correctly as the worked example — its own strings come
from its translation file, keyed by `kind`.

Second risk: `message` drifting into an inconsistent grab-bag across parsers.
Mitigated by keeping it structured in practice — which reader, which stage, what
was expected — rather than writing sentences at the user.

## Follow-up

- Doc comments on `ParseFailure` state the `kind`-versus-`message` division.
- TeaderBook switches on `kind` for its user-facing text at `STEP-07`.
- `NEG-01` verifies that a corrupt fixture returns `ParseErr` and does not throw.

## Related Links

- [product/context.md](../product/context.md) — the no-foreign-result-type
  constraint.
- [engineering/public-api.md](../engineering/public-api.md) — the exported shape.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) — `REQ-02`,
  `NEG-01`, `DEC-08`.

---
title: 'ADR-20260831T162851Z: Zip Routing Is A Decorator, Not A Parser Concern'
doc_kind: adr
doc_function: canonical
purpose: 'Records what bytes a caller passes to IBookParser.parse for a .fb2.zip, and why bookParserFor returns an unwrapping decorator rather than teaching the FB2 parser about archives.'
derived_from:
  - ../engineering/public-api.md
  - ADR-20260831T135425Z-archive-layer-is-public.md
canonical_for:
  - zip_routing_decision
must_not_define:
  - public_api_surface
  - package_layout
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T162851Z: Zip Routing Is A Decorator, Not A Parser Concern

## Context

The entry point is `IBookParser? bookParserFor(String filePath, Uint8List bytes)`
and the port is `Future<ParseResult<BookDocument>> parse(Uint8List bytes, ...)`.
For a `.fb2.zip` the caller holds zip bytes, and no document says which bytes go
into `parse`.

The two upstream statements do not settle it, and read together they exclude each
other:

- [architecture.md](../engineering/architecture.md) says `.fb2.zip` "unpacks
  before the FB2 parser is reached and no parser learns that archives exist";
- [public-api.md](../engineering/public-api.md) says an unambiguous `.fb2.zip` is
  "routed transparently by `bookParserFor`, so the simple case needs none of
  this" — "this" being the archive layer.

If the caller passes the zip bytes to `parse`, the FB2 parser has to unwrap them
and the first statement is false. If the caller must unwrap first, it needs
`inspectBookArchive` for the simple case and the second statement is false, along
with the position taken in
[ADR-20260831T135425Z](ADR-20260831T135425Z-archive-layer-is-public.md) that
explicit inspection is for the *ambiguous* cases only.

`SC-02` — "a `.fb2.zip` produces the same result as the same book unpacked as
`.fb2`" — cannot be written until this is decided.

A distinction the upstream wording blurs is worth stating first, because it
carries the decision. An EPUB container *is* a zip: `epub_parser` necessarily
reads one, and always will. A `.fb2.zip` is a transport wrapper around a book
file that is not itself an archive. "No parser learns that archives exist" is
true only of the second kind, and only because the second kind is not part of any
format.

## Decision Drivers

- The transparent path is a stated capability
  ([value-proposition.md](../product/value-proposition.md)): `.fb2.zip` handling
  is one of the four things analogues lack, and it stops being one if the caller
  has to unwrap by hand.
- A format parser must not acquire transport responsibilities, or a third format
  arriving in a wrapper repeats the work inside a second parser.
- `bookParserFor` already receives the bytes, so the factory has everything the
  decision needs.
- The exported surface is small on purpose, and
  [testing-policy.md](../engineering/testing-policy.md) rejects options added on
  behalf of consumers who have not asked.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| The FB2 parser unwraps a zip itself | No new type; the caller passes whatever it has | Puts transport in a format parser; a third wrapped format repeats it; makes the archive-blindness rule ad hoc rather than structural | Rejected — it solves the caller's problem by moving it somewhere it does not belong |
| `bookParserFor` returns a record of parser plus the bytes to feed it | Fully explicit; no hidden work | Every caller destructures, including the overwhelming majority holding a plain `.epub` or `.fb2`; introduces "the bytes to use" as a second concept beside the bytes the caller has | Rejected — it taxes the common case to describe the rare one |
| A separate top-level `parseBook(path, bytes)` convenience | Shortest call for the simple case | A second entry point doing what the first does; leaves the `bookParserFor` ambiguity unresolved rather than removing it | Rejected — an added option, and it does not answer the question |
| **`bookParserFor` returns an unwrapping decorator** | The caller always passes the bytes it holds; parsers stay transport-blind; no signature changes; `SC-02` becomes literal | One more type inside `src/`; decompression runs once per call | **Accepted** |

## Decision

A caller passes the bytes it holds. `bookParserFor` decides what happens to them.

For bytes that are a zip containing exactly one parseable book file — the
`WrappedBook` case of `inspectBookArchive` — `bookParserFor` returns a decorator
implementing `IBookParser` that unwraps the entry and delegates to the parser for
the inner file. Both `parse` and `parseMetadata` go through it. The decorator
lives in `book_parser_factory.dart` and is not exported: it is an `IBookParser`
like any other, and naming it would put an implementation detail into the
contract.

The other archive outcomes are unchanged:

- `EpubArchive` — `bookParserFor` returns the EPUB parser, which reads the zip
  because an EPUB container is one;
- `NotAnArchive` — ordinary magic-byte detection;
- `NoBookInside` and `SeveralBooksInside` — `bookParserFor` returns `null`, and a
  caller that must tell the two apart uses `inspectBookArchive`, exactly as
  [ADR-20260831T135425Z](ADR-20260831T135425Z-archive-layer-is-public.md)
  intends.

Unwrapping is one level deep. A zip inside a zip is not a distribution form the
package recognises, and recursing would turn an unambiguous rule into a search.

The decorator holds no state and caches nothing. A caller that calls
`parseMetadata` and then `parse` decompresses twice.

## Consequences

### Positive

- The contract has one rule a caller can state: pass the bytes you have.
- `SC-02` becomes a literal assertion — the same book as `.fb2` and as
  `.fb2.zip`, through the same call, producing equal documents.
- Format parsers stay transport-blind structurally, so a third wrapped format
  costs one decorator rather than a second unwrapping code path.
- No exported signature changes, and the archive layer keeps the role its own ADR
  gave it.

### Negative

- Decompressing twice on the metadata-then-parse sequence, which is a common
  sequence in an importing application. Accepted rather than cached: caching
  would make the decorator stateful and hold a second copy of the book in memory,
  which is a worse trade for a package that already asks callers to think about
  large books.
- `bookParserFor` returns something that is not the parser for the detected
  format, which is mildly surprising when reading a stack trace. The decorator is
  named for what it does so the trace says so.

### Neutral / Organizational

- [public-api.md](../engineering/public-api.md) states the rule under its entry
  point section, replacing "routed transparently" with what that means.
- [architecture.md](../engineering/architecture.md) corrects "no parser learns
  that archives exist" to distinguish a format container from a transport
  wrapper, and records where the decorator lives.

## Risks And Mitigation

The risk is a zip that looks unambiguous and is not — a `.fb2.zip` also carrying
a licence file, a cover, or macOS `__MACOSX` entries. Reading it as
`SeveralBooksInside` would refuse a perfectly normal book, and reading it too
loosely would import a file nobody chose.

Mitigation: the "exactly one parseable book file" test counts entries that could
be a book, not entries. That rule already exists in `inspectBookArchive`, which
came from production use rather than from guesswork; the decorator reuses it
rather than restating it. The corpus at `STEP-00b` includes wrapped FB2 from a
public catalogue so the rule is exercised against real packaging.

## Follow-up

- [public-api.md](../engineering/public-api.md) and
  [architecture.md](../engineering/architecture.md) updated before `STEP-01`.
- `SC-02` written against `bookParserFor` rather than against the FB2 parser
  directly.
- A test that `parseMetadata` on a wrapped book equals `parseMetadata` on the
  unwrapped one, alongside `SC-13`.

## Related Links

- [ADR-20260831T135425Z](ADR-20260831T135425Z-archive-layer-is-public.md) — the
  archive layer this leaves intact.
- [public-api.md](../engineering/public-api.md) — the entry point being
  clarified.
- [value-proposition.md](../product/value-proposition.md) — transparent
  `.fb2.zip` as a stated differentiator.

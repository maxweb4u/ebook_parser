---
title: 'ADR-20260831T135325Z: Serialization Ships As A Separate Opt-In Library'
doc_kind: adr
doc_function: canonical
purpose: 'Records why the package owns JSON serialization of its own model behind a second import, and how its schema version divides responsibility with a consumer''s cache policy.'
derived_from:
  - ../domain/model.md
  - ../engineering/architecture.md
canonical_for:
  - serialization_decision
must_not_define:
  - document_model
  - public_api_surface
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T135325Z: Serialization Ships As A Separate Opt-In Library

## Context

TeaderBook persists a parsed `BookDocument` so a cold start re-opens an imported
book without unzipping and re-parsing it. That codec lives in
`book_document_codec.dart`, deliberately omits sentence spans so laziness is
preserved on load, and is versioned by `kBookDocumentCacheVersion`.

Extraction splits its ownership awkwardly. The codec serialises types the
package owns and breaks when they change — but the cache version encodes an
application's policy about when to invalidate its own files. A second, unrelated
block serialiser also exists in the app's `page_disk_cache.dart`, so the same
knowledge is written twice already.

## Decision Drivers

- whoever can break a format is best placed to version it, and only the package
  can change the model's shape;
- persistence is not something every consumer wants, and a parser package should
  not force an opinion about it on callers who only parse;
- cache invalidation policy — how long files live, when to discard them — is the
  application's and cannot move;
- the model is sealed, so a missed variant in a hand-written codec is already a
  compile error, which lowers but does not remove the cost of leaving it out;
- no existing EPUB package on Dart offers a serialisable model, so this is a
  differentiator rather than scope creep.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Leave the codec in the application | Smallest package surface; policy stays put | Every consumer needing persistence rewrites it; the package can change the shape without any signal | Rejected — the party that breaks the format gives no notice |
| Export only a model version constant | A signal without an opinion | Leaves the duplication in place and helps only consumers who already wrote a codec | Rejected — half a solution |
| Codec in the main library | Simple to find | Forces the concept on callers who only parse | Rejected — the default import should be the parsing contract |
| **Codec as a separate opt-in library with its own schema version** | Owned where breakage originates; free for consumers who want it; invisible to those who do not | The package now has a persistence surface to maintain and document | **Accepted** |

## Decision

The package ships JSON serialization for its own model behind a second import,
so a caller that only parses never sees it.

The package owns a schema version describing the *shape of the model*. It is
bumped when the model or the encoded form changes, and it is not a cache policy.

A consumer composes the two: it stores its own cache version alongside the
package's schema version, and treats a mismatch in either as a miss. That splits
responsibility exactly — the package says "the shape changed", the application
says "my policy changed" — and neither has to guess at the other's reason.

Sentence spans stay out of the encoded form, as they are today: they are
re-segmented lazily on access, which keeps the file small and the load cheap and
preserves the behaviour `SC-05` protects.

That has a consequence the decoder must handle explicitly. A paragraph carries
the segmenter it will use ([domain/model.md](../domain/model.md)), and a
segmenter cannot be encoded as JSON. So decoding accepts a segmenter and applies
it to the paragraphs it rebuilds; without that, a document loaded from cache
would segment differently from the same document straight out of the parser —
silently, and only for the languages where the rules differ. A round-trip test
covers it: parse, encode, decode, and assert the segmentation matches.

TeaderBook's `page_disk_cache.dart` stops carrying its own block serialiser and
encodes its paginated wrapper type
([ADR-20260831T135225Z](ADR-20260831T135225Z-model-excludes-pagination.md)) as
its spill fields plus the package's encoding of the block.

## Consequences

### Positive

- The party that can break the encoded shape is the party that versions it.
- Any consumer gets a working parse cache without writing one, which no
  comparable package offers.
- The application's two serialisers collapse into one plus a thin wrapper.
- Callers that never persist anything pay nothing: different import, no code.

### Negative

- The package acquires a persistence surface it must keep compatible, and a
  second published library to document.
- Two versions must now be reasoned about together at every cache read, and a
  consumer that checks only one will silently load a stale shape.
- The encoded form becomes part of the package's compatibility promise, so
  changing it is a breaking change even when the Dart API is untouched.

### Neutral / Organizational

- [engineering/architecture.md](../engineering/architecture.md) gains the second
  library file; this ADR must not define the layout.
- [engineering/public-api.md](../engineering/public-api.md) records what the
  second library exports.
- `DEC-06` in [FT-001/brief.md](../features/FT-001-extract-package/brief.md) is
  settled here.

## Risks And Mitigation

The risk is a forgotten version bump: the model changes, the schema version does
not, and consumers load a document decoded under the wrong assumptions. Mitigated
by a test that asserts a golden encoded document against the current schema
version, so any change to the encoded shape fails until the version moves with it.

## Follow-up

- The package exposes the codec and its schema version from the second library.
- A golden-encoding test pins the shape to the version.
- TeaderBook composes both versions in its cache header and rewrites
  `page_disk_cache.dart` on top of the package codec, in `STEP-07`.

## Superseded In Part

The size argument above reasons entirely about sentence spans and does not
mention images — `DEC-10` made `ImageBlock` a variant both readers produce an
hour later by timestamp. What the encoded form does with image bytes is decided
by [ADR-20260901T101800Z](ADR-20260901T101800Z-images-encoded-by-reference.md),
which keeps them out of the json and hands them to the caller. The separate-library
decision recorded here is unaffected; only the encode and decode signatures
changed.

## Related Links

- [domain/model.md](../domain/model.md) — the shape being encoded, and why
  sentences are not part of it.
- [ADR-20260831T135225Z](ADR-20260831T135225Z-model-excludes-pagination.md) — the
  wrapper type the app's page cache encodes instead of a fattened block.
- [engineering/architecture.md](../engineering/architecture.md) — where the
  second library sits.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) — `DEC-06`.

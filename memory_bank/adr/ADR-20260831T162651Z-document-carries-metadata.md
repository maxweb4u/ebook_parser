---
title: 'ADR-20260831T162651Z: BookDocument Carries A BookMetadata'
doc_kind: adr
doc_function: canonical
purpose: 'Records why BookDocument nests BookMetadata instead of repeating its fields, why authors is a list, and why cover and inline images share one ImageData type.'
derived_from:
  - ../domain/model.md
  - ../engineering/public-api.md
canonical_for:
  - document_metadata_shape_decision
must_not_define:
  - document_model
  - public_api_surface
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T162651Z: BookDocument Carries A BookMetadata

## Context

`BookMetadata` is returned by `IBookParser.parseMetadata` and is described
nowhere. [public-api.md](../engineering/public-api.md) names the type,
[domain/model.md](../domain/model.md) does not define it, and the plan says only
"copied as is, 21 lines". A type that crosses the public boundary with no owner
is a fact the bank does not hold.

Reading the two documents together shows why that gap is not clerical.
`BookDocument` carries `title`, `author`, `sourceLanguageCode` and an optional
cover; `BookMetadata` carries the same four and nothing else. Two types hold one
set of facts, filled by two code paths — `parse` walking the whole book and
`parseMetadata` deliberately not walking it — and nothing keeps them in step.

That is precisely the failure this package exists to prevent, and it has already
happened once in the source: the two parsers diverged on `coverImage`, EPUB
re-encoding it while FB2 returned stored bytes, and the divergence survived
until someone read for it (`ASM-01`, settled by
[ADR-20260831T135125Z](ADR-20260831T135125Z-raw-cover-bytes.md)).

A second nameless type sits beside it. The cover is "the bytes the file stored
plus the media type it declared", and `ImageBlock`
([ADR-20260831T144622Z](ADR-20260831T144622Z-inline-images-are-extracted.md)) is
that same pair under a different name.

## Decision Drivers

- Convergence is the package's premise
  ([ADR-20260830T161443Z](ADR-20260830T161443Z-single-document-model.md)), and
  [testing-policy.md](../engineering/testing-policy.md) states where it breaks:
  one path quietly doing something the other does not.
- `parseMetadata` is sold as the cheap path to the same answer. If it can return
  a different answer, the claim is false and no test in the current plan catches
  it.
- On a published model, removing a field is breaking and adding one to a type
  only the package constructs is not. The asymmetry decides what must be settled
  now and what can wait.
- `NS-03` asks for no behaviour change, but the source model carries a single
  `author` string while both formats allow several — `dc:creator` repeated in
  OPF, `<author>` repeated in FB2 `<title-info>`. Widening `String` to
  `List<String>` after publication is breaking.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Keep flat fields on `BookDocument`, with `BookMetadata` a separate parallel type | `doc.title` reads well; closest to TeaderBook, so `STEP-07` is a smaller diff; honours `NS-03` literally | Two owners of one fact; drift between `parse` and `parseMetadata` is invisible and untestable; the codec serialises the same four facts twice | Rejected — it reproduces the exact divergence `DEC-04` was needed to clean up |
| `BookDocument { BookMetadata metadata; List<Chapter> chapters; }` | One owner; `parse(b).metadata` and `parseMetadata(b)` become comparable, so the cheap path's honesty is a test rather than a claim; the codec has one metadata entry | One extra hop at every call site; app-side adjustment at `STEP-07` | **Accepted** |
| Nest, then add forwarding getters `title`/`author` on `BookDocument` | Both the invariant and the short call site | Puts the duplicate names back into the public surface, doubles the documented API elements pub.dev scores, and is an option added on behalf of a consumer who has not asked | Rejected — [testing-policy.md](../engineering/testing-policy.md) names this shape directly |

## Decision

`BookDocument` holds a `BookMetadata` and a `List<Chapter>`, and holds no
metadata fields of its own.

`BookMetadata` carries `title`, `authors`, `sourceLanguageCode`, and `cover`:

- `title` is nullable. Both formats can omit it, and the package does not invent
  one. A caller that needs a display string supplies its own fallback — usually
  the file name — at the site where it already knows what to show. This follows
  the stance already taken on language, where `normalizeLanguageCode` takes the
  caller's `fallback` rather than guessing
  ([ADR-20260831T135025Z](ADR-20260831T135025Z-language-resolution.md)).
- `authors` is a `List<String>`, empty when the file declares none. Both formats
  allow several, and joining them into one string is a loss that a published
  signature would make permanent. A caller that wants one line joins them; the
  reverse is not available.
- `sourceLanguageCode` is resolved exactly as
  [ADR-20260831T135025Z](ADR-20260831T135025Z-language-resolution.md) settled it,
  so `fallbackLanguageCode` is required on both `parse` and `parseMetadata`.
- `cover` is a nullable `ImageData`.

`ImageData` is one type — `bytes` as the file stored them, plus the `mediaType`
the file declared — used by both the cover and `ImageBlock`. Neither is ever
decoded or re-encoded
([ADR-20260831T135125Z](ADR-20260831T135125Z-raw-cover-bytes.md)), so both are
the same thing and there is no reason for the model to carry two names for it.
`ImageBlock` holds an `ImageData` rather than repeating its two fields.

This makes an invariant expressible that the package previously only asserted in
prose: for the same input bytes and the same `fallbackLanguageCode`,
`parse` and `parseMetadata` produce equal metadata. It becomes `SC-13`.

## Consequences

### Positive

- The metadata shape has one owner, so the cheap path cannot silently answer
  differently from the full path.
- The claim that `parseMetadata` is the same answer for less work becomes a test
  rather than a README sentence.
- The codec has one metadata entry and one image entry instead of two of each,
  which shrinks both the encoded form and its golden test.
- Multi-author books are represented honestly, in the one release where changing
  the signature is still free.
- `ImageData` gives the cover and inline images a single documented contract:
  stored bytes, declared media type, never decoded.

### Negative

- `doc.metadata.title` instead of `doc.title`, at every call site, forever.
- A deviation from `NS-03`: TeaderBook reads flat fields and a single author
  string today, so `STEP-07` gains display-side work — joining `authors`, and
  supplying a fallback where `title` is null.
- `ImageData` couples the cover and inline images: a field added for one appears
  on the other. Given both are "bytes plus media type, never decoded", the
  coupling is the point, but it is a constraint accepted rather than avoided.

### Neutral / Organizational

- [domain/model.md](../domain/model.md) gains `BookMetadata` and `ImageData` and
  stops listing metadata fields on `BookDocument`.
- [public-api.md](../engineering/public-api.md) adds both types to the exported
  surface.
- [format-mapping.md](../engineering/format-mapping.md) records which construct
  in each format fills each metadata field.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) records this as
  `DEC-13`, a named `NS-03` deviation, and adds `SC-13`.

## Risks And Mitigation

The invariant needs value equality, and `Uint8List` does not have it — two
`ImageData` holding identical bytes are not equal by default. Deep byte
comparison is also the wrong default to hand consumers: a cover can be several
megabytes ([ADR-20260831T135125Z](ADR-20260831T135125Z-raw-cover-bytes.md)), so
an `==` that walks it is a performance trap hidden behind an operator.

Mitigation: `ImageData` does not implement `==`. `SC-13` compares the metadata
field by field and asserts cover bytes separately, which is explicit about the
cost and keeps the trap out of the public surface.

The second risk is that the minimal field set proves too thin — FB2 carries
`<annotation>` and `<sequence>`, EPUB carries publisher, identifier and date, and
consumers will ask. Mitigated by the asymmetry above: `BookMetadata` is
constructed only by the package, so a field can be added in a minor release
without breaking anyone. Nothing is added before someone asks.

## Follow-up

- [domain/model.md](../domain/model.md) and
  [public-api.md](../engineering/public-api.md) updated to this shape before
  `STEP-01`.
- `SC-13` added to the brief and to the Test Strategy table in
  [implementation-plan.md](../features/FT-001-extract-package/implementation-plan.md).
- `STEP-07` gains the app-side display adjustments this implies.
- The codec's golden test covers `BookMetadata` and `ImageData` under
  `kBookDocumentSchemaVersion`.

## Related Links

- [ADR-20260830T161443Z](ADR-20260830T161443Z-single-document-model.md) — the
  convergence premise this protects.
- [ADR-20260831T135125Z](ADR-20260831T135125Z-raw-cover-bytes.md) — why bytes and
  media type are the whole of an image.
- [ADR-20260831T144622Z](ADR-20260831T144622Z-inline-images-are-extracted.md) —
  the second user of `ImageData`.
- [ADR-20260831T135025Z](ADR-20260831T135025Z-language-resolution.md) — the
  caller-supplies-the-fallback stance `title` follows.

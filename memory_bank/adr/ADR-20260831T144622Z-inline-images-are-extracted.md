---
title: 'ADR-20260831T144622Z: Both Readers Emit Inline Images'
doc_kind: adr
doc_function: canonical
purpose: 'Records that ImageBlock must actually be produced by both parsers rather than remaining an unfillable variant of the sealed model, and that it carries a media type like the cover does.'
derived_from:
  - ../domain/model.md
  - ADR-20260830T161443Z-single-document-model.md
canonical_for:
  - inline_image_decision
must_not_define:
  - document_model
  - public_api_surface
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T144622Z: Both Readers Emit Inline Images

## Context

`ImageBlock` is one of the three variants of the sealed `Block`. Verified
against the source on 2026-08-31, **no parser ever constructs it.** The EPUB
reader selects `p, h1..h6, li` from chapter XHTML and never looks at `img`; the
FB2 reader handles `title`, `subtitle`, `p` and `section`, and reads `<image>`
only from `<coverpage>`.

The variant is real everywhere else — the reader renders it, the paginator
branches on it, both serialisers encode it — but the only way one can come into
existence is by decoding a cache file that was itself never written with one.
Inline illustrations in books are silently dropped, in both formats.

Inside one application this was survivable. In a published package it is not, and
the reason is the sealed hierarchy: removing a variant later is a breaking
change, and adding one later is a breaking change too
([ADR-20260830T161443Z](ADR-20260830T161443Z-single-document-model.md)). Whatever
`Block` contains at `0.1.0` is what consumers write their exhaustive switches
against.

A second, smaller inconsistency sits alongside it. Covers are returned as stored
bytes together with the media type that says how to decode them
([ADR-20260831T135125Z](ADR-20260831T135125Z-raw-cover-bytes.md)). `ImageBlock`
carries bytes and nothing else, so a consumer holding one has no idea whether it
is JPEG, PNG, GIF or SVG.

## Decision Drivers

- a sealed public type is a compatibility commitment, so its shape must be right
  before the first publication, not after;
- a model variant nothing can produce is discovered by the first consumer who
  tries, and reads as a defect rather than a limitation;
- illustrations are ordinary content — children's books, technical books and
  most FB2 fiction carry them;
- the same argument that gave the cover a media type applies unchanged here;
- the EPUB reader is being written from scratch anyway
  ([ADR-20260831T134825Z](ADR-20260831T134825Z-own-epub-reader.md)), so this is
  scope inside work already committed rather than new work.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Leave it unfillable, document that inline images are dropped | No work | Ships a sealed public type with a dead branch; every consumer writes a case that never runs; the limitation is discovered rather than chosen | Rejected — it publishes a known defect as a feature note |
| Remove `ImageBlock` from `0.1.0`, restore it in `0.2.0` | The model contains only what exists | Removing it now and adding it back later is two breaking changes instead of none, and the reader already has rendering for it | Rejected — the churn costs more than the work |
| **Both readers emit it, and it gains a media type** | The model becomes true; illustrations survive; the cover and inline images behave the same way | Work inside `STEP-01a`/`STEP-01`; new behaviour relative to what TeaderBook does today | **Accepted** |

## Decision

Both readers produce `ImageBlock`, and it carries the image's media type
alongside its bytes.

For EPUB, `img` elements in chapter XHTML are resolved through the manifest and
emitted in document order with the surrounding paragraphs and headings. For FB2,
`<image>` elements in the body are resolved to their `<binary>` element by `id`
and emitted in place.

Bytes are returned exactly as stored, with no decoding or re-encoding, for the
same reasons the cover is
([ADR-20260831T135125Z](ADR-20260831T135125Z-raw-cover-bytes.md)). An image that
cannot be resolved — a missing manifest entry, a dangling `href`, undecodable
base64 — is skipped rather than failing the parse: a book with one broken
illustration is still a readable book.

This is a deliberate deviation from `NS-03`: TeaderBook will start receiving
blocks it never received before. Its reader and paginator already handle the
variant, so the change surfaces as illustrations appearing, not as a break.

## Consequences

### Positive

- The sealed model describes what parsing can actually produce, which is what
  makes exhaustive switching worth its cost.
- Illustrations stop being silently discarded in both formats.
- A consumer holding an `ImageBlock` can decode it, because it knows the type.
- Cover and inline images follow one rule instead of two.

### Negative

- Documents get larger in memory and on disk: a book's illustrations are now
  carried in the model and encoded into the cache. An illustrated book can grow
  the cache file substantially.
- Work added to `STEP-01` and `STEP-01a`: manifest resolution for EPUB, `binary`
  resolution for FB2.
- TeaderBook's page layout meets image blocks in books where it previously never
  did, so pagination gets exercised on paths that were dead before.
- Its parse cache must be invalidated, since documents now contain more.

### Neutral / Organizational

- [domain/model.md](../domain/model.md) owns the resulting shape of
  `ImageBlock`; this ADR only requires that it is produced and typed.
- The verify contract in
  [FT-001/brief.md](../features/FT-001-extract-package/brief.md) gains a
  criterion that both formats emit images.
- The README's format-support table states what is extracted per format.

## Risks And Mitigation

The risk is memory: a heavily illustrated book now carries every image in the
document tree, where before it carried none. Mitigated for now by measuring on a
real illustrated book during `STEP-03` rather than assuming, and by the fact that
covers already established the pattern of returning bytes untouched. If it proves
too heavy, the shape to reach for is a lazy image reference resolved on access —
a change to the model, so it would need its own ADR and could not be added
quietly.

Second risk: scope creep in `STEP-01a`, where image resolution touches manifest
handling that is already the most variable part of EPUB. Mitigated by skipping
unresolvable images rather than treating them as parse failures.

## Follow-up

- `STEP-01` emits `ImageBlock` from FB2 `<image>`/`<binary>`.
- `STEP-01a` emits it from EPUB `img` through the manifest.
- Tests assert an illustrated book of each format yields image blocks in document
  order, and that an unresolvable image is skipped rather than fatal.
- TeaderBook bumps its parse cache version at `STEP-07`.

## Related Links

- [domain/model.md](../domain/model.md) — the model and why `Block` is sealed.
- [ADR-20260830T161443Z](ADR-20260830T161443Z-single-document-model.md) — why a
  variant added later breaks every consumer.
- [ADR-20260831T135125Z](ADR-20260831T135125Z-raw-cover-bytes.md) — the bytes-as-
  stored rule this follows.
- [ADR-20260831T134825Z](ADR-20260831T134825Z-own-epub-reader.md) — the reader
  this work lands in.

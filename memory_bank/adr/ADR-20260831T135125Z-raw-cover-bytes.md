---
title: 'ADR-20260831T135125Z: Covers Are Returned As Stored, Never Re-Encoded'
doc_kind: adr
doc_function: canonical
purpose: 'Records why the package hands back the cover bytes exactly as the file stores them plus a media type, instead of decoding and re-encoding them, and what the caller must do instead.'
derived_from:
  - ../domain/model.md
  - ../product/value-proposition.md
canonical_for:
  - cover_image_decision
must_not_define:
  - document_model
  - public_api_surface
  - current_system_state
status: draft
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T135125Z: Covers Are Returned As Stored, Never Re-Encoded

## Context

The two parsers disagree about covers today. The EPUB path asks `epubx` for a
decoded bitmap and re-encodes it to JPEG at quality 80 using the pure-Dart
`image` package. The FB2 path base64-decodes the `<binary>` element and returns
those bytes untouched.

That is a divergence inside the shared model, which the convergence decision
exists to prevent ([ADR-20260830T161443Z](ADR-20260830T161443Z-single-document-model.md)),
and it sits on the path that is supposed to be the cheap one: `parseMetadata`
promises title, author, language and cover without walking chapters, and then
spends most of its time decoding and re-encoding an image in pure Dart.

## Decision Drivers

- `parseMetadata` is called at import for every book, and its cost is what the
  user waits on;
- a pure-Dart decode plus encode of a full-size cover is the single most
  expensive operation on that path, by a wide margin over the XML work;
- the caller almost always wants a thumbnail, not a re-encoded full-size image,
  and on Flutter can produce one with the platform's native codec far more
  cheaply than any Dart library;
- `image` is a dependency carried solely for this;
- the two formats must agree, whatever the answer is.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Keep re-encoding, apply it to FB2 too | Uniform output format; caller gets predictable JPEG | Makes the cheap path expensive for both formats instead of neither; keeps `image`; still not the size the caller wants | Rejected — it converges on the slower behaviour |
| Re-encode behind an opt-in flag | Callers choose | Two code paths, two behaviours to document and test, for a transformation the caller can do better itself | Rejected — an option is not a decision |
| **Return the stored bytes plus a media type** | Nothing is decoded during parsing; both formats agree; `image` leaves the dependency list | Bytes may be large, and the caller must resize before storing | **Accepted** |

## Decision

The package returns cover bytes exactly as the file stores them, together with
the media type it declared, for both formats. Nothing is decoded, resized, or
re-encoded inside the package.

`image` is therefore not a dependency.

Resizing is the caller's, and on Flutter it is both cheaper and better: the
platform image codec produces a thumbnail at a target width natively, in a
fraction of the time a pure-Dart decode takes, and yields a small image rather
than a full-size re-encode.

The consequence the caller must not miss: a stored cover can be several
megabytes, so anything that persists it should persist the resized version, not
what the package returned.

## Consequences

### Positive

- The cheap metadata path becomes genuinely cheap; the dominant cost is gone.
- Both formats produce covers the same way, closing the `ASM-01` divergence.
- One fewer dependency, and one fewer pure-Dart hot loop.
- Callers that only need a thumbnail get a smaller one, faster, than the package
  could have produced.
- Callers that want the original image now can have it; re-encoding destroyed it.

### Negative

- The caller must handle several image formats — JPEG, PNG, GIF, sometimes SVG
  in EPUB 3 — instead of always receiving JPEG.
- A caller that stores the returned bytes verbatim will store more than before.
- TeaderBook's parse cache changes shape, so its cache version must be bumped
  and existing caches will miss once.

### Neutral / Organizational

- [domain/model.md](../domain/model.md) owns whether the media type sits beside
  the bytes on the model; this ADR only requires that it is available.
- `ASM-01` in [FT-001/brief.md](../features/FT-001-extract-package/brief.md)
  records the divergence this settles, under `DEC-04`.
- The `NS-03` deviation is named: cover output changes for EPUB.

## Risks And Mitigation

The risk is pushing work onto callers who do not notice it, and ending up with
consumers holding multi-megabyte byte arrays in a list view. Mitigated by saying
so plainly in the README and in the doc comment on the field — the cover is what
the file contained, and resizing before storage is the caller's step — and by
TeaderBook doing exactly that at import as the worked example.

## Follow-up

- TeaderBook resizes at import with the platform codec and bumps its cache
  version, in `STEP-07`.
- The README documents the media types a caller can expect from each format.
- Tests assert that a cover survives round-trip unmodified, for both formats.

## Related Links

- [ADR-20260830T161443Z](ADR-20260830T161443Z-single-document-model.md) — the
  convergence this restores.
- [ADR-20260831T134825Z](ADR-20260831T134825Z-own-epub-reader.md) — dropping
  `epubx` is what makes an undecoded cover reachable.
- [engineering/public-api.md](../engineering/public-api.md) — the metadata path
  this cost belongs to.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) — `DEC-04`.

---
title: 'ADR-20260901T101800Z: The Codec Encodes Images By Reference, Not By Value'
doc_kind: adr
doc_function: canonical
purpose: 'Records why image bytes stay out of the encoded document, the measured sizes that forced it, and the encode/decode signatures that hand the bytes back to the caller.'
derived_from:
  - ../engineering/public-api.md
  - ../engineering/corpus-findings.md
canonical_for:
  - image_serialization_decision
must_not_define:
  - public_api_surface
  - document_model
  - real_world_format_variance
status: active
decision_status: accepted
date: '2026-09-01'
audience: humans_and_agents
---
# ADR-20260901T101800Z: The Codec Encodes Images By Reference, Not By Value

## Context

[ADR-20260831T135325Z](ADR-20260831T135325Z-optional-serialization-library.md)
argues its entire size case about sentence spans and does not contain the word
"image". `DEC-10` made `ImageBlock` a variant both readers produce, an hour later
by timestamp. Neither decision is wrong on its own terms; together they leave the
encoded form carrying something nobody sized. Opened as `OQ-15`, and it cannot be
deferred past publication, because the encoded form is a compatibility promise.

### What the corpus actually holds

The FB2 survey in [corpus-findings.md](../engineering/corpus-findings.md)
recorded image *counts*. Counts turn out to be the wrong unit, so 247 files of
the local collection were re-measured by byte:

| Measure | Value |
| --- | --- |
| Files with any `<binary>` | 242 of 247 (98%) |
| Files with **inline** (non-cover) images | 113 (46%) |
| base64 share of the raw FB2 text | median 13.6%, p90 80.5%, max 95.7% |
| inline-only share | median **0%**, p90 73.2%, max 94.3% |
| raw FB2 bytes ÷ the `.fb2.zip` on disk | median 2.9×, p90 3.3× |
| worst case | 328 images, ~15 MB of base64, 94% of the file |

The distribution is bimodal, which no count could show: **half the collection
carries a cover and nothing else, and the other half is mostly picture.** A
single decision has to serve both.

### The decisive number

For an illustrated book, embedding makes the cache slower than the thing it
caches. Restoring a document means parsing ~16 MB of JSON and base64-decoding
most of it; parsing the original costs decompressing a ~5 MB `.fb2.zip`. A cache
whose hit path is more expensive than its miss path is not a cache. That is the
argument, and it is about time rather than disk.

## Decision Drivers

- the encoded form is a compatibility promise from `0.1.0`, so the signature is
  free to change now and costs a major version later;
- image bytes, unlike sentence spans, are **not** derivable — dropping them is
  data loss, not a deferred computation;
- lossiness that only shows up after a restart is the worst failure shape
  available here: images present in the session that parsed, absent in every
  session after;
- half of all books pay nothing either way, so the design must not tax them for
  the other half;
- TeaderBook is the first consumer and runs on phones, where a 16 MB JSON decode
  is not an abstraction.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Embed as base64 | Self-contained; one call each way; matches the dead `ImageBlock` branch already in TeaderBook's codec at `book_document_codec.dart:71` | Cache ~3× the distributed file at the median and ~16 MB at the tail, with a hit path slower than re-parsing | Rejected on measurement |
| Encode `ImageBlock` without bytes, rebuild it empty | Trivial; small files | Silent data loss with a delayed tell — the book shows its pictures until the app restarts. Breaks `SC-12`'s round-trip claim while appearing to pass it | Rejected |
| Hand image bytes to the caller as a side map | Text stays small for everyone; the caller stores bytes where bytes belong; no lossiness that can happen by accident | Two-part return and a decode parameter; a caller who discards the map gets a decode failure rather than a document | **Accepted** |
| Drop `serialization.dart` from `0.1.0` | The encoded form stops being a promise; decide with real consumer data later | TeaderBook needs the parse cache at `STEP-07`, so the cost lands immediately on the one consumer that exists | Rejected |

## Decision

Image bytes are **not** embedded in the encoded document. Every `ImageData` in
the document — inline blocks and the cover alike — is replaced by a reference
carrying a stable id and its `mediaType`, and the bytes are returned to the
caller separately:

```dart
({Map<String, dynamic> json, Map<String, ImageData> images})
    encodeBookDocument(BookDocument document);

BookDocument? decodeBookDocument(
    Map<String, dynamic> json, {
    Map<String, ImageData> images = const {},
    TextSegmenter? segmenter});
```

The cover follows the same rule as an inline image, because it is the same type
and, at 20–30% of a plain novel's bytes, the same problem in miniature.

**An unresolved reference is a decode failure, not a hole.** `decodeBookDocument`
returns `null` when the json names an image the supplied map does not carry. The
default empty map is for callers that store no images and decode documents that
have none; it is not a way to restore an illustrated book without its pictures.

This is the same principle as leaving sentence spans out, applied with one honest
difference stated in the doc comments: spans are re-derived on access, and image
bytes cannot be. That is why they are handed back rather than dropped.

## Consequences

### Positive

- The encoded document is text-sized for every book, and the half of the
  collection with only a cover pays nothing at all.
- The caller stores bytes as bytes — files, a blob store, its own image cache —
  which is what every one of those is better at than JSON.
- No configuration decides fidelity, so no call site can silently produce a
  lossy cache.
- The cache's hit path is faster than its miss path again, which is the property
  it exists for.

### Negative

- Two things must be stored where one was, and a caller that persists the json
  and forgets the map has a cache that fails to decode. Loud, and on the first
  attempt rather than after a restart — but still a failure the embedded design
  would not have.
- The API is less obvious than `toJson`/`fromJson`, and the record return is
  unusual enough to need an example in the README.
- `blockToJson`/`blockFromJson` inherit the same shape, so a consumer storing
  something block-shaped of its own carries the map too.

### Neutral / Organizational

- [public-api.md](../engineering/public-api.md) owns the exported signatures and
  is updated; the function names replace `bookDocumentToJson`/`bookDocumentFromJson`.
- The `OQ-15` note in that document's Serialization section is replaced by the
  outcome.
- `OQ-15` closes in the
  [implementation plan](../features/FT-001-extract-package/implementation-plan.md);
  `STEP-03` implements and tests it, and `SC-12`'s round trip now includes the
  image map.
- `STEP-07`'s rewrite of `page_disk_cache.dart` onto the package codec inherits
  the two-part shape.

## Risks And Mitigation

The risk is a consumer treating the map as optional because the parameter has a
default. Mitigated by returning `null` rather than a partial document, by a doc
comment that says the default exists for image-free documents only, and by a test
asserting that decoding an illustrated document with an empty map fails.

Second risk: id stability. Ids are assigned by the encoder and are meaningful
only within one encoded document; a consumer must not key long-lived storage on
them across re-encodes. Stated in the doc comment.

## Follow-up

- `STEP-03` tests: round trip with images, round trip without, and decode of an
  illustrated document with an empty map returning `null`.
- The README's caching example shows both halves being stored.
- [ADR-20260831T135325Z](ADR-20260831T135325Z-optional-serialization-library.md)
  gains a pointer here, since its size argument is now only half the story.

## Related Links

- [ADR-20260831T135325Z](ADR-20260831T135325Z-optional-serialization-library.md) —
  the serialization decision this completes.
- [ADR-20260831T144622Z](ADR-20260831T144622Z-inline-images-are-extracted.md) —
  `DEC-10`, the decision that created the gap.
- [engineering/corpus-findings.md](../engineering/corpus-findings.md) — the image
  measurements.

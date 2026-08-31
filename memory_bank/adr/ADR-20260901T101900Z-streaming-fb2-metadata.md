---
title: 'ADR-20260901T101900Z: FB2 parseMetadata Streams Rather Than Building A DOM'
doc_kind: adr
doc_function: canonical
purpose: 'Records that the FB2 metadata path is event-based so parseMetadata is cheap for both formats, and what the second FB2 reading path costs to maintain.'
derived_from:
  - ../engineering/format-mapping.md
  - ../engineering/public-api.md
canonical_for:
  - fb2_metadata_read_strategy
must_not_define:
  - format_extraction_boundary
  - public_api_surface
  - package_layout
status: active
decision_status: accepted
date: '2026-09-01'
audience: humans_and_agents
---
# ADR-20260901T101900Z: FB2 parseMetadata Streams Rather Than Building A DOM

## Context

`parseMetadata` exists as a separate method so the cheap path is visible at the
call site — that separation is the reason
[public-api.md](../engineering/public-api.md) gives for not collapsing it into a
flag on `parse`. For EPUB the promise is kept honestly: the container, the OPF
and one manifest entry, and the source confirms it —
`epub_parser.dart:30` calls `EpubReader.openBook`, with a comment saying it "reads
the OPF/schema and cover without decompressing every chapter".

FB2 does not keep it. The source reads:

```dart
final document = XmlDocument.parse(_decode(bytes));
```

— `frontend/lib/src/data/book_parsing/fb2_parser.dart:34`, inside `parseMetadata`,
with a comment above it admitting that what is deferred is only `_collectBlocks`
and segmentation. FB2 is one XML document whose `<binary>` elements sit at the
end, so reaching the cover through a DOM parse means decoding the whole file and
building nodes over every paragraph and every base64 blob. One method name, two
costs differing by orders of magnitude, and the asymmetry was absent from
[format-mapping.md](../engineering/format-mapping.md)'s list of deliberate
differences until it was opened as `OQ-18`.

The measurements taken for
[ADR-20260901T101800Z](ADR-20260901T101800Z-images-encoded-by-reference.md) size
what the DOM is being built over: across 247 local FB2 files, base64 binaries are
a median 13.6% of the file, p90 80.5%, max 95.7%, with one file carrying 328
images and ~15 MB of base64. The raw text is a median 2.9× the `.fb2.zip` it
arrives in.

The shape that pays is a library import, which calls `parseMetadata` across
hundreds of books in a row — the same shape that already justifies the three
decompressions recorded in [public-api.md](../engineering/public-api.md).

## Decision Drivers

- a method named for being cheap should be cheap, or the name is doing the
  opposite of its job;
- the caller cannot work around this: `parseMetadata` has one signature and no
  way to say "skip the cover";
- `xml` already offers `parseEvents`, so the capability needs no new dependency;
- 94% of the FB2 collection arrives as `.fb2.zip`, so the file is decompressed
  before either strategy begins, and that cost is common to both;
- against all of it, this is the only one of the five open questions that is
  **not** a contract: the signature is identical either way, so it could be
  changed in `0.1.1` without a major version.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Keep the DOM parse, document the asymmetry | Matches the source exactly, so `NS-03` is clean; no new code in a step already carrying a 550–600 line EPUB reader; deferrable without a major version | Publishes a method whose name promises what it does not deliver for one of two supported formats, and the fix keeps being deferrable forever | Rejected — the deferral argument is true and was not found persuasive enough to ship a misleading name |
| **Stream with `parseEvents`** | `parseMetadata` is genuinely cheap for both formats; the asymmetry leaves the documentation instead of being explained in it; the DOM over the body — up to 95% of the file — is never built | A second FB2 reading path to keep correct alongside the DOM one; encoding detection has to work on a prefix | **Accepted** |
| Split the API — cheap fields without the cover | Sidesteps the cost entirely | Two metadata methods for one format, and the cover is the field callers most want at import | Rejected |

## Decision

FB2 `parseMetadata` reads the file as an event stream, not as a DOM. It runs a
small state machine: capture `<title-info>` while inside `<description>`, then
skip forward to the single `<binary>` whose `id` matches the `<coverpage>`
reference, decode that one, and stop. No node is built for the body, and no
`<binary>` but the cover has its base64 payload materialised.

`parse` keeps the DOM path. It needs the whole tree anyway, and there is nothing
to gain from making the expensive path lazy as well.

`SC-10` is rewritten to assert the work rather than the shape of the result, and
it now asserts the same thing for both formats: `parseMetadata` builds no block
content and materialises no manifest entry or `<binary>` but the cover. That
symmetry is the point — the guarantee used to come from `epubx.openBook` for one
format and from nothing at all for the other.

The corresponding row in [format-mapping.md](../engineering/format-mapping.md)'s
Where The Two Formats Differ table is removed: `parseMetadata` is no longer a
deliberate asymmetry.

## Consequences

### Positive

- A library import over hundreds of FB2 books stops decoding hundreds of book
  bodies, which is the workload the two-method split exists to make cheap.
- `parseMetadata` means one thing across both formats, so the README's cost
  guidance needs no per-format caveat.
- `SC-10` becomes a real assertion for FB2 instead of an assertion the format
  could not support.
- An improvement over the source rather than a restatement of it — recorded as an
  `NS-03` deviation in the favourable direction.

### Negative

- A second FB2 reading path exists, and the two can drift: the DOM path and the
  event path must agree on title, authors, language and cover for the same file,
  or `SC-13`'s metadata invariant fails. This is the real cost, and it is paid
  every time either path changes.
- Event-based encoding handling is fiddlier. The prolog must be read from the
  leading bytes and the stream decoded accordingly, and the mislabelled and
  undeclared fixtures in
  [corpus-findings.md](../engineering/corpus-findings.md) now exercise the
  metadata path as well as the parse path.
- `STEP-01d` grows, in a step that already carries the largest single piece of
  work in the feature.

### Neutral / Organizational

- `OQ-18` closes in the
  [implementation plan](../features/FT-001-extract-package/implementation-plan.md),
  and `STEP-01d` gains the event-based reader.
- [format-mapping.md](../engineering/format-mapping.md) loses the asymmetry row
  and [public-api.md](../engineering/public-api.md) states the cost as equal.
- `SC-10` is rewritten in the Test Strategy table.

## Risks And Mitigation

The drift between the two FB2 paths is the risk that matters, and it is mitigated
by a test rather than by care: `SC-13` already compares `parse().metadata` against
`parseMetadata()` field by field for both formats, and with two FB2 code paths it
stops being a formality and becomes the guard that keeps them equal. It runs over
the golden fixtures and over all four derived encoding fixtures.

Second risk: the streaming reader mishandles a file whose `<coverpage>` names a
binary that does not exist, or whose binaries precede `<description>`. Both fall
back to no cover rather than to a failure, matching what a missing cover already
does.

## Follow-up

- `STEP-01d` implements the event-based metadata reader.
- `SC-10` is rewritten to assert work done, symmetrically for both formats.
- `SC-13` is extended to run over the four derived encoding fixtures, since they
  are the files most likely to separate the two FB2 paths.
- The corpus runner reports `parseMetadata` cost alongside parse results, so the
  claim is measured on 211 real files rather than asserted on fixtures.

## Related Links

- [engineering/format-mapping.md](../engineering/format-mapping.md) — the
  asymmetry row this removes.
- [engineering/public-api.md](../engineering/public-api.md) — the two-method
  split and its cost guidance.
- [ADR-20260901T101800Z](ADR-20260901T101800Z-images-encoded-by-reference.md) —
  the byte measurements shared with this decision.

---
title: 'ADR-20260831T134825Z: The Package Reads EPUB Itself Rather Than Through epubx'
doc_kind: adr
doc_function: canonical
purpose: 'Records why ebook_parser writes its own EPUB container/OPF/navigation reader instead of depending on epubx, and what that costs in code and schedule.'
derived_from:
  - ../product/value-proposition.md
  - ../engineering/architecture.md
canonical_for:
  - epub_backend_decision
must_not_define:
  - package_layout
  - public_api_surface
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T134825Z: The Package Reads EPUB Itself Rather Than Through epubx

## Context

The EPUB half of the extracted code is not ours. `epub_parser.dart` calls
`EpubReader.openBook` and `EpubReader.readBook` from `epubx`, and reads chapter
titles, spine content, metadata and cover through that package's object graph.
FB2, by contrast, is parsed directly with `xml`.

Extraction forces the question, because the dependency is no longer a private
implementation detail of an application — it becomes something every consumer of
`ebook_parser` inherits, and it constrains what versions they may resolve.

Three facts measured on 2026-08-31 decide the shape of the problem:

- `epubx` 4.0.0 was published on 2023-06-30 and has had no release since;
- it pins `archive: ^3.1.6`, so any package depending on it cannot move to
  `archive` 4;
- its cover API returns a decoded `image` bitmap, which forces a pure-Dart
  image decode on a path whose entire purpose is to be cheap
  ([ADR-20260831T135125Z](ADR-20260831T135125Z-raw-cover-bytes.md)).

## Decision Drivers

- the package's premise is convergence it owns, and half of it being a thin
  wrapper over an unmaintained package undercuts the README's differentiation
  claim ([value-proposition.md](../product/value-proposition.md));
- a transitive pin on a major version of `archive` is inherited by every
  consumer and cannot be worked around downstream;
- the surface actually used is narrow: container path, OPF metadata, manifest,
  spine, table of contents, cover;
- an unmaintained dependency on the critical path is a liability the package
  cannot fix for its own users;
- schedule: writing a reader is the largest single piece of work in the whole
  extraction.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Keep `epubx` | Zero new code; the behaviour being extracted is exactly today's | Caps `archive` at major 3 for every consumer; unmaintained since 2023; forces a pure-Dart image decode; makes half the package a wrapper | Rejected — the version cap and the maintenance risk are inherited by consumers, who cannot undo either |
| Switch to a maintained fork (`epub_pro`) | Maintained; small change | Same category of risk with a different owner; still an object graph shaped by someone else's model; still a wrapper | Rejected — it moves the dependency rather than removing it |
| Write the package's own reader | No version caps; the cover path can return bytes; the code matches the shared model directly; the differentiation claim becomes true | ~550-600 lines to write and test; real-world EPUB variance must be met by us | **Accepted** |

## Decision

The package reads EPUB itself, in `0.1.0` rather than deferred to a later
version. `epubx` is not a dependency.

Scope of what is written: the `META-INF/container.xml` root-file lookup, the OPF
package document (`dc:title`, `dc:creator`, `dc:language`, manifest entries with
their media types and `properties`, and spine order), the table of contents from
either an EPUB 2 NCX `navMap` or an EPUB 3 `nav[epub:type=toc]`, chapter content
resolution including relative-path and percent-encoding handling, and cover
lookup by EPUB 3 `properties="cover-image"` or EPUB 2 `meta name="cover"`.

The reader is written from the EPUB 2 and EPUB 3 specifications, which are
public, and against a corpus of real books. `epubx` is MIT licensed (© 2017 Colin
Nelson) and may be consulted to see how it handled a particular case, but its
code is not copied. Writing rather than deriving means there is no third-party
attribution question, no derivative-work relationship to reason about, and no
inheritance of its defects. The bulk of `epubx` is schema DTOs for parts of OPF
and NCX this package does not read, so transcribing it would have been the wrong
shape anyway.

Two requirements are part of this decision rather than implementation detail,
because getting either wrong removes something the package claims:

**`parseMetadata` must stay cheap.** Its low cost came from `epubx.openBook`,
which read the OPF and cover without inflating chapters. The reader reproduces
that explicitly: read the zip's central directory, inflate the OPF and the cover
entry, and nothing else. Written naively it would decompress the whole book, and
the cheap metadata path — one of the package's four stated capabilities — would
disappear without any test failing.

**Chapter content covers more than paragraphs and headings.** The extracted code
selects `p, h1..h6, li` and drops `blockquote`, text-bearing `div`s and table
cells, and flattens list items into ordinary paragraphs. The new reader treats
`blockquote` as content and the README states what is not extracted, so the
boundary is chosen rather than discovered.

Because the pin is gone, the package depends on `archive: ^4` (latest 4.2.0,
published 2026-08-22). TeaderBook is on `archive: ^3.6.1` today and moves with it
at `STEP-07`, which costs less than it sounds: verified 2026-08-31, `archive` is
imported by exactly two files in the app — `book_archive.dart` and its test — and
both move into the package. The app's direct dependency goes away rather than
being upgraded.

The `epubx` pin is the real gate, not the app's own code. While `epubx` sits in
the app's `pubspec.yaml`, its `archive: ^3.1.6` caps resolution at major 3, so a
package requiring `^4` would fail `dart pub get`. `epubx` is imported by exactly
one file, `epub_parser.dart`, which also moves — so both leave in the same commit
and the conflict never materialises.

## Consequences

### Positive

- No transitive version cap: consumers choose their own `archive` major.
- The dependency list loses `epubx` and, with it, `quiver` and `collection`.
- No third-party attribution file is needed, because nothing is derived.
- The cover path can return stored bytes, because nothing forces a decode.
- The claim that the package is not a wrapper over existing EPUB packages
  becomes literally true, which is what the README has to argue.
- Chapter reading is shaped by the shared model instead of translated into it,
  so the translation layer where format bugs concentrate gets thinner.

### Negative

- The largest piece of work in the extraction, and the one with the widest
  real-world input variance. EPUB files in the wild disagree about relative
  paths, percent-encoding, spine-versus-NCX ordering, and cover declaration.
- Bugs `epubx` had already found and fixed can be rediscovered here.
- `STEP-01` grows from a copy-and-clean step into a copy-clean-and-write step.
- TeaderBook's dependency resolution changes at `STEP-07`: `epubx` and `archive`
  must leave its `pubspec.yaml` in the same commit that adds the package, or
  `dart pub get` fails on the `archive` major.

### Neutral / Organizational

- [engineering/architecture.md](../engineering/architecture.md) gains the
  reader's units; this ADR must not restate the layout.
- `REQ-03` in [FT-001/brief.md](../features/FT-001-extract-package/brief.md)
  loses `epubx` from its dependency inventory.
- The package ships a third-party attribution file, which it otherwise would not
  need.

## Risks And Mitigation

The real risk is real-world EPUB variance: a reader that passes on synthetic
fixtures and fails on books from actual catalogues. It is sharpened by shipping
the reader in `0.1.0`, so the highest-variance code in the package reaches users
before any of them has had a chance to report anything. Mitigated by collecting a
corpus of real books from several producers before writing rather than after, by
golden fixtures covering both EPUB 2 (NCX) and EPUB 3 (nav) rather than one
synthetic sample, and by keeping `epubx` available to compare behaviour against
while the reader is being written.

Secondary risk: scope creep into the parts of OPF and NCX the package does not
need — `guide`, `pageList`, `navList`, bindings. Mitigated by the model itself,
which has nowhere to put them ([ADR-20260830T161443Z](ADR-20260830T161443Z-single-document-model.md)).

## Follow-up

- `STEP-01` in [implementation-plan.md](../features/FT-001-extract-package/implementation-plan.md)
  covers writing the reader, not only copying code.
- A corpus of real EPUB files from several producers is collected **before** the
  reader is written, not after, since it is the only thing that exercises the
  variance this decision takes on.
- A test asserts `parseMetadata` does not inflate chapter entries.
- `pubspec.yaml` declares `archive: ^4`; TeaderBook drops its own `archive` and
  `epubx` in the same commit at `STEP-07`.
- The README's comparison section rests on this decision.

## Related Links

- [product/value-proposition.md](../product/value-proposition.md) — why being a
  wrapper undercuts the package's premise.
- [ADR-20260831T135125Z](ADR-20260831T135125Z-raw-cover-bytes.md) — the cover
  path this decision unblocks.
- [ADR-20260830T161443Z](ADR-20260830T161443Z-single-document-model.md) — the
  model the reader targets.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) — `DEC-02`.

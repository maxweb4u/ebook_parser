---
title: New-Format Candidates Against The 0.1.0 Surfaces
doc_kind: engineering
doc_function: canonical
purpose: 'Read when a new book format is proposed: what MOBI/AZW3, TXT, FB3, CBZ and PDF each cost against the surfaces frozen at 0.1.0, assessed 2026-09-01.'
derived_from:
  - ../adr/ADR-20260830T161443Z-single-document-model.md
status: draft
---
# New-Format Candidates Against The 0.1.0 Surfaces

Assessed 2026-09-01, during the second architecture review, by checking each
candidate against the surfaces that freeze at `0.1.0`: `Block` (sealed, three
variants), `ParseFailureKind` (closed at five), `ArchiveContent` (sealed —
see `OQ-19`), and `BookMetadata` (nullable `title`, empty `authors`).

- **MOBI / AZW3** — highest value, highest cost. Two sub-formats: MOBI7
  (PalmDoc container, own markup) and KF8 (HTML — reuses the XHTML-to-blocks
  unit if it is factored format-neutrally). The real cost is PalmDoc/HUFF-CDIC
  decompression in pure Dart: no maintained pub.dev dependency existed for it
  when checked. Most wild MOBI carries Amazon DRM, so `drmProtected` becomes a
  frequent answer — the kind fits, but its doc comment currently says
  EPUB-only. Detection magic is `BOOKMOBI` at byte offset 60, not in the first
  bytes.
- **TXT** — technically trivial, decision-heavy: chapters from flat text are a
  heuristic (one chapter per book? split on `Глава N` / blank runs?), and
  `Chapter.index` stability would then rest on that heuristic — needs an ADR
  before code. Metadata all-absent is already legal in the model. Encoding
  sniffing wants the FB2 prolog/encoding unit factored out.
- **FB3** — zip container, so it lands directly on `OQ-19`
  (`ArchiveContent` has no case for a third container format).
- **CBZ / CBR** — beyond `OQ-19`, adding CBZ reclassifies existing inputs: a
  zip of images honestly yields `NoBookInside` today and would become a book —
  a behaviour change for current consumers. Resurfaces the undecided
  fixed-layout question in corpus-findings. CBR is RAR: likely no pure-Dart
  dependency.
- **PDF / DjVu** — do not: the model excludes layout by decision
  (pagination ADR); this would be a different package.

Suggested gate if any of this proceeds: a format-admission checklist (maps
onto the three `Block` variants; chapters definable; five failure kinds
suffice; container fits `ArchiveContent`; producer corpus collected before the
reader is written) — it turns the single-model ADR's procedural mitigation
into something enforceable.

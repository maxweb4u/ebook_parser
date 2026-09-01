---
title: '2026-09-01 Review: Recommendations That Are Not Defects'
doc_kind: engineering
doc_function: canonical
purpose: 'Read before post-0.1.0 hardening or an API-evolution discussion: four improvements from the 2026-09-01 review that were deliberately not recorded as open questions.'
derived_from:
  - public-api.md
status: active
---
# 2026-09-01 Review: Recommendations That Are Not Defects

The 2026-09-01 architecture review recorded its defects as `OQ-19`..`OQ-25` in
the FT-001 plan. These four are recommendations, not defects — parked here so
they are not re-derived at review cost.

- **Zip-bomb guard with no API change.** public-api.md accepts "no guard in
  `0.1.0`", but the position never considered the cheap variant: compare the
  central directory's *declared* uncompressed sizes against a ceiling before
  inflating anything. No new parameter, no behaviour change on honest files.
- **Factor HTML and encoding knowledge out of the format directories.**
  `epub/xhtml_blocks.dart` is HTML knowledge, not EPUB knowledge, and the
  prolog/encoding sniffing in `fb2/fb2_encoding.dart` is encoding knowledge,
  not FB2 knowledge. Neutral units are free to name now and are exactly what
  KF8 (HTML) and TXT (encoding sniffing) would reuse. Internal move, so it can
  also happen after `0.1.0` at no cost — the point is to not entrench the
  placement.
- **`IBookParser` evolution.** It is an `abstract interface class`, so
  consumers implement it (mocks, custom parsers) and a third method is a
  breaking change for them. The obvious v2 capability — lazy / per-chapter
  parsing, motivated by the corpus's 825-item spine and the 15 MB
  images-resident FB2 — should arrive as a separate interface or extension,
  never as a new method on the port.
- **Surface the `.fb2.zip` fast path.** The triple decompression on the normal
  path (94% of the FB2 collection) has a recorded workaround — inspect once
  with `inspectBookArchive`, hand inner bytes to the parser — but it lives in
  a public-api.md aside. It belongs in the README as the recipe for library
  imports, which is exactly the caller the cost lands on.

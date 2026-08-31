---
title: Decision Records Index
doc_kind: adr
doc_function: index
purpose: Registry of accepted architecture and engineering decisions.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---
# Decision Records Index

Read when you need to find an accepted decision or record a new one.

## Registry

- [ADR-20260830T161251Z: Package Name Is ebook_parser](ADR-20260830T161251Z-package-name-ebook-parser.md) — Records why the package is named ebook_parser rather than fb2, epub_parser, epub, epub_fb2, biblio, or libris, and what that name commits us to.
- [ADR-20260830T161443Z: Both Formats Converge On One Document Model](ADR-20260830T161443Z-single-document-model.md) — Records why EPUB and FB2 parse into a single shared document model rather than two parallel type trees, and what that costs.
- [ADR-20260831T134825Z: The Package Reads EPUB Itself Rather Than Through epubx](ADR-20260831T134825Z-own-epub-reader.md) — Records why ebook_parser writes its own EPUB container/OPF/navigation reader instead of depending on epubx, and what that costs in code and schedule.
- [ADR-20260831T134925Z: Segmentation Is Script-Driven, Rule-Based, And Replaceable](ADR-20260831T134925Z-script-driven-segmentation.md) — Records that sentence and word segmentation is decided by writing system rather than language, what the built-in rules cover, and why the segmenter is an injectable port.
- [ADR-20260831T135025Z: The Package Validates Languages Against Full ISO-639-1](ADR-20260831T135025Z-language-resolution.md) — Records that a book's declared language is normalized to ISO-639-1 and accepted against the whole standard, and that narrowing to an application's supported set is the caller's job.
- [ADR-20260831T135125Z: Covers Are Returned As Stored, Never Re-Encoded](ADR-20260831T135125Z-raw-cover-bytes.md) — Records why the package hands back the cover bytes exactly as the file stores them plus a media type, instead of decoding and re-encoding them, and what the caller must do instead.
- [ADR-20260831T135225Z: Pagination State Stays Out Of The Document Model](ADR-20260831T135225Z-model-excludes-pagination.md) — Records why ParagraphBlock sheds the reader's spillBefore/spillAfter/wholeSentence, and why a consumer that needs them wraps the block instead of extending it.
- [ADR-20260831T135325Z: Serialization Ships As A Separate Opt-In Library](ADR-20260831T135325Z-optional-serialization-library.md) — Records why the package owns JSON serialization of its own model behind a second import, and how its schema version divides responsibility with a consumer's cache policy.
- [ADR-20260831T135425Z: The Archive Layer Is Part Of The Public Surface](ADR-20260831T135425Z-archive-layer-is-public.md) — Records why inspectBookArchive and the sealed ArchiveContent are exported rather than hidden behind transparent unwrapping, because a zip holding several books is a caller decision.
- [ADR-20260831T140218Z: Expected Failures Are Returned As ParseResult, Never Thrown](ADR-20260831T140218Z-parse-result-type.md) — Records the package-local result type, why its cases are named ParseOk and ParseErr rather than Ok and Err, and why ParseFailure carries a diagnostic message alongside its kind.
- [ADR-20260831T144622Z: Both Readers Emit Inline Images](ADR-20260831T144622Z-inline-images-are-extracted.md) — Records that ImageBlock must actually be produced by both parsers rather than remaining an unfillable variant of the sealed model, and that it carries a media type like the cover does.

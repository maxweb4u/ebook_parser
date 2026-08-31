---
title: Format Mapping
doc_kind: engineering
doc_function: canonical
purpose: 'What each EPUB and FB2 construct becomes in the shared model, and what is deliberately not extracted — the source of the README''s format support table.'
derived_from:
  - ../domain/model.md
canonical_for:
  - format_extraction_boundary
must_not_define:
  - document_model
  - public_api_surface
  - package_layout
status: active
audience: humans_and_agents
---
# Format Mapping

Construct by construct, what each format contributes to the shared model. The
model itself is owned by [domain/model.md](../domain/model.md); the governing
decision is
[ADR-20260831T162951Z](../adr/ADR-20260831T162951Z-non-prose-flattens-to-paragraphs.md).

This document is the source for the README's format support table, and `CHK-05`
reviews the README against it.

## The Rule

**Text is preserved, structure is not.** Every textual construct becomes a
paragraph, a heading, or an image. Nothing textual is dropped except where this
document says otherwise, and no structural marker survives into the model.

A construct not listed here is handled by that rule, not by an exception.

## Metadata

Fields are owned by [domain/model.md](../domain/model.md); this table records
where each one comes from.

| Field | EPUB | FB2 | Absent when |
| --- | --- | --- | --- |
| `title` | OPF `dc:title`, first occurrence | `<title-info><book-title>` | `null` — the package supplies no fallback |
| `authors` | every OPF `dc:creator`, in document order | every `<title-info><author>`, name parts joined | empty list |
| `sourceLanguageCode` | OPF `dc:language`, normalised | `<title-info><lang>`, normalised | falls back to the caller's `fallbackLanguageCode` |
| `cover` | manifest item with `properties="cover-image"`, else the `meta name="cover"` idref, else a manifest id of `cover` | `<binary>` referenced by `<coverpage><image>` | `null` |

Normalisation and the fallback are owned by
[ADR-20260831T135025Z](../adr/ADR-20260831T135025Z-language-resolution.md).
Cover bytes are never decoded
([ADR-20260831T135125Z](../adr/ADR-20260831T135125Z-raw-cover-bytes.md)), so an
SVG cover is returned as SVG with its media type, not rasterised.

Not extracted in `0.1.0`, on the reasoning in
[ADR-20260831T162651Z](../adr/ADR-20260831T162651Z-document-carries-metadata.md):
EPUB `dc:publisher`, `dc:identifier`, `dc:date`, `dc:subject`, `dc:description`;
FB2 `<annotation>`, `<sequence>`, `<genre>`, `<keywords>`, `<document-info>`,
`<publish-info>`. All can be added later without breaking anyone.

## Chapters And Navigation

Chapter shape — flat, ordered, with `level` — is owned by
[ADR-20260831T162751Z](../adr/ADR-20260831T162751Z-flat-chapter-list.md).

| Aspect | EPUB | FB2 |
| --- | --- | --- |
| What produces a chapter | one navigation entry; a spine item holding several is split at its anchors ([ADR-20260831T173725Z](../adr/ADR-20260831T173725Z-chapter-per-navigation-entry.md)) | one top-level `<section>` of `<body>` |
| `title` | matching NCX `navPoint/navLabel` or EPUB 3 `nav` `<a>` text; `null` when the spine item has no entry | the section's `<title>`; `null` when absent |
| `level` | depth of the matching navigation entry | nesting depth of the `<section>` |
| Nested subsections | deeper navigation entries inside one spine item each become a chapter at their own `level`, split before the block holding the anchor | a nested `<section>` becomes its own chapter at the deeper `level` |
| Unnavigated documents | a spine item with no navigation entry becomes an untitled chapter, **except** one the format declares to be the table of contents — EPUB 2 `<guide><reference type="toc">`, or EPUB 3 `properties="nav"` in the spine, or a `landmarks` link with `epub:type="toc"` ([ADR-20260831T184812Z](../adr/ADR-20260831T184812Z-unnavigated-spine-items.md)). A `type="cover"` page is kept — its text is not what `BookMetadata.cover` carries | — |
| Non-linear content | the `linear="no"` attribute is ignored; the item is a chapter in spine order like any other, and usually an untitled one because such files rarely carry a navigation entry | `<body name="notes">` is likewise kept in document order |
| Extra bodies | — | `<body name="notes">` and any further `<body>` become chapters appended after the main body |

`spine` order plus document order is reading order in EPUB; the navigation
document supplies titles, depth and split points, never order. Where the two
disagree, the spine wins — it is what the format defines as reading order. An
anchor that resolves to nothing drops its entry rather than failing the parse, an
anchor on an inline element splits before its enclosing block, and an entry
pointing outside the spine is ignored.

## Block Content

Both readers produce only `ParagraphBlock`, `HeadingBlock` and `ImageBlock`.

### EPUB — XHTML

| Construct | Becomes |
| --- | --- |
| `<p>` | one paragraph |
| `<h1>`–`<h6>` | heading, `level` from the tag |
| `<div>` holding text directly | one paragraph |
| `<br>` | a newline inside the paragraph text; never splits a paragraph |
| `<ul>`, `<ol>` | one paragraph per `<li>`; nesting not marked |
| `<table>` | one paragraph per `<tr>`, cells joined by a single space, row-major |
| `<blockquote>` | paragraphs, no marker |
| `<a>` | its text; the `href` is dropped |
| `<em>`, `<strong>`, `<b>`, `<i>`, `<s>`, `<sup>`, `<sub>`, `<span>` | their text |
| `<img>`, `<image>` in a `<figure>` | `ImageBlock` resolved through the manifest |
| `<figcaption>` | a paragraph after the image |
| `<ruby>` | base text; the reading is dropped |
| MathML, inline SVG, `<audio>`, `<video>` | dropped |
| CSS, in any form | never read |

Chapter XHTML is parsed with `html`, not with `xml`: real books do not guarantee
well-formed XML ([public-api.md](public-api.md) records why the dependency
exists).

### FB2

| Construct | Becomes |
| --- | --- |
| `<p>` | one paragraph |
| `<title>` inside a section | the chapter title, and a heading at the section's level |
| `<subtitle>` | heading, one level below its section |
| `<stanza>` | one paragraph; `<v>` lines joined by newlines |
| `<poem>` | its `<stanza>`s in order; `<title>` becomes a heading |
| `<epigraph>`, `<cite>` | paragraphs, no marker; `<text-author>` a paragraph |
| `<table>` | one paragraph per `<tr>`, cells joined by a single space |
| `<emphasis>`, `<strong>`, `<strikethrough>`, `<sup>`, `<sub>`, `<style>` | their text |
| `<a l:href>` | its text; the target is dropped, so a footnote reference reads as its marker |
| `<image>` | `ImageBlock` resolved to the `<binary>` it names |
| `<empty-line>` | dropped |
| `<annotation>` inside a section | paragraphs |
| `<code>` | its text as a paragraph |

FB2 encoding is resolved from the XML prolog before parsing, with
`enough_convert` covering windows-1251/1250/1252 and koi8-r/u — without which FB2
from public catalogues is unreadable ([public-api.md](public-api.md)).

## Where The Two Formats Differ

Deliberate asymmetries, each because the formats carry different information.
[testing-policy.md](testing-policy.md) requires any behaviour claimed for one
format to be asserted for the other; these are the cases where the claim itself
differs, and they are listed rather than tested for parity.

| Difference | Why |
| --- | --- |
| FB2 marks verse, epigraphs and subtitles explicitly; EPUB expresses them in CSS the package never reads | An EPUB epigraph is indistinguishable from a paragraph without reading a stylesheet |
| FB2 note texts arrive as trailing chapters; EPUB note texts are ordinary spine items | Both end up as chapters, by different routes |
| EPUB has an inline navigation heading heuristic; FB2 has none | Only EPUB duplicates a navigation label as an inline heading ([`DEC-11`](../features/FT-001-extract-package/brief.md)) |
| An EPUB cover may be SVG; an FB2 cover is always a raster `<binary>` | Format difference, surfaced through `mediaType` |

## Not Extracted, Either Format

- Any styling, class, or stylesheet.
- Link targets, and therefore working cross-references and footnote links.
- List nesting, table geometry, quotation attribution as structure.
- MathML, SVG illustrations, embedded audio and video.
- Page-break hints, and anything else describing layout — the model excludes
  pagination by decision
  ([ADR-20260831T135225Z](../adr/ADR-20260831T135225Z-model-excludes-pagination.md)).
- EPUB 3 media overlays, and EPUB encryption of any kind.
- DRM. A DRM-protected book is not decrypted and parses as corrupt.
- A table-of-contents page the book declares as such. Only a declaration counts;
  a contents page that is merely recognisable stays.

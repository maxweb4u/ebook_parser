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

A chapter that ends up with no blocks at all is dropped rather than emitted, so
`Chapter.index` stays dense and equal to the chapter's position in the list
([ADR-20260901T101700Z](../adr/ADR-20260901T101700Z-empty-document-means-no-blocks.md)).
This does not compete with the rule above that keeps unnavigated spine items:
that one decides which documents become chapters, this one decides that a chapter
with nothing in it earns no entry in the contents. A spine item holding a
full-page image has an `ImageBlock` and survives both — which is why a
fixed-layout book parses rather than vanishing.

A document in which *no* chapter has any block is refused as `emptyDocument`.
That is a stricter test than the source's, which asks for readable **text** and
would therefore refuse every comic; a chapter holding a single `ImageBlock` is
content here.

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

`HeadingBlock` is empty on many real EPUBs, and this belongs in the README rather
than in a consumer's debugging session. Publishers carry heading semantics in CSS
classes, which the package never reads: the retail Baen file in
[corpus-findings.md](corpus-findings.md) has one `<h1>`–`<h6>` tag against 6 822
`<p>` tags, and all thirty of its chapter headings are `<p class="chapter">`. On
such a book every chapter title arrives through `Chapter.title` and none through
a block. A consumer that renders blocks alone and expects headings among them
gets a wall of undifferentiated prose — so render `Chapter.title` yourself.

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
| An FB2 `<title>` becomes both `Chapter.title` and a `HeadingBlock`; an EPUB navigation label becomes `Chapter.title` only | FB2 marks the title inside the section, so the heading is in the document. EPUB's label lives in the navigation, outside the content, and synthesising a block from it would be inventing text ([`DEC-11`](../features/FT-001-extract-package/brief.md)) |
| An EPUB cover may be SVG; an FB2 cover is always a raster `<binary>` | Format difference, surfaced through `mediaType` |
| `drmProtected` is reachable for EPUB only | FB2 has no encryption concept; there is nothing to detect |

`parseMetadata`'s cost used to be on this list — cheap for EPUB and, as written,
O(file) for FB2. It is not an asymmetry any more: the FB2 metadata reader streams
to the cover instead of building a DOM over the body
([ADR-20260901T101900Z](../adr/ADR-20260901T101900Z-streaming-fb2-metadata.md)),
so the method means the same thing for both formats. What that costs instead is
two FB2 reading paths that must agree, which `SC-13` is what guards.

## Not Extracted, Either Format

- Any styling, class, or stylesheet.
- Link targets, and therefore working cross-references and footnote links.
- List nesting, table geometry, quotation attribution as structure.
- MathML, SVG illustrations, embedded audio and video.
- Page-break hints, and anything else describing layout — the model excludes
  pagination by decision
  ([ADR-20260831T135225Z](../adr/ADR-20260831T135225Z-model-excludes-pagination.md)).
- EPUB 3 media overlays.
- DRM. A protected book is not decrypted and is refused as `drmProtected`
  ([ADR-20260901T101600Z](../adr/ADR-20260901T101600Z-parse-failure-kinds-closed-at-five.md)),
  which is a distinct failure kind precisely because a locked book is intact and
  "damaged file" is the wrong thing to tell its owner. Detection is the
  container's own declaration — `META-INF/encryption.xml` covering publication
  resources, or `META-INF/rights.xml` — and needs no decryption.
- A table-of-contents page the book declares as such. Only a declaration counts;
  a contents page that is merely recognisable stays.

**Encryption is not the same as DRM, and the distinction is load-bearing.** The
same `META-INF/encryption.xml` also carries font obfuscation, which protects a
typeface rather than the book. The package reads neither fonts nor CSS, so such a
book is parsed normally with nothing missing from the model. A reader that tests
for the file's presence rather than for what it encrypts refuses well-produced
books that are perfectly readable. No file in the fetched corpus carries an
`encryption.xml` at all, so this rule rests on the OCF specification rather than
on evidence from the collection, and generated fixtures cover both branches.

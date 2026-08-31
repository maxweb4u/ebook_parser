---
title: Corpus Findings
doc_kind: engineering
doc_function: canonical
purpose: 'What real EPUB and FB2 files actually contain, measured over the local collection — the evidence STEP-00b exists to produce, and what the collection still does not cover.'
derived_from:
  - format-mapping.md
canonical_for:
  - real_world_format_variance
must_not_define:
  - format_extraction_boundary
  - document_model
  - public_api_surface
status: active
audience: humans_and_agents
---
# Corpus Findings

Measured 2026-08-31. Two collections, surveyed with the same script: the files
already on this machine (177 EPUB, 211 FB2), and nine EPUB files fetched from
Project Gutenberg and Standard Ebooks to cover the producers the local files do
not. Every file was opened and its structure counted; nothing here is an
estimate.

This is the evidence `STEP-00b` exists to produce. It is not yet complete — the
gaps are named in [Still Missing](#still-missing).

One measurement caveat: navigation depth for EPUB 3 `nav` documents is derived by
counting unclosed `<ol>` elements before each link, which is an approximation.
Depth for NCX is exact, from the `navPoint` tree.

## Producer Coverage

The 177 EPUB files are effectively **one producer**, not several:

| Signal | Value |
| --- | --- |
| EPUB version | `2.0` — all 177 |
| Navigation | NCX — all 177; EPUB 3 nav documents: **zero** |
| OPF path | `OPS/content.opf` — 175 of 177 |
| File name ending `.fb2.epub` | 165 of 177 |
| Identifiable generator | 2 files (Calibre 4.99.5 and 5.17.0); the rest declare none |
| Declared language | `ru` — 175; `en` — 2 |

That is a single FB2-to-EPUB conversion pipeline, plus two Calibre exports. The
twelve files whose names do not follow the converter's pattern were checked
individually in case any was a retail file: eleven carry the converter's own
`OPS/content.opf`, and the twelfth had been through Calibre. No file in the
collection comes straight from a store or a publisher. The
plan asks for "several producers" precisely because a reader written against one
toolchain passes its tests and fails in the field, and `STOP-04` is written
against a whole producer's output failing.

Nine files were fetched to close that gap — Project Gutenberg's own toolchain and
Standard Ebooks' hand-produced editions, both public domain:

| File | Version | Navigation | Spine | Nav entries | Depth | `cover-image` | Language |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Gutenberg 11 *Alice*, epub3 | 3.0 | nav | 15 | 16 | 1 | yes | `en` |
| Gutenberg 11 *Alice*, epub2 | 2.0 | NCX | 14 | 16 | 0 | no | `en` |
| Gutenberg 2600 *War and Peace* | 3.0 | nav | 368 | 385 | 1 | yes | `en` |
| Gutenberg 1982 *羅生門* | 3.0 | nav | 3 | 2 | 1 | yes | `ja` |
| Gutenberg 12479 *三字經* | 3.0 | nav | 3 | 1 | 1 | yes | `zh` |
| Gutenberg 30774 *Московия* | 3.0 | nav | 3 | 17 | 2 | yes | `ru` |
| Standard Ebooks *Pride and Prejudice* | 3.0 | nav | 65 | 65 | 1 | yes | `en-GB` |
| Standard Ebooks *Pride and Prejudice*, advanced | 3.0 | nav | 65 | 65 | 1 | yes | `en-GB` |
| Standard Ebooks *Leaves of Grass* | 3.0 | nav | 44 | 718 | 4 | yes | `en-US` |
| Wikisource *كليلة ودمنة* | 3.0 | nav | 22 | 22 | 1 | no | `ar` |
| Baen *Witchy Eye* | 2.0 | NCX | 37 | 30 | 0 | no | `en` |

Three things this immediately supplies that 177 local files did not: eight EPUB 3
navigation documents, eight `properties="cover-image"` covers, and the first
BCP-47 language subtags in the whole corpus — `en-GB` and `en-US`, which are
exactly what `normalizeLanguageCode` exists to reduce to a primary subtag
([ADR-20260831T135025Z](../adr/ADR-20260831T135025Z-language-resolution.md)).
Japanese and Chinese also arrive, so the per-writing-system claims in
[ADR-20260831T134925Z](../adr/ADR-20260831T134925Z-script-driven-segmentation.md)
have something to be checked against.

### Still Missing

- **A genuine legacy-encoded FB2 from the wild.** Every FB2 seen so far declares
  `utf-8`, including a file supplied specifically as a windows-1251 sample, which
  was UTF-8 on inspection. Four derived files now cover the mechanism (see
  [Derived Encoding Fixtures](#derived-encoding-fixtures)); what they cannot show
  is whatever an old catalogue export does that nobody predicted.
- **Non-linear spine items** are absent from all 186 EPUB files, and this is
  recorded rather than pursued. `linear="no"` is ignored by decision — such an
  item becomes a chapter in spine order like any other — so there is no code path
  the corpus could exercise. It is listed here so the absence is not mistaken for
  an oversight.
- **Fixed-layout EPUB** — comics, children's books, textbooks, one document per
  printed page — is unrepresented, and would yield hundreds of one-block
  chapters. Whether the package should detect and refuse it is not decided.
- **InDesign and Sigil specifically** are still absent, but the pathology they
  were wanted for is not: see [Retail Output](#retail-output) below, where a
  commercial publisher's own file turned out to have it.

  A note so nobody repeats the search: this material resists scripted
  collection. Baen prices its Free Library at `$0.00` but routes downloads
  through `customer/account/login`, so a file needs an account and a person.
  Safahat sits behind a Cloudflare challenge. Open Book Publishers and Qatru
  render their download links in the browser rather than in the HTML.
- **Vertical Japanese and Hebrew text** are still unrepresented, though both
  matter less than they sound. Reading direction is a rendering property and the
  package does not render, so `page-progression-direction` and vertical writing
  change nothing in the model — the spine is still the spine and the characters
  are still the characters. What mattered was the sentence terminator table, and
  Arabic now covers it (see below).

## Retail Output

*Witchy Eye* (D. J. Butler, Baen Books) was downloaded from the publisher's own
store — the first file in the corpus that a paying customer would actually
receive. Three things it settles.

**Retail is not InDesign.** The file declares
`contributor=calibre (2.31.0)`, timestamped 2017, and ships as EPUB 2 with an
NCX. A live commercial publisher distributes Calibre output, so "publisher
toolchain" and "InDesign" are not the same gap, and the corpus now covers the
first.

**The CSS-carried-semantics pathology is here, and it is total.** Across the
book's 37 documents there is exactly **one** `<h1>`–`<h6>` tag and **6 822**
`<p>` tags. All thirty chapter headings are marked as:

```html
<p class="chapter" id="calibre_toc_3">CHAPTER ONE</p>
```

The package never reads CSS
([ADR-20260831T162951Z](../adr/ADR-20260831T162951Z-non-prose-flattens-to-paragraphs.md)),
so **this entire book yields no `HeadingBlock` at all**. Nothing is lost — every
chapter title arrives through the NCX as `Chapter.title` — but a consumer
expecting `HeadingBlock` to be populated on a normal novel will find it empty,
and this is the file that proves the case rather than assuming it.

**Rule 2 of the chapter decision gets its first real workout.** The spine has 37
items and the navigation has 30 entries, so seven leading documents carry no
entry and become untitled chapters
([ADR-20260831T173725Z](../adr/ADR-20260831T173725Z-chapter-per-navigation-entry.md)):
`titlepage.xhtml`, `contents.xhtml`, and five unlabelled front-matter splits
holding the half-title, the dedication and similar. Six of the seven are genuine
content and belong in reading order.

The seventh is not. `contents.xhtml` is a generated table-of-contents *page* —
thirty links, 591 characters — and the package keeps link text while dropping
targets, so it becomes an untitled chapter that restates the table of contents as
prose. The format says so explicitly: the OPF `<guide>` carries
`<reference type="toc" href="contents.xhtml"/>`, recorded as `OQ-12`.

Reading the source to settle `OQ-12` turned up something larger.
`epub_parser.dart` builds chapters from `book.Chapters` — epubx's
navigation-derived tree — and never looks at the spine. **A document with no
navigation entry produces no chapter there at all.** So the source yields 30
chapters for this book where rule 2 yields 37, and the six front-matter documents
that rule 2 preserves are content the application has never shown. Whether rule 2
should exist is reopened as `OQ-13`; `OQ-12` is the narrower case inside it.

The same reading corrects a second assumption. The source *injects* a
`HeadingBlock` built from the navigation title at the top of each chapter, unless
the label is front matter or the content already begins with it. So where this
package emits no `HeadingBlock` for *Witchy Eye*, the application today shows 30
synthetic ones. Nothing is lost either way — the title is in `Chapter.title` —
but "this book yields no headings" is a statement about the package, not about
what the application currently does.

Two smaller confirmations from the same file: 29 of its 30 navigation entries
carry a fragment even though each points at its own document, so rule 3 —
one entry means no split — is what keeps the book from being re-partitioned
pointlessly; and nothing here loses an entry at spine granularity, which is the
opposite of the *Leaves of Grass* case and shows again that the answer is
producer-dependent.

## EPUB Structure

| Measure | Value |
| --- | --- |
| Spine items | min 1, median 26, p90 45, max 825 |
| Books with one spine item | 12 of 177 (7%) |
| Navigation depth ≥ 1 | 40 of 177 (23%) — max depth 4 |
| Books with more than one `dc:creator` | 8 of 177 |
| Books with no `dc:title` | 0 |

Navigation depth in nearly a quarter of the collection is direct support for
`Chapter.level`
([ADR-20260831T162751Z](../adr/ADR-20260831T162751Z-flat-chapter-list.md)): had
the field been omitted, 40 of these books would render as a flat list of
undifferentiated entries.

## Evidence For OQ-11

`OQ-11` asks whether one EPUB chapter is one spine item or one navigation entry
with its content split at the anchor. The measurement is how many navigation
entries point into a document that already has one — those are the entries a
spine-granularity reader collapses away.

| Navigation entries lost at spine granularity | Books |
| --- | --- |
| at least 1 | 37 of 177 (21%) |
| at least 5 | 27 |
| at least 20 | 8 |
| at least 50 | 4 |

The worst case turns 121 navigation entries into 16 chapters. The single-spine
books are the milder problem than expected: of the 12, nine have no navigation
entries at all and only one has more than three, so "one huge file with a rich
table of contents" is rare *here*.

Read carefully, this says one producer collapses a fifth of its books' tables of
contents under spine granularity.

The fetched producers make the answer sharper, and they disagree with each other:

| Book | Spine | Nav entries | Lost at spine granularity |
| --- | --- | --- | --- |
| Standard Ebooks *Pride and Prejudice* | 65 | 65 | **0** |
| Gutenberg *War and Peace* | 368 | 385 | 17 |
| Gutenberg *Alice* (epub3) | 15 | 16 | 2 |
| Gutenberg *Московия* | 3 | 17 | 15 |
| Standard Ebooks *Leaves of Grass* | 44 | 718 | **674** |

Standard Ebooks splits one file per navigation entry, so spine granularity is
exactly right and loses nothing — for prose. Its own poetry edition is the
opposite extreme: 718 navigation entries over 44 files, because each poem is an
anchor inside a collection file. Spine granularity turns that book's table of
contents into 44 entries out of 718.

So the answer is producer-dependent and content-dependent, and the failure is not
rare or exotic: it appears in a conversion pipeline, in Gutenberg, and in the most
carefully produced source available. That is the evidence `OQ-11` was waiting
for.

## FB2 Structure

Of 211 files, 199 (94%) are distributed as `.fb2.zip` — the transparent
unwrapping in
[ADR-20260831T162851Z](../adr/ADR-20260831T162851Z-zip-routing-decorator.md)
covers the normal case, not an edge case.

| Construct | Books containing it | Volume where present |
| --- | --- | --- |
| `<sequence>` | 208 (98%) | — |
| `<image>` / `<binary>` | 207 (98%) | median 1, max 660 |
| `<annotation>` | 203 (96%) | — |
| `<empty-line>` | 164 (77%) | — |
| `<subtitle>` | 161 (76%) | — |
| `<a>` links | 124 (58%) | median 2, max 288 |
| `<cite>` | 21 (9%) | — |
| second `<body>` | 21 (9%) | — |
| `<body name="notes">` | 21 (9%) | — |
| `<epigraph>` | 13 (6%) | median 2, max 23 |
| `<poem>` / `<stanza>` | 9 (4%) | median 11 stanzas, max 59 |
| `<table>` | 2 (1%) | 4 tables each |
| more than one `<author>` | 35 (17%) | — |
| sections | all | median 26, max 1851 |

Declared encoding is `utf-8` in **all 211 files**. Not one legacy encoding
appears.

### Derived Encoding Fixtures

`enough_convert` exists for windows-1251 and koi8, and no file in either
collection exercises it. Four fixtures were derived from the public-domain
Chekhov file to close that, each isolating one thing the encoding path must do:

| File | Bytes | Prolog declares | What it tests |
| --- | --- | --- | --- |
| `Chehov_Palata.cp1251.fb2` | cp1251 | `windows-1251` | the happy path — declaration and content agree |
| `Chehov_Palata.cp1251-undeclared.fb2` | cp1251 | nothing | sniffing, when the prolog carries no encoding at all |
| `Chehov_Palata.cp1251-mislabelled.fb2` | cp1251 | `UTF-8` | the liar — the declaration is wrong and the bytes decide |
| `Chehov_Palata.koi8r.fb2` | koi8-r | `koi8-r` | the second legacy family |

None of the four decodes as UTF-8, so a reader that ignores the encoding fails
them loudly rather than silently producing mojibake.

Deriving these is not a compromise. The mechanism under test is entirely "read
the prolog, decode the bytes", so a re-encoded file exercises it exactly — and
the mislabelled and undeclared cases are the ones that actually break readers,
which no single real file would have supplied. This is the same reasoning
[testing-policy.md](testing-policy.md) already applies to corrupt inputs:
generated coverage beats a handful of broken files someone happened to find.

The koi8-r file carries one honest caveat. koi8-r has no typographic punctuation
and no numero sign, so `«» — … №` were substituted before encoding. Its text
therefore differs from the original; its bytes are what it is for.

One file was added to the corpus separately: `corpus/fb2/Chehov_Palata.fb2`,
Chekhov's *Ward No. 6*. It is public domain, so unlike the rest of the local
collection it can become a fixture, and it carries a second `<body name="notes">`
with a link into it from the text — the shape `SC-14` needs. It is UTF-8; it was
supplied as a windows-1251 sample and is not one.

### Images By Byte, Not By Count

Measured 2026-09-01, when `OQ-15` needed a unit the table above does not carry.
The counts say how many books hold images; the decision turned on how much of a
book an image is. Re-measured over 247 files matching `*.fb2`/`*.fb2.zip` in the
local collection — more than the 211 surveyed on 2026-08-31, since the directory
has grown and holds a few duplicates, so treat these as proportions rather than
as a second census.

| Measure | Value |
| --- | --- |
| Files with any `<binary>` | 242 of 247 (98%) |
| Files with **inline** (non-cover) images | 113 (**46%**) |
| base64 share of the raw FB2 text | median 13.6%, p90 80.5%, max 95.7% |
| inline-only share | median **0%**, p90 73.2%, max 94.3% |
| raw FB2 bytes ÷ the `.fb2.zip` on disk | median 2.9×, p90 3.3× |
| Worst case | 328 images, ~15 MB of base64, 94% of the file |

**The distribution is bimodal, and no count could have shown it.** Half the
collection carries a cover and nothing else; the other half is mostly picture.
"98% carry binaries" reads as though nearly every book is affected by an
image-embedding decision, and in bytes 54% of them are not affected at all. The
same measurement in the other direction: a plain novel with only a cover is
already 20–30% base64, so "median 1 image" is not the same as "negligible".

This is what closed
[ADR-20260901T101800Z](../adr/ADR-20260901T101800Z-images-encoded-by-reference.md),
and the survey scripts in `corpus/` should grow a byte mode so the number is
reproducible rather than quoted from here.

## What These Numbers Change

- **Tables are not the risk they looked like.** Two books of 211 contain any, four
  tables each. The flattening cost accepted in
  [ADR-20260831T162951Z](../adr/ADR-20260831T162951Z-non-prose-flattens-to-paragraphs.md)
  lands on almost nobody in this collection.
- **`authors` as a list is confirmed by data.** 35 FB2 books (17%) and 8 EPUB
  books declare more than one author. A single joined string would have been
  wrong for one book in six
  ([ADR-20260831T162651Z](../adr/ADR-20260831T162651Z-document-carries-metadata.md)).
- **Note bodies are a real behaviour change.** 9% of FB2 books carry
  `<body name="notes">`, and the source parser skips it outright — verified at
  `frontend/lib/src/data/book_parsing/fb2_parser.dart`, which reads
  `if (body.getAttribute('name') == 'notes') continue;`. Extracting it as
  trailing chapters is therefore a deviation from `NS-03`, not a restatement of
  current behaviour.
- **Inline images matter more than a variant nothing produced suggested.** 98% of
  FB2 books carry binaries, and one carries 660. `DEC-10` is not a formality.
  Read by byte the same fact is sharper and differently shaped: only 46% carry an
  image that is not the cover, but where they do it is a median 73% of the file at
  the top decile. See [Images By Byte, Not By Count](#images-by-byte-not-by-count)
  — and do not quote the 98% in an argument about size, which is what happened
  before the byte measurement existed.
- **`<annotation>` and `<sequence>` are nearly universal**, and both are excluded
  from `BookMetadata` in `0.1.0`. The decision to wait until someone asks stands,
  but the wait is likely to be short: 96% and 98% of books carry them.
- **The Arabic terminator table is now testable, and the failure it guards
  against is measurable.** `كليلة ودمنة` contains 311 occurrences of the Arabic
  question mark `؟` (U+061F) and **not one ASCII `?`**, alongside 729 Arabic
  semicolons `؛` (U+061B) and 2 772 Arabic commas `،` (U+060C). A terminator
  table carrying only ASCII punctuation would split that book's sentences at its
  1 989 full stops and miss every one of its 311 questions — silently, and only
  in Arabic. This is exactly the per-writing-system honesty
  [ADR-20260831T134925Z](../adr/ADR-20260831T134925Z-script-driven-segmentation.md)
  claims, and it is now an assertion rather than a claim.
- **`enough_convert` is unexercised by this collection.** Every FB2 here declares
  `utf-8`. The dependency exists for windows-1251 and koi8 files from older
  catalogue exports, which are real but absent here. The `FB2 in windows-1251`
  golden fixture that [architecture.md](architecture.md) requires has to be
  sourced or constructed deliberately — it will not come from this collection.

## Re-fetching The Corpus

The fetched files live in `corpus/epub/` at the repository root and are excluded
by `.gitignore` — real books are never committed, and `dart pub publish` would
ship anything under `test/` to every consumer. The survey scripts sit beside them
in `corpus/`, so the numbers above can be reproduced rather than trusted.

```bash
python3 corpus/survey_epub.py out.json 'corpus/epub/*.epub'
```

Every file is public domain and re-fetchable. Project Gutenberg, by book id:

| Id | Book | URL suffix |
| --- | --- | --- |
| 11 | *Alice's Adventures in Wonderland* | `.epub3.images` and `.epub.noimages` |
| 2600 | *War and Peace* | `.epub3.images` |
| 1982 | *羅生門* | `.epub3.images` |
| 12479 | *三字經* | `.epub3.images` |
| 30774 | *Московия в представлении иностранцев* | `.epub3.images` |

`https://www.gutenberg.org/ebooks/<id><suffix>`. A 404 arrives as an HTML page
with a `200`, so check the media type rather than the status: several Gutenberg
books have no `epub3` build, and the failure is silent.

Wikisource, whose export service renders any Wikisource work as EPUB 3 and is a
fourth producer in its own right:

```
https://ws-export.wmcloud.org/?lang=ar&format=epub-3&page=<page title>
```

`lang=ar`, page `كليلة ودمنة` produced the Arabic book above. The content is
freely licensed and the service needs no key.

Standard Ebooks, from `https://standardebooks.org/ebooks/<author>/<title>/downloads/<slug>.epub`:

- `jane-austen/pride-and-prejudice` — plain and `_advanced`;
- `walt-whitman/leaves-of-grass` — the poetry edition, and the sharpest evidence
  in this document.

Two things about that host. A bare download URL returns an interstitial page, not
the file; appending `?source=download` returns the file itself. And the
interstitial contains a `/honeypot` link labelled as banning the caller's IP for
24 hours — anything walking these pages automatically must follow the meta
refresh only, never the page's links.

## Fixture Licensing

The local collection is mixed, not uniformly commercial. Judged by author and
title — none of the files carries a licence statement — 35 of the 177 EPUB files
are by authors long in the public domain (Chekhov, Turgenev, Tolstoy, Pushkin,
Gogol, Garshin, Kuprin, Twain, O. Henry, Zoshchenko, Zhukovsky), and the other
142 are contemporary works still in copyright.

That still rules the whole local collection out as fixture material, for two
reasons. `dart pub publish` ships `test/` to every consumer
([architecture.md](architecture.md)), so a golden fixture is redistribution and
the in-copyright majority cannot go in. And the public-domain minority reaches us
through a conversion pipeline whose own terms are not stated in the files, so its
provenance is unclear even where the underlying text is free.

The fetched files have neither problem: Project Gutenberg and Standard Ebooks
both state their terms, and both are public domain in the relevant sense. Golden
fixtures come from there.

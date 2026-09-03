# Changelog

## 0.1.1

- **Fixed:** an FB2 file whose XML prolog declares `utf-8` while its bytes are
  legacy Cyrillic — or which declares no encoding at all — parsed as `ParseOk`
  with the title, chapter titles and whole body replaced by U+FFFD. A lenient
  UTF-8 decode that comes back mostly replacement characters is now taken as
  evidence against the declaration, and the bytes are retried as
  windows-1251 and koi8-r. Mislabelled FB2 is common in public catalogues,
  so this turns a class of unreadable books readable; genuine UTF-8 with a
  damaged run is unaffected.

## 0.1.0

Initial release.

- EPUB and FB2 parsing into one shared document model: `BookDocument` →
  `Chapter` → `ParagraphBlock` / `HeadingBlock` / `ImageBlock`, down to lazy
  `Sentence` and `Word` spans.
- `bookParserFor` entry point with magic-byte format detection and
  transparent `.fb2.zip` unwrapping; the archive layer
  (`inspectBookArchive`) is exported for the ambiguous cases.
- A cheap `parseMetadata` path for both formats — the FB2 side streams
  events instead of building a DOM, so neither format reads chapter content
  to answer with a title, authors, language, and cover.
- Expected failures returned as `ParseResult` (`corrupt`,
  `unsupportedFormat`, `encoding`, `emptyDocument`, `drmProtected`), never
  thrown.
- Script-driven rule-based segmentation behind the replaceable
  `TextSegmenter` port, with a per-writing-system support boundary.
- Language normalization against the whole of ISO-639-1, including an
  ISO-639-2 mapping.
- Opt-in JSON serialization (`package:ebook_parser/serialization.dart`)
  versioned by `kBookDocumentSchemaVersion`, with image bytes handed back
  by reference.

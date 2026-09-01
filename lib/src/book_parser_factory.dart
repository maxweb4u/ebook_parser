// Format detection, parser selection, and the unwrapping decorator a wrapped
// book is routed through. The only place that branches on file format.

import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'book_archive.dart';
import 'book_document.dart';
import 'book_metadata.dart';
import 'book_parser.dart';
import 'epub/epub_parser.dart';
import 'fb2/fb2_parser.dart';
import 'parse_result.dart';
import 'segmentation/text_segmenter.dart';

/// Formats the package can **parse** (lowercase, no dot).
const List<String> supportedBookExtensions = ['epub', 'fb2'];

/// Extensions a file picker or an "Open with" filter should accept.
///
/// Wider than [supportedBookExtensions] by the transport wrapper: `zip` is
/// importable but not a format — `.fb2.zip` is how FB2 is normally
/// distributed, and it is unpacked before parsing.
const List<String> importableBookExtensions = [
  ...supportedBookExtensions,
  'zip',
];

/// Returns the parser for the book at [filePath] with content [bytes], or
/// `null` when no parser matches — an unrecognised file is an expected
/// outcome, not an error.
///
/// Format detection does not trust the extension: magic bytes decide, which
/// is why both the path and the bytes are taken. A caller always passes the
/// bytes it holds — to this function, and then to `parse`. For a zip holding
/// exactly one book file, the returned parser is an unwrapping decorator
/// over the parser for the inner file, so no format parser acquires
/// transport responsibilities and the caller unwraps nothing. Unwrapping is
/// one level deep, and the decorator caches nothing.
///
/// A zip holding nothing readable, or several books, yields `null`; telling
/// those two apart is what [inspectBookArchive] is for.
IBookParser? bookParserFor(String filePath, Uint8List bytes) {
  if (isZipArchive(bytes)) {
    switch (inspectBookArchive(bytes)) {
      case EpubArchive():
        return EpubParser();
      case WrappedBook(name: final name, bytes: final inner):
        final innerParser = _parserForPlainFile(name, inner);
        if (innerParser == null) return null;
        return _UnwrappingBookParser(innerParser);
      case NoBookInside():
      case SeveralBooksInside():
        return null;
      case NotAnArchive():
        // Zip magic but an unreadable archive: fall through to the
        // extension, so a truncated EPUB surfaces as ParseErr(corrupt)
        // rather than as "not a book".
        break;
    }
  }
  return _parserForPlainFile(filePath, bytes);
}

/// Parser selection for bytes that are not a transport wrapper: content
/// sniffing first, extension as the fallback.
IBookParser? _parserForPlainFile(String filePath, Uint8List bytes) {
  if (isZipArchive(bytes)) return EpubParser();
  final head =
      String.fromCharCodes(bytes.take(512).where((b) => b != 0)).toLowerCase();
  if (head.contains('<fictionbook')) return Fb2Parser();
  switch (p.extension(filePath).replaceFirst('.', '').toLowerCase()) {
    case 'epub':
      return EpubParser();
    case 'fb2':
      return Fb2Parser();
  }
  return null;
}

/// Unwraps a one-book zip and delegates to the parser for the inner file.
///
/// Holds no state and caches nothing: a caller that calls `parseMetadata`
/// and then `parse` decompresses twice, which is accepted rather than
/// holding a second copy of the book in memory.
class _UnwrappingBookParser implements IBookParser {
  const _UnwrappingBookParser(this._inner);

  final IBookParser _inner;

  @override
  Future<ParseResult<BookDocument>> parse(
    Uint8List bytes, {
    required String fallbackLanguageCode,
    TextSegmenter? segmenter,
  }) async {
    final content = inspectBookArchive(bytes);
    if (content is! WrappedBook) return ParseErr(_notAWrappedBook(content));
    return _inner.parse(
      content.bytes,
      fallbackLanguageCode: fallbackLanguageCode,
      segmenter: segmenter,
    );
  }

  @override
  Future<ParseResult<BookMetadata>> parseMetadata(
    Uint8List bytes, {
    required String fallbackLanguageCode,
  }) async {
    final content = inspectBookArchive(bytes);
    if (content is! WrappedBook) return ParseErr(_notAWrappedBook(content));
    return _inner.parseMetadata(
      content.bytes,
      fallbackLanguageCode: fallbackLanguageCode,
    );
  }

  ParseFailure _notAWrappedBook(ArchiveContent content) => ParseFailure(
        ParseFailureKind.corrupt,
        'Wrapped book: expected a zip holding exactly one book file, '
        'found ${content.runtimeType}',
      );
}

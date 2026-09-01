import 'dart:typed_data';

import 'book_document.dart';
import 'book_metadata.dart';
import 'parse_result.dart';
import 'segmentation/text_segmenter.dart';

/// Parses a book file's bytes into the shared document model.
///
/// Both methods are `Future`-returning but do no I/O — the work is CPU-bound
/// from start to finish. Awaiting [parse] on a large book blocks the isolate
/// it runs on, so callers with a user interface should run it through
/// `Isolate.run`; everything inside the returned document is sendable as
/// long as any caller-supplied [TextSegmenter] holds plain data only.
///
/// Note that segmentation is not moved into the isolate by moving the parse
/// into it: it is lazy, and runs on whichever isolate first touches
/// [ParagraphBlock.sentences]. Images, in contrast, are eager and resident.
abstract interface class IBookParser {
  /// Parses [bytes] into a full [BookDocument].
  ///
  /// [fallbackLanguageCode] is required, not defaulted: a book that declares
  /// no language is common, and the caller is the only party that knows what
  /// to assume. It must reduce to ISO-639-1 or [ArgumentError] is thrown.
  ///
  /// With [segmenter] omitted, paragraphs get exactly
  /// `RuleBasedSegmenter(languageCode: <the document's resolved language>)`,
  /// with no other configuration — that default is a contract, so a consumer
  /// can reconstruct the identical segmenter from
  /// [BookMetadata.sourceLanguageCode].
  ///
  /// Returns [ParseErr] on malformed input; never throws for expected parse
  /// failures.
  Future<ParseResult<BookDocument>> parse(
    Uint8List bytes, {
    required String fallbackLanguageCode,
    TextSegmenter? segmenter,
  });

  /// Extracts only the [BookMetadata] — title, authors, language, cover.
  ///
  /// This is the cheap path for both formats: it walks no chapters, builds
  /// no block content, and materialises no manifest entry or FB2 `<binary>`
  /// but the cover. It also fails the same way as [parse]: a DRM-protected
  /// EPUB returns [ParseFailureKind.drmProtected] here too, so the cheap
  /// path cannot put an unopenable book into a consumer's library.
  Future<ParseResult<BookMetadata>> parseMetadata(
    Uint8List bytes, {
    required String fallbackLanguageCode,
  });
}

import '../book_document.dart';

/// Splits one paragraph's text into [Sentence]s, each carrying its [Word]s,
/// with offsets relative to that paragraph's text.
///
/// A paragraph holds the segmenter it was built with and calls it lazily on
/// the first access to [ParagraphBlock.sentences]. Because the segmenter
/// travels inside every paragraph, an implementation **must hold plain data
/// only** — strings, sets, numbers, enums. In particular a compiled [RegExp]
/// in an instance field stops the whole document from crossing an isolate
/// boundary, and the failure surfaces at the caller's `Isolate.run` naming
/// neither the segmenter nor the paragraph. Keep pattern objects in top-level
/// or static finals, or build them inside [segment].
abstract interface class TextSegmenter {
  /// Segments [paragraphText] into sentences with paragraph-relative offsets.
  List<Sentence> segment(String paragraphText);
}

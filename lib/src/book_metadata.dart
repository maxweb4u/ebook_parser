import 'dart:typed_data';

/// Image bytes exactly as the file stores them, plus the media type it
/// declared.
///
/// Serves both the cover and every inline image. The package never decodes or
/// re-encodes image data: an SVG cover is returned as SVG, and a caller that
/// needs a thumbnail makes one itself.
///
/// Compares by identity, deliberately: the bytes are unbounded — a cover can
/// be several megabytes — and an equality operator that walks them is a cost
/// hidden behind a symbol.
class ImageData {
  /// Creates image data from stored [bytes] and their declared [mediaType].
  const ImageData({required this.bytes, required this.mediaType});

  /// The stored bytes, byte-identical to what the file carries.
  final Uint8List bytes;

  /// The declared media type, such as `image/jpeg` or `image/svg+xml`.
  final String mediaType;
}

/// Cheap-to-extract book metadata: what `parseMetadata` returns and what
/// `parse` puts on the document, so the two paths cannot answer differently.
///
/// The package declares what the file declared and invents nothing: [title]
/// is `null` when absent and [authors] may be empty.
///
/// Compares by identity, deliberately: it holds the cover, and comparing it
/// walks megabytes while skipping it would call two different books equal.
class BookMetadata {
  /// Creates book metadata.
  const BookMetadata({
    required this.title,
    required this.authors,
    required this.sourceLanguageCode,
    this.cover,
  });

  /// The declared title, or `null` when the file declares none. A caller that
  /// needs a display string supplies its own fallback.
  final String? title;

  /// Every declared author, in document order. Empty when the file declares
  /// none.
  final List<String> authors;

  /// The book's language as an ISO-639-1 code: the declared value when it
  /// normalizes to one, and the caller's `fallbackLanguageCode` otherwise.
  final String sourceLanguageCode;

  /// The cover image as stored in the file, or `null` when there is none.
  final ImageData? cover;
}

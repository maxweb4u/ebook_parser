// The JSON codec behind `package:ebook_parser/serialization.dart`, kept out
// of the parsing path entirely.
//
// Two things stay out of the json, for two different reasons. Sentence spans
// are re-segmented lazily on access, which is what keeps the file small and
// the load cheap. Image bytes cannot be regenerated from anything, so they
// are handed back to the caller instead of being embedded — measured over
// real FB2 collections, embedding makes an illustrated book's cache hit path
// more expensive than its miss path.

import '../book_document.dart';
import '../book_metadata.dart';
import '../segmentation/rule_based_segmenter.dart';
import '../segmentation/text_segmenter.dart';

/// The version of the encoded shape. Written into every encoded document and
/// block, and checked on decode.
///
/// This describes the shape of the model, not a cache policy: a consumer
/// stores it beside its own cache version and treats a mismatch in either as
/// a miss.
const int kBookDocumentSchemaVersion = 1;

/// Encodes [document] as JSON plus its image bytes.
///
/// Every [ImageData] in the document — inline blocks and the cover alike —
/// becomes a reference in the json carrying a stable id and its media type,
/// and the bytes arrive in the returned `images` map for the caller to store
/// as it likes. Ids are meaningful only within this one encoded document; do
/// not key long-lived storage on them across re-encodes.
///
/// Sentence spans are not encoded: they are re-segmented lazily on access.
({Map<String, dynamic> json, Map<String, ImageData> images})
    encodeBookDocument(BookDocument document) {
  final images = <String, ImageData>{};
  final metadata = document.metadata;
  final cover = metadata.cover;
  final json = <String, dynamic>{
    'v': kBookDocumentSchemaVersion,
    'metadata': {
      'title': metadata.title,
      'authors': metadata.authors,
      'lang': metadata.sourceLanguageCode,
      'cover': cover == null ? null : _imageRef(cover, images),
    },
    'chapters': [
      for (final chapter in document.chapters)
        {
          'title': chapter.title,
          'level': chapter.level,
          'blocks': [
            for (final block in chapter.blocks) _blockJson(block, images),
          ],
        },
    ],
  };
  return (json: json, images: images);
}

/// Rebuilds a [BookDocument] from [json] and the [images] its references
/// name.
///
/// Returns `null` in exactly three cases: unreadable json, a schema-version
/// mismatch, or an unresolved image reference. **An unresolved reference is
/// a decode failure, not a hole** — the default empty [images] map exists
/// for documents that have no images, not as a way to restore an illustrated
/// book without its pictures.
///
/// Pass the same [segmenter] the document was parsed with. Omitted, the
/// default is seeded from the decoded metadata's language — the same seeding
/// `parse` performs — so the default-to-default round trip segments
/// identically by construction.
BookDocument? decodeBookDocument(
  Map<String, dynamic> json, {
  Map<String, ImageData> images = const {},
  TextSegmenter? segmenter,
}) {
  try {
    if (json['v'] != kBookDocumentSchemaVersion) return null;
    final metaJson = json['metadata'] as Map<String, dynamic>;
    final lang = metaJson['lang'] as String;
    final effectiveSegmenter =
        segmenter ?? RuleBasedSegmenter(languageCode: lang);
    final coverJson = metaJson['cover'] as Map<String, dynamic>?;
    final metadata = BookMetadata(
      title: metaJson['title'] as String?,
      authors: (metaJson['authors'] as List).cast<String>(),
      sourceLanguageCode: lang,
      cover: coverJson == null ? null : _resolveImage(coverJson, images),
    );
    final chapters = <Chapter>[];
    for (final chapterJson
        in (json['chapters'] as List).cast<Map<String, dynamic>>()) {
      chapters.add(Chapter(
        index: chapters.length,
        title: chapterJson['title'] as String?,
        level: chapterJson['level'] as int,
        blocks: [
          for (final blockJson
              in (chapterJson['blocks'] as List).cast<Map<String, dynamic>>())
            _blockFromJson(blockJson, images, effectiveSegmenter),
        ],
      ));
    }
    return BookDocument(metadata: metadata, chapters: chapters);
  } catch (_) {
    return null;
  }
}

/// Encodes one [block], with the same two-part shape as
/// [encodeBookDocument]: an [ImageBlock]'s bytes arrive in the returned
/// `images` map, not in the json.
///
/// Exported so a consumer that stores something block-shaped of its own — a
/// paginated wrapper, for instance — composes with this instead of writing a
/// second block serialiser.
({Map<String, dynamic> json, Map<String, ImageData> images}) encodeBlock(
    Block block) {
  final images = <String, ImageData>{};
  final json = _blockJson(block, images);
  json['v'] = kBookDocumentSchemaVersion;
  return (json: json, images: images);
}

/// Rebuilds one [Block] from [json] and the [images] its references name.
///
/// Returns `null` on unreadable json, a schema-version mismatch, or an
/// unresolved image reference, exactly like [decodeBookDocument].
///
/// Unlike [decodeBookDocument], a lone block carries no metadata to seed the
/// default segmenter from, so with [segmenter] omitted a paragraph gets the
/// unseeded default. A consumer restoring blocks of a non-Latin book
/// supplies `RuleBasedSegmenter(languageCode: ...)` itself.
Block? decodeBlock(
  Map<String, dynamic> json, {
  Map<String, ImageData> images = const {},
  TextSegmenter? segmenter,
}) {
  try {
    if (json['v'] != kBookDocumentSchemaVersion) return null;
    return _blockFromJson(
      json,
      images,
      segmenter ?? const RuleBasedSegmenter(),
    );
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _imageRef(ImageData image, Map<String, ImageData> images) {
  final id = 'img${images.length}';
  images[id] = image;
  return {'ref': id, 'mediaType': image.mediaType};
}

Map<String, dynamic> _blockJson(Block block, Map<String, ImageData> images) =>
    switch (block) {
      // Sentence spans are intentionally omitted — re-derived from the text
      // on first access.
      ParagraphBlock(:final text) => {'t': 'p', 'text': text},
      HeadingBlock(:final text, :final level) => {
          't': 'h',
          'text': text,
          'level': level,
        },
      ImageBlock(:final image) => {'t': 'img', ..._imageRef(image, images)},
    };

Block _blockFromJson(
  Map<String, dynamic> json,
  Map<String, ImageData> images,
  TextSegmenter segmenter,
) {
  switch (json['t']) {
    case 'p':
      return ParagraphBlock(
        text: json['text'] as String,
        segmenter: segmenter,
      );
    case 'h':
      return HeadingBlock(
        text: json['text'] as String,
        level: json['level'] as int,
      );
    case 'img':
      return ImageBlock(image: _resolveImage(json, images));
    default:
      throw FormatException('Unknown block type: ${json['t']}');
  }
}

ImageData _resolveImage(
  Map<String, dynamic> json,
  Map<String, ImageData> images,
) {
  final id = json['ref'] as String;
  final image = images[id];
  if (image == null) {
    throw FormatException('Unresolved image reference: $id');
  }
  return image;
}

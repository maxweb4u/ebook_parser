import 'book_metadata.dart';
import 'segmentation/rule_based_segmenter.dart';
import 'segmentation/text_segmenter.dart';

/// A fully parsed book: metadata plus an ordered list of chapters.
///
/// Both EPUB and FB2 parse into this one structure; nothing above the parsing
/// layer needs to know which format a book came from.
///
/// Compares by identity, deliberately: a deep `==` walks the whole book.
class BookDocument {
  /// Creates a document from its [metadata] and [chapters].
  const BookDocument({required this.metadata, required this.chapters});

  /// The document's metadata. For the same bytes and the same fallback,
  /// `parse(b).metadata` equals `parseMetadata(b)` field by field.
  final BookMetadata metadata;

  /// The chapters, flat and in reading order. [Chapter.index] equals each
  /// chapter's position in this list.
  final List<Chapter> chapters;
}

/// One chapter of a [BookDocument].
///
/// The chapter list is flat and in reading order; [level] is the depth the
/// source navigation gave the chapter, `0` at the top. A chapter has no
/// identifier beyond [index], which is stable for the same input bytes
/// within one major version of the package.
///
/// Compares by identity, deliberately: a deep `==` walks the whole chapter.
class Chapter {
  /// Creates a chapter.
  const Chapter({
    required this.index,
    required this.title,
    required this.level,
    required this.blocks,
  });

  /// The chapter's position in [BookDocument.chapters].
  final int index;

  /// The navigation label or section title, or `null` for content nobody
  /// navigated to — untitled front matter is a normal occurrence, so a
  /// consumer building a table of contents filters on `title != null`.
  final String? title;

  /// Navigation depth, `0` at the top. This is navigation depth, not heading
  /// depth.
  final int level;

  /// The chapter's content, in document order.
  final List<Block> blocks;
}

/// A content block: exactly one of [ParagraphBlock], [HeadingBlock], or
/// [ImageBlock].
///
/// Sealed deliberately: a consumer switching over it must handle every
/// variant, and a new variant breaks the build at every call site rather
/// than being silently dropped.
sealed class Block {
  const Block();
}

/// A paragraph of body text.
///
/// [sentences] are segmented **lazily** on first access and cached, through
/// the [TextSegmenter] the paragraph was built with; the whole book is never
/// segmented up front. [text] may contain newlines: a line break inside a
/// paragraph is preserved rather than splitting the paragraph, which is how
/// verse survives.
///
/// Compares by identity, deliberately: it holds a consumer-supplied
/// [TextSegmenter], which has no equality contract of its own.
final class ParagraphBlock extends Block {
  /// Creates a paragraph. With [segmenter] omitted, sentences are produced by
  /// an unseeded [RuleBasedSegmenter]; the parsers always pass one seeded
  /// with the document's resolved language.
  ParagraphBlock({required this.text, TextSegmenter? segmenter})
      : _segmenter = segmenter ?? const RuleBasedSegmenter();

  /// Full paragraph text; sentence and word offsets are relative to this
  /// string.
  final String text;

  final TextSegmenter _segmenter;

  List<Sentence>? _sentences;

  /// Sentences (each carrying its words), segmented on first access and
  /// cached.
  List<Sentence> get sentences => _sentences ??= _segmenter.segment(text);
}

/// A heading line inside the flow.
///
/// Compares by identity, so `List<Block>` comparison has a single semantics
/// across the sealed family.
final class HeadingBlock extends Block {
  /// Creates a heading with its [text] and [level].
  const HeadingBlock({required this.text, required this.level});

  /// The heading text.
  final String text;

  /// The heading level, `1` for a top-level heading — heading depth, not
  /// navigation depth.
  final int level;
}

/// An inline or illustration image.
///
/// Compares by identity: it holds an [ImageData], and any `==` would compare
/// that by identity — a value-looking comparison that is not one.
final class ImageBlock extends Block {
  /// Creates an image block carrying [image].
  const ImageBlock({required this.image});

  /// The image as stored in the file.
  final ImageData image;
}

/// A sentence span within its [ParagraphBlock.text].
///
/// [start] and [end] are positions within the owning paragraph's text, not
/// within the book. Defines `==` over its fields, comparing [words]
/// element-wise — for the scripts the built-in rules carry no word rule for
/// (Thai, Khmer, Lao, Burmese), [words] is the empty list: no rule means no
/// words, not one sentence-wide word pretending to be one.
class Sentence {
  /// Creates a sentence span.
  const Sentence({
    required this.text,
    required this.start,
    required this.end,
    required this.words,
  });

  /// The sentence text, a substring of the paragraph text.
  final String text;

  /// Start offset within the paragraph text, inclusive.
  final int start;

  /// End offset within the paragraph text, exclusive.
  final int end;

  /// The sentence's words, in order. Empty for scripts with no word rule.
  final List<Word> words;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Sentence) return false;
    if (text != other.text || start != other.start || end != other.end) {
      return false;
    }
    if (words.length != other.words.length) return false;
    for (var i = 0; i < words.length; i++) {
      if (words[i] != other.words[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(text, start, end, words.length);
}

/// A single word span within its [ParagraphBlock.text].
///
/// [start] and [end] are positions within the owning paragraph's text.
/// Defines `==` over its fields.
class Word {
  /// Creates a word span.
  const Word({required this.text, required this.start, required this.end});

  /// The word text, a substring of the paragraph text.
  final String text;

  /// Start offset within the paragraph text, inclusive.
  final int start;

  /// End offset within the paragraph text, exclusive.
  final int end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Word &&
          text == other.text &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(text, start, end);
}

/// Body sampling for language detection.
extension BookDocumentSample on BookDocument {
  /// The first paragraphs of the document, for deciding what language it is
  /// in.
  ///
  /// Collects paragraph text from the start of the body forward until
  /// [maxChars] is reached — a couple of thousand characters is plenty for a
  /// language, and a book can be megabytes. Headings are skipped
  /// deliberately: chapter titles are short, often stylised, and a table of
  /// contents is the least representative text in a book. Returns `''` for a
  /// document with no paragraphs, such as an image-only book.
  String bodySample({int maxChars = 4000}) {
    final buffer = StringBuffer();
    for (final chapter in chapters) {
      for (final block in chapter.blocks) {
        if (block is! ParagraphBlock) continue;
        buffer.writeln(block.text);
        if (buffer.length >= maxChars) return buffer.toString();
      }
    }
    return buffer.toString();
  }
}

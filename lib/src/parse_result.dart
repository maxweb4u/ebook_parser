/// The result of a parse: [ParseOk] with a value, or [ParseErr] with a
/// [ParseFailure].
///
/// Expected failures — a corrupt file, an unsupported format, a DRM-protected
/// book — are returned as [ParseErr], never thrown. Only caller contract
/// violations (such as a `fallbackLanguageCode` that is not ISO-639-1) throw.
sealed class ParseResult<T> {
  /// Const base constructor for the two cases.
  const ParseResult();

  /// The parsed value, or `null` when this is a [ParseErr].
  T? get valueOrNull;
}

/// A successful parse carrying its [value].
final class ParseOk<T> extends ParseResult<T> {
  /// Wraps a successful [value].
  const ParseOk(this.value);

  /// The parsed value.
  final T value;

  @override
  T? get valueOrNull => value;
}

/// A failed parse carrying its [failure].
final class ParseErr<T> extends ParseResult<T> {
  /// Wraps a [failure].
  const ParseErr(this.failure);

  /// What went wrong.
  final ParseFailure failure;

  @override
  T? get valueOrNull => null;
}

/// Why a parse failed.
///
/// The set is closed for the major version: a sixth kind is a breaking
/// change, not an addition, because a `switch` expression over an enum must
/// cover every constant.
enum ParseFailureKind {
  /// The bytes are not a readable file of the format they claim, at any stage.
  corrupt,

  /// The bytes are recognisable and not a format this package reads.
  unsupportedFormat,

  /// The declared or sniffed encoding cannot decode the bytes.
  encoding,

  /// Parsing succeeded and produced no block of any variant, in any chapter.
  ///
  /// This is not "no text": a chapter holding a single [ImageBlock] is
  /// content, so an image-only book parses successfully.
  emptyDocument,

  /// An EPUB container declares encryption over its content —
  /// `META-INF/encryption.xml` covering publication resources, or
  /// `META-INF/rights.xml`.
  ///
  /// An `encryption.xml` that only obfuscates fonts is *not* DRM: such a book
  /// parses normally. FB2 has no encryption concept, so this kind is
  /// EPUB-only.
  drmProtected,
}

/// Describes a failed parse.
///
/// [kind] and [message] serve different audiences: a consumer switches on
/// [kind] to produce user-facing text in its own language; [message] carries
/// diagnostic detail for logs and is never localised.
final class ParseFailure {
  /// Creates a failure description.
  const ParseFailure(this.kind, this.message, {this.cause});

  /// What went wrong. Branch on this to produce user-facing text.
  final ParseFailureKind kind;

  /// Diagnostic detail for logs and bug reports: which reader, which stage,
  /// what was expected. English, never localised — not a string to display.
  final String message;

  /// The underlying exception, when one exists.
  final Object? cause;

  @override
  String toString() => 'ParseFailure(${kind.name}: $message)';
}

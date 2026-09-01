// Zip handling, and public rather than internal: a zip holding no book or
// several books is an outcome the caller must decide about.
//
// The line drawn here is between a format container and a transport wrapper.
// An EPUB container *is* a zip, so the EPUB reader reads one and always will;
// a `.fb2.zip` wraps a file that is not itself an archive, and no format
// parser learns that such a wrapper exists — it is unwrapped by the decorator
// in the parser factory before the FB2 parser sees anything.

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'book_parser_factory.dart';

/// What a picked file turned out to be.
///
/// Sealed: a sixth outcome would break every consumer's switch, and that is
/// intended. A future zip-native format is a major-version event, knowingly.
sealed class ArchiveContent {
  const ArchiveContent();
}

/// Not a zip — an ordinary FB2 (or anything else); parse it as it is.
class NotAnArchive extends ArchiveContent {
  /// Creates the not-an-archive outcome.
  const NotAnArchive();
}

/// A zip that **is** the book: EPUB. The EPUB parser reads the container
/// itself, so unwrapping it would be undoing the format.
class EpubArchive extends ArchiveContent {
  /// Creates the EPUB-container outcome.
  const EpubArchive();
}

/// A zip holding exactly one book file, already extracted.
class WrappedBook extends ArchiveContent {
  /// Creates a wrapped-book outcome with the inner file's [name] and [bytes].
  const WrappedBook({required this.name, required this.bytes});

  /// The inner file's name, which carries the extension the parser factory
  /// dispatches on.
  final String name;

  /// The inner file's bytes.
  final Uint8List bytes;
}

/// A zip with nothing in it we can read.
class NoBookInside extends ArchiveContent {
  /// Creates the nothing-readable outcome.
  const NoBookInside();
}

/// A zip holding several books. Refused rather than guessed: picking the
/// first one silently imports a book nobody chose.
class SeveralBooksInside extends ArchiveContent {
  /// Creates the several-books outcome listing the candidate [names].
  const SeveralBooksInside(this.names);

  /// The candidate book file names inside the archive.
  final List<String> names;
}

/// Whether [bytes] starts with the zip magic `PK\x03\x04`.
bool isZipArchive(Uint8List bytes) =>
    bytes.length >= 4 &&
    bytes[0] == 0x50 &&
    bytes[1] == 0x4B &&
    bytes[2] == 0x03 &&
    bytes[3] == 0x04;

/// Looks inside [bytes] and reports what to import.
///
/// Pure and synchronous: it decides, it does not write anything. The simple
/// case — an unambiguous `.fb2.zip` — is routed transparently by
/// `bookParserFor`, so a caller reaches for this when it must tell the
/// ambiguous cases apart: [NoBookInside] and [SeveralBooksInside] are import
/// decisions, not parse failures.
ArchiveContent inspectBookArchive(Uint8List bytes) {
  if (!isZipArchive(bytes)) return const NotAnArchive();

  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    // A corrupt or encrypted zip: not something we can unwrap. Left to the
    // parser, which will fail with its own diagnostic.
    return const NotAnArchive();
  }

  // EPUB first: it is a zip whose *own* container is the format. Detected by
  // content rather than by the file name, because a shared EPUB often
  // arrives named `.zip`.
  final names =
      archive.where((f) => f.isFile).map((f) => f.name).toList();
  final isEpub = names.any(
    (n) => n == 'mimetype' || n.endsWith('META-INF/container.xml'),
  );
  if (isEpub) return const EpubArchive();

  final books = archive.where((f) => f.isFile && _isBook(f.name)).toList();
  if (books.isEmpty) return const NoBookInside();
  if (books.length > 1) {
    return SeveralBooksInside(books.map((f) => p.basename(f.name)).toList());
  }

  final file = books.single;
  return WrappedBook(
    name: p.basename(file.name),
    bytes: file.content,
  );
}

/// Whether an entry inside the archive is a book we can parse. Ignores the
/// junk zips carry — `__MACOSX/…`, thumbnails, readmes.
bool _isBook(String name) {
  if (name.startsWith('__MACOSX/') || p.basename(name).startsWith('.')) {
    return false;
  }
  final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
  return supportedBookExtensions.contains(ext);
}

// The OCF container: entry lookup, the container.xml -> OPF path step, and
// the DRM declaration check.
//
// Paths inside an EPUB are URLs, not file paths: every join and normalize
// here goes through the `p.url` context, never the top-level functions whose
// behaviour depends on the current platform.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

/// Entry lookup over a decoded EPUB zip, with names normalized the way OPF
/// and navigation hrefs will reference them.
class EpubContainer {
  EpubContainer(Archive archive) {
    for (final file in archive) {
      if (!file.isFile) continue;
      _entries[_normalizeName(file.name)] = file;
    }
  }

  final Map<String, ArchiveFile> _entries = {};

  /// Test instrumentation: when non-null, receives every entry path whose
  /// bytes are actually read. The cheap-metadata guarantee — `parseMetadata`
  /// materialises no manifest entry but the cover — is asserted on the work
  /// done, and this is the probe that sees the work.
  static void Function(String path)? readProbe;

  /// Whether an entry exists at [path].
  bool has(String path) => _entries.containsKey(_normalizeName(path));

  /// The decompressed bytes of the entry at [path], or null.
  Uint8List? readBytes(String path) {
    final name = _normalizeName(path);
    final file = _entries[name];
    if (file == null) return null;
    readProbe?.call(name);
    return file.content;
  }

  /// The entry at [path] decoded as UTF-8 text, or null.
  String? readString(String path) {
    final bytes = readBytes(path);
    if (bytes == null) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String _normalizeName(String name) {
    var n = p.url.normalize(name);
    if (n.startsWith('/')) n = n.substring(1);
    if (n.startsWith('./')) n = n.substring(2);
    return n;
  }
}

/// Resolves [href] against [baseDir] into a normalized container entry path,
/// percent-decoding it the way zip entry names are stored.
String resolveEpubHref(String baseDir, String href) {
  var h = href;
  try {
    h = Uri.decodeFull(href);
  } catch (_) {
    // A malformed percent-escape: use the href as written.
  }
  final joined = baseDir.isEmpty ? h : p.url.join(baseDir, h);
  var norm = p.url.normalize(joined);
  if (norm.startsWith('/')) norm = norm.substring(1);
  return norm;
}

/// Splits an href into its path and fragment.
({String path, String? fragment}) splitFragment(String href) {
  final hash = href.indexOf('#');
  if (hash < 0) return (path: href, fragment: null);
  return (
    path: href.substring(0, hash),
    fragment: href.substring(hash + 1),
  );
}

/// The OPF path declared by `META-INF/container.xml`, or null when the
/// container does not declare one.
String? opfPathOf(EpubContainer container) {
  final xml = container.readString('META-INF/container.xml');
  if (xml == null) return null;
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } catch (_) {
    return null;
  }
  for (final rootfile in document.findAllElements('rootfile', namespace: '*')) {
    final fullPath = rootfile.getAttribute('full-path');
    if (fullPath != null && fullPath.isNotEmpty) {
      return resolveEpubHref('', fullPath);
    }
  }
  return null;
}

/// Algorithms that protect a typeface rather than the book. A file that only
/// obfuscates fonts is not DRM: the package reads neither fonts nor CSS, so
/// such a book parses normally with nothing missing.
const Set<String> _fontObfuscationAlgorithms = {
  'http://www.idpf.org/2008/embedding',
  'http://ns.adobe.com/pdf/enc#RC',
};

const Set<String> _fontExtensions = {
  '.ttf', '.otf', '.woff', '.woff2', '.ttc', '.eot',
};

/// Whether the container declares encryption over its content:
/// `META-INF/encryption.xml` covering publication resources, or
/// `META-INF/rights.xml`. Detection is the container's own declaration and
/// needs no decryption.
bool isDrmProtected(EpubContainer container) {
  if (container.has('META-INF/rights.xml')) return true;
  final xml = container.readString('META-INF/encryption.xml');
  if (xml == null) return false;
  final XmlDocument document;
  try {
    document = XmlDocument.parse(xml);
  } catch (_) {
    // An unreadable declaration cannot tell fonts from content; let the
    // content decide — an actually locked book will fail its own way.
    return false;
  }
  for (final encrypted
      in document.findAllElements('EncryptedData', namespace: '*')) {
    String? algorithm;
    for (final method
        in encrypted.findAllElements('EncryptionMethod', namespace: '*')) {
      algorithm = method.getAttribute('Algorithm');
      break;
    }
    if (algorithm != null && _fontObfuscationAlgorithms.contains(algorithm)) {
      continue;
    }
    String? uri;
    for (final ref
        in encrypted.findAllElements('CipherReference', namespace: '*')) {
      uri = ref.getAttribute('URI');
      break;
    }
    if (uri != null &&
        _fontExtensions.contains(p.url.extension(uri).toLowerCase())) {
      continue;
    }
    // Encryption over something that is not a font: the book's content is
    // locked.
    return true;
  }
  return false;
}

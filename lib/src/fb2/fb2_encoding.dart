// FB2 byte decoding: the XML prolog `encoding=` is honored, with
// enough_convert covering the legacy Cyrillic and Central European codecs
// without which FB2 from public catalogues is unreadable.

import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';

/// Thrown by [decodeFb2Bytes] when the file declares an encoding the package
/// has no codec for. The parser maps it to `ParseFailureKind.encoding`.
class UnsupportedEncodingException implements Exception {
  const UnsupportedEncodingException(this.name);

  /// The declared encoding name.
  final String name;

  @override
  String toString() => 'UnsupportedEncodingException($name)';
}

/// Decodes FB2 [bytes] to a string, honoring the XML prolog's `encoding=`
/// declaration and a UTF-16 byte-order mark.
///
/// An undeclared encoding falls back to lenient UTF-8, matching what real
/// files need; a *declared but unsupported* one throws
/// [UnsupportedEncodingException] rather than silently decoding wrong.
///
/// A declaration of UTF-8 is treated as a hypothesis, not a fact. Mislabelled
/// FB2 is endemic in public catalogues, and a lenient UTF-8 decode of legacy
/// Cyrillic bytes succeeds while replacing every letter with U+FFFD — a book
/// of `\uFFFD` returned as a success. When the decode comes back mostly
/// replacement characters the declaration is abandoned and the legacy Cyrillic
/// codecs are tried instead; see [_decodeUtf8WithLegacyRecovery].
String decodeFb2Bytes(Uint8List bytes) {
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) return _utf16(bytes, little: true);
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _utf16(bytes, little: false);
    }
  }
  final declared = _sniffEncodingName(bytes);
  final codec = _codecForEncoding(declared);
  if (codec == null) throw UnsupportedEncodingException(declared!);
  if (identical(codec, utf8)) {
    return _decodeUtf8WithLegacyRecovery(_stripBom(bytes));
  }
  try {
    return codec.decode(bytes);
  } catch (_) {
    return utf8.decode(bytes, allowMalformed: true);
  }
}

/// The share of a lenient UTF-8 decode that may be U+FFFD before the UTF-8
/// hypothesis is abandoned.
///
/// The two populations are nowhere near each other, so the exact value does
/// not matter much: genuine UTF-8 with a damaged run measures in thousandths
/// of a percent, while single-byte Cyrillic read as UTF-8 measures above 50%
/// — 53.6% on the corpus's mislabelled Chekhov. Two percent sits in the empty
/// space between them, close enough to zero that a real file has to be mostly
/// unreadable before its declaration is doubted.
const double _maxUtf8DamageRatio = 0.02;

/// The legacy codecs a mislabelled or undeclared file is retried against,
/// in order of how common they are in FB2 catalogues.
const List<Encoding> _legacyRecoveryCodecs = [
  Windows1251Codec(allowInvalid: true),
  Koi8rCodec(allowInvalid: true),
];

/// Decodes [bytes] as UTF-8, falling back to a legacy Cyrillic codec when the
/// result is too damaged for the bytes to plausibly be UTF-8 at all.
///
/// Reached for a declared `utf-8` and for no declaration alike, because both
/// fail the same way: [_codecForEncoding] answers UTF-8 for either.
///
/// The two candidates are distinguished by letter case rather than by
/// replacement count — both map every byte, so both decode without
/// replacements whatever the bytes really are. Their Cyrillic ranges are
/// mirror images (koi8-r puts lowercase where windows-1251 puts uppercase),
/// so reading one as the other turns ordinary prose into shouting. Preferring
/// the candidate whose Cyrillic is mostly lowercase picks the right one
/// without a frequency table.
String _decodeUtf8WithLegacyRecovery(Uint8List bytes) {
  final lenient = utf8.decode(bytes, allowMalformed: true);
  final damaged = _countReplacements(lenient);
  if (damaged <= lenient.length * _maxUtf8DamageRatio) return lenient;

  var best = lenient;
  var bestScore = -1.0;
  for (final codec in _legacyRecoveryCodecs) {
    final String candidate;
    try {
      candidate = codec.decode(bytes);
    } catch (_) {
      // `allowInvalid` is not a promise these codecs keep on arbitrary
      // bytes — NEG-01 feeds them random input and enough_convert throws.
      // A candidate that cannot be produced simply loses.
      continue;
    }
    if (_countReplacements(candidate) >= damaged) continue;
    final score = _cyrillicLowercaseShare(candidate);
    if (score > bestScore) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
}

int _countReplacements(String text) {
  var count = 0;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0xFFFD) count++;
  }
  return count;
}

/// The share of [text]'s Cyrillic letters that are lowercase, or 0 when it
/// has none. Russian prose sits above 0.9; the same bytes read through the
/// mirrored codec sit below 0.1.
double _cyrillicLowercaseShare(String text) {
  var lower = 0;
  var total = 0;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (unit < 0x0400 || unit > 0x04FF) continue;
    total++;
    // U+0430..U+044F plus ё at U+0451 are the lowercase letters of the range
    // this heuristic cares about; the archaic tail above U+0460 is rare
    // enough in FB2 that pairing it up would add rules without changing an
    // answer.
    if ((unit >= 0x0430 && unit <= 0x044F) || unit == 0x0451) lower++;
  }
  return total == 0 ? 0 : lower / total;
}

String _utf16(Uint8List bytes, {required bool little}) {
  final units = <int>[];
  for (var i = 2; i + 1 < bytes.length; i += 2) {
    units.add(
      little ? bytes[i] | (bytes[i + 1] << 8) : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  return String.fromCharCodes(units);
}

/// Reads the `encoding="..."` value from the XML declaration, or null.
///
/// Only the `<?xml ... ?>` declaration itself is examined — scanning further
/// would let the word `encoding="..."` inside early *content* hijack the
/// codec choice for the whole file.
String? _sniffEncodingName(Uint8List bytes) {
  var start = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    start = 3;
  }
  final head = latin1.decode(
    bytes.skip(start).take(1024).toList(),
    allowInvalid: true,
  );
  final trimmed = head.trimLeft();
  // `<?xml` must be followed by whitespace: `<?xml-stylesheet` is a
  // different processing instruction, and a pseudo-attribute inside it must
  // not pick the codec.
  if (!trimmed.startsWith('<?xml') ||
      trimmed.length <= 5 ||
      trimmed[5].trim().isNotEmpty) {
    return null;
  }
  final end = trimmed.indexOf('?>');
  final declaration = end < 0 ? trimmed : trimmed.substring(0, end);
  final match = RegExp(
    '''encoding\\s*=\\s*["']([\\w-]+)["']''',
    caseSensitive: false,
  ).firstMatch(declaration);
  return match?.group(1)?.toLowerCase();
}

/// Maps an encoding name to a codec. Absent → UTF-8; unknown → null.
Encoding? _codecForEncoding(String? name) {
  switch (name) {
    case null || 'utf-8' || 'utf8':
      return utf8;
    case 'windows-1251' || 'cp1251' || 'windows1251' || 'x-cp1251':
      return const Windows1251Codec(allowInvalid: true);
    case 'windows-1250' || 'cp1250':
      return const Windows1250Codec(allowInvalid: true);
    case 'windows-1252' || 'cp1252':
      return const Windows1252Codec(allowInvalid: true);
    case 'koi8-r' || 'koi8r':
      return const Koi8rCodec(allowInvalid: true);
    case 'koi8-u' || 'koi8u':
      return const Koi8uCodec(allowInvalid: true);
    case 'iso-8859-1' || 'latin1' || 'l1':
      return latin1;
    case 'us-ascii' || 'ascii':
      return utf8;
    default:
      return null;
  }
}

/// Drops a leading UTF-8 BOM if present.
Uint8List _stripBom(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return Uint8List.sublistView(bytes, 3);
  }
  return bytes;
}

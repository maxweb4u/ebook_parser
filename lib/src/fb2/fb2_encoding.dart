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
    return utf8.decode(_stripBom(bytes), allowMalformed: true);
  }
  try {
    return codec.decode(bytes);
  } catch (_) {
    return utf8.decode(bytes, allowMalformed: true);
  }
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

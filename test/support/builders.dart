// In-code fixture builders: the contract tests construct their inputs, and
// corrupt inputs are produced by mutating these bytes. Golden files from
// real producers live in test/fixtures/.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:enough_convert/enough_convert.dart';

/// A 1×1 red PNG.
final Uint8List kTinyPng = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/'
  'q842iQAAAABJRU5ErkJggg==',
));

/// A 1×1 grey JPEG-ish payload — content is irrelevant, bytes are asserted
/// byte-identical.
final Uint8List kTinyJpeg =
    Uint8List.fromList(List<int>.generate(64, (i) => (i * 7) % 251));

/// One spine content document.
class EpubDoc {
  EpubDoc(this.path, this.body, {this.inSpine = true, this.mediaType});

  final String path;

  /// The contents of `<body>`.
  final String body;
  final bool inSpine;
  final String? mediaType;
}

/// One navigation entry for the generated NCX or nav document.
class Nav {
  Nav(this.label, this.src, {this.depth = 0});

  final String label;
  final String src;
  final int depth;
}

/// Builds an EPUB in memory.
class EpubBuilder {
  EpubBuilder({
    this.title = 'Test Book',
    this.authors = const ['Test Author'],
    this.language = 'en',
    this.epub3 = false,
  });

  String? title;
  List<String> authors;
  String? language;

  /// With `epub3` a nav document is generated from [nav]; otherwise an NCX.
  bool epub3;

  final List<EpubDoc> docs = [];
  final List<Nav> nav = [];

  /// Extra archive entries: images, encryption.xml, fonts.
  final Map<String, List<int>> files = {};

  /// Extra manifest items as (id, href, mediaType, properties).
  final List<(String, String, String, String?)> manifestExtra = [];

  /// `<guide><reference type="toc" href="…"/>` target.
  String? guideTocHref;

  /// Cover: bytes plus how the OPF declares it —
  /// 'properties', 'meta', or 'id'.
  (String path, List<int> bytes, String mediaType, String mode)? cover;

  /// Whether the generated nav document itself appears in the spine.
  bool navInSpine = false;

  Uint8List build() {
    final manifest = StringBuffer();
    final spine = StringBuffer();
    var docIndex = 0;
    for (final doc in docs) {
      final id = 'doc${docIndex++}';
      manifest.writeln(
        '<item id="$id" href="${doc.path}" '
        'media-type="${doc.mediaType ?? 'application/xhtml+xml'}"/>',
      );
      if (doc.inSpine) spine.writeln('<itemref idref="$id"/>');
    }
    var coverMeta = '';
    final cover = this.cover;
    if (cover != null) {
      final (path, _, mediaType, mode) = cover;
      final properties = mode == 'properties' ? ' properties="cover-image"' : '';
      final id = mode == 'id' ? 'cover' : 'coverimg';
      manifest.writeln(
        '<item id="$id" href="$path" media-type="$mediaType"$properties/>',
      );
      if (mode == 'meta') coverMeta = '<meta name="cover" content="$id"/>';
    }
    for (final (id, href, mediaType, properties) in manifestExtra) {
      final props = properties == null ? '' : ' properties="$properties"';
      manifest.writeln(
        '<item id="$id" href="$href" media-type="$mediaType"$props/>',
      );
    }
    String navPath = 'nav.xhtml';
    if (nav.isNotEmpty || epub3) {
      if (epub3) {
        manifest.writeln(
          '<item id="nav" href="$navPath" media-type="application/xhtml+xml" '
          'properties="nav"/>',
        );
        if (navInSpine) spine.writeln('<itemref idref="nav"/>');
      } else {
        manifest.writeln(
          '<item id="ncx" href="toc.ncx" '
          'media-type="application/x-dtbncx+xml"/>',
        );
      }
    }
    final guide = guideTocHref == null
        ? ''
        : '<guide><reference type="toc" title="Contents" '
            'href="$guideTocHref"/></guide>';
    final opf = '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="${epub3 ? '3.0' : '2.0'}" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">test-book</dc:identifier>
    ${title == null ? '' : '<dc:title>$title</dc:title>'}
    ${authors.map((a) => '<dc:creator>$a</dc:creator>').join('\n    ')}
    ${language == null ? '' : '<dc:language>$language</dc:language>'}
    $coverMeta
  </metadata>
  <manifest>
$manifest  </manifest>
  <spine${epub3 ? '' : ' toc="ncx"'}>
$spine  </spine>
  $guide
</package>
''';

    final entries = <String, List<int>>{
      'META-INF/container.xml': utf8.encode('''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'''),
      'content.opf': utf8.encode(opf),
      for (final doc in docs) doc.path: utf8.encode(_xhtml(doc.body)),
      if (cover != null) cover.$1: cover.$2,
      ...files,
    };
    if (nav.isNotEmpty || epub3) {
      if (epub3) {
        entries[navPath] = utf8.encode(_navDoc());
      } else {
        entries['toc.ncx'] = utf8.encode(_ncx());
      }
    }
    return buildZip(entries, mimetypeFirst: true);
  }

  String _xhtml(String body) => '''
<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>x</title></head>
<body>$body</body></html>
''';

  /// The flat depth-annotated [nav] list as a tree.
  List<_NavNode> _navTree() {
    final roots = <_NavNode>[];
    final stack = <_NavNode>[];
    for (final entry in nav) {
      final node = _NavNode(entry);
      while (stack.length > entry.depth) {
        stack.removeLast();
      }
      if (stack.isEmpty) {
        roots.add(node);
      } else {
        stack.last.children.add(node);
      }
      stack.add(node);
    }
    return roots;
  }

  String _ncx() {
    var play = 0;
    String points(List<_NavNode> nodes) => nodes.map((node) {
          play++;
          return '<navPoint id="np$play" playOrder="$play">'
              '<navLabel><text>${node.nav.label}</text></navLabel>'
              '<content src="${node.nav.src}"/>'
              '${points(node.children)}'
              '</navPoint>';
        }).join();
    return '''
<?xml version="1.0" encoding="utf-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head><meta name="dtb:uid" content="test-book"/></head>
  <docTitle><text>${title ?? ''}</text></docTitle>
  <navMap>${points(_navTree())}</navMap>
</ncx>
''';
  }

  String _navDoc() {
    String list(List<_NavNode> nodes) => nodes.isEmpty
        ? ''
        : '<ol>${nodes.map((node) => '<li>'
            '<a href="${node.nav.src}">${node.nav.label}</a>'
            '${list(node.children)}'
            '</li>').join()}</ol>';
    final ol = nav.isEmpty ? '<ol></ol>' : list(_navTree());
    return '''
<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>nav</title></head>
<body><nav epub:type="toc">$ol</nav></body></html>
''';
  }
}

class _NavNode {
  _NavNode(this.nav);

  final Nav nav;
  final children = <_NavNode>[];
}

/// Builds a zip; with [mimetypeFirst] an EPUB `mimetype` entry is stored
/// first.
Uint8List buildZip(Map<String, List<int>> entries, {bool mimetypeFirst = false}) {
  final archive = Archive();
  if (mimetypeFirst) {
    archive.add(ArchiveFile.bytes('mimetype', utf8.encode('application/epub+zip')));
  }
  entries.forEach((name, bytes) {
    archive.add(ArchiveFile.bytes(name, bytes));
  });
  return ZipEncoder().encodeBytes(archive);
}

/// Builds an FB2 document string.
String fb2({
  String? bookTitle = 'Test FB2',
  String authorsXml =
      '<author><first-name>Anna</first-name><last-name>Author</last-name></author>',
  String? lang = 'en',
  String? coverHref,
  String bodiesXml = '<body><section><title><p>One</p></title>'
      '<p>First paragraph.</p></section></body>',
  String binariesXml = '',
  String encodingDeclaration = 'utf-8',
}) {
  return '''
<?xml version="1.0" encoding="$encodingDeclaration"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      ${bookTitle == null ? '' : '<book-title>$bookTitle</book-title>'}
      $authorsXml
      ${lang == null ? '' : '<lang>$lang</lang>'}
      ${coverHref == null ? '' : '<coverpage><image l:href="$coverHref"/></coverpage>'}
    </title-info>
  </description>
  $bodiesXml
  $binariesXml
</FictionBook>
''';
}

/// UTF-8 FB2 bytes.
Uint8List fb2Bytes(String document) => Uint8List.fromList(utf8.encode(document));

/// Windows-1251 FB2 bytes. The declaration is whatever [document] carries —
/// the mislabelling tests pass one that says `utf-8` on purpose.
Uint8List fb2BytesCp1251(String document) =>
    Uint8List.fromList(const Windows1251Codec().encode(document));

/// KOI8-R FB2 bytes, on the same terms as [fb2BytesCp1251].
Uint8List fb2BytesKoi8r(String document) =>
    Uint8List.fromList(const Koi8rCodec().encode(document));

/// A `<binary>` element carrying [bytes] as base64.
String fb2Binary(String id, List<int> bytes, {String contentType = 'image/png'}) =>
    '<binary id="$id" content-type="$contentType">${base64Encode(bytes)}</binary>';

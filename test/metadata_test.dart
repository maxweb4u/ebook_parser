// SC-13: parse().metadata equals parseMetadata() field by field, both
// formats — including over a reordered FB2 whose binaries precede its
// description. SC-10: the metadata path is cheap in work, asserted on the
// work done rather than timed.

import 'dart:typed_data';

import 'package:ebook_parser/ebook_parser.dart';
import 'package:ebook_parser/src/epub/container_reader.dart';
import 'package:ebook_parser/src/epub/epub_parser.dart';
import 'package:ebook_parser/src/fb2/fb2_parser.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

Future<void> expectMetadataInvariant(
    IBookParser parser, Uint8List bytes) async {
  final parsed = await parser.parse(bytes, fallbackLanguageCode: 'en');
  final meta = await parser.parseMetadata(bytes, fallbackLanguageCode: 'en');
  expect(parsed, isA<ParseOk<BookDocument>>(),
      reason: parsed is ParseErr ? '${(parsed as ParseErr).failure}' : null);
  expect(meta, isA<ParseOk<BookMetadata>>(),
      reason: meta is ParseErr ? '${(meta as ParseErr).failure}' : null);
  final a = (parsed as ParseOk<BookDocument>).value.metadata;
  final b = (meta as ParseOk<BookMetadata>).value;
  expect(b.title, a.title);
  expect(b.authors, a.authors);
  expect(b.sourceLanguageCode, a.sourceLanguageCode);
  expect(b.cover == null, a.cover == null,
      reason: 'one path found a cover the other did not');
  if (a.cover != null) {
    expect(b.cover!.mediaType, a.cover!.mediaType);
    expect(b.cover!.bytes, a.cover!.bytes);
  }
}

void main() {
  group('metadata invariant (SC-13)', () {
    test('EPUB: cover via properties="cover-image"', () async {
      final builder = EpubBuilder(title: 'T', authors: ['A'], language: 'en')
        ..docs.add(EpubDoc('c1.xhtml', '<p>Text.</p>'))
        ..cover = ('cover.png', kTinyPng, 'image/png', 'properties');
      await expectMetadataInvariant(EpubParser(), builder.build());
    });

    test('EPUB: cover via meta name="cover"', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc('c1.xhtml', '<p>Text.</p>'))
        ..cover = ('cover.jpg', kTinyJpeg, 'image/jpeg', 'meta');
      await expectMetadataInvariant(EpubParser(), builder.build());
    });

    test('EPUB: cover via manifest id "cover"', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc('c1.xhtml', '<p>Text.</p>'))
        ..cover = ('cover.jpg', kTinyJpeg, 'image/jpeg', 'id');
      await expectMetadataInvariant(EpubParser(), builder.build());
    });

    test('EPUB: no cover, no title, no language', () async {
      final builder = EpubBuilder(title: null, authors: [], language: null)
        ..docs.add(EpubDoc('c1.xhtml', '<p>Text.</p>'));
      await expectMetadataInvariant(EpubParser(), builder.build());
    });

    test('FB2: cover, authors, language', () async {
      final bytes = fb2Bytes(fb2(
        bookTitle: 'Книга',
        lang: 'ru',
        coverHref: '#cover',
        binariesXml: fb2Binary('cover', kTinyJpeg, contentType: 'image/jpeg'),
      ));
      await expectMetadataInvariant(Fb2Parser(), bytes);
    });

    test('FB2: no cover, nickname author', () async {
      final bytes = fb2Bytes(fb2(
        authorsXml: '<author><nickname>ghost</nickname></author>',
      ));
      await expectMetadataInvariant(Fb2Parser(), bytes);
    });

    test('FB2 reordered: binaries precede the description (DEC-27)',
        () async {
      final reordered = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  ${fb2Binary('cover', kTinyJpeg, contentType: 'image/jpeg')}
  <description>
    <title-info>
      <book-title>Reordered</book-title>
      <author><first-name>Anna</first-name><last-name>Author</last-name></author>
      <lang>en</lang>
      <coverpage><image l:href="#cover"/></coverpage>
    </title-info>
  </description>
  <body><section><p>Text.</p></section></body>
</FictionBook>
''';
      await expectMetadataInvariant(Fb2Parser(), fb2Bytes(reordered));
    });

    test('FB2 in windows-1251 through both paths', () async {
      final document = fb2(
        bookTitle: 'Русское заглавие',
        lang: 'ru',
        coverHref: '#c',
        binariesXml: fb2Binary('c', kTinyJpeg, contentType: 'image/jpeg'),
        bodiesXml: '<body><section><p>Текст.</p></section></body>',
        encodingDeclaration: 'windows-1251',
      );
      await expectMetadataInvariant(Fb2Parser(), fb2BytesCp1251(document));
    });
  });

  group('the metadata path is cheap in work (SC-10)', () {
    test('EPUB parseMetadata reads no spine entry', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc('c1.xhtml', '<p>One.</p>'))
        ..docs.add(EpubDoc('c2.xhtml', '<p>Two.</p>'))
        ..nav.addAll([Nav('One', 'c1.xhtml'), Nav('Two', 'c2.xhtml')])
        ..cover = ('cover.png', kTinyPng, 'image/png', 'properties');
      final bytes = builder.build();
      final reads = <String>[];
      EpubContainer.readProbe = reads.add;
      try {
        final meta = await EpubParser()
            .parseMetadata(bytes, fallbackLanguageCode: 'en');
        expect(meta, isA<ParseOk<BookMetadata>>());
      } finally {
        EpubContainer.readProbe = null;
      }
      expect(
        reads,
        unorderedEquals(
            ['META-INF/container.xml', 'content.opf', 'cover.png']),
        reason: 'the cheap path must not materialise chapter entries',
      );
    });

    test('FB2 parseMetadata stops at the cover and never reaches the body',
        () async {
      // The body after the cover binary is malformed XML: the DOM path
      // refuses the file, while the streaming metadata reader stops before
      // ever seeing it — which is the work assertion.
      final earlyCover = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>Streamed</book-title>
      <author><first-name>Anna</first-name><last-name>Author</last-name></author>
      <lang>en</lang>
      <coverpage><image l:href="#cover"/></coverpage>
    </title-info>
  </description>
  ${fb2Binary('cover', kTinyJpeg, contentType: 'image/jpeg')}
  <body><section><p>Broken <unclosed</p></section></body>
</FictionBook>
''';
      final bytes = fb2Bytes(earlyCover);
      final parser = Fb2Parser();
      final meta =
          await parser.parseMetadata(bytes, fallbackLanguageCode: 'en');
      expect(meta, isA<ParseOk<BookMetadata>>());
      final value = (meta as ParseOk<BookMetadata>).value;
      expect(value.title, 'Streamed');
      expect(value.cover!.bytes, kTinyJpeg);
      final parsed = await parser.parse(bytes, fallbackLanguageCode: 'en');
      expect(parsed, isA<ParseErr<BookDocument>>());
    });

    test('FB2 parseMetadata with no cover stops at the description',
        () async {
      final noCover = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info><book-title>No Cover</book-title><lang>en</lang></title-info>
  </description>
  <body><section><p>Broken <unclosed</p></section></body>
</FictionBook>
''';
      final meta = await Fb2Parser()
          .parseMetadata(fb2Bytes(noCover), fallbackLanguageCode: 'en');
      expect(meta, isA<ParseOk<BookMetadata>>());
      expect((meta as ParseOk<BookMetadata>).value.title, 'No Cover');
    });
  });

  group('covers are returned as stored (DEC-04)', () {
    test('EPUB cover bytes are byte-identical, SVG included', () async {
      final svg = '<svg xmlns="http://www.w3.org/2000/svg"/>'.codeUnits;
      final builder = EpubBuilder()
        ..docs.add(EpubDoc('c1.xhtml', '<p>Text.</p>'))
        ..cover = ('cover.svg', svg, 'image/svg+xml', 'properties');
      final result = await EpubParser()
          .parseMetadata(builder.build(), fallbackLanguageCode: 'en');
      final cover = (result as ParseOk<BookMetadata>).value.cover!;
      expect(cover.mediaType, 'image/svg+xml');
      expect(cover.bytes, svg);
    });

    test('FB2 cover bytes are byte-identical to the decoded binary',
        () async {
      final bytes = fb2Bytes(fb2(
        coverHref: '#c',
        binariesXml: fb2Binary('c', kTinyJpeg, contentType: 'image/jpeg'),
      ));
      final result = await Fb2Parser()
          .parseMetadata(bytes, fallbackLanguageCode: 'en');
      final cover = (result as ParseOk<BookMetadata>).value.cover!;
      expect(cover.mediaType, 'image/jpeg');
      expect(cover.bytes, kTinyJpeg);
    });
  });
}

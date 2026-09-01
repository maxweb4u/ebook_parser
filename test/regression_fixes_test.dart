// Regressions pinned by the post-implementation bug-review passes: each test
// here failed against the code as first written.

import 'dart:convert';
import 'dart:typed_data';

import 'package:ebook_parser/ebook_parser.dart';
import 'package:ebook_parser/src/epub/navigation_reader.dart';
import 'package:ebook_parser/src/epub/xhtml_blocks.dart';
import 'package:ebook_parser/src/fb2/fb2_parser.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

void main() {
  group('FB2 metadata first-wins agreement between the DOM and stream paths', () {
    final doc = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>First Title</book-title>
      <book-title>Second Title</book-title>
      <author><first-name>Anna</first-name><last-name>Author</last-name></author>
      <lang>en</lang>
      <coverpage><image l:href="#a"/><image l:href="#b"/></coverpage>
    </title-info>
  </description>
  <body><section><p>Text.</p></section></body>
  ${fb2Binary('a', kTinyPng)}
  ${fb2Binary('b', kTinyJpeg, contentType: 'image/jpeg')}
</FictionBook>
''';

    test('parse and parseMetadata both take the first book-title and the '
        'first coverpage image', () async {
      final bytes = Uint8List.fromList(fb2Bytes(doc));
      final parser = Fb2Parser();
      final full = await parser.parse(bytes, fallbackLanguageCode: 'en');
      final cheap =
          await parser.parseMetadata(bytes, fallbackLanguageCode: 'en');
      final fullMeta = (full as ParseOk<BookDocument>).value.metadata;
      final cheapMeta = (cheap as ParseOk<BookMetadata>).value;

      expect(fullMeta.title, 'First Title');
      expect(cheapMeta.title, 'First Title');
      expect(fullMeta.cover!.mediaType, 'image/png');
      expect(cheapMeta.cover!.mediaType, 'image/png');
      expect(cheapMeta.cover!.bytes, fullMeta.cover!.bytes);
      expect(fullMeta.cover!.bytes, kTinyPng);
    });
  });

  group('FB2 stream/DOM agreement on structurally unusual input', () {
    Future<(BookMetadata, BookMetadata)> bothPaths(String doc) async {
      final bytes = Uint8List.fromList(fb2Bytes(doc));
      final parser = Fb2Parser();
      final full = await parser.parse(bytes, fallbackLanguageCode: 'en');
      final cheap =
          await parser.parseMetadata(bytes, fallbackLanguageCode: 'en');
      return (
        (full as ParseOk<BookDocument>).value.metadata,
        (cheap as ParseOk<BookMetadata>).value,
      );
    }

    test('a self-closing <title-info/> is the first title-info for both '
        'paths', () async {
      const doc = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info/>
    <title-info><book-title>Ghost</book-title><lang>ru</lang></title-info>
  </description>
  <body><section><p>Text.</p></section></body>
</FictionBook>
''';
      final (dom, stream) = await bothPaths(doc);
      expect(dom.title, isNull);
      expect(stream.title, isNull);
      expect(dom.sourceLanguageCode, 'en');
      expect(stream.sourceLanguageCode, 'en');
    });

    test('only a direct-child <image> of the coverpage is the cover, for '
        'both paths', () async {
      final doc = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>T</book-title>
      <coverpage><wrap><image l:href="#a"/></wrap><image l:href="#b"/></coverpage>
    </title-info>
  </description>
  <body><section><p>Text.</p></section></body>
  ${fb2Binary('a', kTinyJpeg, contentType: 'image/jpeg')}
  ${fb2Binary('b', kTinyPng)}
</FictionBook>
''';
      final (dom, stream) = await bothPaths(doc);
      expect(dom.cover!.mediaType, 'image/png');
      expect(stream.cover!.mediaType, 'image/png');
      expect(stream.cover!.bytes, dom.cover!.bytes);
    });

    test('a cover binary before <description> beats a later duplicate id in '
        'both paths', () async {
      final doc = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  ${fb2Binary('c', kTinyJpeg, contentType: 'image/jpeg')}
  <description>
    <title-info>
      <book-title>T</book-title>
      <coverpage><image l:href="#c"/></coverpage>
    </title-info>
  </description>
  <body><section><p>Text.</p></section></body>
  ${fb2Binary('c', kTinyPng)}
</FictionBook>
''';
      final (dom, stream) = await bothPaths(doc);
      expect(dom.cover!.mediaType, 'image/jpeg');
      expect(stream.cover!.mediaType, 'image/jpeg');
      expect(stream.cover!.bytes, dom.cover!.bytes);
      expect(dom.cover!.bytes, kTinyJpeg);
    });
  });

  group('FB2 self-closing description', () {
    test('a self-closing <description/> is the first description for both '
        'paths', () async {
      final doc = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description/>
  <description>
    <title-info>
      <book-title>Ghost</book-title>
      <author><last-name>Wr</last-name></author>
      <lang>ru</lang>
      <coverpage><image l:href="#c"/></coverpage>
    </title-info>
  </description>
  <body><section><p>Text.</p></section></body>
  ${fb2Binary('c', kTinyPng)}
</FictionBook>
''';
      final bytes = Uint8List.fromList(fb2Bytes(doc));
      final parser = Fb2Parser();
      final full = await parser.parse(bytes, fallbackLanguageCode: 'en');
      final cheap =
          await parser.parseMetadata(bytes, fallbackLanguageCode: 'en');
      final dom = (full as ParseOk<BookDocument>).value.metadata;
      final stream = (cheap as ParseOk<BookMetadata>).value;
      expect(dom.title, isNull);
      expect(stream.title, isNull);
      expect(dom.authors, isEmpty);
      expect(stream.authors, isEmpty);
      expect(dom.cover, isNull);
      expect(stream.cover, isNull);
    });
  });

  group('FB2 nested tables', () {
    test('rows of a nested table are not emitted twice', () async {
      const doc = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description><title-info><book-title>T</book-title></title-info></description>
  <body><section>
    <table><tr><td>Outer <table><tr><td>NESTED</td></tr></table></td><td>B</td></tr></table>
  </section></body>
</FictionBook>
''';
      final bytes = Uint8List.fromList(fb2Bytes(doc));
      final result = await Fb2Parser().parse(bytes, fallbackLanguageCode: 'en');
      final chapters = (result as ParseOk<BookDocument>).value.chapters;
      final texts = [
        for (final chapter in chapters)
          for (final block in chapter.blocks)
            if (block is ParagraphBlock) block.text,
      ];
      expect(texts, ['Outer NESTED B']);
    });
  });

  group('FB2 namespace-prefixed documents', () {
    test('a fully fb:-prefixed document parses with body, authors and '
        'cover', () async {
      final doc = '''
<?xml version="1.0" encoding="utf-8"?>
<fb:FictionBook xmlns:fb="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <fb:description>
    <fb:title-info>
      <fb:book-title>Prefixed</fb:book-title>
      <fb:author><fb:first-name>Ivan</fb:first-name><fb:last-name>Petrov</fb:last-name></fb:author>
      <fb:lang>ru</fb:lang>
      <fb:coverpage><fb:image l:href="#c"/></fb:coverpage>
    </fb:title-info>
  </fb:description>
  <fb:body><fb:section><fb:title><fb:p>One</fb:p></fb:title><fb:p>Text here.</fb:p></fb:section></fb:body>
  <fb:binary id="c" content-type="image/png">${base64Encode(kTinyPng)}</fb:binary>
</fb:FictionBook>
''';
      final bytes = Uint8List.fromList(fb2Bytes(doc));
      final parser = Fb2Parser();
      final full = await parser.parse(bytes, fallbackLanguageCode: 'en');
      final cheap =
          await parser.parseMetadata(bytes, fallbackLanguageCode: 'en');
      final dom = (full as ParseOk<BookDocument>).value;
      final stream = (cheap as ParseOk<BookMetadata>).value;

      expect(dom.chapters, isNotEmpty);
      expect(dom.metadata.title, 'Prefixed');
      expect(stream.title, 'Prefixed');
      expect(dom.metadata.authors, ['Ivan Petrov']);
      expect(stream.authors, ['Ivan Petrov']);
      expect(dom.metadata.cover!.bytes, kTinyPng);
      expect(stream.cover!.bytes, dom.metadata.cover!.bytes);
    });
  });

  group('FB2 attribute and payload edge cases', () {
    Future<(BookMetadata, BookMetadata)> bothPaths(String doc) async {
      final bytes = Uint8List.fromList(fb2Bytes(doc));
      final parser = Fb2Parser();
      final full = await parser.parse(bytes, fallbackLanguageCode: 'en');
      final cheap =
          await parser.parseMetadata(bytes, fallbackLanguageCode: 'en');
      return (
        (full as ParseOk<BookDocument>).value.metadata,
        (cheap as ParseOk<BookMetadata>).value,
      );
    }

    test('the first href attribute of the cover image decides, even a '
        'non-local one', () async {
      final doc = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>T</book-title>
      <coverpage><image href="cover.png" l:href="#c"/></coverpage>
    </title-info>
  </description>
  <body><section><p>Text.</p></section></body>
  ${fb2Binary('c', kTinyPng)}
</FictionBook>
''';
      final (dom, stream) = await bothPaths(doc);
      expect(dom.cover, isNull);
      expect(stream.cover, isNull);
    });

    test('an xml:id on a binary is not its id, on either path', () async {
      final doc = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  <description>
    <title-info>
      <book-title>T</book-title>
      <coverpage><image l:href="#c"/></coverpage>
    </title-info>
  </description>
  <body><section><p>Text.</p></section></body>
  <binary xml:id="c" content-type="image/png">${base64Encode(kTinyPng)}</binary>
</FictionBook>
''';
      final (dom, stream) = await bothPaths(doc);
      expect(dom.cover, isNull);
      expect(stream.cover, isNull);
    });

    test('a stray child element inside the cover binary contributes its '
        'text, before and after the description', () async {
      const payload = 'QUFB<z>QkJC</z>Q0ND'; // AAA BBB CCC once concatenated
      for (final binaryFirst in [true, false]) {
        final binary =
            '<binary id="c" content-type="image/png">$payload</binary>';
        final doc = '''
<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0" xmlns:l="http://www.w3.org/1999/xlink">
  ${binaryFirst ? binary : ''}
  <description>
    <title-info>
      <book-title>T</book-title>
      <coverpage><image l:href="#c"/></coverpage>
    </title-info>
  </description>
  <body><section><p>Text.</p></section></body>
  ${binaryFirst ? '' : binary}
</FictionBook>
''';
        final (dom, stream) = await bothPaths(doc);
        final expected = utf8.encode('AAABBBCCC');
        expect(dom.cover!.bytes, expected,
            reason: 'DOM, binaryFirst=$binaryFirst');
        expect(stream.cover!.bytes, expected,
            reason: 'stream, binaryFirst=$binaryFirst');
      }
    });

    test('rootless input is corrupt on both paths; a wrong root is '
        'unsupportedFormat on both', () async {
      final parser = Fb2Parser();
      final rootless = Uint8List.fromList(utf8.encode('just some text'));
      final fullR = await parser.parse(rootless, fallbackLanguageCode: 'en');
      final cheapR =
          await parser.parseMetadata(rootless, fallbackLanguageCode: 'en');
      expect((fullR as ParseErr).failure.kind, ParseFailureKind.corrupt);
      expect((cheapR as ParseErr).failure.kind, ParseFailureKind.corrupt);

      final wrongRoot =
          Uint8List.fromList(utf8.encode('<?xml version="1.0"?><html/>'));
      final fullW = await parser.parse(wrongRoot, fallbackLanguageCode: 'en');
      final cheapW =
          await parser.parseMetadata(wrongRoot, fallbackLanguageCode: 'en');
      expect(
        (fullW as ParseErr).failure.kind,
        ParseFailureKind.unsupportedFormat,
      );
      expect(
        (cheapW as ParseErr).failure.kind,
        ParseFailureKind.unsupportedFormat,
      );
    });
  });

  group('FB2 encoding declaration', () {
    test('encoding="..." inside content does not hijack the codec', () async {
      // The prolog declares no encoding, so the file is UTF-8 by default;
      // the strings inside the content must not change that.
      const doc = '''
<?xml version="1.0"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <book-title>Книга про encoding="windows-1251" и разбор</book-title>
      <lang>ru</lang>
    </title-info>
  </description>
  <body><section>
    <p>Текст, где встречается encoding="shift_jis" как слова.</p>
  </section></body>
</FictionBook>
''';
      final bytes = Uint8List.fromList(fb2Bytes(doc));
      final parser = Fb2Parser();
      final full = await parser.parse(bytes, fallbackLanguageCode: 'en');
      expect(full, isA<ParseOk<BookDocument>>());
      final metadata = (full as ParseOk<BookDocument>).value.metadata;
      expect(metadata.title, 'Книга про encoding="windows-1251" и разбор');
    });

    test('an <?xml-stylesheet?> pseudo-attribute does not pick the codec',
        () async {
      const doc = '''
<?xml-stylesheet type="text/xsl" href="s.xsl" encoding="windows-1251"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info><book-title>Привет</book-title><lang>ru</lang></title-info>
  </description>
  <body><section><p>Текст.</p></section></body>
</FictionBook>
''';
      final bytes = Uint8List.fromList(fb2Bytes(doc));
      final full = await Fb2Parser().parse(bytes, fallbackLanguageCode: 'en');
      expect(full, isA<ParseOk<BookDocument>>());
      final metadata = (full as ParseOk<BookDocument>).value.metadata;
      expect(metadata.title, 'Привет');
    });
  });

  group('EPUB 3 navigation with multi-token epub:type', () {
    test('a toc nav also typed frontmatter is still the toc nav', () {
      const nav = '''
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>nav</title></head>
<body>
  <nav epub:type="landmarks bodymatter">
    <ol><li><a epub:type="toc other" href="toc.xhtml">Contents</a></li></ol>
  </nav>
  <nav epub:type="toc frontmatter">
    <ol><li><a href="ch1.xhtml">Chapter 1</a></li></ol>
  </nav>
</body></html>
''';
      final navigation = readNavDoc(nav, '');
      expect(navigation.entries, hasLength(1));
      expect(navigation.entries.single.label, 'Chapter 1');
      expect(navigation.entries.single.path, 'ch1.xhtml');
      expect(navigation.tocDeclaredPaths, ['toc.xhtml']);
    });
  });

  group('table captions', () {
    test('caption text is kept and its id is an anchor', () {
      const xhtml = '<html><body><table>'
          '<caption id="cap">Cap text</caption>'
          '<tr><td>A</td></tr>'
          '</table></body></html>';
      final parsed = blocksFromXhtml(
        xhtml,
        segmenter: const RuleBasedSegmenter(),
      );
      final texts = [
        for (final block in parsed.blocks)
          if (block is ParagraphBlock) block.text,
      ];
      expect(texts, ['Cap text', 'A']);
      expect(parsed.anchors['cap'], 0);
    });
  });

  group('table structure anchors', () {
    test('ids on row groups and columns are recorded anchors', () {
      const xhtml = '<html><body><table>'
          '<caption id="cap">C</caption>'
          '<colgroup id="cols"><col id="col1"/></colgroup>'
          '<thead id="head"><tr><td>H</td></tr></thead>'
          '<tbody id="data"><tr><td>row1</td></tr><tr><td>row2</td></tr></tbody>'
          '</table></body></html>';
      final parsed = blocksFromXhtml(
        xhtml,
        segmenter: const RuleBasedSegmenter(),
      );
      // caption=0, head row=1, data rows=2..3
      expect(parsed.anchors['cap'], 0);
      expect(parsed.anchors['cols'], 1);
      expect(parsed.anchors['col1'], 1);
      expect(parsed.anchors['head'], 1);
      expect(parsed.anchors['data'], 2);
    });
  });

  group('self-closing rcdata with ">" in an attribute value', () {
    test('a quoted ">" does not stop the expansion', () {
      const xhtml = '<html><head><title data-x="a>b"/></head>'
          '<body><p>content</p></body></html>';
      final parsed = blocksFromXhtml(
        xhtml,
        segmenter: const RuleBasedSegmenter(),
      );
      final texts = [
        for (final block in parsed.blocks)
          if (block is ParagraphBlock) block.text,
      ];
      expect(texts, ['content']);
    });
  });

  group('block boundaries inside flattened text', () {
    test('compact markup does not fuse words across block children', () {
      const xhtml = '<html><body>'
          '<h2>Alpha<div>Beta</div></h2>'
          '<table><tr><td><p>One</p><p>Two</p></td></tr></table>'
          '<table><tr><td>Out<table><tr><td>In1</td><td>In2</td></tr>'
          '<tr><td>In3</td></tr></table></td></tr></table>'
          '</body></html>';
      final parsed = blocksFromXhtml(
        xhtml,
        segmenter: const RuleBasedSegmenter(),
      );
      final texts = [
        for (final block in parsed.blocks)
          if (block is ParagraphBlock)
            block.text
          else if (block is HeadingBlock)
            block.text,
      ];
      expect(texts, ['Alpha Beta', 'One Two', 'Out In1 In2 In3']);
    });
  });

  group('nested tables', () {
    test('rows of a nested table are not emitted twice', () {
      const xhtml = '''
<html><body>
  <table>
    <tr><td>Outer A</td><td><table><tr><td>Inner</td></tr></table></td></tr>
    <tr><td>Outer B</td></tr>
  </table>
</body></html>
''';
      final parsed = blocksFromXhtml(
        xhtml,
        segmenter: const RuleBasedSegmenter(),
      );
      final texts = [
        for (final block in parsed.blocks)
          if (block is ParagraphBlock) block.text,
      ];
      // "Inner" appears once, flattened into the outer row's paragraph.
      expect(texts, ['Outer A Inner', 'Outer B']);
    });
  });

  group('list items', () {
    test('an id on a <li> is a recorded anchor', () {
      const xhtml = '<html><body><ol>'
          '<li id="rule1">First rule.</li>'
          '<li id="rule2">Second rule.</li>'
          '</ol></body></html>';
      final parsed = blocksFromXhtml(
        xhtml,
        segmenter: const RuleBasedSegmenter(),
      );
      expect(parsed.anchors['rule1'], 0);
      expect(parsed.anchors['rule2'], 1);
    });

    test('a non-li child of a list keeps its text', () {
      const xhtml = '<html><body><ul>'
          '<li>one</li>'
          '<div><p>stray text</p></div>'
          '<li>two</li>'
          '</ul></body></html>';
      final parsed = blocksFromXhtml(
        xhtml,
        segmenter: const RuleBasedSegmenter(),
      );
      final texts = [
        for (final block in parsed.blocks)
          if (block is ParagraphBlock) block.text,
      ];
      expect(texts, ['one', 'stray text', 'two']);
    });
  });

  group('percent-encoded anchor fragments', () {
    test('an encoded fragment still splits at its non-ASCII id', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
          'c.xhtml',
          '<h1 id="one">Глава первая</h1><p>Первый текст.</p>'
          '<h1 id="гл2">Глава вторая</h1><p>Второй текст.</p>',
        ))
        ..nav.addAll([
          Nav('Первая', 'c.xhtml#one'),
          Nav('Вторая', 'c.xhtml#%D0%B3%D0%BB2'),
        ]);
      final bytes = builder.build();
      final result = await bookParserFor('book.epub', bytes)!
          .parse(bytes, fallbackLanguageCode: 'ru');
      final doc = (result as ParseOk<BookDocument>).value;
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[1].title, 'Вторая');
      expect(doc.chapters[1].blocks, hasLength(2));
    });
  });

  group('CJK closing marks', () {
    test('an opening 【 starts the next sentence rather than closing the '
        'previous one', () {
      const segmenter = RuleBasedSegmenter(languageCode: 'zh');
      final sentences = segmenter.segment('第一句。【第二句】');
      expect(sentences, hasLength(2));
      expect(sentences[0].text, '第一句。');
      expect(sentences[1].text, '【第二句】');
    });
  });
}

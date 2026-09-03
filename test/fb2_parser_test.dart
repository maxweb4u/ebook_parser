// The FB2 reader against constructed documents: SC-01, SC-04, SC-09, SC-14,
// SC-15, and the encoding table.

import 'dart:typed_data';

import 'package:ebook_parser/ebook_parser.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

Future<BookDocument> parseFb2(String document, {String fallback = 'en'}) =>
    parseFb2Bytes(fb2Bytes(document), fallback: fallback);

Future<BookDocument> parseFb2Bytes(List<int> bytes,
    {String fallback = 'en'}) async {
  final input = Uint8List.fromList(bytes);
  final result = await bookParserFor('book.fb2', input)!
      .parse(input, fallbackLanguageCode: fallback);
  expect(result, isA<ParseOk<BookDocument>>(),
      reason: result is ParseErr<BookDocument>
          ? 'parse failed: ${result.failure}'
          : null);
  return (result as ParseOk<BookDocument>).value;
}

void main() {
  group('happy path (SC-01)', () {
    test('title, authors, chapters and first paragraph match', () async {
      final doc = await parseFb2(fb2(
        bookTitle: 'Заглавие',
        authorsXml: '<author><first-name>Антон</first-name>'
            '<middle-name>Павлович</middle-name>'
            '<last-name>Чехов</last-name></author>',
        lang: 'ru',
        bodiesXml: '<body><section><title><p>Глава первая</p></title>'
            '<p>Первый абзац.</p><p>Второй абзац.</p></section>'
            '<section><title><p>Глава вторая</p></title>'
            '<p>Третий абзац.</p></section></body>',
      ));
      expect(doc.metadata.title, 'Заглавие');
      expect(doc.metadata.authors, ['Антон Павлович Чехов']);
      expect(doc.metadata.sourceLanguageCode, 'ru');
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[0].title, 'Глава первая');
      // The FB2 <title> becomes both the chapter title and a heading block.
      expect(doc.chapters[0].blocks.first, isA<HeadingBlock>());
      expect(
        (doc.chapters[0].blocks[1] as ParagraphBlock).text,
        'Первый абзац.',
      );
    });

    test('several authors and a nickname fallback', () async {
      final doc = await parseFb2(fb2(
        authorsXml: '<author><first-name>Anna</first-name>'
            '<last-name>Author</last-name></author>'
            '<author><nickname>ghost</nickname></author>',
      ));
      expect(doc.metadata.authors, ['Anna Author', 'ghost']);
    });

    test('no declared language receives the fallback (SC-04)', () async {
      final doc = await parseFb2(fb2(lang: null), fallback: 'uk');
      expect(doc.metadata.sourceLanguageCode, 'uk');
    });

    test('a missing title stays null', () async {
      final doc = await parseFb2(fb2(bookTitle: null));
      expect(doc.metadata.title, isNull);
    });
  });

  group('nested sections flatten with level (SC-15)', () {
    test('a nested section becomes its own chapter one level deeper',
        () async {
      final doc = await parseFb2(fb2(
        bodiesXml: '<body>'
            '<section><title><p>Part I</p></title>'
            '<p>Part intro.</p>'
            '<section><title><p>Chapter 1</p></title><p>Text one.</p></section>'
            '<section><title><p>Chapter 2</p></title><p>Text two.</p></section>'
            '</section></body>',
      ));
      expect(doc.chapters.map((c) => c.title),
          ['Part I', 'Chapter 1', 'Chapter 2']);
      expect(doc.chapters.map((c) => c.level), [0, 1, 1]);
      expect(doc.chapters.map((c) => c.index), [0, 1, 2]);
    });

    test('a part section with only a title still yields its chapter',
        () async {
      final doc = await parseFb2(fb2(
        bodiesXml: '<body>'
            '<section><title><p>Part I</p></title>'
            '<section><title><p>Chapter 1</p></title><p>Text.</p></section>'
            '</section></body>',
      ));
      // The part's <title> produces a heading block, so the chapter is not
      // empty and survives.
      expect(doc.chapters.map((c) => c.title), ['Part I', 'Chapter 1']);
    });
  });

  group('flattened constructs (SC-14)', () {
    test('verse: stanzas become paragraphs with newline-joined lines',
        () async {
      final doc = await parseFb2(fb2(
        bodiesXml: '<body><section>'
            '<poem><title><p>Song</p></title>'
            '<stanza><v>Line one</v><v>Line two</v></stanza>'
            '<stanza><v>Line three</v></stanza></poem>'
            '</section></body>',
      ));
      final blocks = doc.chapters.single.blocks;
      expect(blocks[0], isA<HeadingBlock>());
      expect((blocks[1] as ParagraphBlock).text, 'Line one\nLine two');
      expect((blocks[2] as ParagraphBlock).text, 'Line three');
    });

    test('tables, citations and epigraphs flatten to paragraphs in order',
        () async {
      final doc = await parseFb2(fb2(
        bodiesXml: '<body><section>'
            '<epigraph><p>Epigraph text.</p>'
            '<text-author>Someone</text-author></epigraph>'
            '<cite><p>Quoted.</p></cite>'
            '<table><tr><td>A1</td><td>B1</td></tr>'
            '<tr><td>A2</td><td>B2</td></tr></table>'
            '<p>Body.</p>'
            '</section></body>',
      ));
      final texts = doc.chapters.single.blocks
          .whereType<ParagraphBlock>()
          .map((p) => p.text)
          .toList();
      expect(texts,
          ['Epigraph text.', 'Someone', 'Quoted.', 'A1 B1', 'A2 B2', 'Body.']);
    });

    test('subtitles become headings below the section title', () async {
      final doc = await parseFb2(fb2(
        bodiesXml: '<body><section><title><p>Chapter</p></title>'
            '<subtitle>Part break</subtitle><p>Text.</p></section></body>',
      ));
      final headings =
          doc.chapters.single.blocks.whereType<HeadingBlock>().toList();
      expect(headings.map((h) => h.text), ['Chapter', 'Part break']);
      expect(headings[1].level, greaterThan(headings[0].level));
    });

    test('inline markup keeps its text, links keep text and drop targets',
        () async {
      final doc = await parseFb2(fb2(
        bodiesXml: '<body><section>'
            '<p>Text with <emphasis>emphasis</emphasis> and '
            '<a l:href="#note1">a link<sup>1</sup></a>.</p>'
            '</section></body>',
      ));
      expect(
        (doc.chapters.single.blocks.single as ParagraphBlock).text,
        'Text with emphasis and a link1.',
      );
    });

    test('empty-line is dropped', () async {
      final doc = await parseFb2(fb2(
        bodiesXml:
            '<body><section><p>One.</p><empty-line/><p>Two.</p></section></body>',
      ));
      expect(doc.chapters.single.blocks, hasLength(2));
    });

    test('note bodies become trailing chapters (SC-14)', () async {
      final doc = await parseFb2(fb2(
        bodiesXml: '<body><section><title><p>Main</p></title>'
            '<p>Story text.</p></section></body>'
            '<body name="notes">'
            '<section><title><p>1</p></title><p>Note text.</p></section>'
            '</body>',
      ));
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[1].title, '1');
      expect(
        (doc.chapters[1].blocks[1] as ParagraphBlock).text,
        'Note text.',
      );
    });

    test('body-level content outside sections is preserved', () async {
      final doc = await parseFb2(fb2(
        bodiesXml: '<body><title><p>The Book</p></title>'
            '<epigraph><p>Motto.</p></epigraph>'
            '<section><p>Text.</p></section></body>',
      ));
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[0].title, 'The Book');
      expect(
        doc.chapters[0].blocks.whereType<ParagraphBlock>().single.text,
        'Motto.',
      );
    });
  });

  group('inline images (SC-09)', () {
    test('images resolve to binaries in document order with media types',
        () async {
      final doc = await parseFb2(fb2(
        bodiesXml: '<body><section><p>Before.</p>'
            '<image l:href="#pic1"/>'
            '<p>After.</p>'
            '<image l:href="#pic2"/>'
            '</section></body>',
        binariesXml: fb2Binary('pic1', kTinyPng) +
            fb2Binary('pic2', kTinyJpeg, contentType: 'image/jpeg'),
      ));
      final blocks = doc.chapters.single.blocks;
      expect(blocks.map((b) => b.runtimeType.toString()),
          ['ParagraphBlock', 'ImageBlock', 'ParagraphBlock', 'ImageBlock']);
      expect((blocks[1] as ImageBlock).image.mediaType, 'image/png');
      expect((blocks[1] as ImageBlock).image.bytes, kTinyPng);
      expect((blocks[3] as ImageBlock).image.mediaType, 'image/jpeg');
    });

    test('an unresolvable image is skipped (NEG-02)', () async {
      final doc = await parseFb2(fb2(
        bodiesXml: '<body><section><p>Text.</p>'
            '<image l:href="#missing"/></section></body>',
      ));
      expect(doc.chapters.single.blocks, hasLength(1));
    });
  });

  group('encodings', () {
    test('windows-1251 declared and encoded parses identically', () async {
      final document = fb2(
        bookTitle: 'Русская книга',
        lang: 'ru',
        bodiesXml: '<body><section><p>Привет, мир.</p></section></body>',
        encodingDeclaration: 'windows-1251',
      );
      final doc = await parseFb2Bytes(fb2BytesCp1251(document));
      expect(doc.metadata.title, 'Русская книга');
      expect(
        (doc.chapters.single.blocks.single as ParagraphBlock).text,
        'Привет, мир.',
      );
    });

    test('a UTF-8 BOM is tolerated', () async {
      final bytes = fb2Bytes(fb2());
      final withBom = [0xEF, 0xBB, 0xBF, ...bytes];
      final doc = await parseFb2Bytes(withBom);
      expect(doc.metadata.title, 'Test FB2');
    });

    test('a declared but unsupported encoding returns ParseErr(encoding)',
        () async {
      final bytes = fb2Bytes(fb2(encodingDeclaration: 'ibm866'));
      final result = await bookParserFor('book.fb2', bytes)!
          .parse(bytes, fallbackLanguageCode: 'en');
      expect(result, isA<ParseErr<BookDocument>>());
      expect(
        (result as ParseErr).failure.kind,
        ParseFailureKind.encoding,
      );
    });
  });

  // D-1: a lenient UTF-8 decode of legacy Cyrillic bytes succeeds while
  // replacing every letter, so the book came back as ParseOk with a body of
  // U+FFFD. Recovery is by decode, not by declaration; the three corpus
  // variants these mirror had no test naming them.
  group('a UTF-8 declaration that the bytes contradict', () {
    test('windows-1251 bytes labelled utf-8 are recovered', () async {
      final bytes = fb2BytesCp1251(_russianFb2());
      final doc = await parseFb2Bytes(bytes);
      expect(doc.metadata.title, _russianTitle);
      expect(_textOf(doc), contains(_russianOpening));
      expect(_textOf(doc), isNot(contains('\uFFFD')));
    });

    test('windows-1251 bytes with no declaration at all are recovered',
        () async {
      final bytes = fb2BytesCp1251(_undeclared(_russianFb2()));
      final doc = await parseFb2Bytes(bytes);
      expect(doc.metadata.title, _russianTitle);
      expect(_textOf(doc), isNot(contains('\uFFFD')));
    });

    test('koi8-r bytes labelled utf-8 are recovered as koi8-r, not cp1251',
        () async {
      final bytes = fb2BytesKoi8r(_russianFb2());
      final doc = await parseFb2Bytes(bytes);
      // Read through windows-1251 the same bytes decode without a single
      // replacement character, so only the case heuristic separates them:
      // the wrong codec would have returned the title in capitals.
      expect(doc.metadata.title, _russianTitle);
      expect(_textOf(doc), contains(_russianOpening));
    });

    test('genuine utf-8 with a damaged run keeps its lenient decode', () async {
      // The recovery must not fire on a real UTF-8 file that lost a few
      // bytes: re-reading it as windows-1251 would turn a book with three
      // broken characters into a book of mojibake.
      final bytes = fb2Bytes(_russianFb2()).toList();
      for (final at in [bytes.length ~/ 2, bytes.length ~/ 2 + 1]) {
        bytes[at] = 0xC3;
      }
      final doc = await parseFb2Bytes(bytes);
      expect(doc.metadata.title, _russianTitle);
      expect(_textOf(doc), contains(_russianOpening));
      expect(_textOf(doc), contains('\uFFFD'));
    });
  });
}

// No `№`: koi8-r has no code point for it, and the fixture has to survive
// every codec the recovery may pick.
const _russianTitle = 'Палата номер шесть';
const _russianOpening = 'В больничном дворе стоит небольшой флигель';

/// A Russian FB2 long enough that a wrong decode is unmistakable: the damage
/// ratio has to clear the threshold by a wide margin for the test to be
/// measuring the rule rather than the fixture's length.
String _russianFb2() {
  const paragraph = '<p>В больничном дворе стоит небольшой флигель, окружённый '
      'целым лесом репейника, крапивы и дикой конопли. Крыша на нём ржавая, '
      'труба наполовину обвалилась, ступеньки у крыльца сгнили и поросли '
      'травою, а от штукатурки остались одни только следы.</p>';
  return fb2(
    bookTitle: _russianTitle,
    lang: 'ru',
    bodiesXml: '<body><section>${paragraph * 5}</section></body>',
  );
}

/// Strips the `encoding=` pseudo-attribute, leaving a prolog that declares
/// nothing — the case `_codecForEncoding` also answers UTF-8 for.
String _undeclared(String document) => document.replaceFirst(
      '<?xml version="1.0" encoding="utf-8"?>',
      '<?xml version="1.0"?>',
    );

String _textOf(BookDocument doc) => doc.chapters
    .expand((c) => c.blocks)
    .whereType<ParagraphBlock>()
    .map((b) => b.text)
    .join('\n');

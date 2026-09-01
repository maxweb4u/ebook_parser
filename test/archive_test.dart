// SC-19: every ArchiveContent case reachable and distinguishable.
// SC-02: a .fb2.zip produces the same result as the same book unpacked.

import 'dart:convert';
import 'dart:typed_data';

import 'package:ebook_parser/ebook_parser.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

void main() {
  final fb2Doc = fb2(
    bodiesXml: '<body><section><title><p>Глава</p></title>'
        '<p>Первое предложение. Второе предложение.</p></section></body>',
  );

  group('inspectBookArchive (SC-19)', () {
    test('a plain .fb2 is NotAnArchive', () {
      expect(inspectBookArchive(fb2Bytes(fb2Doc)), isA<NotAnArchive>());
    });

    test('an EPUB is EpubArchive', () {
      final epub = (EpubBuilder()..docs.add(EpubDoc('c1.xhtml', '<p>x</p>')))
          .build();
      expect(isZipArchive(epub), isTrue);
      expect(inspectBookArchive(epub), isA<EpubArchive>());
    });

    test('a one-book zip is WrappedBook naming the entry', () {
      final zip = buildZip({'book.fb2': fb2Bytes(fb2Doc)});
      final content = inspectBookArchive(zip);
      expect(content, isA<WrappedBook>());
      final wrapped = content as WrappedBook;
      expect(wrapped.name, 'book.fb2');
      expect(utf8.decode(wrapped.bytes), fb2Doc);
    });

    test('junk entries do not make a wrapped book ambiguous', () {
      final zip = buildZip({
        'book.fb2': fb2Bytes(fb2Doc),
        '__MACOSX/book.fb2': [1, 2, 3],
        '.hidden.fb2': [1, 2, 3],
        'readme.txt': utf8.encode('hello'),
      });
      final content = inspectBookArchive(zip);
      expect(content, isA<WrappedBook>());
      expect((content as WrappedBook).name, 'book.fb2');
    });

    test('a zip of unrelated files is NoBookInside', () {
      final zip = buildZip({
        'readme.txt': utf8.encode('no books here'),
        'data.json': utf8.encode('{}'),
      });
      expect(inspectBookArchive(zip), isA<NoBookInside>());
    });

    test('a zip of three books is SeveralBooksInside listing all three', () {
      final zip = buildZip({
        'a.fb2': fb2Bytes(fb2Doc),
        'b.fb2': fb2Bytes(fb2Doc),
        'sub/c.fb2': fb2Bytes(fb2Doc),
      });
      final content = inspectBookArchive(zip);
      expect(content, isA<SeveralBooksInside>());
      expect(
        (content as SeveralBooksInside).names,
        unorderedEquals(['a.fb2', 'b.fb2', 'c.fb2']),
      );
    });

    test('random bytes are NotAnArchive', () {
      expect(
        inspectBookArchive(Uint8List.fromList(List.filled(64, 0x41))),
        isA<NotAnArchive>(),
      );
    });
  });

  group('transparent .fb2.zip routing (SC-02)', () {
    test('a .fb2.zip parses identically to the unpacked .fb2', () async {
      final plain = fb2Bytes(fb2Doc);
      final zipped = buildZip({'book.fb2': plain});

      final plainParser = bookParserFor('book.fb2', plain)!;
      final zippedParser = bookParserFor('book.fb2.zip', zipped)!;

      final plainDoc = (await plainParser.parse(plain,
              fallbackLanguageCode: 'en')) as ParseOk<BookDocument>;
      final zippedDoc = (await zippedParser.parse(zipped,
              fallbackLanguageCode: 'en')) as ParseOk<BookDocument>;

      expect(
        zippedDoc.value.chapters.length,
        plainDoc.value.chapters.length,
      );
      for (var i = 0; i < plainDoc.value.chapters.length; i++) {
        final a = plainDoc.value.chapters[i];
        final b = zippedDoc.value.chapters[i];
        expect(b.title, a.title);
        expect(b.level, a.level);
        expect(b.blocks.length, a.blocks.length);
        for (var j = 0; j < a.blocks.length; j++) {
          final ba = a.blocks[j];
          final bb = b.blocks[j];
          expect(bb.runtimeType, ba.runtimeType);
          if (ba is ParagraphBlock) {
            expect((bb as ParagraphBlock).text, ba.text);
          }
        }
      }
      expect(zippedDoc.value.metadata.title, plainDoc.value.metadata.title);
    });

    test('parseMetadata on a wrapped book equals the unwrapped one', () async {
      final plain = fb2Bytes(fb2Doc);
      final zipped = buildZip({'book.fb2': plain});
      final plainMeta = (await bookParserFor('book.fb2', plain)!
              .parseMetadata(plain, fallbackLanguageCode: 'en'))
          as ParseOk<BookMetadata>;
      final zippedMeta = (await bookParserFor('book.zip', zipped)!
              .parseMetadata(zipped, fallbackLanguageCode: 'en'))
          as ParseOk<BookMetadata>;
      expect(zippedMeta.value.title, plainMeta.value.title);
      expect(zippedMeta.value.authors, plainMeta.value.authors);
      expect(
        zippedMeta.value.sourceLanguageCode,
        plainMeta.value.sourceLanguageCode,
      );
    });

    test('an ambiguous zip yields no parser from bookParserFor', () {
      final several = buildZip({
        'a.fb2': fb2Bytes(fb2Doc),
        'b.fb2': fb2Bytes(fb2Doc),
      });
      expect(bookParserFor('books.zip', several), isNull);
      final none = buildZip({'readme.txt': utf8.encode('x')});
      expect(bookParserFor('stuff.zip', none), isNull);
    });
  });
}

// Golden files from real producers: EPUB 2 with an NCX (Project Gutenberg),
// EPUB 3 with a nav document (Project Gutenberg), and FB2 in windows-1251.
// A constructed sample confirms only what we already believed about the
// format; these do not.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ebook_parser/ebook_parser.dart';
import 'package:test/test.dart';

Uint8List fixture(String name) =>
    Uint8List.fromList(File('test/fixtures/$name').readAsBytesSync());

Future<BookDocument> parseOk(Uint8List bytes, String name) async {
  final result = await bookParserFor(name, bytes)!
      .parse(bytes, fallbackLanguageCode: 'en');
  expect(result, isA<ParseOk<BookDocument>>(),
      reason: result is ParseErr ? '${(result as ParseErr).failure}' : null);
  return (result as ParseOk<BookDocument>).value;
}

void main() {
  group('EPUB 2 with NCX: Alice in Wonderland', () {
    late final bytes = fixture('alice-epub2-ncx.epub');

    test('parses with known metadata and structure', () async {
      final doc = await parseOk(bytes, 'alice-epub2-ncx.epub');
      expect(doc.metadata.title, "Alice's Adventures in Wonderland");
      expect(doc.metadata.authors, ['Lewis Carroll']);
      expect(doc.metadata.sourceLanguageCode, 'en');
      expect(doc.chapters.length, greaterThanOrEqualTo(12));
      // Navigation supplies titles; the twelve chapter labels are among
      // them.
      final titles = doc.chapters.map((c) => c.title).whereType<String>();
      expect(titles.where((t) => t.contains('Down the Rabbit')), isNotEmpty);
      // Chapter indexes are dense.
      for (var i = 0; i < doc.chapters.length; i++) {
        expect(doc.chapters[i].index, i);
      }
    });

    test('cover bytes are byte-identical to the archive entry (DEC-04)',
        () async {
      final doc = await parseOk(bytes, 'alice-epub2-ncx.epub');
      final cover = doc.metadata.cover;
      expect(cover, isNotNull);
      final archive = ZipDecoder().decodeBytes(bytes);
      final entry = archive.singleWhere(
        (f) => f.isFile && f.content.length == cover!.bytes.length,
      );
      expect(cover!.bytes, entry.content);
    });
  });

  group('EPUB 3 with nav: 三字經', () {
    late final bytes = fixture('sanzijing-epub3-nav.epub');

    test('parses with the declared language and nav titles', () async {
      final doc = await parseOk(bytes, 'sanzijing-epub3-nav.epub');
      expect(doc.metadata.title, '三字經');
      expect(doc.metadata.sourceLanguageCode, 'zh');
      expect(doc.chapters, isNotEmpty);
      expect(doc.chapters.map((c) => c.title).whereType<String>(),
          isNotEmpty);
      // CJK text segments: some paragraph yields sentences with
      // per-ideograph words.
      final paragraph = doc.chapters
          .expand((c) => c.blocks)
          .whereType<ParagraphBlock>()
          .firstWhere((p) => p.text.contains('人之初'));
      expect(paragraph.sentences, isNotEmpty);
      expect(paragraph.sentences.first.words, isNotEmpty);
    });
  });

  group('FB2 in windows-1251: Чехов', () {
    late final bytes = fixture('chekhov-cp1251.fb2');

    test('parses with decoded Cyrillic metadata and text', () async {
      final doc = await parseOk(bytes, 'chekhov-cp1251.fb2');
      expect(doc.metadata.title, 'Палата № 6');
      expect(doc.metadata.authors, ['Антон Павлович Чехов']);
      expect(doc.metadata.sourceLanguageCode, 'ru');
      expect(doc.chapters, isNotEmpty);
      expect(doc.bodySample(maxChars: 200), contains('флигель'));
    });

    test('cover bytes are byte-identical to the stored binary (DEC-04)',
        () async {
      final doc = await parseOk(bytes, 'chekhov-cp1251.fb2');
      final cover = doc.metadata.cover;
      expect(cover, isNotNull);
      // The binary payload as the file stores it, decoded independently.
      final text = String.fromCharCodes(bytes);
      final match = RegExp(
        r'<binary[^>]*>([A-Za-z0-9+/=\s]+)</binary>',
      ).firstMatch(text)!;
      final stored =
          base64Decode(match.group(1)!.replaceAll(RegExp(r'\s'), ''));
      expect(cover!.bytes, stored);
    });

    test('metadata invariant holds on a real file (SC-13)', () async {
      final parser = bookParserFor('chekhov-cp1251.fb2', bytes)!;
      final doc = await parseOk(bytes, 'chekhov-cp1251.fb2');
      final meta = (await parser.parseMetadata(bytes,
          fallbackLanguageCode: 'en')) as ParseOk<BookMetadata>;
      expect(meta.value.title, doc.metadata.title);
      expect(meta.value.authors, doc.metadata.authors);
      expect(
          meta.value.sourceLanguageCode, doc.metadata.sourceLanguageCode);
      expect(meta.value.cover!.bytes, doc.metadata.cover!.bytes);
    });
  });
}

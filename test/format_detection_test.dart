// SC-03: a file whose extension is wrong or absent is routed by magic bytes.

import 'dart:typed_data';

import 'package:ebook_parser/ebook_parser.dart';
import 'package:ebook_parser/src/epub/epub_parser.dart';
import 'package:ebook_parser/src/fb2/fb2_parser.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

void main() {
  final epubBytes =
      (EpubBuilder()..docs.add(EpubDoc('c1.xhtml', '<p>x</p>'))).build();
  final fb2Doc = fb2Bytes(fb2());

  test('the extension lists differ by the transport wrapper only', () {
    expect(supportedBookExtensions, ['epub', 'fb2']);
    expect(importableBookExtensions, ['epub', 'fb2', 'zip']);
  });

  test('correct extensions route to their parsers', () {
    expect(bookParserFor('book.epub', epubBytes), isA<EpubParser>());
    expect(bookParserFor('book.fb2', fb2Doc), isA<Fb2Parser>());
  });

  test('a wrong extension is overridden by the content', () {
    expect(bookParserFor('book.fb2', epubBytes), isA<EpubParser>());
    expect(bookParserFor('book.epub', fb2Doc), isA<Fb2Parser>());
    expect(bookParserFor('book.txt', fb2Doc), isA<Fb2Parser>());
  });

  test('an absent extension is routed by magic bytes', () {
    expect(bookParserFor('somebook', epubBytes), isA<EpubParser>());
    expect(bookParserFor('somebook', fb2Doc), isA<Fb2Parser>());
  });

  test('an unrecognised file yields null, not an error', () {
    final junk = Uint8List.fromList(List.filled(128, 0x2A));
    expect(bookParserFor('notes.txt', junk), isNull);
    expect(bookParserFor('', Uint8List(0)), isNull);
  });

  test('a truncated file with a book extension still gets a parser', () async {
    // The parser reports ParseErr(corrupt) — better than "not a book".
    final truncated = Uint8List.fromList(epubBytes.sublist(4));
    final parser = bookParserFor('book.epub', truncated);
    expect(parser, isNotNull);
    final result =
        await parser!.parse(truncated, fallbackLanguageCode: 'en');
    expect(result, isA<ParseErr<BookDocument>>());
  });
}

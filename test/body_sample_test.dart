// bodySample: forward from the body start, paragraphs only, respecting
// maxChars.

import 'package:ebook_parser/ebook_parser.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

BookDocument docWith(List<Block> blocks) => BookDocument(
      metadata: const BookMetadata(
        title: 't',
        authors: [],
        sourceLanguageCode: 'en',
      ),
      chapters: [
        Chapter(index: 0, title: null, level: 0, blocks: blocks),
      ],
    );

void main() {
  test('collects paragraph text forward and skips headings', () {
    final doc = docWith([
      const HeadingBlock(text: 'Chapter One', level: 1),
      ParagraphBlock(text: 'First paragraph.'),
      const HeadingBlock(text: 'Interlude', level: 2),
      ParagraphBlock(text: 'Second paragraph.'),
    ]);
    expect(doc.bodySample(), 'First paragraph.\nSecond paragraph.\n');
  });

  test('stops once maxChars is reached', () {
    final doc = docWith([
      for (var i = 0; i < 100; i++) ParagraphBlock(text: 'x' * 100),
    ]);
    final sample = doc.bodySample(maxChars: 250);
    expect(sample.length, lessThan(500));
    expect(sample.length, greaterThanOrEqualTo(250));
  });

  test('an image-only document samples to the empty string', () {
    final doc = docWith([
      ImageBlock(image: ImageData(bytes: kTinyPng, mediaType: 'image/png')),
    ]);
    expect(doc.bodySample(), '');
  });

  test('reads across chapters in order', () {
    final doc = BookDocument(
      metadata: const BookMetadata(
        title: 't',
        authors: [],
        sourceLanguageCode: 'en',
      ),
      chapters: [
        Chapter(index: 0, title: null, level: 0, blocks: [
          ParagraphBlock(text: 'One.'),
        ]),
        Chapter(index: 1, title: null, level: 0, blocks: [
          ParagraphBlock(text: 'Two.'),
        ]),
      ],
    );
    expect(doc.bodySample(), 'One.\nTwo.\n');
  });
}

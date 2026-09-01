// SC-11: a parsed document survives Isolate.run, including with a
// caller-supplied segmenter — which is why segmenter implementations must
// hold plain data only.

import 'dart:isolate';
import 'dart:typed_data';

import 'package:ebook_parser/ebook_parser.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

/// Plain data only: sendable across the isolate boundary.
class UppercaseHintSegmenter implements TextSegmenter {
  const UppercaseHintSegmenter({this.hint = 'custom'});

  final String hint;

  @override
  List<Sentence> segment(String paragraphText) =>
      const RuleBasedSegmenter().segment(paragraphText);
}

void main() {
  test('a parsed document crosses the isolate boundary', () async {
    final builder = EpubBuilder(title: 'Isolated')
      ..docs.add(EpubDoc(
          'c1.xhtml', '<p>One sentence. Two sentences.</p>'))
      ..files['pic.png'] = kTinyPng
      ..cover = ('cover.png', kTinyPng, 'image/png', 'properties');
    final bytes = builder.build();

    final document = await Isolate.run(() async {
      final result = await bookParserFor('book.epub', bytes)!
          .parse(bytes, fallbackLanguageCode: 'en');
      return (result as ParseOk<BookDocument>).value;
    });

    expect(document.metadata.title, 'Isolated');
    expect(document.metadata.cover!.bytes, kTinyPng);
    // Lazy segmentation still works on this side of the boundary.
    final paragraph =
        document.chapters.single.blocks.whereType<ParagraphBlock>().single;
    expect(paragraph.sentences, hasLength(2));
  });

  test('a caller-supplied segmenter travels with the document', () async {
    final fb2Data = fb2Bytes(fb2(
      bodiesXml:
          '<body><section><p>First one. Second one.</p></section></body>',
    ));

    final document = await Isolate.run(() async {
      final result = await bookParserFor('book.fb2', fb2Data)!.parse(
        Uint8List.fromList(fb2Data),
        fallbackLanguageCode: 'en',
        segmenter: const UppercaseHintSegmenter(),
      );
      return (result as ParseOk<BookDocument>).value;
    });

    final paragraph =
        document.chapters.single.blocks.whereType<ParagraphBlock>().single;
    expect(paragraph.sentences.map((s) => s.text),
        ['First one.', 'Second one.']);
  });
}

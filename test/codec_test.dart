// SC-12: parse, encode, decode — the restored document segments
// identically, including with no segmenter passed to decode. SC-21: the
// encoded shape is pinned to kBookDocumentSchemaVersion. Images are encoded
// by reference (DEC-22): an unresolved reference is a decode failure.

import 'dart:typed_data';

import 'package:ebook_parser/ebook_parser.dart';
import 'package:ebook_parser/serialization.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

Future<BookDocument> parseOk(Uint8List bytes, String name) async {
  final result = await bookParserFor(name, bytes)!
      .parse(bytes, fallbackLanguageCode: 'en');
  expect(result, isA<ParseOk<BookDocument>>(),
      reason: result is ParseErr ? '${(result as ParseErr).failure}' : null);
  return (result as ParseOk<BookDocument>).value;
}

List<List<Sentence>> allSentences(BookDocument doc) => [
      for (final chapter in doc.chapters)
        for (final block in chapter.blocks)
          if (block is ParagraphBlock) block.sentences,
    ];

void main() {
  group('round trip (SC-12)', () {
    test('an illustrated document round-trips with its image map', () async {
      final bytes = fb2Bytes(fb2(
        bookTitle: 'Illustrated',
        coverHref: '#cover',
        bodiesXml: '<body><section><title><p>One</p></title>'
            '<p>First sentence. Second sentence.</p>'
            '<image l:href="#pic"/>'
            '<p>After the picture.</p></section></body>',
        binariesXml: fb2Binary('cover', kTinyJpeg, contentType: 'image/jpeg') +
            fb2Binary('pic', kTinyPng),
      ));
      final original = await parseOk(bytes, 'book.fb2');
      final encoded = encodeBookDocument(original);
      expect(encoded.images, hasLength(2));

      final decoded =
          decodeBookDocument(encoded.json, images: encoded.images);
      expect(decoded, isNotNull);
      expect(decoded!.metadata.title, original.metadata.title);
      expect(decoded.metadata.cover!.bytes, original.metadata.cover!.bytes);
      expect(decoded.chapters.length, original.chapters.length);

      final imageBlock = decoded.chapters.single.blocks
          .whereType<ImageBlock>()
          .single;
      expect(imageBlock.image.bytes, kTinyPng);
      expect(imageBlock.image.mediaType, 'image/png');

      // Segmentation identical to the original.
      expect(allSentences(decoded), allSentences(original));
    });

    test(
        'no-segmenter decode of a divergent-language document segments '
        'identically (DEC-26)', () async {
      // Greek is the language where the default rules diverge: the ASCII
      // semicolon terminates only when the segmenter is seeded with el.
      final bytes = fb2Bytes(fb2(
        bookTitle: 'Ελληνικά',
        lang: 'el',
        bodiesXml: '<body><section>'
            '<p>Τι ώρα είναι; Είναι αργά.</p></section></body>',
      ));
      final original = await parseOk(bytes, 'book.fb2');
      expect(allSentences(original).single, hasLength(2),
          reason: 'the seeded segmenter must split at the Greek question mark');

      final encoded = encodeBookDocument(original);
      final decoded = decodeBookDocument(encoded.json);
      expect(allSentences(decoded!), allSentences(original));
    });

    test('a version-mismatched json returns null (DEC-25)', () async {
      final doc = await parseOk(fb2Bytes(fb2()), 'book.fb2');
      final encoded = encodeBookDocument(doc);
      final mutated = Map<String, dynamic>.from(encoded.json);
      mutated['v'] = kBookDocumentSchemaVersion + 1;
      expect(decodeBookDocument(mutated, images: encoded.images), isNull);
    });

    test('an illustrated document with an empty image map returns null',
        () async {
      final bytes = fb2Bytes(fb2(
        bodiesXml: '<body><section><p>Text.</p>'
            '<image l:href="#pic"/></section></body>',
        binariesXml: fb2Binary('pic', kTinyPng),
      ));
      final doc = await parseOk(bytes, 'book.fb2');
      final encoded = encodeBookDocument(doc);
      expect(decodeBookDocument(encoded.json), isNull);
    });

    test('unreadable json returns null rather than throwing', () {
      expect(decodeBookDocument({'v': kBookDocumentSchemaVersion}), isNull);
      expect(
        decodeBookDocument({
          'v': kBookDocumentSchemaVersion,
          'metadata': 'not a map',
          'chapters': [],
        }),
        isNull,
      );
    });
  });

  group('the encoded shape is pinned (SC-21)', () {
    test('a golden document encodes to the expected shape', () {
      final document = BookDocument(
        metadata: BookMetadata(
          title: 'Golden',
          authors: const ['A. Author'],
          sourceLanguageCode: 'en',
          cover: ImageData(bytes: kTinyJpeg, mediaType: 'image/jpeg'),
        ),
        chapters: [
          Chapter(index: 0, title: 'One', level: 0, blocks: [
            const HeadingBlock(text: 'One', level: 1),
            ParagraphBlock(text: 'Some text.'),
            ImageBlock(
                image: ImageData(bytes: kTinyPng, mediaType: 'image/png')),
          ]),
          Chapter(index: 1, title: null, level: 1, blocks: [
            ParagraphBlock(text: 'More text.'),
          ]),
        ],
      );
      final encoded = encodeBookDocument(document);
      expect(encoded.json, {
        'v': kBookDocumentSchemaVersion,
        'metadata': {
          'title': 'Golden',
          'authors': ['A. Author'],
          'lang': 'en',
          'cover': {'ref': 'img0', 'mediaType': 'image/jpeg'},
        },
        'chapters': [
          {
            'title': 'One',
            'level': 0,
            'blocks': [
              {'t': 'h', 'text': 'One', 'level': 1},
              {'t': 'p', 'text': 'Some text.'},
              {'t': 'img', 'ref': 'img1', 'mediaType': 'image/png'},
            ],
          },
          {
            'title': null,
            'level': 1,
            'blocks': [
              {'t': 'p', 'text': 'More text.'},
            ],
          },
        ],
      });
      expect(encoded.images.keys, unorderedEquals(['img0', 'img1']));
      expect(encoded.images['img0']!.bytes, kTinyJpeg);
      expect(encoded.images['img1']!.bytes, kTinyPng);
    });
  });

  group('block codec', () {
    test('a paragraph round-trips and carries the version', () {
      final encoded = encodeBlock(ParagraphBlock(text: 'One. Two.'));
      expect(encoded.json['v'], kBookDocumentSchemaVersion);
      final decoded = decodeBlock(encoded.json) as ParagraphBlock;
      expect(decoded.text, 'One. Two.');
      expect(decoded.sentences, hasLength(2));
    });

    test('an image block hands its bytes back through the map', () {
      final encoded = encodeBlock(
        ImageBlock(image: ImageData(bytes: kTinyPng, mediaType: 'image/png')),
      );
      expect(encoded.images, hasLength(1));
      final decoded =
          decodeBlock(encoded.json, images: encoded.images) as ImageBlock;
      expect(decoded.image.bytes, kTinyPng);
      // Without the map the decode fails rather than producing a hole.
      expect(decodeBlock(encoded.json), isNull);
    });

    test('a version-mismatched block returns null', () {
      final encoded = encodeBlock(const HeadingBlock(text: 'H', level: 1));
      final mutated = Map<String, dynamic>.from(encoded.json);
      mutated['v'] = kBookDocumentSchemaVersion + 1;
      expect(decodeBlock(mutated), isNull);
    });

    test('decodeBlock without a segmenter gets the unseeded default', () {
      // The documented limitation: a lone block has no metadata to seed
      // from, so Greek text decoded without a segmenter segments as the
      // unseeded default does.
      final encoded =
          encodeBlock(ParagraphBlock(text: 'Τι ώρα είναι; Είναι αργά.'));
      final unseeded = decodeBlock(encoded.json) as ParagraphBlock;
      expect(unseeded.sentences, hasLength(1));
      final seeded = decodeBlock(
        encoded.json,
        segmenter: const RuleBasedSegmenter(languageCode: 'el'),
      ) as ParagraphBlock;
      expect(seeded.sentences, hasLength(2));
    });
  });
}

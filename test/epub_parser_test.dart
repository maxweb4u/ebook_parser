// The EPUB reader against constructed books: SC-01, SC-04, SC-09, SC-15,
// SC-16, SC-17, SC-18.

import 'package:ebook_parser/ebook_parser.dart';
import 'package:ebook_parser/src/epub/xhtml_blocks.dart';
import 'package:test/test.dart';

import 'support/builders.dart';

Future<BookDocument> parseEpub(EpubBuilder builder,
    {String fallback = 'en'}) async {
  final bytes = builder.build();
  final result = await bookParserFor('book.epub', bytes)!
      .parse(bytes, fallbackLanguageCode: fallback);
  expect(result, isA<ParseOk<BookDocument>>(),
      reason: (result as dynamic).valueOrNull == null
          ? 'parse failed: ${(result as ParseErr).failure}'
          : null);
  return (result as ParseOk<BookDocument>).value;
}

void main() {
  group('happy path (SC-01)', () {
    test('title, authors, chapters and first paragraph match', () async {
      final builder = EpubBuilder(
        title: 'The Title',
        authors: ['First Author', 'Second Author'],
        language: 'en',
      )
        ..docs.add(EpubDoc(
            'c1.xhtml', '<h1>One</h1><p>First paragraph.</p><p>Second.</p>'))
        ..docs.add(EpubDoc('c2.xhtml', '<h1>Two</h1><p>Third paragraph.</p>'))
        ..nav.addAll([Nav('One', 'c1.xhtml'), Nav('Two', 'c2.xhtml')]);
      final doc = await parseEpub(builder);
      expect(doc.metadata.title, 'The Title');
      expect(doc.metadata.authors, ['First Author', 'Second Author']);
      expect(doc.metadata.sourceLanguageCode, 'en');
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[0].title, 'One');
      expect(doc.chapters[0].index, 0);
      final first = doc.chapters[0].blocks
          .whereType<ParagraphBlock>()
          .first;
      expect(first.text, 'First paragraph.');
    });

    test('a book with no declared language receives the fallback (SC-04)',
        () async {
      final builder = EpubBuilder(language: null)
        ..docs.add(EpubDoc('c1.xhtml', '<p>Text.</p>'));
      final doc = await parseEpub(builder, fallback: 'uk');
      expect(doc.metadata.sourceLanguageCode, 'uk');
    });

    test('declared BCP-47 language is reduced (SC-20 integration)', () async {
      final builder = EpubBuilder(language: 'en-GB')
        ..docs.add(EpubDoc('c1.xhtml', '<p>Text.</p>'));
      final doc = await parseEpub(builder, fallback: 'ru');
      expect(doc.metadata.sourceLanguageCode, 'en');
    });
  });

  group('chapter granularity (SC-16)', () {
    test('several navigation entries into one document split at anchors',
        () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
          'poems.xhtml',
          '<h2 id="p1">Poem One</h2><p>Line one.</p>'
          '<h2 id="p2">Poem Two</h2><p>Line two.</p>'
          '<h2 id="p3">Poem Three</h2><p>Line three.</p>',
        ))
        ..nav.addAll([
          Nav('Poem One', 'poems.xhtml#p1'),
          Nav('Poem Two', 'poems.xhtml#p2'),
          Nav('Poem Three', 'poems.xhtml#p3'),
        ]);
      final doc = await parseEpub(builder);
      expect(doc.chapters.map((c) => c.title),
          ['Poem One', 'Poem Two', 'Poem Three']);
      expect(doc.chapters[0].blocks, hasLength(2));
      expect(doc.chapters[1].blocks, hasLength(2));
      expect(
        (doc.chapters[1].blocks[1] as ParagraphBlock).text,
        'Line two.',
      );
    });

    test('an anchor on an inline element splits before its enclosing block',
        () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
          'c.xhtml',
          '<p>Before the anchor.</p>'
          '<p>Starts <a id="here"></a>the second chapter.</p>',
        ))
        ..nav.addAll([
          Nav('First', 'c.xhtml'),
          Nav('Second', 'c.xhtml#here'),
        ]);
      final doc = await parseEpub(builder);
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[0].blocks, hasLength(1));
      expect(
        (doc.chapters[1].blocks.single as ParagraphBlock).text,
        'Starts the second chapter.',
      );
    });

    test('an anchor that resolves to nothing drops its entry', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
          'c.xhtml',
          '<h2 id="one">One</h2><p>Text one.</p>',
        ))
        ..nav.addAll([
          Nav('One', 'c.xhtml#one'),
          Nav('Ghost', 'c.xhtml#missing'),
        ]);
      final doc = await parseEpub(builder);
      expect(doc.chapters.map((c) => c.title), ['One']);
    });

    test('an entry pointing outside the spine is ignored', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc('c.xhtml', '<p>Text.</p>'))
        ..nav.addAll([
          Nav('Real', 'c.xhtml'),
          Nav('Elsewhere', 'other.xhtml'),
        ]);
      final doc = await parseEpub(builder);
      expect(doc.chapters.map((c) => c.title), ['Real']);
    });

    test('content before the first anchor becomes an untitled chapter',
        () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
          'c.xhtml',
          '<p>Prefatory text.</p><h2 id="ch1">One</h2><p>Body.</p>',
        ))
        ..nav.add(Nav('One', 'c.xhtml#ch1'));
      // One entry means no split (rule 3), so use two entries to force the
      // split path.
      builder.docs[0] = EpubDoc(
        'c.xhtml',
        '<p>Prefatory text.</p><h2 id="ch1">One</h2><p>Body.</p>'
        '<h2 id="ch2">Two</h2><p>More.</p>',
      );
      builder.nav.add(Nav('Two', 'c.xhtml#ch2'));
      final doc = await parseEpub(builder);
      expect(doc.chapters.map((c) => c.title), [null, 'One', 'Two']);
      expect(
        (doc.chapters[0].blocks.single as ParagraphBlock).text,
        'Prefatory text.',
      );
    });

    test('entries sharing a split point each still yield a chapter (DEC-31)',
        () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
          'part.xhtml',
          '<h1 id="part">Part I</h1><p>Chapter text.</p>'
          '<h2 id="late">Later</h2><p>More text.</p>',
        ))
        ..nav.addAll([
          Nav('Part I', 'part.xhtml#part'),
          Nav('Chapter 1', 'part.xhtml#part', depth: 1),
          Nav('Later', 'part.xhtml#late', depth: 1),
        ]);
      final doc = await parseEpub(builder);
      expect(doc.chapters.map((c) => c.title),
          ['Part I', 'Chapter 1', 'Later']);
      // The shallower entry keeps title and level with no blocks; the last
      // one in navigation order takes the content.
      expect(doc.chapters[0].level, 0);
      expect(doc.chapters[0].blocks, isEmpty);
      expect(doc.chapters[1].level, 1);
      expect(doc.chapters[1].blocks, hasLength(2));
      expect(doc.chapters[2].blocks, hasLength(2));
      // Index stays dense.
      expect(doc.chapters.map((c) => c.index), [0, 1, 2]);
    });
  });

  group('nested navigation flattens with level (SC-15)', () {
    test('depth arrives as Chapter.level in reading order', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc('part1.xhtml', '<h1>Part I</h1><p>Intro.</p>'))
        ..docs.add(EpubDoc('c1.xhtml', '<p>One.</p>'))
        ..docs.add(EpubDoc('c2.xhtml', '<p>Two.</p>'))
        ..nav.addAll([
          Nav('Part I', 'part1.xhtml'),
          Nav('Chapter 1', 'c1.xhtml', depth: 1),
          Nav('Chapter 2', 'c2.xhtml', depth: 1),
        ]);
      final doc = await parseEpub(builder);
      expect(doc.chapters.map((c) => c.title),
          ['Part I', 'Chapter 1', 'Chapter 2']);
      expect(doc.chapters.map((c) => c.level), [0, 1, 1]);
    });

    test('the same shape works through an EPUB 3 nav document', () async {
      final builder = EpubBuilder(epub3: true)
        ..docs.add(EpubDoc('part1.xhtml', '<h1>Part I</h1><p>Intro.</p>'))
        ..docs.add(EpubDoc('c1.xhtml', '<p>One.</p>'))
        ..nav.addAll([
          Nav('Part I', 'part1.xhtml'),
          Nav('Chapter 1', 'c1.xhtml', depth: 1),
        ]);
      final doc = await parseEpub(builder);
      expect(doc.chapters.map((c) => c.level), [0, 1]);
    });
  });

  group('unnavigated spine items (SC-17)', () {
    test('front matter becomes untitled chapters at the preceding level',
        () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc('dedication.xhtml', '<p>For someone.</p>'))
        ..docs.add(EpubDoc('c1.xhtml', '<p>Chapter text.</p>'))
        ..nav.add(Nav('One', 'c1.xhtml'));
      final doc = await parseEpub(builder);
      expect(doc.chapters.map((c) => c.title), [null, 'One']);
      expect(
        (doc.chapters[0].blocks.single as ParagraphBlock).text,
        'For someone.',
      );
    });

    test('a spine item declared type="toc" yields no chapter', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
            'contents.xhtml', '<p><a href="c1.xhtml">One</a></p>'))
        ..docs.add(EpubDoc('c1.xhtml', '<p>Chapter text.</p>'))
        ..nav.add(Nav('One', 'c1.xhtml'))
        ..guideTocHref = 'contents.xhtml';
      final doc = await parseEpub(builder);
      expect(doc.chapters.map((c) => c.title), ['One']);
    });

    test('an undeclared contents page is kept', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
            'contents.xhtml', '<p><a href="c1.xhtml">One</a></p>'))
        ..docs.add(EpubDoc('c1.xhtml', '<p>Chapter text.</p>'))
        ..nav.add(Nav('One', 'c1.xhtml'));
      final doc = await parseEpub(builder);
      expect(doc.chapters.map((c) => c.title), [null, 'One']);
      // Link text is kept, the target is dropped.
      expect(
        (doc.chapters[0].blocks.single as ParagraphBlock).text,
        'One',
      );
    });

    test('an empty unnavigated item is dropped, and index stays dense',
        () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc('blank.xhtml', ''))
        ..docs.add(EpubDoc('c1.xhtml', '<p>Text.</p>'))
        ..nav.add(Nav('One', 'c1.xhtml'));
      final doc = await parseEpub(builder);
      expect(doc.chapters, hasLength(1));
      expect(doc.chapters.single.index, 0);
    });
  });

  group('no synthetic headings (SC-18)', () {
    test('navigation labels never become heading blocks', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc('c1.xhtml', '<p class="chapter">ONE</p><p>Text.</p>'))
        ..docs.add(EpubDoc('c2.xhtml', '<p class="chapter">TWO</p><p>More.</p>'))
        ..nav.addAll([Nav('Chapter One', 'c1.xhtml'), Nav('Chapter Two', 'c2.xhtml')]);
      final doc = await parseEpub(builder);
      for (final chapter in doc.chapters) {
        expect(chapter.blocks.whereType<HeadingBlock>(), isEmpty);
      }
      expect(doc.chapters.map((c) => c.title),
          ['Chapter One', 'Chapter Two']);
    });
  });

  group('inline images (SC-09)', () {
    test('images resolve through the manifest with their media type',
        () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
          'c1.xhtml',
          '<p>Before.</p><img src="images/pic.png" alt=""/>'
          '<p>After.</p>',
        ))
        ..files['images/pic.png'] = kTinyPng
        ..manifestExtra.add(('pic', 'images/pic.png', 'image/png', null));
      final doc = await parseEpub(builder);
      final blocks = doc.chapters.single.blocks;
      expect(blocks, hasLength(3));
      final image = blocks[1] as ImageBlock;
      expect(image.image.mediaType, 'image/png');
      expect(image.image.bytes, kTinyPng);
    });

    test('an unresolvable image is skipped, the book still parses (NEG-02)',
        () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
          'c1.xhtml',
          '<p>Before.</p><img src="missing.png" alt=""/><p>After.</p>',
        ));
      final doc = await parseEpub(builder);
      expect(doc.chapters.single.blocks.whereType<ImageBlock>(), isEmpty);
      expect(doc.chapters.single.blocks, hasLength(2));
    });

    test('an svg-wrapped cover page image becomes an ImageBlock', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
          'titlepage.xhtml',
          '<div><svg xmlns="http://www.w3.org/2000/svg" '
              'xmlns:xlink="http://www.w3.org/1999/xlink">'
              '<image width="100" height="100" xlink:href="cover.png"/>'
              '</svg></div>',
        ))
        ..docs.add(EpubDoc('c1.xhtml', '<p>Text.</p>'))
        ..files['cover.png'] = kTinyPng
        ..nav.add(Nav('One', 'c1.xhtml'));
      final doc = await parseEpub(builder);
      expect(doc.chapters, hasLength(2));
      expect(doc.chapters[0].blocks.single, isA<ImageBlock>());
    });
  });

  group('flattened constructs (SC-14, EPUB side)', () {
    test('lists, tables, quotes and breaks flatten per the mapping',
        () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
          'c1.xhtml',
          '<ul><li>Item one</li><li>Item two</li></ul>'
          '<table><tr><td>A1</td><td>B1</td></tr>'
          '<tr><td>A2</td><td>B2</td></tr></table>'
          '<blockquote><p>Quoted words.</p></blockquote>'
          '<p>Line one<br/>Line two</p>'
          '<div>Bare div text</div>',
        ));
      final doc = await parseEpub(builder);
      final texts = doc.chapters.single.blocks
          .whereType<ParagraphBlock>()
          .map((p) => p.text)
          .toList();
      expect(texts, [
        'Item one',
        'Item two',
        'A1 B1',
        'A2 B2',
        'Quoted words.',
        'Line one\nLine two',
        'Bare div text',
      ]);
    });

    test('a br inside a paragraph never splits it', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc('c1.xhtml', '<p>Verse one<br/>verse two</p>'));
      final doc = await parseEpub(builder);
      final paragraph =
          doc.chapters.single.blocks.single as ParagraphBlock;
      expect(paragraph.text, 'Verse one\nverse two');
    });

    test('a self-closing <title/> in the head does not swallow the body', () {
      // XHTML allows <title/>, but under HTML parsing rules a raw-text
      // element opened and never closed swallows the rest of the document.
      // One real conversion pipeline emits it in every chapter head — 165
      // of the 178 EPUBs in the local collection.
      const hostile = '<?xml version="1.0" encoding="UTF-8"?>\n'
          '<html xmlns="http://www.w3.org/1999/xhtml">\n'
          '<head><title/>'
          '<link rel="stylesheet" href="style.css" type="text/css"/></head>\n'
          '<body><div class="title"><p class="p">Visible text.</p></div>'
          '</body></html>';
      final parsed = blocksFromXhtml(
        hostile,
        segmenter: const RuleBasedSegmenter(),
      );
      expect(parsed.blocks, hasLength(1));
      expect((parsed.blocks.single as ParagraphBlock).text, 'Visible text.');
    });

    test('headings keep their tag level', () async {
      final builder = EpubBuilder()
        ..docs.add(EpubDoc(
            'c1.xhtml', '<h1>Top</h1><h3>Deep</h3><p>Text.</p>'));
      final doc = await parseEpub(builder);
      final headings =
          doc.chapters.single.blocks.whereType<HeadingBlock>().toList();
      expect(headings.map((h) => h.level), [1, 3]);
    });
  });
}

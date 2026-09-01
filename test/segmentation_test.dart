// SC-05 (laziness), the script classes of the rule-based segmenter, and the
// equality asymmetry: Sentence and Word behave as values, everything above
// them keeps identity.

import 'package:ebook_parser/ebook_parser.dart';
import 'package:test/test.dart';

/// Counts calls through a static so the segmenter itself stays plain data.
class CountingSegmenter implements TextSegmenter {
  const CountingSegmenter();

  static int calls = 0;

  @override
  List<Sentence> segment(String paragraphText) {
    calls++;
    return const RuleBasedSegmenter().segment(paragraphText);
  }
}

void main() {
  group('laziness (SC-05)', () {
    test('no segmentation runs before sentences is touched', () {
      CountingSegmenter.calls = 0;
      final paragraph = ParagraphBlock(
        text: 'One sentence. Another sentence.',
        segmenter: const CountingSegmenter(),
      );
      expect(CountingSegmenter.calls, 0);
      expect(paragraph.sentences, hasLength(2));
      expect(CountingSegmenter.calls, 1);
      // Cached: a second access does not re-segment.
      expect(paragraph.sentences, hasLength(2));
      expect(CountingSegmenter.calls, 1);
    });
  });

  group('sentence splitting', () {
    List<String> sentencesOf(String text, {String? language}) =>
        RuleBasedSegmenter(languageCode: language)
            .segment(text)
            .map((s) => s.text)
            .toList();

    test('plain English sentences split on terminators', () {
      expect(
        sentencesOf('First one. Second one! Third one?'),
        ['First one.', 'Second one!', 'Third one?'],
      );
    });

    test('offsets are paragraph-relative and cover the text', () {
      const text = 'One two. Three four.';
      final sentences = const RuleBasedSegmenter().segment(text);
      expect(sentences, hasLength(2));
      expect(text.substring(sentences[0].start, sentences[0].end), 'One two.');
      expect(
        text.substring(sentences[1].start, sentences[1].end),
        'Three four.',
      );
      final word = sentences[1].words.first;
      expect(text.substring(word.start, word.end), 'Three');
    });

    test('initials do not split (Layer 2)', () {
      expect(
        sentencesOf('J. R. R. Tolkien wrote it. И читал А. С. Пушкин.'),
        ['J. R. R. Tolkien wrote it.', 'И читал А. С. Пушкин.'],
      );
    });

    test('two-letter abbreviations built from initials do not split', () {
      expect(
        sentencesOf('В списке были книги, статьи и т. д. до самого конца.'),
        ['В списке были книги, статьи и т. д. до самого конца.'],
      );
      // The accepted cost of the single-letter rule: a genuine sentence
      // start after such an abbreviation stays merged — a missed split
      // merges two sentences, while a false split truncates one, and
      // truncation is what a reader notices.
      expect(sentencesOf('и т. д. Новая мысль.'), hasLength(1));
    });

    test('decimals and domains survive', () {
      expect(
        sentencesOf('Pi is 3.14 exactly. See example.com now.'),
        ['Pi is 3.14 exactly.', 'See example.com now.'],
      );
    });

    test('caller abbreviations suppress splits', () {
      final segmenter =
          const RuleBasedSegmenter(abbreviations: {'mr', 'dr'});
      expect(
        segmenter.segment('Mr. Smith met Dr. Jones. They left.').map(
              (s) => s.text,
            ),
        ['Mr. Smith met Dr. Jones.', 'They left.'],
      );
    });

    test('lower-case continuation does not split', () {
      expect(
        sentencesOf('"Wait!" he said. Then silence.'),
        ['"Wait!" he said.', 'Then silence.'],
      );
    });

    test('a terminator before a closing quote ends the sentence after it', () {
      expect(
        sentencesOf('«Стой!» Он замер.'),
        ['«Стой!»', 'Он замер.'],
      );
    });

    test('CJK full stops split without following whitespace', () {
      expect(
        sentencesOf('这是第一句。这是第二句。'),
        ['这是第一句。', '这是第二句。'],
      );
    });

    test('Arabic question mark splits', () {
      expect(
        sentencesOf('هل تقرأ؟ نعم أقرأ.'),
        ['هل تقرأ؟', 'نعم أقرأ.'],
      );
    });

    test('Greek ASCII semicolon terminates only with the el hint', () {
      const text = 'Τι ώρα είναι; Είναι αργά.';
      expect(sentencesOf(text), hasLength(1));
      expect(
        sentencesOf(text, language: 'el'),
        ['Τι ώρα είναι;', 'Είναι αργά.'],
      );
    });
  });

  group('words per writing system', () {
    List<List<String>> wordsOf(String text, {String? language}) =>
        RuleBasedSegmenter(languageCode: language)
            .segment(text)
            .map((s) => s.words.map((w) => w.text).toList())
            .toList();

    test('spaced scripts: letter runs with inner apostrophes and hyphens', () {
      expect(
        wordsOf("It's a well-known fact."),
        [
          ["It's", 'a', 'well-known', 'fact'],
        ],
      );
    });

    test('Chinese: one ideograph per word', () {
      expect(wordsOf('我爱书。'), [
        ['我', '爱', '书'],
      ]);
    });

    test('Japanese: words split at script transitions', () {
      // Kanji, hiragana and katakana runs become separate words, so 読む
      // splits at the kanji-to-hiragana transition.
      expect(wordsOf('私は本を読むテスト。'), [
        ['私', 'は', '本', 'を', '読', 'む', 'テスト'],
      ]);
    });

    test('the zh hint forces per-ideograph words even without kana', () {
      expect(wordsOf('漢字文', language: 'zh'), [
        ['漢', '字', '文'],
      ]);
    });

    test('the ja hint keeps a kanji run as one word', () {
      expect(wordsOf('漢字文', language: 'ja'), [
        ['漢字文'],
      ]);
    });

    test('unruled scripts yield sentences with empty words (DEC-30)', () {
      final sentences =
          const RuleBasedSegmenter(languageCode: 'th').segment('สวัสดีครับ');
      expect(sentences, hasLength(1));
      expect(sentences.single.words, isEmpty);
    });

    test('Latin embedded in an unruled script still yields words', () {
      final sentences =
          const RuleBasedSegmenter().segment('สวัสดี Dart ครับ');
      expect(sentences.single.words.map((w) => w.text), ['Dart']);
    });
  });

  group('equality (SC-01 pinning)', () {
    test('Sentence and Word behave as values in a Set', () {
      // Runtime-constructed so equality, not const canonicalisation, is
      // what deduplicates.
      final word = Word(text: 'one', start: 0, end: 3);
      final same = Word(text: 'one', start: 0, end: 3);
      final other = Word(text: 'two', start: 4, end: 7);
      expect(identical(word, same), isFalse);
      expect({word, same, other}, hasLength(2));

      final sentence =
          Sentence(text: 'one', start: 0, end: 3, words: [word]);
      final sameSentence =
          Sentence(text: 'one', start: 0, end: 3, words: [same]);
      expect({sentence, sameSentence}, hasLength(1));
    });

    test('Sentence equality compares words element-wise', () {
      const a = Sentence(text: 'one', start: 0, end: 3, words: [
        Word(text: 'one', start: 0, end: 3),
      ]);
      const b = Sentence(text: 'one', start: 0, end: 3, words: []);
      expect(a == b, isFalse);
    });

    test('paragraph-level types and BookMetadata keep identity', () {
      final p1 = ParagraphBlock(text: 'same');
      final p2 = ParagraphBlock(text: 'same');
      expect(p1 == p2, isFalse);

      final h1 = HeadingBlock(text: 'same', level: 1); // ignore: prefer_const_constructors
      final h2 = HeadingBlock(text: 'same', level: 1); // ignore: prefer_const_constructors
      expect(h1 == h2, isFalse);

      final m1 = BookMetadata(
        title: 't',
        authors: const ['a'],
        sourceLanguageCode: 'en',
      );
      final m2 = BookMetadata(
        title: 't',
        authors: const ['a'],
        sourceLanguageCode: 'en',
      );
      expect(m1 == m2, isFalse);
    });
  });
}

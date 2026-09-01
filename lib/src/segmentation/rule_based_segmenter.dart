import '../book_document.dart';
import 'script_rules.dart';
import 'text_segmenter.dart';

// Pattern objects live in top-level finals, never in instance fields: the
// segmenter travels inside every paragraph it segments, and a compiled RegExp
// is not sendable across an isolate boundary.
final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _wordStart = RegExp(r'[\p{L}\p{N}]', unicode: true);
final RegExp _wordContinue = RegExp(r"[\p{L}\p{N}'’-]", unicode: true);

/// The built-in [TextSegmenter]: rule-based, decided by writing system rather
/// than by language.
///
/// Sentences are split on the terminator set of every space-separated script
/// plus the CJK, Indic, Arabic, Armenian, Ethiopic, Tibetan, Khmer and
/// Burmese stops. False splits on initials (`J. R. R. Tolkien`,
/// `А. С. Пушкин`), on caller-supplied abbreviations, and before a
/// lower-case continuation are suppressed. Words are letter and number runs
/// in spaced scripts; Japanese splits at script transitions, Chinese takes
/// one ideograph per word, and Thai, Khmer, Lao and Burmese carry no word
/// rule at all — their sentences have empty `words`.
///
/// [languageCode] exists for the cases rules cannot infer from the text:
/// modern Greek's ASCII `;` question mark enters the terminator set only when
/// the hint is `el`, and `ja`/`zh` force the Japanese or Chinese word rule
/// where the text alone is ambiguous.
///
/// Holds plain data only, so documents built with it cross isolate
/// boundaries.
class RuleBasedSegmenter implements TextSegmenter {
  /// Creates the default segmenter, optionally seeded with [languageCode]
  /// and caller-supplied [abbreviations].
  const RuleBasedSegmenter({this.languageCode, this.abbreviations = const {}});

  /// Optional ISO-639-1 hint for the rules that need one.
  final String? languageCode;

  /// Abbreviations (lower-case, without the trailing period) that never end
  /// a sentence, such as `{'mr', 'dr'}`.
  final Set<String> abbreviations;

  @override
  List<Sentence> segment(String paragraphText) {
    final text = paragraphText;
    final n = text.length;
    final sentences = <Sentence>[];
    var i = 0;
    var start = -1;
    while (i < n) {
      final ch = text[i];
      if (start == -1) {
        if (_isWhitespace(ch)) {
          i++;
          continue;
        }
        start = i;
      }
      if (isTerminator(ch, languageCode)) {
        final termStart = i;
        var j = i;
        var sawUnspaced = false;
        while (j < n && isTerminator(text[j], languageCode)) {
          if (kUnspacedTerminators.contains(text[j])) sawUnspaced = true;
          j++;
        }
        final termEnd = j;
        while (j < n && kClosingMarks.contains(text[j])) {
          j++;
        }
        if (!sawUnspaced) {
          // A spaced terminator must be followed by whitespace or end of
          // text, which is what keeps "3.14" and "example.com" whole.
          if (j < n && !_isWhitespace(text[j])) {
            i = j;
            continue;
          }
          if (_suppressSplit(text, termStart, termEnd, j)) {
            i = j;
            continue;
          }
        }
        sentences.add(_sentence(text, start, j));
        start = -1;
        i = j;
        continue;
      }
      i++;
    }
    if (start != -1) {
      var end = n;
      while (end > start && _isWhitespace(text[end - 1])) {
        end--;
      }
      if (end > start) sentences.add(_sentence(text, start, end));
    }
    return sentences;
  }

  bool _suppressSplit(String text, int termStart, int termEnd, int boundary) {
    final isSinglePeriod = termEnd - termStart == 1 && text[termStart] == '.';
    if (isSinglePeriod) {
      final token = _tokenBefore(text, termStart);
      // A single letter before the period is an initial, which also covers
      // the two-letter abbreviations built from initials ("т. д.").
      if (token.length == 1 && _letter.hasMatch(token)) return true;
      if (token.isNotEmpty && abbreviations.contains(token.toLowerCase())) {
        return true;
      }
    }
    // A lower-case continuation in a cased script is not a sentence start —
    // this also keeps `"Wait!" he said.` together.
    var k = boundary;
    while (k < text.length && _isWhitespace(text[k])) {
      k++;
    }
    if (k < text.length) {
      final next = text[k];
      if (_letter.hasMatch(next) &&
          next.toLowerCase() == next &&
          next.toUpperCase() != next) {
        return true;
      }
    }
    return false;
  }

  String _tokenBefore(String text, int termStart) {
    var s = termStart;
    while (s > 0 && _letter.hasMatch(text[s - 1])) {
      s--;
    }
    return text.substring(s, termStart);
  }

  Sentence _sentence(String text, int start, int end) {
    final raw = text.substring(start, end);
    return Sentence(
      text: raw,
      start: start,
      end: end,
      words: _words(raw, start),
    );
  }

  List<Word> _words(String sentence, int offset) {
    final words = <Word>[];
    // Japanese and Chinese share the Han script, so the word rule for a Han
    // run needs a tiebreak: an explicit hint wins, and otherwise the
    // presence of kana marks the text as Japanese.
    final bool japanese;
    if (languageCode == 'ja') {
      japanese = true;
    } else if (languageCode == 'zh') {
      japanese = false;
    } else {
      japanese = _containsKana(sentence);
    }

    var i = 0;
    while (i < sentence.length) {
      final rune = sentence.runeAt(i);
      final size = rune > 0xFFFF ? 2 : 1;
      if (isUnruledScript(rune)) {
        i += size;
        continue;
      }
      if (isHan(rune)) {
        if (japanese) {
          final end = _runEnd(sentence, i, isHan);
          words.add(_word(sentence, i, end, offset));
          i = end;
        } else {
          // One ideograph per word: not linguistically correct, but usable
          // for per-word lookup where a whole run is not.
          words.add(_word(sentence, i, i + size, offset));
          i += size;
        }
        continue;
      }
      if (isHiragana(rune)) {
        final end = _runEnd(sentence, i, isHiragana);
        words.add(_word(sentence, i, end, offset));
        i = end;
        continue;
      }
      if (isKatakana(rune)) {
        final end = _runEnd(sentence, i, isKatakana);
        words.add(_word(sentence, i, end, offset));
        i = end;
        continue;
      }
      final ch = String.fromCharCode(rune);
      if (_wordStart.hasMatch(ch)) {
        var end = i + size;
        while (end < sentence.length) {
          final r = sentence.runeAt(end);
          if (isHan(r) ||
              isHiragana(r) ||
              isKatakana(r) ||
              isUnruledScript(r)) {
            break;
          }
          final c = String.fromCharCode(r);
          if (!_wordContinue.hasMatch(c)) break;
          end += r > 0xFFFF ? 2 : 1;
        }
        words.add(_word(sentence, i, end, offset));
        i = end;
        continue;
      }
      i += size;
    }
    return words;
  }

  Word _word(String sentence, int start, int end, int offset) => Word(
        text: sentence.substring(start, end),
        start: offset + start,
        end: offset + end,
      );

  int _runEnd(String s, int start, bool Function(int rune) inRun) {
    var i = start;
    while (i < s.length) {
      final rune = s.runeAt(i);
      if (!inRun(rune)) break;
      i += rune > 0xFFFF ? 2 : 1;
    }
    return i;
  }

  bool _containsKana(String s) {
    for (var i = 0; i < s.length; i++) {
      final rune = s.runeAt(i);
      if (isHiragana(rune) || isKatakana(rune)) return true;
      if (rune > 0xFFFF) i++;
    }
    return false;
  }

  bool _isWhitespace(String ch) => ch.trim().isEmpty;
}

extension on String {
  /// The rune starting at code-unit [index], combining a surrogate pair.
  int runeAt(int index) {
    final unit = codeUnitAt(index);
    if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < length) {
      final low = codeUnitAt(index + 1);
      if (low >= 0xDC00 && low <= 0xDFFF) {
        return 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
      }
    }
    return unit;
  }
}

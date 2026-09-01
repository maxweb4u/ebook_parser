// Terminator sets and script classes for the rule-based segmenter.
//
// Segmentation is decided by writing system, not by language
// (ADR: script-driven segmentation). Everything here is plain data or pure
// functions over code units, so the segmenter that uses it stays sendable.

/// Sentence terminators after which a following whitespace (or end of text)
/// is required, because their scripts separate sentences with spaces:
/// ASCII `.!?`, ellipsis, Indic danda, Arabic and Urdu, Armenian, Ethiopic.
const String kSpacedTerminators = '.!?…।॥؟۔։።';

/// Sentence terminators that need no following whitespace, because their
/// scripts do not use it: full-width and CJK stops, Tibetan, Khmer, Burmese.
const String kUnspacedTerminators = '。！？．‼⁇⁈⁉།༎។။၊';

/// Closing quotation marks and brackets a terminator may be followed by; the
/// sentence boundary falls after them, not before.
const String kClosingMarks = '"\'”’»›)]}」』〉》〕】）';

/// Whether [ch] (a single-character string) terminates a sentence, given the
/// optional [languageCode] hint. Modern Greek uses the ASCII semicolon as its
/// question mark, which cannot join a shared terminator class without
/// breaking every other language.
bool isTerminator(String ch, String? languageCode) {
  if (kSpacedTerminators.contains(ch) || kUnspacedTerminators.contains(ch)) {
    return true;
  }
  if (languageCode == 'el' && (ch == ';' || ch == ';')) return true;
  return false;
}

/// Whether [rune] is a CJK ideograph (Han).
bool isHan(int rune) =>
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0x20000 && rune <= 0x2A6DF);

/// Whether [rune] is hiragana.
bool isHiragana(int rune) => rune >= 0x3040 && rune <= 0x309F;

/// Whether [rune] is katakana, including the prolonged sound mark.
bool isKatakana(int rune) =>
    (rune >= 0x30A0 && rune <= 0x30FF) || (rune >= 0x31F0 && rune <= 0x31FF);

/// Whether [rune] belongs to a script the built-in rules carry no word rule
/// for: Thai, Lao, Khmer, Burmese. Runs in these scripts yield no words —
/// no rule means no words, not one sentence-wide word pretending to be one.
bool isUnruledScript(int rune) =>
    (rune >= 0x0E00 && rune <= 0x0E7F) || // Thai
    (rune >= 0x0E80 && rune <= 0x0EFF) || // Lao
    (rune >= 0x1780 && rune <= 0x17FF) || // Khmer
    (rune >= 0x1000 && rune <= 0x109F); // Myanmar

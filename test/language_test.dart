// SC-20: BCP-47 reduction, ISO-639-1 acceptance, the 639-2/B mapping, and
// the fallback contract.

import 'package:ebook_parser/ebook_parser.dart';
import 'package:test/test.dart';

void main() {
  test('BCP-47 values reduce to their primary subtag', () {
    expect(normalizeLanguageCode('en-GB', fallback: 'ru'), 'en');
    expect(normalizeLanguageCode('en-US', fallback: 'ru'), 'en');
    expect(normalizeLanguageCode('zh-Hans-CN', fallback: 'ru'), 'zh');
    expect(normalizeLanguageCode('sr_Latn', fallback: 'ru'), 'sr');
  });

  test('any ISO-639-1 code is accepted, case-insensitively', () {
    expect(normalizeLanguageCode('fr', fallback: 'en'), 'fr');
    expect(normalizeLanguageCode('KO', fallback: 'en'), 'ko');
    expect(normalizeLanguageCode(' de ', fallback: 'en'), 'de');
  });

  test('639-2 codes map to their 639-1 equivalent (DEC-29)', () {
    expect(normalizeLanguageCode('eng', fallback: 'ru'), 'en');
    expect(normalizeLanguageCode('deu', fallback: 'ru'), 'de');
    expect(normalizeLanguageCode('ger', fallback: 'ru'), 'de');
    expect(normalizeLanguageCode('rus', fallback: 'en'), 'ru');
    expect(normalizeLanguageCode('fre', fallback: 'en'), 'fr');
    expect(normalizeLanguageCode('fra', fallback: 'en'), 'fr');
    expect(normalizeLanguageCode('chi', fallback: 'en'), 'zh');
    expect(normalizeLanguageCode('zho', fallback: 'en'), 'zh');
  });

  test('anything else falls back', () {
    expect(normalizeLanguageCode(null, fallback: 'en'), 'en');
    expect(normalizeLanguageCode('', fallback: 'en'), 'en');
    expect(normalizeLanguageCode('xx', fallback: 'en'), 'en');
    expect(normalizeLanguageCode('klingon', fallback: 'en'), 'en');
  });

  test('the fallback itself is normalized like a declared value', () {
    expect(normalizeLanguageCode('xx', fallback: 'en-GB'), 'en');
    expect(normalizeLanguageCode(null, fallback: 'ENG'), 'en');
  });

  test('a fallback outside ISO-639-1 throws ArgumentError (DEC-28)', () {
    expect(
      () => normalizeLanguageCode('en', fallback: 'xx'),
      throwsArgumentError,
    );
    expect(
      () => normalizeLanguageCode('en', fallback: ''),
      throwsArgumentError,
    );
  });
}

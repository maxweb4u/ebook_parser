// ISO-639-1 validation and BCP-47 normalization. The package validates
// against the whole standard and holds no application's supported-language
// list; narrowing is the caller's, at its own call site.

/// Every two-letter ISO-639-1 code.
const Set<String> _iso6391 = {
  'aa', 'ab', 'ae', 'af', 'ak', 'am', 'an', 'ar', 'as', 'av', 'ay', 'az',
  'ba', 'be', 'bg', 'bh', 'bi', 'bm', 'bn', 'bo', 'br', 'bs',
  'ca', 'ce', 'ch', 'co', 'cr', 'cs', 'cu', 'cv', 'cy',
  'da', 'de', 'dv', 'dz',
  'ee', 'el', 'en', 'eo', 'es', 'et', 'eu',
  'fa', 'ff', 'fi', 'fj', 'fo', 'fr', 'fy',
  'ga', 'gd', 'gl', 'gn', 'gu', 'gv',
  'ha', 'he', 'hi', 'ho', 'hr', 'ht', 'hu', 'hy', 'hz',
  'ia', 'id', 'ie', 'ig', 'ii', 'ik', 'io', 'is', 'it', 'iu',
  'ja', 'jv',
  'ka', 'kg', 'ki', 'kj', 'kk', 'kl', 'km', 'kn', 'ko', 'kr', 'ks', 'ku',
  'kv', 'kw', 'ky',
  'la', 'lb', 'lg', 'li', 'ln', 'lo', 'lt', 'lu', 'lv',
  'mg', 'mh', 'mi', 'mk', 'ml', 'mn', 'mr', 'ms', 'mt', 'my',
  'na', 'nb', 'nd', 'ne', 'ng', 'nl', 'nn', 'no', 'nr', 'nv', 'ny',
  'oc', 'oj', 'om', 'or', 'os',
  'pa', 'pi', 'pl', 'ps', 'pt',
  'qu',
  'rm', 'rn', 'ro', 'ru', 'rw',
  'sa', 'sc', 'sd', 'se', 'sg', 'si', 'sk', 'sl', 'sm', 'sn', 'so', 'sq',
  'sr', 'ss', 'st', 'su', 'sv', 'sw',
  'ta', 'te', 'tg', 'th', 'ti', 'tk', 'tl', 'tn', 'to', 'tr', 'ts', 'tt',
  'tw', 'ty',
  'ug', 'uk', 'ur', 'uz',
  've', 'vi', 'vo',
  'wa', 'wo',
  'xh',
  'yi', 'yo',
  'za', 'zh', 'zu',
};

/// ISO-639-2 (both the bibliographic and terminological forms) to ISO-639-1,
/// for every language that has a two-letter code. Older conversion
/// toolchains do emit three-letter declarations — `eng`, `deu`, `rus` — and
/// a mislabelled language would seed the wrong segmentation rules, not just
/// the wrong metadata.
const Map<String, String> _iso6392to1 = {
  'aar': 'aa', 'abk': 'ab', 'ave': 'ae', 'afr': 'af', 'aka': 'ak',
  'amh': 'am', 'arg': 'an', 'ara': 'ar', 'asm': 'as', 'ava': 'av',
  'aym': 'ay', 'aze': 'az',
  'bak': 'ba', 'bel': 'be', 'bul': 'bg', 'bih': 'bh', 'bis': 'bi',
  'bam': 'bm', 'ben': 'bn', 'bod': 'bo', 'tib': 'bo', 'bre': 'br',
  'bos': 'bs',
  'cat': 'ca', 'che': 'ce', 'cha': 'ch', 'cos': 'co', 'cre': 'cr',
  'ces': 'cs', 'cze': 'cs', 'chu': 'cu', 'chv': 'cv', 'cym': 'cy',
  'wel': 'cy',
  'dan': 'da', 'deu': 'de', 'ger': 'de', 'div': 'dv', 'dzo': 'dz',
  'ewe': 'ee', 'ell': 'el', 'gre': 'el', 'eng': 'en', 'epo': 'eo',
  'spa': 'es', 'est': 'et', 'eus': 'eu', 'baq': 'eu',
  'fas': 'fa', 'per': 'fa', 'ful': 'ff', 'fin': 'fi', 'fij': 'fj',
  'fao': 'fo', 'fra': 'fr', 'fre': 'fr', 'fry': 'fy',
  'gle': 'ga', 'gla': 'gd', 'glg': 'gl', 'grn': 'gn', 'guj': 'gu',
  'glv': 'gv',
  'hau': 'ha', 'heb': 'he', 'hin': 'hi', 'hmo': 'ho', 'hrv': 'hr',
  'hat': 'ht', 'hun': 'hu', 'hye': 'hy', 'arm': 'hy', 'her': 'hz',
  'ina': 'ia', 'ind': 'id', 'ile': 'ie', 'ibo': 'ig', 'iii': 'ii',
  'ipk': 'ik', 'ido': 'io', 'isl': 'is', 'ice': 'is', 'ita': 'it',
  'iku': 'iu',
  'jpn': 'ja', 'jav': 'jv',
  'kat': 'ka', 'geo': 'ka', 'kon': 'kg', 'kik': 'ki', 'kua': 'kj',
  'kaz': 'kk', 'kal': 'kl', 'khm': 'km', 'kan': 'kn', 'kor': 'ko',
  'kau': 'kr', 'kas': 'ks', 'kur': 'ku', 'kom': 'kv', 'cor': 'kw',
  'kir': 'ky',
  'lat': 'la', 'ltz': 'lb', 'lug': 'lg', 'lim': 'li', 'lin': 'ln',
  'lao': 'lo', 'lit': 'lt', 'lub': 'lu', 'lav': 'lv',
  'mlg': 'mg', 'mah': 'mh', 'mri': 'mi', 'mao': 'mi', 'mkd': 'mk',
  'mac': 'mk', 'mal': 'ml', 'mon': 'mn', 'mar': 'mr', 'msa': 'ms',
  'may': 'ms', 'mlt': 'mt', 'mya': 'my', 'bur': 'my',
  'nau': 'na', 'nob': 'nb', 'nde': 'nd', 'nep': 'ne', 'ndo': 'ng',
  'nld': 'nl', 'dut': 'nl', 'nno': 'nn', 'nor': 'no', 'nbl': 'nr',
  'nav': 'nv', 'nya': 'ny',
  'oci': 'oc', 'oji': 'oj', 'orm': 'om', 'ori': 'or', 'oss': 'os',
  'pan': 'pa', 'pli': 'pi', 'pol': 'pl', 'pus': 'ps', 'por': 'pt',
  'que': 'qu',
  'roh': 'rm', 'run': 'rn', 'ron': 'ro', 'rum': 'ro', 'rus': 'ru',
  'kin': 'rw',
  'san': 'sa', 'srd': 'sc', 'snd': 'sd', 'sme': 'se', 'sag': 'sg',
  'sin': 'si', 'slk': 'sk', 'slo': 'sk', 'slv': 'sl', 'smo': 'sm',
  'sna': 'sn', 'som': 'so', 'sqi': 'sq', 'alb': 'sq', 'srp': 'sr',
  'ssw': 'ss', 'sot': 'st', 'sun': 'su', 'swe': 'sv', 'swa': 'sw',
  'tam': 'ta', 'tel': 'te', 'tgk': 'tg', 'tha': 'th', 'tir': 'ti',
  'tuk': 'tk', 'tgl': 'tl', 'tsn': 'tn', 'ton': 'to', 'tur': 'tr',
  'tso': 'ts', 'tat': 'tt', 'twi': 'tw', 'tah': 'ty',
  'uig': 'ug', 'ukr': 'uk', 'urd': 'ur', 'uzb': 'uz',
  'ven': 've', 'vie': 'vi', 'vol': 'vo',
  'wln': 'wa', 'wol': 'wo',
  'xho': 'xh',
  'yid': 'yi', 'yor': 'yo',
  'zha': 'za', 'zho': 'zh', 'chi': 'zh', 'zul': 'zu',
};

/// Reduces [declared] to an ISO-639-1 code, or returns the normalized
/// [fallback] when it does not reduce to one.
///
/// Takes the primary subtag of a BCP-47 value (`en-GB` → `en`,
/// `zh-Hans-CN` → `zh`), lower-cases it, and maps an ISO-639-2 code to its
/// 639-1 equivalent (`eng` → `en`, `rus` → `ru`). A `null`, empty, or
/// unrecognisable [declared] yields the fallback.
///
/// [fallback] is normalized exactly like a declared value, and one that does
/// not reduce to ISO-639-1 throws [ArgumentError] — that is a caller
/// contract violation, not an expected parse outcome, and silently accepting
/// it would poison the language and the segmenter seeding of every book
/// parsed with it.
String normalizeLanguageCode(String? declared, {required String fallback}) {
  final normalizedFallback = _reduce(fallback);
  if (normalizedFallback == null) {
    throw ArgumentError.value(
      fallback,
      'fallback',
      'does not reduce to an ISO-639-1 language code',
    );
  }
  if (declared == null) return normalizedFallback;
  return _reduce(declared) ?? normalizedFallback;
}

/// The primary subtag of [value], lower-cased and mapped through ISO-639-2
/// when needed — or `null` when it is not an ISO-639-1 language.
String? _reduce(String value) {
  final primary = value.trim().split(_subtagSeparator).first.toLowerCase();
  if (_iso6391.contains(primary)) return primary;
  return _iso6392to1[primary];
}

final RegExp _subtagSeparator = RegExp(r'[-_]');

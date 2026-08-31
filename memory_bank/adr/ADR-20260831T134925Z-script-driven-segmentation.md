---
title: 'ADR-20260831T134925Z: Segmentation Is Script-Driven, Rule-Based, And Replaceable'
doc_kind: adr
doc_function: canonical
purpose: 'Records that sentence and word segmentation is decided by writing system rather than language, what the built-in rules cover, and why the segmenter is an injectable port.'
derived_from:
  - ../domain/model.md
  - ../product/value-proposition.md
canonical_for:
  - segmentation_decision
must_not_define:
  - document_model
  - public_api_surface
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T134925Z: Segmentation Is Script-Driven, Rule-Based, And Replaceable

## Context

Lazy segmentation into sentences and words is one of the four things the package
claims analogues lack. The implementation being extracted is 39 lines and two
regular expressions: sentences are runs ending in `.!?…` followed by whitespace
or end of text, words are Unicode letter/number runs allowing inner apostrophes
and hyphens.

Measured against the source on 2026-08-31, it takes no language parameter at
all. The boundary of what it handles is therefore not a language boundary but a
**writing-system** boundary:

| Script class | Sentences | Words |
| --- | --- | --- |
| Latin, Cyrillic, Greek, Armenian, Hebrew, Arabic, Devanagari — anything space-separated | split, but naively | correct |
| Chinese, Japanese | whole paragraph becomes one sentence: `。` is not in the terminator set, and nothing follows it that the lookahead accepts | whole run becomes one word |
| Thai, Khmer, Lao, Burmese | same | same |

Russian and English fail identically, on abbreviations and initials — `Mr. Smith`
and `т. д.` both split wrongly. Decimals such as `3.14` survive, because the
period is not followed by whitespace.

So the question is not "how good is it for language X" but how much of the
world's writing the package commits to, and how someone who needs more than
rules can get it without forking.

## Decision Drivers

- the package's stated goal is breadth: as many languages as rules can honestly
  serve;
- rules can carry every space-separated script and can split sentences in CJK,
  but no rule set segments Thai or Khmer words — that needs a dictionary;
- a dictionary or ICU dependency would be large and would not be pure Dart, so
  it cannot be a hard dependency ([product/context.md](../product/context.md));
- one script genuinely needs a language hint: modern Greek uses ASCII `;`
  (U+003B) as its question mark, which cannot go into a shared terminator class
  without breaking every other language;
- segmentation is lazy and per paragraph
  ([domain/model.md](../domain/model.md)), so whatever segments must be reachable
  from a paragraph at first access.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Ship the 39 lines as they are, document the boundary | No work; honest | Concedes every non-Latin, non-Cyrillic writing system for no reason — the terminator set is a data change, not a redesign | Rejected — the cheapest improvement is also the largest |
| Rules for every script, no extension point | Broad out of the box | Anyone needing dictionary-quality Thai must fork the package | Rejected — the ceiling is fixed by us for everyone |
| Bundle a dictionary or bind ICU | Correct word segmentation everywhere | Not pure Dart, or a large data payload, on a package whose selling point is that it is cheap to depend on | Rejected — violates the no-Flutter, small-dependency premise |
| **Expanded rules, script-driven, behind a replaceable port** | Broad default; honest ceiling; a caller who needs more supplies it without forking | More surface to document; the model must carry a reference to the segmenter | **Accepted** |

## Decision

Segmentation is decided by writing system, not by language, and ships in three
rule layers behind an injectable port.

**Layer 1 — terminators and boundaries.** Beyond `.!?…`, the sentence terminator
set includes the full-width and CJK stops `。！？．‼⁇⁈⁉`, the Indic danda `।` and
`॥`, Arabic and Urdu `؟` and `۔`, Armenian `։`, Ethiopic `።`, Tibetan `།` and
`༎`, Khmer `។`, and Burmese `။` and `၊`. After a wide or CJK terminator no
following whitespace is required, because those scripts do not use it. A
terminator may be followed by a closing quotation mark or bracket, and the
sentence boundary falls after it, not before.

Greek is the exception the rule cannot carry: `;` enters the terminator set only
when the language hint is `el`.

**Layer 2 — suppressing false splits.** No split when the token before the
period is a single letter, which covers initials (`J. R. R. Tolkien`,
`А. С. Пушкин`) and the common two-letter abbreviations built from them
(`т. д.`); no split when the next non-space character is lower case in a cased
script; and no split on an abbreviation supplied by the caller.

**Layer 3 — words in unspaced scripts.** Japanese is split at script
transitions, so kanji, hiragana and katakana runs become separate words. Chinese
takes one ideograph per word — not linguistically correct, but usable for
per-word lookup where a whole run is not. Thai, Khmer, Lao and Burmese get no
word rule at all: the run stays whole, and the package states that these are
sentence-level only.

**The port.** `TextSegmenter` is an interface with a rule-based default that
accepts an optional language hint and abbreviation set. A caller who needs
dictionary-quality segmentation supplies an implementation instead of forking.

What this does not do: dictionary or model-based word segmentation, and any
promise of linguistic correctness for the unspaced scripts named above. The
README describes support per writing system, never per language.

## Consequences

### Positive

- Every space-separated writing system is served, not only Latin and Cyrillic.
- Sentence splitting works in CJK, where it previously did not happen at all.
- Initials and lower-case continuations stop producing false sentence breaks,
  which is the most common defect in the current output in every language.
- The ceiling is the caller's to raise, so the package can stay small without
  capping quality.
- No dependency is added; all of this is rules over Unicode properties.

### Negative

- More rules mean more ways to be subtly wrong, and the failure is silent — a
  bad split produces a plausible sentence, not an error.
- The language hint makes output depend on `sourceLanguageCode`, so a
  misdetected language changes segmentation for Greek.
- `ParagraphBlock` must reach a segmenter to compute `sentences` lazily, so it
  stops being a pure value; that shape is owned by
  [domain/model.md](../domain/model.md).
- Because the segmenter travels inside the document, it constrains what an
  implementation may hold: plain data only, no compiled `RegExp` in instance
  fields, or the document stops crossing an isolate boundary. The failure appears
  at the caller's `Isolate.run` rather than at the segmenter, which makes it
  expensive to diagnose. The rule is stated on the model and covered by a test
  that parses inside an isolate with a custom segmenter.
- The per-ideograph rule for Chinese is a deliberate approximation, and someone
  will reasonably report it as a bug.

### Neutral / Organizational

- [domain/model.md](../domain/model.md) records how a paragraph reaches its
  segmenter; this ADR must not define the model.
- [engineering/public-api.md](../engineering/public-api.md) gains `TextSegmenter`
  and the default implementation.
- `DEC-01` in [FT-001/brief.md](../features/FT-001-extract-package/brief.md) is
  settled by this decision; `CHK-05` is checked against it.

## Risks And Mitigation

The main risk is over-claiming. A rule set covering fifteen terminators reads as
"works everywhere", and the layer-3 approximations do not. Mitigated by a README
table keyed on writing system with separate columns for sentences and words, and
by naming Thai, Khmer, Lao and Burmese explicitly as sentence-level only.

Second risk: layer 2 suppresses a real sentence break — a sentence genuinely
starting with a lower-case word, or after a single-letter abbreviation. Accepted
as the cheaper error: a missed split merges two sentences, while a false split
truncates one, and truncation is what a reader notices when tapping to translate.

## Follow-up

- The README carries the per-script support table; `CHK-05` verifies it.
- Tests cover one sample per script class, including a CJK paragraph and an
  initials case, alongside the laziness assertion required by `SC-05`.
- If a caller-supplied segmenter becomes common, a companion package for
  dictionary-based segmentation is the shape to reach for, not a fatter default.

## Related Links

- [domain/model.md](../domain/model.md) — lazy segmentation and
  paragraph-relative offsets.
- [product/value-proposition.md](../product/value-proposition.md) — lazy
  segmentation as a stated selling point.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) — `DEC-01`.

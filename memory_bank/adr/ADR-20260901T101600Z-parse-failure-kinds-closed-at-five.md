---
title: 'ADR-20260901T101600Z: ParseFailureKind Is Closed At Five, With drmProtected'
doc_kind: adr
doc_function: canonical
purpose: 'Records the final set of parse failure causes, why DRM earns its own kind, and why an encryption.xml alone must not be read as DRM.'
derived_from:
  - ../engineering/public-api.md
  - ../engineering/format-mapping.md
canonical_for:
  - parse_failure_kind_set
must_not_define:
  - public_api_surface
  - format_extraction_boundary
  - result_type_decision
status: active
decision_status: accepted
date: '2026-09-01'
audience: humans_and_agents
---
# ADR-20260901T101600Z: ParseFailureKind Is Closed At Five, With drmProtected

## Context

[ADR-20260831T140218Z](ADR-20260831T140218Z-parse-result-type.md) chose an enum
over a sealed hierarchy on the grounds that "adding a fifth cause should not
break every call site the way a new `Block` variant deliberately does". That
premise is false for the Dart 3 the package targets: an enum is an exhaustive
type exactly as a sealed class is, a `switch` expression over one must cover
every constant, and a fifth constant breaks any consumer who wrote the idiomatic
form. The correction is already recorded in
[public-api.md](../engineering/public-api.md); what it leaves behind is the real
question, opened as `OQ-14`. The set is closed before `0.1.0` or it costs a major
version.

The baseline is narrower than it looks. TeaderBook today has **one** cause for
every parse failure of either format — `FailureKind.bookParse`, at
`epub_parser.dart:48`, `:70` and `:94` and at `fb2_parser.dart:45`, `:79` and
`:96`. So the four kinds already proposed are a refinement rather than a
departure, and `NS-03` is not in play here: no set of kinds regresses against a
single undifferentiated one. The only thing at stake is which set.

The known gap is DRM. [format-mapping.md](../engineering/format-mapping.md)
routes a protected book to `corrupt`, which tells a reader application nothing it
can turn into a sentence — and an Adobe-ADEPT library loan is among the most
common failures a reader meets in the field. "This file is damaged" is the wrong
thing to say about a book that is intact and merely locked.

## Decision Drivers

- a `kind` exists so a consumer can say something specific in its own language;
  a kind that maps to the same sentence as another kind earns nothing;
- DRM is detectable without decrypting anything: OCF puts `META-INF/encryption.xml`
  in the container, and Adobe adds `META-INF/rights.xml`;
- the same `encryption.xml` also carries **font obfuscation**, which is not DRM
  and leaves the book perfectly readable — the package never reads fonts or CSS,
  so such a book must parse normally;
- FB2 has no encryption concept at all, so this kind is EPUB-only and that
  asymmetry is a format property, not an inconsistency;
- every added constant is a `switch` every consumer must extend, so the bar is a
  distinct consumer action, not a distinct internal cause.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Keep the four | Nothing to decide; smallest surface | A locked library loan reports as a damaged file, which is both wrong and unactionable — the single most common real-world failure misdescribed | Rejected |
| **Four plus `drmProtected`** | The one failure a reader app must explain differently gets its own branch; detection is cheap and needs no decryption | Requires distinguishing DRM from font obfuscation, or it refuses ordinary books | **Accepted** |
| Plus `unsupportedVersion` | Names a real class of file | No consumer action differs from `unsupportedFormat`; EPUB 3.x reads through the same path and EPUB 1.0 is extinct | Rejected — a constant nobody can branch on usefully |
| A sealed hierarchy instead | Cases could carry data | Identical exhaustiveness cost in Dart 3, and worse ergonomics for a consumer that wants a default branch | Rejected — the enum decision stands on its remaining leg |

## Decision

`ParseFailureKind` has exactly five constants and is closed for `0.1.0`:

`corrupt`, `unsupportedFormat`, `encoding`, `emptyDocument`, `drmProtected`.

`drmProtected` is returned when an EPUB container declares encryption over its
**content** — a `META-INF/encryption.xml` whose `EncryptionMethod` covers
publication resources, or the presence of `META-INF/rights.xml`. It is **not**
returned for font obfuscation: the IDPF and Adobe font-mangling algorithms
encrypt font resources only, the package reads neither fonts nor CSS, and such a
book parses normally with nothing missing from the model.

The distinction is the whole content of this decision. "An `encryption.xml`
exists" is the obvious test and the wrong one — it would refuse well-produced
books that merely obfuscate their embedded fonts.

`emptyDocument` is defined by
[ADR-20260901T101700Z](ADR-20260901T101700Z-empty-document-means-no-blocks.md),
not here.

## Consequences

### Positive

- A locked book produces a message a user can act on — find another copy, use
  the vendor's own reader — instead of "this file is damaged".
- Detection costs one container lookup and no decryption, on a path that already
  opens the container.
- The set is closed with a recorded reason for each exclusion, so the next
  candidate is argued against a document.

### Negative

- Five constants is five branches in every exhaustive `switch` a consumer writes,
  and this is now fixed for the major version.
- The font-obfuscation carve-out is a rule that can be got wrong quietly: a book
  with obfuscated fonts wrongly classified is refused outright, and the corpus
  cannot currently catch it.

### Neutral / Organizational

- [public-api.md](../engineering/public-api.md) owns the exported enum and is
  updated to list five constants.
- [format-mapping.md](../engineering/format-mapping.md) currently says a
  DRM-protected book "parses as corrupt" under Not Extracted; that line is
  corrected to name `drmProtected` and to state the font-obfuscation exception.
- `OQ-14` closes in the
  [implementation plan](../features/FT-001-extract-package/implementation-plan.md);
  `STEP-02` writes five constants rather than four.
- TeaderBook gains a fifth branch at `STEP-07`, where today it has one kind and
  one English string.

## Risks And Mitigation

**The font-obfuscation rule is judged, not measured.** No file among the 11
fetched corpus EPUBs contains a `META-INF/encryption.xml` at all, so the corpus
cannot confirm that the carve-out is drawn in the right place. This is recorded
in the same spirit as the ISO-639-2 limitation in
[public-api.md](../engineering/public-api.md): the frequency is unknown here and
the rule rests on the OCF specification rather than on evidence from this
collection. Mitigated by generated fixtures — an `encryption.xml` naming a font
resource and one naming a content document — which test the branch even though
no real file in the corpus does.

Second risk: a DRM scheme that leaves no `encryption.xml`. Such a book falls
through to `corrupt`, which is the status quo and not a regression.

## Follow-up

- `STEP-02` writes the five constants; `STEP-01a` adds the container check.
- Two generated fixtures cover obfuscated fonts and encrypted content, since the
  corpus supplies neither.
- The README's failure table lists all five with the consumer action each implies.

## Related Links

- [ADR-20260831T140218Z](ADR-20260831T140218Z-parse-result-type.md) — the result
  type whose enum this closes.
- [engineering/public-api.md](../engineering/public-api.md) — the exported enum.
- [engineering/format-mapping.md](../engineering/format-mapping.md) — the DRM line
  this corrects.

---
title: 'ADR-20260831T135025Z: The Package Validates Languages Against Full ISO-639-1'
doc_kind: adr
doc_function: canonical
purpose: 'Records that a book''s declared language is normalized to ISO-639-1 and accepted against the whole standard, and that narrowing to an application''s supported set is the caller''s job.'
derived_from:
  - ../product/context.md
  - ../domain/model.md
canonical_for:
  - language_resolution_decision
must_not_define:
  - document_model
  - public_api_surface
  - current_system_state
status: active
decision_status: accepted
date: '2026-08-31'
audience: humans_and_agents
---
# ADR-20260831T135025Z: The Package Validates Languages Against Full ISO-639-1

## Context

Both parsers resolve a book's declared language the same way today: take the
declared value, cut it at the first `-` or `_`, lower-case it, and accept it only
if `languageForCode` finds it in TeaderBook's catalog. Anything else becomes
`fallbackLanguageCode`.

That catalog is the app's list of 59 languages, copied from ML Kit's on-device
translator, and it drags in the app's localisation helper and `Language` model.
It cannot follow the code into the package (`REQ-02`), so the package needs a
policy of its own — and whatever it picks is observable, because the app reads
`sourceLanguageCode` from every book it imports.

## Decision Drivers

- 59 languages is a constraint of a *translator*, not of a *parser*; a package
  that returns a fallback for a book in Latin or Icelandic behaves oddly for a
  consumer that does no translation at all;
- the package needs only to validate a code, never to display a language name,
  so it needs no names and no localisation;
- carrying a copy of another product's supported-language list means tracking
  someone else's release cycle;
- `NS-03` asks for no behaviour change, and any policy here changes TeaderBook's
  behaviour for at least some books.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| Copy the 59-language catalog into the package | Behaviour identical for TeaderBook | Bakes a translator's limits into a parser; needs maintenance against ML Kit; wrong for every other consumer | Rejected — the wrong list for the wrong reason |
| No validation: return the normalized code as declared | Simplest; nothing to maintain | A malformed or invented `xx-YY` reaches the caller as if it were a language; the fallback parameter loses most of its purpose | Rejected — the caller asked for a fallback and should get one |
| Caller supplies a predicate | Preserves any caller's behaviour exactly | An extra required concept in the API for a problem most callers do not have | Kept as a possible future addition, not shipped |
| **Validate against the whole of ISO-639-1** | One flat set, about a kilobyte, no names, no maintenance; correct for any consumer | Wider than any one consumer's needs, so consumers that care must narrow it themselves | **Accepted** |

## Decision

The package normalizes a declared language to ISO-639-1 and accepts it if it is
in the standard; otherwise it returns `fallbackLanguageCode`.

Normalization takes the primary subtag of a BCP-47 value and lower-cases it, so
`en-US` becomes `en` and `zh_Hans` becomes `zh`. An absent, empty, or unknown
value yields the fallback.

Amended 2026-09-01, closing `OQ-24` and `OQ-23`: normalization also maps an
ISO-639-2/B code to its 639-1 equivalent before validating — `eng`, `deu` and
`rus` from older toolchains resolve to the language they declare rather than to
the fallback — and `fallbackLanguageCode` itself is held to the same contract,
throwing `ArgumentError` when it does not reduce to ISO-639-1. Both are
recorded with their reasoning in [public-api.md](../engineering/public-api.md)
(`DEC-29`, `DEC-28`).

The validation set is the full ISO-639-1 code list — codes only, no display
names and no localisation. Narrowing to what a particular application supports
is the caller's job, done at the call site where the application's own catalog
already lives.

TeaderBook keeps its current behaviour with one line at the import call site:
resolve the document's language against its own catalog and substitute its own
fallback when it is not there. This is a deliberate, named deviation from
`NS-03`: the package's answer widens, and the app narrows it back.

## Consequences

### Positive

- The package is correct for consumers that never translate anything.
- No dependency on another product's release cycle.
- No localisation surface: the package never needs a language *name*.
- The rule is one sentence long and testable in isolation.

### Negative

- TeaderBook must narrow the result itself, so `STEP-07` includes a call-site
  change rather than a pure import swap.
- A consumer that forgets to narrow will see codes its own stack cannot handle,
  and the failure surfaces downstream rather than at parse time.
- The ISO-639-1 list is static data in the package and will need a revision if
  the standard is amended.

### Neutral / Organizational

- [engineering/public-api.md](../engineering/public-api.md) records the
  normalization entry point; this ADR does not define the surface.
- `REQ-02` in [FT-001/brief.md](../features/FT-001-extract-package/brief.md)
  names the catalog as a coupling to remove; `DEC-03` is settled here.
- `CHK-03`'s grep gate includes `languageForCode` so the coupling cannot return
  unnoticed.

## Risks And Mitigation

The risk is a silent behaviour change at `STEP-07`: books whose declared
language is valid ISO-639-1 but outside TeaderBook's 59 would arrive with a
language the app cannot translate, where previously they arrived with the
fallback. Mitigated by making the narrowing explicit at the import call site and
covering it with an app-side test, rather than relying on the package to enforce
someone else's list.

## Follow-up

- The package ships the ISO-639-1 code set as internal static data.
- TeaderBook narrows at the import call site in `STEP-07`, with a test.
- If more than one consumer needs a different acceptance rule, add the optional
  predicate that was considered and deferred here.

## Related Links

- [product/context.md](../product/context.md) — the no-references-to-TeaderBook
  constraint this decision serves.
- [domain/model.md](../domain/model.md) — `sourceLanguageCode` on the document.
- [FT-001/brief.md](../features/FT-001-extract-package/brief.md) — `DEC-03`,
  and the `NS-03` deviation it is named under.

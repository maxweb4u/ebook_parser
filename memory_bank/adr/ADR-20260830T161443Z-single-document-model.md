---
title: 'ADR-20260830T161443Z: Both Formats Converge On One Document Model'
doc_kind: adr
doc_function: canonical
purpose: 'Records why EPUB and FB2 parse into a single shared document model rather than two parallel type trees, and what that costs.'
derived_from:
  - ../product/value-proposition.md
canonical_for:
  - single_model_decision
must_not_define:
  - current_system_state
  - implementation_plan
  - document_model
status: active
decision_status: accepted
date: '2026-08-30'
audience: humans_and_agents
---

# ADR-20260830T161443Z: Both Formats Converge On One Document Model

## Context

EPUB and FB2 are structurally unlike each other. EPUB is a zip container of
XHTML documents tied together by a manifest and spine; FB2 is a single XML file
with its own body and section elements. A parser for each produces a natural,
format-shaped result, and those two results have almost nothing in common.

The question is what the package hands back. Either each format keeps its own
type tree and the caller reconciles them, or both parsers converge on one shared
model and the reconciliation happens once, inside the package.

This is not an implementation detail. EPUB packages on Dart already exist; what
they lack is agreement, because each returns its own model. If this package
returns two models it reproduces exactly the problem it was extracted to solve.

## Decision Drivers

- code above the parsing layer should be written once and not branch by format;
- the package's stated value is convergence, not the parsing of either format
  alone (see [value-proposition.md](../product/value-proposition.md));
- callers frequently do not know the format in advance — detection is by magic
  bytes, so the type cannot be known statically at the call site;
- a third format (MOBI, TXT) must be addable without changing consumer code.

## Options Considered

| Option | Pros | Cons | Verdict |
| --- | --- | --- | --- |
| Two parallel type trees (`EpubDocument`, `Fb2Document`) | Each is faithful to its format; no information is lost in translation | Every consumer branches by format forever; a third format multiplies the branching; `bookParserFor` cannot return a useful common type | Rejected |
| One shared model, format-specific extras exposed via an escape hatch | Convergence plus fidelity for callers who need it | The escape hatch is where format branching returns, quietly, and the shared model stops being authoritative | Rejected for now |
| **One shared model, no format-specific surface** | Consumers are written once; detection can return a single port type; a third format is additive | Format-specific information not in the model is lost | **Accepted** |

## Decision

Both parsers produce the same document model. The types are owned by
[domain/model.md](../domain/model.md); this decision records only that there is
one such model and that it is the sole result type.

The consequence that makes it real: `IBookParser.parse` returns
`ParseResult<BookDocument>` for every format, and the format-specific parsers
are the only files in the package that know a format exists. Nothing above them
branches.

Format-specific data that does not fit the model is dropped rather than exposed
alongside it. An escape hatch was considered and rejected for now, because it
reintroduces format branching in consumer code while appearing not to.

## Consequences

### Positive

- Consumer code is written once against one model, which is the package's whole
  premise rather than a convenience.
- `bookParserFor` can return a single port type, so magic-byte detection and
  static typing coexist: the caller never learns which format won.
- Adding a third format is additive — a new parser, no consumer changes — which
  is what the format-neutral package name assumes
  ([ADR-20260830T161251Z](ADR-20260830T161251Z-package-name-ebook-parser.md)).
  Scoped on 2026-09-01, closing `OQ-19`: the promise holds for formats that are
  not zip containers. A zip-native format — FB3, CBZ — needs a new case in the
  sealed `ArchiveContent`
  ([ADR-20260831T135425Z](ADR-20260831T135425Z-archive-layer-is-public.md)),
  which is a breaking change by design. Generalising `EpubArchive` into a
  format-tagged container case was considered and declined: the named case's
  ergonomics today were preferred, and the major-version cost of a future
  container format is accepted knowingly rather than discovered.

### Negative

- Format-specific richness is lost. FB2 and EPUB metadata that the shared model
  does not represent has no way to reach the caller.
- The model becomes a bottleneck for change: supporting anything new means
  changing a type that both parsers and every consumer depend on.
- Each parser carries translation code that a format-native parser would not
  need, and translation is where format-specific bugs will concentrate.

### Neutral / Organizational

- `domain/model.md` owns the model's shape; this ADR must not restate it.
- The README's comparison against existing EPUB packages rests on this
  decision, since convergence is the stated differentiator.

## Risks And Mitigation

The real risk is pressure to widen the model for one format's benefit, one
field at a time, until it is a union of both formats rather than a shared
abstraction. Mitigation is procedural, not technical: a field that only one
format can populate is a signal to reconsider, and `Block` being sealed means
adding a variant breaks every consumer loudly rather than silently.

Information loss is accepted knowingly. If a concrete caller need appears that
the model cannot serve, that is grounds for a follow-up ADR revisiting the
escape hatch, not for widening the model quietly.

## Follow-up

- The README must state which format-specific data is not surfaced, so the loss
  is documented rather than discovered.
- Tests assert that a `.fb2.zip` and its unpacked `.fb2` produce the same
  result — the narrowest available check that convergence actually holds.

## Related Links

- [product/value-proposition.md](../product/value-proposition.md) — convergence
  as the package's premise.
- [domain/model.md](../domain/model.md) — the model itself.
- [engineering/public-api.md](../engineering/public-api.md) — the port that
  returns it.
- [ADR-20260830T161251Z](ADR-20260830T161251Z-package-name-ebook-parser.md) —
  the format-neutral name this decision underwrites.

---
title: A Corpus Run That Only Asks "Did It Parse" Will Pass On A Book Of Replacement Characters
doc_kind: process
doc_function: canonical
purpose: 'Read before trusting a corpus run as evidence, or before adding a fixture for a case: the two mislabelled-encoding fixtures reported ok in every run for a day, because the runner asserted that parsing returned a value and never looked at the value.'
derived_from:
  - ../engineering/testing-policy.md
canonical_for:
  - corpus_assertion_rule
status: active
---
# A Corpus Run That Only Asks "Did It Parse" Will Pass On A Book Of Replacement Characters

Found 2026-09-02, when `STEP-07` ran TeaderBook on the published package and a
library card came back reading `������ ��6`.

## What Happened

`STEP-00b` collected the corpus and deliberately derived four Chekhov variants
to cover legacy encodings: correctly declared cp1251, correctly declared
koi8-r, **cp1251 mislabelled as UTF-8**, and **cp1251 with no declaration at
all**. The last two exist precisely because someone anticipated the failure.

Every `CHK-07` run reported all four as `ok`. The report even printed their
titles — `"title": "������ ��6"` — and the summary line that everyone read
said *652 ok, 0 errors, 0 throws*.

The fixture was right. The corpus was right. The assertion was
`result is ParseOk`, and `ParseOk` is exactly what a book of replacement
characters comes back as.

## The Rule

**A corpus run is evidence about the property it asserts, and about nothing
else.** "It parsed" is a liveness property. Almost every interesting defect in
a parser is a correctness property: what came out is the book that went in.

Concretely, for this project:

- A derived fixture is created *to make an outcome distinguishable*. Deriving
  it and then asserting only that it parses throws the distinction away. If a
  variant exists to test recovery, something has to compare it against the
  variant it was derived from.
- Where the corpus holds a pair — the same book under two encodings, one
  correct and one broken — the runner can assert equality between them without
  knowing anything about the content. That is nearly free and would have caught
  this on the day the fixtures landed.
- Where no pair exists, cheap content invariants still beat none: a title that
  is not empty, a body that is not majority U+FFFD, a chapter count above zero.

## Why Five Review Passes Missed It

Worth recording, because the reviews were not lazy. `STEP-00d` and `STEP-00e`
read the decisions against each other, as
[review-decisions-against-each-other.md](review-decisions-against-each-other.md)
prescribes, and that is the pass that finds seams between documents. This
defect sat in no seam. Every document said the right thing — `format-mapping.md`
documented the encoding table correctly, and the doc comment on
`decodeFb2Bytes` even explained that an unsupported declaration is refused
"rather than silently decoding wrong". The code did something the documents
never claimed, in a case the documents never named.

Reviews compare artefacts to each other. Only running the thing compares the
artefact to reality. Both are needed, and the second one arrived in the shape
of a consumer with a device — which is the strongest argument for finishing
`STEP-07` early rather than treating it as cleanup after publication.

## Related

[measure-in-the-unit-the-decision-turns-on.md](measure-in-the-unit-the-decision-turns-on.md)
is the same failure one step upstream: a survey that counts the easy unit
answers a question nobody asked. This one is a runner that asserts the easy
property.

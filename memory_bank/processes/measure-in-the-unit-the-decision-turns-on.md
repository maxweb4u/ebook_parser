---
title: 'Survey In The Unit The Decision Will Turn On, Not The Unit That Is Easy To Count'
doc_kind: process
doc_function: canonical
purpose: 'Read before writing a corpus survey script, or before closing a question on survey data: the FB2 survey counted images where the decision turned on bytes, and the count pointed the opposite way.'
derived_from:
  - ../engineering/corpus-findings.md
canonical_for:
  - survey_unit_rule
status: active
---
# Survey In The Unit The Decision Will Turn On, Not The Unit That Is Easy To Count

The `STEP-00b` survey measured how many FB2 books contain `<image>`/`<binary>`
and how many each contains: **98% of books, median 1, max 660**. Those numbers
were then quoted three times — in `corpus-findings.md`, in `public-api.md`, and
in the `OQ-15` question itself — as the evidence that embedding images in the
encoded document would be ruinous.

Closing `OQ-15` on 2026-09-01 required bytes, so 247 files were re-measured:

| Measure | Value |
| --- | --- |
| Files with any `<binary>` | 98% |
| Files with **inline** (non-cover) images | **46%** |
| base64 share of the file | median 13.6%, p90 80.5%, max 95.7% |
| inline-only share | median **0%**, p90 73.2%, max 94.3% |

The count and the byte measure tell different stories, and the count tells the
wrong one twice over. "98% carry binaries" reads as *nearly every book is
affected*; in bytes, **half the collection carries a cover and nothing else** and
pays nothing at all. And "median 1" reads as *the volume is negligible*; in bytes
the median book is already 13.6% base64, and the top decile is over 80%.

Neither number is false. The survey answered "how many" correctly and the
decision needed "how much" — and the distribution turned out to be bimodal, which
no count of any kind could have shown.

## Why This Is Not The Same As The Sibling Rules

[verify-source-behaviour-before-recording-it.md](verify-source-behaviour-before-recording-it.md)
guards the premise an ADR takes from outside the bank, and
[review-decisions-against-each-other.md](review-decisions-against-each-other.md)
guards the premise it takes from another ADR. This one guards the premise it
takes from the bank's own **evidence** — a survey that is accurate, reproducible,
and measuring the wrong quantity. That failure is harder to see than the other
two, because the number is right there with a script behind it, and a number with
a script behind it does not look like an assumption.

## Suggested Standing Rule, If Promoted

Before a survey script is written, name the decision it is being collected for
and the unit that decision will be argued in. Counts answer "how many books are
affected"; bytes, milliseconds and depths answer "how much does it cost". A
question about cost is never closed on a count.

Where a survey is already written and a new question arrives, the cheap move is
to re-measure rather than to reason from the numbers on hand — the FB2
re-measurement above was one script and a few minutes, against a decision that
would have been fixed for a major version.

And when a measurement is quoted onward into other documents, it carries its unit
with it. "98% of FB2 books carry binaries" has now been repeated in three
documents as support for an argument about size, which is how a count becomes a
premise nobody re-examines.

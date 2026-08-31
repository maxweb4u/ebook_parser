---
title: 'Review Passes Pay At Falling Rates, And The Last Defect Was Between Rules, Not Documents'
doc_kind: process
doc_function: canonical
purpose: 'Read when deciding whether another architecture review pass is worth running, or at what granularity to compare decisions: the measured yield across three passes and where the final defect hid.'
derived_from:
  - ../processes/review-decisions-against-each-other.md
status: draft
---
# Review Passes Pay At Falling Rates, And The Last Defect Was Between Rules, Not Documents

Three parallel review passes ran over the FT-001 decisions, and their yield is
worth keeping because a future session cannot re-derive it without redoing the
reviews:

- **Pass 1 (2026-08-31)** — ADRs read against each other: 12 defects, of which
  4 were major-version-costing (`OQ-14`..`OQ-18` and amendments).
- **Pass 2 (2026-09-01)** — ADRs read against the canonical engineering
  documents: 7 defects (`OQ-19`..`OQ-25`), one of them a promise
  (additive formats) contradicted by a published sealed type.
- **Pass 3 (2026-09-01, same day)** — previously unread ADRs in full, plus the
  pass's own edits re-checked: 1 real defect (`OQ-26`/`DEC-31`), 3 loose ends
  of pass 2's own closures, 2 hygiene items.

Two refinements to [review-decisions-against-each-other.md](review-decisions-against-each-other.md)
if it is ever amended:

- **The granularity shrank each pass.** Pass 1 compared documents, pass 2
  compared a document against its derived canon, pass 3 found its defect by
  composing *individual rules* — rule 4 of the chapter-granularity ADR against
  the empty-chapter drop of another ADR. The last hiding place is
  rule-by-rule composition inside already-reviewed pairs; and a closure pass
  is itself review input (three of pass 3's findings were pass 2's own edits).
- **The yield curve argues for stopping after a pass that finds only hygiene.**
  12 → 7 → 1 real defect; a fourth pass over the same corpus of decisions
  would likely return polish. The cheaper continuation is reviewing the *next*
  artifact (the code of `STEP-01`) against the decisions, not the decisions
  against each other again.

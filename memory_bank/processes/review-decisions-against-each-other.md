---
title: Decisions Taken Serially Have To Be Reviewed In Parallel
doc_kind: process
doc_function: canonical
purpose: 'Read before an architecture review, or before declaring a decision pass complete: every defect found on 2026-08-31 was in a seam between two ADRs, not inside either one.'
derived_from:
  - verify-source-behaviour-before-recording-it.md
canonical_for:
  - parallel_decision_review_rule
status: active
---
# Decisions Taken Serially Have To Be Reviewed In Parallel

A review on 2026-08-31 read the accepted FT-001 decisions against each other
rather than one at a time. Twelve defects came out, and the striking thing is
that **none of them was inside a decision**. Every one sat in a seam between two
decisions taken at different moments, each correct when written.

- [ADR-20260831T135325Z](../adr/ADR-20260831T135325Z-optional-serialization-library.md)
  (serialization) argues its whole size case about sentence spans and does not
  contain the word "image". `DEC-10` made `ImageBlock` something both readers
  produce — an hour later by timestamp, `144622Z` against `135325Z`. Neither ADR
  is wrong; the cache is now larger than the book it caches, and nobody owned
  that fact. Opened as `OQ-15`, and closed on 2026-09-01 by measurement rather
  than by argument.
- `DEC-11` described the EPUB heading heuristic as *suppressing* a heading;
  `corpus-findings.md`, written later against the same source, described it as
  *injecting* one. Both documents were active, both were canonical, and they
  said opposite things about observable behaviour.
- `ParseFailureKind` chose an enum over a sealed hierarchy on the grounds that
  adding a case later would not break consumers. True of Dart 2, false of the
  Dart 3 the package targets — the decision was internally coherent and rested
  on an unstated premise about the language.
- `DEC-17` invalidates index-keyed reading positions, `brief.md` says so, and
  `STEP-07`'s checklist never acquired the item. The fact was recorded in the
  document that reasons and missing from the document that acts.

## What Happened To Them

All five questions the review opened were settled on 2026-09-01 as `STEP-00d`,
and the split is the part worth keeping. **Four of the five were genuine
compatibility promises** — the failure enum, model equality, the encoded form,
and the definition of `emptyDocument` — meaning answering them after `0.1.0`
would have cost a major version rather than an edit. One, the FB2 metadata cost,
turned out on inspection not to be a contract at all: the signature is identical
whichever way it is implemented, so it could have waited.

That ratio is the argument for the rule. A review that finds four
major-version-costing defects in the seams of seventeen ADRs is not finding
polish; and the one false positive cost nothing to examine.

The common shape: an ADR is written to be self-contained and reviewed on its own
terms, and that is exactly what makes it blind to what a neighbouring ADR
decided afterwards. A decision pass that produces N sound ADRs produces roughly
N²/2 unexamined pairs, and the pairs are where the cost lands — after
publication, when `Block`, `ArchiveContent` and the encoded form have all become
compatibility promises.

Suggested standing rule, if this is promoted: a decision pass is not complete
when every decision is accepted. It is complete when the later decisions have
been read against the earlier ones, with attention to any ADR whose reasoning
predates a decision that changed what it reasons about — the timestamps in the
filenames make that ordering readable at a glance. The specific question worth
asking of each pair: *does the later decision put something into the earlier
one's scope that the earlier one never considered?*

This is the sibling of
[verify-source-behaviour-before-recording-it.md](verify-source-behaviour-before-recording-it.md).
That one guards the premise an ADR rests on outside the bank; this one guards
the premise it rests on inside it.

The continuation this document predicted — reviewing the next artifact against
the decisions — ran on 2026-09-01, and the measured yield curves are worth
keeping because they cannot be re-derived without redoing the reviews. The
architecture passes paid at falling rates: 12 defects (pass 1, ADRs against
each other), 7 (pass 2, ADRs against the canonical engineering documents,
`OQ-19`..`OQ-25`), 1 real defect (pass 3, previously unread ADRs in full plus
the pass's own edits re-checked — three of its findings were pass 2's own
closures, so a closure pass is itself review input). The granularity shrank
each pass — documents, then document-against-canon, then *individual rules*
composed across already-reviewed pairs — so the last hiding place is
rule-by-rule composition. The code review that followed (seven adversarial
passes over the STEP-01..05 implementation) repeated the shape: 4 → 7 → 7 → 3 →
2 → 1 → 0 confirmed bugs, stopping at the first clean pass. Both series argue
the same stopping rule: stop after a pass that finds only hygiene, and spend
the next pass on the next artifact rather than on the same one again.

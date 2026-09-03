---
title: A Cross-Repository Inventory Fails Exactly In The Facts Only The Far Side Holds
doc_kind: process
doc_function: canonical
purpose: 'Read before writing a work order against a repository this session cannot open: the STEP-07 handoff was wrong in three places on 2026-09-01 and all three were app-side facts, not reasoning — the shape is predictable and can be guarded against.'
derived_from:
  - ../processes/verify-source-behaviour-before-recording-it.md
status: draft
---
# A Cross-Repository Inventory Fails Exactly In The Facts Only The Far Side Holds

Captured 2026-09-02, from the `D-2` half of the defect report `STEP-07` sent
back. The corrections themselves are already in
[step-07-teaderbook-handoff.md](../features/FT-001-extract-package/step-07-teaderbook-handoff.md);
this note is the pattern, which outlives that document.

## What Happened

`step-07-teaderbook-handoff.md` was written from the package repository to be
obeyed by a session rooted at the app, and it opened by saying its inventory
had been "re-verified against the app on 2026-09-01, not inherited". It was
still wrong in three places:

1. it listed five departing dependencies and missed `xml`, which — like
   `archive` — does not merely become dead weight but blocks `pub get`;
2. it described stored reading positions as chapter indices; the app stores a
   flat block index, which makes the first remedy it proposed impossible
   rather than merely awkward;
3. it told the reader to render `Chapter.title` itself, which is right for
   EPUB and prints every FB2 heading twice.

## The Pattern

**None of the three was a reasoning error.** Every decision the handoff cited
was correct, every rationale held, and the document was internally consistent.
All three errors were *facts about the far repository* — its pubspec, its
persistence schema, its widget tree — checked once, from a session that could
open the files but had not run the thing.

The failure mode is not carelessness, it is asymmetry: the side that writes
the work order knows the reasoning best and the facts worst, and the two are
indistinguishable in the finished prose.

## What To Do Instead

- **Mark the boundary in the document itself.** Separate "this follows from a
  decision" from "this is what the other repository currently contains", so a
  reader on the far side knows which claims they are expected to re-check
  before acting and which they can take on trust.
- **Let the far side own its own inventory.** A dependency list, a storage
  schema, a call-site count — write these as questions the receiving session
  answers first, not as answers it merely obeys.
- **Expect corrections to come back, and take them.** All three surfaced only
  because the app-side session recorded them as defects instead of quietly
  working around them. A work order that is never contradicted has probably
  not been executed carefully.

This is the cross-repository sibling of
[verify-source-behaviour-before-recording-it.md](../processes/verify-source-behaviour-before-recording-it.md),
which says the same thing about an ADR resting on unverified source behaviour
inside one repository. It is also why
[step-07-crosses-into-a-bank-that-collides-with-this-one.md](step-07-crosses-into-a-bank-that-collides-with-this-one.md)
sits in this same quarantine: both are about the seam between the two banks,
and whether that seam deserves a permanent process document is a review
decision, not mine.

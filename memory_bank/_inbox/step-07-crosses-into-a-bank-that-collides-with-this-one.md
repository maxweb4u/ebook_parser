---
title: STEP-07 Crosses Into A Second Memory Bank Whose Identifiers Collide With This One
doc_kind: process
doc_function: canonical
purpose: 'Read before starting STEP-07 or briefing any session against TeaderBook: FT-001 names a different feature in each bank, the app repository has no bank_* tools at all, and FT-001''s closure stays owned here.'
derived_from:
  - ../features/FT-001-extract-package/implementation-plan.md
status: draft
---
# STEP-07 Crosses Into A Second Memory Bank Whose Identifiers Collide With This One

Surveyed 2026-09-01, when `STEP-06` finished and the question of where to run
`STEP-07` came up. These are properties of the two repositories as they stand,
not a decision about which session does the work.

## FT-001 means two different features

TeaderBook's bank holds 42 feature packages, and its own `FT-001` is
`FT-001-library-book-import`. This bank's `FT-001` is the extraction. So the
bare token `FT-001` is ambiguous the moment work crosses over, and an agent told
to "continue FT-001" in a TeaderBook session would open a different feature and
be entirely right to. Anything written for that side must say
"`ebook_parser` FT-001" or avoid the token. The app-side work needs its own
identifier in that bank; the first free one on 2026-09-01 was `FT-043`.

## The app repository cannot reach this bank, or any bank

`readtolearn/frontend` has no `.mcp.json`, so a session rooted there starts with
no `bank_*` tools — not merely without this bank, but without its own. Its
`memory_bank/` is therefore reachable only as ordinary files unless a server is
configured. The consequence for a handoff is concrete: the `STEP-07` work list
in the implementation plan hangs on `DEC-05`, `DEC-06`, `DEC-11`, `DEC-13`,
`DEC-17`, `DEC-18`, `DEC-20`, `DEC-26` and `DEC-31`, and none of those
references resolve on the other side. A brief written for that session has to
carry its reasoning inline rather than cite it.

Two further facts about that repository, both true on 2026-09-01: its git root
is `frontend`, not `readtolearn`, and it sits on branch `dev`, 25 commits ahead
of `origin/dev`.

## Closure stays here

`EVID-05` and `EC-01` are owned by this bank, so however the app-side work is
run, FT-001 is not closed by finishing it — someone has to come back and record
it here. Publication did not close the feature and neither will the refactor
until that return trip happens.

## The two banks already overlap unknowingly

TeaderBook carries `FT-038-more-book-formats`; this bank carries
`engineering/new-format-candidates.md`, which assesses MOBI/AZW3, TXT, FB3, CBZ
and PDF against the surfaces frozen at `0.1.0` and defers all of them for
roughly five releases. They are about the same question and neither references
the other. Worth reconciling before either is acted on, rather than discovering
it when the app plans a format the package has already ruled out.

---
title: Verify Current Behaviour Before An ADR Rests On It
doc_kind: process
doc_function: canonical
purpose: Read before writing an FT-001 ADR that claims what TeaderBook does today — two accepted ADRs had to be amended because their premise about the source was never checked.
derived_from:
  - ../features/FT-001-extract-package/brief.md
canonical_for:
  - source_behaviour_verification_rule
status: active
---
# Verify Current Behaviour Before An ADR Rests On It

`NS-03` makes every FT-001 decision an argument about how far it departs from
what TeaderBook does today. That makes "what the source does" a load-bearing
premise, and on 2026-08-31 two ADRs were written with it guessed rather than
read. Both had to be amended after acceptance.

- `ADR-20260831T162951Z` assumed FB2 note bodies were already extracted and only
  needed documenting. `fb2_parser.dart` contains
  `if (body.getAttribute('name') == 'notes') continue;` — it drops them. The rule
  is a behaviour change affecting 9% of the local FB2 collection.
- `ADR-20260831T173725Z` stated that spine granularity "matches the source".
  `epub_parser.dart` iterates `book.Chapters`, epubx's navigation-derived tree,
  and never reads the spine. The premise was backwards, and correcting it moved
  the `NS-03` deviation from the granularity to rule 2 — which then needed a
  second ADR.

Both checks were single greps and took under a minute each. Neither was hard;
both were skipped because the claim felt safe.

The cost is not the amendment itself. It is that an ADR carrying `decision_status:
accepted` reads as settled, so a wrong premise inside one propagates into the
brief, the plan and the next decision before anyone re-reads it.

## The Rule

An FT-001 ADR asserting what the source does today names the file and quotes the
line. A claim that cannot be quoted is written as an assumption carrying an
`ASM-` id, not as a fact.

The source it is checked against is the local TeaderBook checkout, whose path the
[implementation plan](../features/FT-001-extract-package/implementation-plan.md)
records beside its Current State table.

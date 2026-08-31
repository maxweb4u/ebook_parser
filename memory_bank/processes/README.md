---
title: Process Registry
doc_kind: process
doc_function: index
purpose: Registry of durable working processes and session protocols.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---
# Process Registry

Read when you need a recurring procedure rather than a one-off decision.

## Registry

Three rules, and they guard three different premises: one taken from outside the
bank, one taken from another decision inside it, and one taken from the bank's own
evidence.

- [Verify Current Behaviour Before An ADR Rests On It](verify-source-behaviour-before-recording-it.md) — Read before writing an FT-001 ADR that claims what TeaderBook does today — two accepted ADRs had to be amended because their premise about the source was never checked.
- [Decisions Taken Serially Have To Be Reviewed In Parallel](review-decisions-against-each-other.md) — Read before an architecture review, or before declaring a decision pass complete: every defect found on 2026-08-31 was in a seam between two ADRs, not inside either one.
- [Survey In The Unit The Decision Will Turn On, Not The Unit That Is Easy To Count](measure-in-the-unit-the-decision-turns-on.md) — Read before writing a corpus survey script, or before closing a question on survey data: the FB2 survey counted images where the decision turned on bytes, and the count pointed the opposite way.

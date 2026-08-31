---
title: "ADR-ID: Short Decision Name"
doc_kind: adr
doc_function: template
purpose: Governed wrapper template for ADRs. Read this to instantiate a decision record without mixing wrapper-document metadata with the future ADR frontmatter.
derived_from:
  - ../../../dna/governance.md
  - ../../../dna/frontmatter.md
status: active
audience: humans_and_agents
template_for: adr
template_target_path: ../../../adr/ADR-<timestamp>-short-decision-name.md
---

# ADR-ID: Short Decision Name

This file describes the wrapper template. The instantiated ADR lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

`decision_status: proposed` in the embedded contract below means the ADR text is a proposal and is not considered an accepted decision until the instantiated ADR is moved to `accepted`.

Replace `ID` with a UTC timestamp in `YYYYMMDDTHHMMSSZ` format, for example `20260706T102415Z`. Do not allocate a local monotonic sequence number.

## Instantiated Frontmatter

```yaml
title: "ADR-ID: Short Decision Name"
doc_kind: adr
doc_function: canonical
purpose: "Records an architecture or engineering decision, its current `decision_status`, and consequences."
derived_from:
  - ../features/FT-XXX/brief.md
status: draft
decision_status: proposed
date: YYYY-MM-DD
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
```

## Instantiated Body

```markdown
# ADR-ID: Short Decision Name

## Context

Which problem, constraint, trade-off, or architecture tension needs to be resolved.

## Decision Drivers

- which requirements or constraints influence the choice;
- which KPIs, operational factors, or product factors matter;
- which dependencies and already accepted decisions must be considered.

## Options Considered

| Option | Pros | Cons | Why considered a primary candidate / not a primary candidate |
| --- | --- | --- | --- |
| `Option A` | What it gives | Which constraints it creates | Reason for the decision |

## Decision

For `decision_status: proposed`, describe the proposed decision here and avoid final-choice language (`chosen`, `finally rejected`, `accepted`) until the ADR is moved to `accepted`. After moving the ADR to `accepted`, update the wording so this section records the accepted decision, its boundaries, and affected components.

## Consequences

### Positive

What becomes simpler, improves, or becomes possible.

### Negative

Which constraints, debt, or additional costs appear.

### Neutral / Organizational

Which documents, processes, or ownership areas must be updated after acceptance.

## Risks And Mitigation

Which risks remain after the choice and how we reduce them.

## Follow-up

Which downstream documents, tasks, benchmarks, or migrations must follow this decision.

## Related Links

- feature `brief.md` / `design.md` / analysis documents that provide context;
- related ADRs, if the decision depends on them or refines them.
```

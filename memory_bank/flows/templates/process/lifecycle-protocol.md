---
title: "PROCESS-ID: Lifecycle Protocol"
doc_kind: process
doc_function: template
purpose: Governed wrapper template for a full lifecycle protocol. Read this when a process moves through phases, gates, verification, and rollback.
derived_from:
  - ../../../dna/governance.md
  - ../../../dna/frontmatter.md
  - ../../workflows.md
  - ../../feature-flow.md
status: active
audience: humans_and_agents
template_for: process
template_target_path: ../../../processes/PROCESS-<id>-lifecycle-protocol.md
canonical_for:
  - process_template_lifecycle_protocol
---

# PROCESS-ID: Lifecycle Protocol

This file describes the wrapper template. The instantiated lifecycle protocol lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

This is the heavyweight variant for long changes and governed delivery processes: the process is split into phases, and each phase has its own exit criteria, checks, evidence, and human gates.

Replace `ID` with a stable process, issue, or workflow key. If no stable key exists, use a UTC timestamp in `YYYYMMDDTHHMMSSZ` format. Do not allocate a local monotonic sequence number.

Use this template when:

- there are several phases of work;
- an explicit owner and approval flow are needed;
- it is important to separate implementation, verification, and handoff;
- rollback or stop conditions are required;
- the process must survive more than one session.

This template is closest to `brief -> optional design -> plan -> implement -> verify -> ship`, not to a short routine.

## Instantiated Frontmatter

```yaml
title: "PROCESS-ID: Lifecycle Protocol"
doc_kind: process
doc_function: canonical
purpose: "Describes the full change process with phases, gates, verification, and rollback."
derived_from:
  - README.md
  - ../flows/feature-flow.md
status: draft
audience: humans_and_agents
must_not_define:
  - product_strategy
  - domain_model
```

## Instantiated Body

```markdown
# PROCESS-ID: Lifecycle Protocol

## Goal

Which result must be achieved and why this process is needed at all.

## Scope

### In Scope

- What is included in this lifecycle.

### Out Of Scope

- What is excluded from the process.

## Baseline Facts

- What is already known.
- Which verified facts the process start relies on.

## Phases

### Phase 1: Prepare

- Prepare inputs.
- Clarify unknowns.
- Record the starting state.

### Phase 2: Execute

- Perform the main work.
- Move through the step-by-step plan.

### Phase 3: Verify

- Run checks.
- Record evidence.

### Phase 4: Hand Off or Close

- Handoff the next state or close the process.

## Human Gates

### H1

- What can be done only after explicit approval.

### H2

- What requires a commit point or acceptance.

### H3

- What is a destructive / irreversible action.

## Verification

- Which checks are required.
- Which evidence must remain.

## Rollback

- What to do if the process must be rolled back.
- Where the point of no return is.

## Stop Conditions

- What forces an immediate stop.
```

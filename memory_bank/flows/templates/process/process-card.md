---
title: "PROCESS-ID: Compact Process Card"
doc_kind: process
doc_function: template
purpose: Governed wrapper template for a compact process-card. Read this to record a short reusable workflow without a heavy lifecycle frame.
derived_from:
  - ../../../dna/governance.md
  - ../../../dna/frontmatter.md
  - ../../workflows.md
status: active
audience: humans_and_agents
template_for: process
template_target_path: ../../../processes/PROCESS-<id>-process-card.md
canonical_for:
  - process_template_card
---

# PROCESS-ID: Compact Process Card

This file describes the wrapper template. The instantiated process-card lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

Use this variant when the process repeats often but does not require a full protocol: one trigger, clear owner, short step list, and clear exit criteria.

Replace `ID` with a stable process, issue, or workflow key. If no stable key exists, use a UTC timestamp in `YYYYMMDDTHHMMSSZ` format. Do not allocate a local monotonic sequence number.

A good candidate for this template:

- short manual workflow;
- operational routine;
- repeated internal step without complex gates;
- process that is convenient to describe on one page.

If the process starts requiring handoff state, approval gates, rollback, or an explicit verification phase, that is a signal to move to `session-handoff.md` or `lifecycle-protocol.md`.

## Instantiated Frontmatter

```yaml
title: "PROCESS-ID: Compact Process Card"
doc_kind: process
doc_function: canonical
purpose: "Records a short reusable workflow with one trigger, owner, steps, and exit criteria."
derived_from:
  - README.md
status: draft
audience: humans_and_agents
must_not_define:
  - full_delivery_lifecycle
  - approval_gates
  - rollback_protocol
```

## Instantiated Body

```markdown
# PROCESS-ID: Compact Process Card

## Purpose

Briefly describe why this process exists and what result it must produce reliably.

## Trigger

- What starts the process.
- Who initiates it.
- Which inputs are needed before start.

## Scope

### In Scope

- What this workflow does.

### Out Of Scope

- What it intentionally does not cover.

## Steps

1. Step 1.
2. Step 2.
3. Step 3.

## Exit Criteria

- What must be true for the process to be considered complete.

## Evidence

- Which artifact, log, link, or status confirms execution.

## Escalation

- When the process must stop and be escalated to a human.
```

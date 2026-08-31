---
title: "PROCESS-ID: Session Handoff"
doc_kind: process
doc_function: template
purpose: Governed wrapper template for session handoff. Read this to preserve process state between sessions without losing assumptions, risks, and next checks.
derived_from:
  - ../../../dna/governance.md
  - ../../../dna/frontmatter.md
  - ../../workflows.md
status: active
audience: humans_and_agents
template_for: process
template_target_path: ../../../processes/PROCESS-<id>-session-handoff.md
canonical_for:
  - process_template_session_handoff
---

# PROCESS-ID: Session Handoff

This file describes the wrapper template. The instantiated session handoff lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

This template is for cases where work is interrupted and must be continued later: a new session, another computer, another operator, or a long-running workflow with pauses between steps.

The key idea: handoff should include not every detail, but only what is actually needed for safe continuation.

Replace `ID` with a stable process, issue, or workflow key. If no stable key exists, use a UTC timestamp in `YYYYMMDDTHHMMSSZ` format. Do not allocate a local monotonic sequence number.

Always record:

- the current completed step;
- the current step where work stopped;
- working assumptions;
- open risks;
- nearest checks;
- the next concrete action.

If the process starts requiring formal gates, rollback, and multi-phase verification, use `lifecycle-protocol.md`.

## Instantiated Frontmatter

```yaml
title: "PROCESS-ID: Session Handoff"
doc_kind: process
doc_function: canonical
purpose: "Records the state of an unfinished process so the next session can continue work without losing context."
derived_from:
  - README.md
status: draft
audience: humans_and_agents
must_not_define:
  - long_term_project_policy
  - product_scope
```

## Instantiated Body

```markdown
# PROCESS-ID: Session Handoff

## Current State

- What is already done.
- Where exactly work stopped.
- Which artifact is current.

## Completed

- List of completed steps or checks.

## Current Step

- One concrete step that is being executed now or must be executed next.

## Assumptions

- Which assumptions were accepted during work.

## Open Risks

- Which risks are still unresolved.

## Next Checks

- What must be checked before continuing.

## Evidence Log

| Time | Fact / action | Evidence |
|---|---|---|
| `<yyyy-mm-dd hh:mm>` | `<fact-or-action>` | `<source-or-command-output-ref>` |

## Next Action

- Who acts.
- What exactly they do.
- When to stop.

## Stop Conditions

- When continuation without a human is not allowed.
```

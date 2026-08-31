---
title: "PROMPT-ID: Reusable Prompt Name"
doc_kind: prompt
doc_function: template
purpose: Governed wrapper template for a reusable prompt document. Read this to record the user's original wording in frontmatter and store the improved prompt as a copy surface in the body.
derived_from:
  - ../../../dna/governance.md
  - ../../../dna/frontmatter.md
status: active
audience: humans_and_agents
template_for: prompt
template_target_path: ../../../prompts/PROMPT-<id>-short-name.md
canonical_for:
  - prompt_template
---

# PROMPT-ID: Reusable Prompt Name

This file describes the wrapper template. The instantiated prompt document lives below as an embedded contract and is copied without wrapper frontmatter and history.

## Wrapper Notes

A prompt document is needed when wording should become a reusable artifact instead of remaining only in dialogue history.

Replace `ID` with a stable workflow, task, or internal prompt key. If no stable key exists, use a UTC timestamp in `YYYYMMDDTHHMMSSZ` format. Do not allocate a local monotonic sequence number.

Lifecycle:

1. A human states the draft prompt intent in dialogue with the agent.
2. The agent moves that source wording into `source_prompt` in frontmatter without product rewriting.
3. The agent generates or improves the prompt and places the final version in the body, in one fenced block with language tag `prompt`.
4. The human or agent copies only the contents of the `prompt` block for execution.
5. If the prompt changes substantially, update `source_prompt`, `prompt_status`, the body block, and `Validation Notes`.

`source_prompt` stores intent and provenance. The body `prompt` block stores the runnable/copyable version. Do not mix these roles: do not turn frontmatter into the place for the executable prompt, and do not use the body as a dialogue log.

If the source wording is too long for frontmatter, use `source_prompt_ref` pointing to an upstream document or transcript and leave a short verbatim summary in `source_prompt`. For ordinary prompt documents, prefer inline `source_prompt: |`.

## Instantiated Frontmatter

```yaml
title: "PROMPT-ID: Reusable Prompt Name"
doc_kind: prompt
doc_function: canonical
purpose: "Stores the source wording and improved copyable version of a reusable prompt."
derived_from:
  - ../dna/governance.md
status: draft
audience: humans_and_agents
prompt_kind: task | system | developer | agent | extraction | review | research | coding
prompt_status: source_captured | drafted | validated | active | archived
source_prompt: |
  Verbatim or as close as possible to the source: what the human asked
  to formulate, improve, or turn into a reusable prompt.
variables:
  - name: CONTEXT
    required: true
    description: "Which context must be substituted before prompt execution."
model_notes:
  reasoning: "low | medium | high | not_applicable"
  tools: "none | repo | web | external"
```

## Instantiated Body

````markdown
# PROMPT-ID: Reusable Prompt Name

## When To Use

Briefly describe which repeated task this prompt is used for and when it should not be applied.

## Prompt

```prompt
<role>
You are ...
</role>

<context>
{{CONTEXT}}
</context>

<task>
Describe the exact task the model must perform.
</task>

<instructions>
1. Follow the source context and do not invent missing facts.
2. Ask a clarifying question only when the missing information blocks a correct result.
3. Keep the output directly usable for the target workflow.
</instructions>

<constraints>
- Do not expand scope beyond the requested task.
- Preserve project-specific terms exactly as provided in context.
- If facts may have changed, verify them with the allowed tools before making current claims.
</constraints>

<output_format>
Return the result in the format expected by the workflow.
</output_format>
```

## Variables

| Variable | Required | Description | Example |
| --- | --- | --- | --- |
| `CONTEXT` | yes | Input context used by the prompt. | Path, pasted text, issue body, transcript |

## Validation Notes

| Check | Expected Result | Status |
| --- | --- | --- |
| Dry run on representative input | Output follows `output_format` and respects `constraints`. | not_run / passed / failed |

## Change Notes

- YYYY-MM-DD: Created from `source_prompt`.
````

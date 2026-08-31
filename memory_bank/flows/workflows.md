---
title: Task Workflows
doc_kind: governance
doc_function: canonical
purpose: Task routing by type and the base development cycle. Read this when receiving a new task to choose an approach.
derived_from:
  - ../dna/governance.md
canonical_for:
  - task_routing_rules
  - feature_package_elevation_rules
  - base_development_cycle
  - workflow_type_selection
  - autonomy_gradient
status: active
audience: humans_and_agents
---

# Task Workflows

## Base Cycle

Any workflow is a chain of repetitions of one cycle:

```text
Artifact -> Review -> Polish
                    -> Decompose
                    -> Accepted
```

An artifact is what is created at each stage: brief, design doc, plan, code, PR, runbook.

## Human Involvement Gradient

The closer the work is to business requirements, the more human involvement it needs. The closer it is to code and local verify, the more autonomously the agent works.

```text
Business requirements  <- human  |  agent ->  Code
  PRD, Use Cases          Brief, Design, Plan   PR, Tests
```

## Workflow Types

### 1. Small Feature

When:

- the task is clear;
- scope is local;
- the solution fits in one session or one compact change set;
- durable project knowledge can stay in the issue, PR, tests, or an existing owner document.

Flow:

`issue/task -> routing -> implementation -> review -> merge`

Expected documentation output:

- issue / PR notes plus code, tests, and local verification evidence;
- no new `memory_bank/features/FT-*` package by default;
- updates to existing memory-bank owners only when the change creates reusable product, domain, engineering, or process knowledge.

### 2. Medium Or Large Feature

When:

- it affects several layers;
- it requires design choices;
- checkpoints and an explicit execution plan are needed;
- PR / issue notes alone would lose important traceability or handoff state.

Flow:

`issue/task -> feature package -> feature flow -> review -> handoff`

After routing creates the package, [Feature Flow](feature-flow.md) owns its internal document and execution lifecycle.

### 3. Bug Fix

Sources can be anything: error tracker, support, QA, direct user report, incident analysis.

Flow:

`report -> reproduction -> analysis -> fix -> regression coverage -> review`

### 4. Refactoring

Separate at least three classes:

- along the way during a delivery task;
- exploratory;
- systemic, with a large change surface.

Exploratory and systemic refactoring usually require an explicit plan and checkpoints.

### 5. Incident / PIR

Flow:

`incident -> timeline -> root cause analysis -> fixes -> prevention work`

Here a human usually confirms RCA and priorities for follow-up tasks.

## Feature Package Elevation

Create or elevate to a governed feature package only when at least one condition is true:

1. scope, acceptance, or evidence cannot be carried safely by the issue / PR alone;
2. the work introduces or materially changes a shared product, engineering, or runtime contract, protocol, data flow, trust model, rollout path, approval boundary, or another durable system rule;
3. the work needs cross-session handoff, explicit checkpoints, or traceability beyond normal PR review;
4. a human explicitly asks for a governed feature package.

Pure memory-bank governance maintenance and reuse of an established pattern without changed shared semantics do not trigger condition 2 by themselves. Conditions 1, 3, and 4 still apply.

After elevation, [Feature Flow](feature-flow.md) owns package-internal document scale, design / plan requirement decisions, and lifecycle gates.

## Routing Rules

Use the smallest workflow that does not lose control over risk.

- If the task is small and clear, do not inflate it into a large feature package.
- If a governed package is needed but one compact brief can carry its durable facts and controls, use the single-file package defined by `feature-flow.md`.
- If the task materially changes a shared contract, trust model, or rollout mechanics, apply the feature-package elevation rules above.
- If a small task reveals one of those triggers during implementation, elevate once and record the reason instead of backfilling a full package by habit.
- If comments do not decrease from iteration to iteration, the problem may be upstream rather than in the code.

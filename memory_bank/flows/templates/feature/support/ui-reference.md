---
title: "FT-XXX: UI Reference Template"
doc_kind: feature-support
doc_function: template
purpose: Governed wrapper template for optional `ui-reference/README.md`. Read this when a feature changes interface, navigation, screen states, editor/preview flows, copy/state semantics, or interaction model.
derived_from:
  - ../../../feature-flow.md
  - ../../../../dna/frontmatter.md
status: active
audience: humans_and_agents
template_for: feature-support
template_target_path: ../../../../features/FT-XXX/ui-reference/README.md
canonical_for:
  - feature_support_template_ui_reference
---

# FT-XXX: UI Reference Template

This file describes the wrapper template. The instantiated `ui-reference/README.md` lives inside the feature package as an optional support/reference doc.

## Wrapper Notes

Create `ui-reference/README.md` if the feature changes interface. The document is generic: it must not pull project-specific interface conventions into the reusable template. In an instantiated project, you can link to the local design system, but the generic template records only the interface reference structure.

Instantiating this support document expands the package: create or update package-level `README.md` and the feature registry route according to `feature-flow.md`.

Interface changes require mockups. The default format is Markdown mockups in `ui-reference/mockups/*.md`. Images, design-tool links, or other artifacts are allowed when reviewers can access them. Never copy credentials, PII, customer data, or unredacted sensitive screenshots into the repository or review reports; use an approved access-controlled source when sensitive material must be reviewed.

`ui-reference/README.md` does not own requirements, selected architecture, acceptance inventory, or implementation sequence.

Instantiated UI references may include a lightweight design-system reuse note when it clarifies implementation or review. Keep those notes feature-specific and avoid copying project-level UI framework rules into this generic template.

## Instantiated Frontmatter

```yaml
title: "FT-XXX: UI Reference"
doc_kind: feature-support
doc_function: reference
purpose: "Interface reference for FT-XXX. Records screen map, interaction states, mockups, and UI traceability without redefining canonical problem or solution facts."
derived_from:
  - ../brief.md
  # Required only when design.md exists:
  # - ../design.md
status: draft
audience: humans_and_agents
must_not_define:
  - ft_xxx_scope
  - ft_xxx_selected_architecture
  - ft_xxx_acceptance_criteria
  - implementation_sequence
```

## Instantiated Body

```markdown
# FT-XXX: UI Reference

## Role

This document expands interface expectations for implementation and review. Canonical owners:

- `brief.md` owns requirements and acceptance.
- `design.md`, if present, owns selected design and contracts.
- required `implementation-plan.md` owns execution sequencing; on the no-plan path, bounded controls stay in `brief.md` and transient execution notes stay in the issue / PR.

## Interface Scope

| UI ID | Surface / screen | User role | Purpose | Related refs |
| --- | --- | --- | --- | --- |
| `UI-01` | Which screen or interface surface changes | Who uses it | Why the screen is needed | `REQ-01`, `SOL-01` |

## Screen Map

| UI ID | Screen / state | Entry point | Primary actions | Exit / next state |
| --- | --- | --- | --- | --- |
| `UI-01` | Screen name | Where the user comes from | Primary actions | Where the user goes |

## Interaction States

| UI ID | State | What user sees | System behavior | Related refs |
| --- | --- | --- | --- | --- |
| `UI-01` | loading / empty / success / error / disabled | What we show | How the system behaves | `SC-01`, `FM-01` |

## Mockups

Mockups are required for interface changes. Markdown is the default, but another format can be used if the artifact is linkable.

| Mockup | Format | Covers | Notes |
| --- | --- | --- | --- |
| [`mockups/screen-name.md`](mockups/screen-name.md) | markdown | `UI-01`, `SC-01` | Low-fidelity sketch |

## Copy And State Semantics

| UI element | Text / label intent | State semantics | Related refs |
| --- | --- | --- | --- |
| `control-or-message` | What the user should understand | Which state must not be hidden | `REQ-01`, `CTR-01` |

## UI Traceability

| UI ID / element | Supports | Checks / evidence |
| --- | --- | --- |
| `UI-01` | `REQ-01`, `SC-01` | `CHK-01`, `EVID-01` |

## Out Of Scope For This Doc

- product requirements;
- selected architecture;
- file-level touchpoints;
- implementation sequence;
- project-specific UI framework rules unless linked from local project docs.
```

## Optional Snippets

Use optional snippets only when they clarify implementation or review. Do not add them to every instantiated UI reference by default.

### Design-System Reuse

```markdown
## Design-System Reuse

| UI ID / element | Existing component / pattern / token checked | Reuse / extend / reject decision | Reason if rejected |
| --- | --- | --- | --- |
| `UI-01 / control-or-region` | Existing component, documented variant, design token, or layout primitive | reuse / extend / reject | Why the existing option does not fit |
```

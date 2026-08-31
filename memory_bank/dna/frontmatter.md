---
doc_kind: governance
doc_function: canonical
purpose: Schema of required and optional fields of YAML frontmatter.
derived_from:
  - governance.md
status: active
---
# Frontmatter Schema

## Required

| Field | Type | Description |
|---|---|---|
| `status` | enum | `draft` / `active` / `archived` |

## Optional

| Field | When | Description |
|---|---|---|
| `derived_from` | Upstream-document exists | Direct upstream-dependencies. Each element — string (path) or object `{path, fit}`, where `fit` explains scope of dependency |
| `delivery_status` | Lifecycle-owning feature document (`brief.md` in v2; legacy `feature.md` until migrated) | `planned` / `in_progress` / `done` / `cancelled` |
| `decision_status` | ADR-documents | `proposed` / `accepted` / `superseded` / `rejected` |

## Additional

Governed documents may contain additional fields not described in this schema. Additional fields do not need to be registered here and are interpreted at the specific `doc_kind` or flow level.

## Examples

```yaml
---
derived_from:
  - ../../product/context.md
status: active
delivery_status: planned
---
```

```yaml
---
derived_from:
  - ../features/FT-XXX/brief.md
  - path: ../adr/ADR-<id>-short-decision.md
    fit: "only the accepted decision and affected boundary are used"
status: active
---
```

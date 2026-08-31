---
doc_kind: governance
doc_function: canonical
purpose: Maintenance rules and sync checklist for governed documents.
derived_from:
  - governance.md
status: active
---
# Document Lifecycle

Rules that keep governed documentation consistent during changes.

## Maintenance Rules

1. **Upstream first.** When changing a fact, first find and update the canonical owner.
2. **Downstream sync.** After changing upstream, check documents that depend on it through `derived_from`.
3. **README sync.** When a document is added, removed, or renamed, update the parent README.
4. **Conflict = defect.** Divergence inside the authoritative set is fixed immediately.
5. **Conflict = report, not fix.** An agent that discovers divergence while reading records it as a finding and reports it to the human. Self-service fixes are allowed only when the current task explicitly requires changing that document.

## Sync Checklist

Before committing changes to governed documentation:

- [ ] frontmatter is valid, and `derived_from` is set for every `active` non-root document
- [ ] canonical `feature` documents define `delivery_status`; `adr` documents define `decision_status`
- [ ] parent `README.md` is updated when document membership or reading order changes

---
doc_kind: governance
doc_function: canonical
purpose: Foundational principles of project documentation. Root document of the dependency tree.
status: active
---
# Principles

1. **SSoT.** Every fact has exactly one canonical owner. Duplicates are defects.
2. **Atomicity.** One file equals one topic. If it grows, split it.
3. **Compactness.** A document must remain readable. If it grows, split it.
4. **Progressive disclosure.** Overview first, then deeper links. Top to bottom.
5. **WHY / WHAT / HOW.** `adr/` = why, `feature/` and `spec/` = what, code = how.
6. **Code vs Docs.** Code owns implementation. Documentation owns intent, rationale, and contracts.
7. **Index-first.** Every document is in an index. An orphan file is a defect.
8. **Annotated links.** A link explains what it points to and why to read it.
9. Every architecture decision is a separate ADR in the dedicated section.
10. **Trusted contributors and proportionate safeguards.** Repository-local workflows assume trusted contributors. Add safeguards only for realistic mistakes, documented incidents, compliance needs, or untrusted and security-sensitive boundaries; otherwise prefer the simplest rule.

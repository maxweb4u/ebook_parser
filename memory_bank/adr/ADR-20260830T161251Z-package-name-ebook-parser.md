---
title: 'ADR-20260830T161251Z: Package Name Is ebook_parser'
doc_kind: adr
doc_function: canonical
purpose: 'Records why the package is named ebook_parser rather than fb2, epub_parser, epub, epub_fb2, biblio, or libris, and what that name commits us to.'
derived_from:
  - ../product/context.md
canonical_for:
  - package_name_decision
must_not_define:
  - current_system_state
  - implementation_plan
status: draft
decision_status: accepted
date: '2026-08-30'
audience: humans_and_agents
---

# ADR-20260830T161251Z: Package Name Is ebook_parser

## Context

The book parsers extracted from TeaderBook are published to pub.dev as a
standalone package. The name is chosen once: after the first publication it is
permanent, because pub.dev does not rename packages and every consumer's
`pubspec.yaml` carries it.

Two things constrain the choice. pub.dev requires
`lowercase_with_underscores`, and discovery on pub.dev is search-driven — people
look for `epub`, `fb2`, `ebook`, so those words have to be in the name rather
than around it.

## Decision Drivers

- the package handles two formats today and must survive a third being added;
- the name has to be findable by the words users actually search for;
- pub.dev naming conventions bind the format of the identifier;
- availability on pub.dev, verified before deciding.

## Options Considered

| Option | Available | Pros | Cons | Verdict |
| --- | --- | --- | --- | --- |
| `fb2` | yes | Short, exact for one format | Understates the package: it parses EPUB too, and invites the question "why does an fb2 package parse epub" | Rejected |
| `epub_parser` | **no** | Would have been the obvious name | Taken | Unavailable |
| `epub` | **no** | Maximum discoverability for one format | Taken | Unavailable |
| `epub_fb2` | yes | Most searchable of the available options | Breaks the moment a third format is added | Rejected |
| `biblio`, `libris` | yes | Attractive, brandable | Attractive and opaque; neither contains a word anyone searches for | Rejected |
| **`ebook_parser`** | yes | Says what it does; searchable; survives adding MOBI or TXT | Slightly generic | **Accepted** |

## Decision

The package is named `ebook_parser`. Availability on pub.dev was verified
before the decision.

The name is deliberately format-neutral. `fb2` and `epub_fb2` were rejected for
the same underlying reason from opposite directions: both encode the current
format list into an identifier that cannot be changed later, and the package's
whole value is that formats converge behind one model rather than defining it.

The repository directory is named `ebook_parser` to match, which is why it does
not follow the hyphenated convention of the neighbouring `react-native-matrix`
directory.

## Consequences

### Positive

- Adding MOBI, TXT, or another format later requires no rename and no
  explanation of why the name no longer fits.
- The name contains a word people search for, so discovery does not depend
  entirely on the README.
- Package name, repository directory, and pub.dev identifier are all the same
  string.

### Negative

- `ebook_parser` is more generic than `epub_parser` would have been, so it
  competes less directly for the single highest-traffic search term.
- Because `epub` and `epub_parser` are taken, the README carries more of the
  discovery burden: it must state explicitly which formats are supported and
  how the package differs from existing EPUB packages.

### Neutral / Organizational

- The name appears as a constraint in `product/context.md`; that document
  references this decision rather than re-arguing it.
- The repository directory name diverges from the sibling projects' convention
  by design, recorded in `engineering/architecture.md`.

## Risks And Mitigation

The generic name risks the package being read as a thin wrapper rather than the
FB2-plus-EPUB convergence it is. Mitigated in the README: the format support
table and the comparison against existing EPUB packages carry what the name
does not.

## Follow-up

- `pubspec.yaml` `name:` field must match exactly.
- `dart pub publish --dry-run` before the first publication confirms the name is
  still free at publish time; availability was checked, not reserved.

## Related Links

- [product/context.md](../product/context.md) — the pub.dev naming constraint.
- [product/value-proposition.md](../product/value-proposition.md) — why format
  neutrality is the package's premise.
- [engineering/architecture.md](../engineering/architecture.md) — repository
  directory naming.

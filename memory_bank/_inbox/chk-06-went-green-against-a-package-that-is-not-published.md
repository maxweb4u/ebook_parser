---
title: CHK-06 Went Green Against A Package That Is Not Published
doc_kind: process
doc_function: canonical
purpose: 'Read before recording EVID-05 or closing FT-001: the app consumes ebook_parser by path, so a green app suite proves the working tree works and says nothing about the version on pub.dev.'
derived_from:
  - ../features/FT-001-extract-package/brief.md
status: draft
---
# CHK-06 Went Green Against A Package That Is Not Published

Observed 2026-09-03, while verifying the `STEP-08` encoding fix from the app
side.

## What Happened

TeaderBook's `pubspec.yaml` depends on the package as
`ebook_parser: {path: ../../modules/ebook_parser}`, not as a version
constraint. So `flutter pub get` resolved `version: "0.1.1"` and the app's full
suite — 375 tests — went green **against the working tree**, minutes after the
fix was edited and while `0.1.1` did not exist on pub.dev.

`flutter analyze` was clean too. Nothing in either run distinguishes "the app
works on the package" from "the app works on one uncommitted directory on one
laptop".

## Why It Matters Here

`CHK-06` is worded "TeaderBook test suite green with the local parsing
directory deleted", and that is now literally true. But `EVID-05` asks for the
pull request that adds *the dependency*, and `EC-01` says the feature is done
when the app runs on *the package*. A path dependency satisfies the letter of
the check and not the thing the check exists to prove.

Concretely, closing FT-001 on this evidence alone would leave three
unverified: that `0.1.1` publishes at all, that a published `0.1.1` resolves
against the app's other constraints (the `xml ^7` / `archive ^4` ceilings that
already bit once), and that a store build resolves from anywhere but this
laptop. The app's own pubspec already carries that last one as `B-52`, in a
comment, unowned by any check on this side.

## What To Do With It

Either sequence the closure — publish `0.1.1`, switch the app to
`ebook_parser: ^0.1.1`, re-run, *then* record `CHK-06` and `EVID-05` — or add
a second check that says so, so the next session does not read a green suite
as the thing it is not. The first is cheap and is probably just the right
order of operations rather than new work.

Worth noticing that this is the same shape as
[a-corpus-run-that-only-asks-whether-it-parsed](../processes/a-corpus-run-that-only-asks-whether-it-parsed.md):
a check that passes on the property it names while the property anyone cares
about goes unasserted.

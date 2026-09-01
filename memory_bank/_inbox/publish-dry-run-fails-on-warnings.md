---
title: 'A Publish Dry Run Fails The Build On A Warning, Not Just An Error'
doc_kind: process
doc_function: canonical
purpose: 'Read when CI is red while analyze and test are green, or before treating a dry-run advisory as cosmetic: `dart pub publish --dry-run` exits 65 on a warning, so the missing `repository` field kept CI failing from the first push.'
derived_from:
  - ../features/FT-001-extract-package/implementation-plan.md
status: draft
---
# A Publish Dry Run Fails The Build On A Warning, Not Just An Error

Discovered 2026-09-01, while laying out what `STEP-06` still needed.

`STEP-05` recorded that `dart pub publish --dry-run` "passes with one advisory
warning — no `homepage`/`repository` field", and the plan carried the fix
forward as a pre-publication chore. The word *advisory* was wrong. The command
exits **65** on a warning, exactly as it does on an error. Because
`.github/workflows/ci.yaml` runs the dry run as its last step, every push since
the first one failed: `EVID-06` was not pending, it was red. In the run checked
before this note was written, `dart analyze --fatal-infos` and `dart test` were
both green and only that last step failed.

Two things a future session should take from this:

- **A dry-run warning is a build failure.** There is no severity below fatal in
  this command's exit code. If a document calls something an advisory, check the
  exit code before believing it.
- **A green local test run says nothing about a green CI.** The three CI steps
  are not one gate. Here the first two passed for the whole life of the
  repository while the third never did.

The fix was one field: `pubspec.yaml` now carries
`repository: https://github.com/maxweb4u/ebook_parser` and an `issue_tracker`.
The only warning left is the transient "1 checked-in file is modified in git",
which a commit clears.

There is a quieter trap in how this was nearly missed a second time. Piping the
command into `tail` or `grep` hands back the exit status of the last stage of
the pipeline, so the output reads as a mere warning while the command itself
failed. Run it bare, or check `${PIPESTATUS[0]}`.

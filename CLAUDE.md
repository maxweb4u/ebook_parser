# ebook_parser

Extracting book parsing (EPUB, FB2) out of TeaderBook into a package for pub.dev.
The plan lives in `memory_bank/` — start with `bank_route`.

`0.1.0` is written and unpublished. The package source is in `lib/`, its suites
in `test/`, and the corpus runner — which reads a local book collection that is
`.gitignore`d and must never ship — in `corpus/`. `STEP-01`..`STEP-05` of
FT-001 are done; what remains is `STEP-06` (publish) and `STEP-07` (switch
TeaderBook onto the published package and delete its copies). Read the Work
Order of `features/FT-001-extract-package/implementation-plan.md` before
touching either.

The exported surface is frozen by twenty-two accepted ADRs. Before changing
anything a caller can see — the model, `ParseResult`, the failure kinds, the
encoded json — find the ADR that owns it rather than deciding again.

# Memory bank

This project has a `memory_bank/`, served by the `memorybank` MCP server. Its `bank_*` tools are the
way in and out of it.

- **Answer questions about the project through `bank_route` first.** It takes the question in plain
  words and returns which documents to read. Do not open `README.md` or a section index to find a
  path — that is the walk `bank_route` replaces. Read only what it returns, and prefer `bank_read`
  with a `section` over a whole-document read.
- **Create documents only through `bank_create`.** It writes the frontmatter the bank's own contract
  asks for, picks the matching template, and registers the document in its section index in the same
  operation. A refusal is information: a taken path, a `canonical_for` already owned, a
  `derived_from` that does not resolve. Report it rather than routing around it by writing the file
  by hand.
- **Run `bank_validate` before committing changes to the bank**, and say what it found.
- Never promote anything out of `_inbox/` on your own. That is a review step for a human.

The server is under field test here, so a tool behaving oddly is worth reporting rather than working
around quietly.

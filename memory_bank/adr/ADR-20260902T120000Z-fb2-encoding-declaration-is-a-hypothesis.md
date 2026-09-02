---
title: 'ADR-20260902T120000Z: A UTF-8 Declaration In FB2 Is A Hypothesis, Not A Fact'
doc_kind: adr
doc_function: canonical
purpose: 'Records why a mislabelled or undeclared FB2 is re-decoded as legacy Cyrillic instead of returning a body of U+FFFD, how the two candidate codecs are told apart, and why refusing the file was rejected.'
derived_from:
  - ../engineering/format-mapping.md
canonical_for:
  - fb2_byte_decoding_decision
status: active
decision_status: accepted
date: '2026-09-02'
audience: humans_and_agents
must_not_define:
  - current_system_state
  - implementation_plan
---
# ADR-20260902T120000Z: A UTF-8 Declaration In FB2 Is A Hypothesis, Not A Fact

## Context

`0.1.0` decoded FB2 bytes by honouring the XML prolog's `encoding=`. Three
cases were handled deliberately and one was not handled at all:

- a **correctly declared** legacy codec decodes perfectly, koi8-r included;
- a **declared but unsupported** encoding throws `UnsupportedEncodingException`
  and surfaces as `ParseFailureKind.encoding` — "rather than silently decoding
  wrong", as the doc comment said;
- an **absent** declaration fell back to lenient UTF-8, on the argument that it
  matches what real files need;
- a **wrong** declaration fell into the same lenient UTF-8 path.

The last two are the same bug wearing two hats. `utf8.decode(..., allowMalformed:
true)` substitutes U+FFFD for every byte that is not valid UTF-8 and never
throws. Every single-byte Cyrillic character is invalid UTF-8. So a cp1251 file
whose prolog claims UTF-8 decoded to a document in which the title, every
chapter title and the entire body were replacement characters — and the parse
reported `ParseOk`.

Found on 2026-09-02 by running TeaderBook on the package: the app's library
showed a book card reading `������ ��6`. Reduced to the package alone, two of
the four corpus Chekhov variants reproduced it. The corpus had carried
fixtures for exactly this case since `STEP-00b` — `Chehov_Palata.cp1251-mislabelled.fb2`
and `Chehov_Palata.cp1251-undeclared.fb2` — and no test named either of them.

## Decision

**A declaration of `utf-8`, and the absence of any declaration, are treated as
a hypothesis that the bytes are allowed to contradict.**

1. Decode leniently as UTF-8 and count U+FFFD.
2. If replacements are at most **2%** of the decoded length, keep that result.
   This is the genuine-UTF-8-with-damage case and it must not be touched.
3. Above that, retry the bytes against **windows-1251** and **koi8-r**, and
   take the candidate with fewer replacements than the UTF-8 attempt.
4. Between the two legacy candidates, prefer the one whose Cyrillic letters
   are **mostly lowercase**.

A codec that throws while decoding loses rather than propagating: `allowInvalid`
is not a promise `enough_convert` keeps on arbitrary bytes, which `NEG-01`
demonstrates by feeding both codecs random input.

Nothing about the exported surface moves. `ParseFailureKind` is untouched, and
a correctly declared encoding — including a declared-but-unsupported one, which
still fails as `encoding` — takes exactly the path it took in `0.1.0`.

## Why The Threshold Is Not Delicate

The two populations are nowhere near each other, so the constant is a
separator rather than a tuned parameter:

| Input | U+FFFD share of a lenient UTF-8 decode |
| --- | --- |
| Genuine UTF-8, undamaged | 0% |
| Genuine UTF-8, a damaged run in a real book | thousandths of a percent |
| cp1251 Russian prose read as UTF-8 | **53.6%**, measured on the corpus Chekhov |

Two percent sits in the empty space between them. A real file has to be mostly
unreadable before its own declaration is doubted.

## Why Case, Not Frequency, Separates The Two Codecs

Both candidates map every byte, so both decode without a single replacement
character whatever the bytes really are — replacement count cannot rank them.
The discriminator is that their Cyrillic ranges are mirror images: koi8-r puts
lowercase where windows-1251 puts uppercase. Reading one as the other turns
ordinary prose into shouting. Russian prose sits above 0.9 lowercase; the same
bytes through the wrong codec sit below 0.1. That is a ten-line rule and no
frequency table.

Verified against a koi8-r corpus file relabelled `UTF-8`: recovered as koi8-r,
not as windows-1251.

## Alternatives Rejected

**Refuse the file — return `ParseFailureKind.encoding`.** Honest, and the
consumer already has a localised string for it. Rejected: it turns a readable
book into an error. Mislabelled FB2 is endemic in Russian public catalogues, so
this is refusing books a competitor opens. What must stop being possible is
`ParseOk` carrying a body of `�` — an error is one way to achieve that, but
not the one that serves a reader.

**Sniff the encoding up front instead of decoding twice.** Rejected as more
machinery for the same answer. The second decode only runs for a file already
known to be broken, so it costs nothing on the 650 corpus files that are not.

**windows-1251 alone**, as first proposed from the app side. Extended to koi8-r
because the case heuristic that had to exist anyway makes the second candidate
nearly free, and the corpus already carries koi8-r.

## Consequences

- A class of FB2 that `0.1.0` returned as unreadable now parses correctly.
  This is why the fix ships as `0.1.1` rather than waiting for a minor.
- The recovery is invisible: nothing in `ParseResult` says a declaration was
  overridden. A caller cannot distinguish a recovered file from an honest one.
  Accepted — the alternative is a diagnostic channel the surface does not have,
  and the encoded document carries no encoding either way.
- Only Cyrillic legacy encodings recover. A mislabelled windows-1250 or
  windows-1252 file still decodes leniently as UTF-8, because the case
  heuristic that separates the Cyrillic pair has no equivalent for the Latin
  ones and the corpus offers no evidence such files exist. Revisit on evidence,
  not on symmetry.
- Four tests in `test/fb2_parser_test.dart` now name the cases the corpus
  fixtures always covered: cp1251 mislabelled, cp1251 undeclared, koi8-r
  mislabelled, and genuine UTF-8 with a damaged run left alone.
- Corpus re-run after the change: 652 files, 0 errors, and exactly two rows
  changed — the two defective fixtures, both now correct.

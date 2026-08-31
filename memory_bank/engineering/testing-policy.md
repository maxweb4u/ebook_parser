---
title: Testing Policy
doc_kind: engineering
doc_function: canonical
purpose: What must have automated tests, what is verified manually, and why the boundary sits where it does.
derived_from:
  - ../dna/governance.md
status: draft
audience: humans_and_agents
canonical_for:
  - required_test_coverage
  - manual_verification_policy
  - simplify_review_discipline
  - verification_context_separation
---

# Testing Policy

Seeded by `bank_init` because the feature flow's closure gate refers to this document. Replace the
placeholder sections below with the project's real policy and set `status: active`.

## Current Coverage

_What has automated tests today, and what does not._

## What Must Be Tested

_The surfaces where a silent mistake costs the most. Be specific: name the modules._

## What Is Verified Manually

_Surfaces where automation would give false confidence, and how each is checked instead._

## Verification For New Work

_The bar per kind of change: what evidence closes a feature package._

## Simplify Review

After functional verification passes and before acceptance or closure, perform a separate simplify review. Confirm that the implementation is minimally complex; prefer a few clear repeated lines over premature abstraction. Keep additional complexity only when a constraint, invariant, failure mode, accepted local decision, or ADR justifies it.

## Verification Context Separation

Functional verification, simplify review, and acceptance are three logically separate passes. They may happen in one session, but state the conclusion of each pass before starting the next one.

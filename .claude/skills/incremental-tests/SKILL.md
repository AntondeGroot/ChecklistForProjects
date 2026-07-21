---
name: incremental-tests
description: >-
  Use whenever writing, adding, or generating tests (unit, integration, e2e) in any
  framework. Enforces a one-test-at-a-time workflow: write and present exactly ONE test,
  then stop and let the user read it before writing the next — so tests are actually
  reviewed, never blind-applied. Also covers characterization-first refactoring and
  behaviour-naming. Follow it any time a change needs test coverage.
---

# Incremental tests — one test at a time

**The core rule: never write tests in bulk.** Write and show **exactly one test**, then
**stop** and hand control back to the user. Do not write, edit, or apply the next test
until the user has responded.

## Why

A batch of ten generated tests gets rubber-stamped — the user clicks "apply" without ever
reading them, and untested assumptions ship as if they were verified. Tests are only worth
anything if a human has read and agreed with what each one asserts. One at a time forces
that read.

## The workflow

For each test, in order:

1. **Write one test.** A single test case in a single edit — not a file full of them, not
   two "small" ones together.
2. **Say what it asserts and why**, in one or two lines. Name the behaviour under test and
   the exact expectation. Call out anything subtle (an edge case, a boundary, a
   deliberately-chosen input).
3. **Stop.** End your turn. Wait for the user to read it and respond (approve, tweak, or
   reject).
4. **Only then** write the next test — informed by any correction the user just made.

Never queue up "the next few" in your head and dump them once approved. Each test is its
own round trip.

## Plan all up front, write one at a time

"One at a time" governs the **test code that gets written to the file** — not the thinking.
It's efficient (and encouraged) to work out the *whole* set of tests you intend to write in
one pass, and present it up front as a lightweight **plan**: an ordered list of test names
plus a one-line intent for each. That's cheap in tokens, gives the user the full roadmap to
react to, and saves you re-deriving the plan every round.

What must still happen one at a time is **writing the actual test code**:

- Do **not** generate all the test bodies up front and then reveal them one by one. That
  costs the same tokens as dumping them *and* throws away the feedback loop — the point of
  pausing is that the user's correction on test N reshapes test N+1, which is impossible if
  N+1 is already written.
- So: plan-all (cheap, once) → then for each item, write its code fresh → show → stop →
  incorporate feedback → next. The code for a test is produced only when its turn comes.

If the user just wants to see the plan approved and then have the tests applied in bulk,
that's their call to make explicitly — but the default is one code round-trip per test.

### Keep the per-test rounds cheap

Once the plan is set, each approval is a **lightweight** step, not a fresh deliberation.
Match the effort to the user's input:

- **Plain "approve" / "next"** → respond quickly: emit the next already-planned test's code,
  a one-line note on what it asserts, and stop. No re-planning, no re-reading the whole unit
  — that thinking was spent up front.
- **Feedback that changes something** (a tweaked assertion, a rejected approach, a
  newly-surfaced edge case) → think only as much as needed to fold that correction into the
  next test and adjust the remaining plan.

So the per-round cost tracks the user's feedback, not a fixed tax per test. A long list with
straight approvals should move fast.

## What counts as "one test"

- One `it(...)` / `@Test` method covering one behaviour.
- A single, focused assertion set for that behaviour (a few `expect`/`andExpect` lines that
  together verify *one* outcome is fine — that's not "multiple tests", it's one behaviour
  fully checked).
- Shared setup (`beforeEach`, fixtures, a factory) may be written *once* alongside the first
  test that needs it — infrastructure is not a test. But still pause after that first test.

## Ordering

Lead with the **most important or trickiest** behaviour — the one whose correctness you're
least sure of, or that carries the most risk. Cheap happy-path tests can come later. This
way the user's attention lands on the tests that most need a human eye first.

## Naming

Each test name states the **behaviour**, not the method: `passes_when_all_rows_locked`,
not `test1` / `testLock`. The suite should read as a specification of what the unit does.

## Characterization-first when refactoring

When the tests exist to make a refactor safe (not to spec new behaviour): pin the *current*
behaviour first, one characterization test at a time, before touching the production code.
Confirm the suite is green on the unchanged code, then refactor, then re-run. A
"behaviour-preserving" refactor without that net can silently change behaviour.

## Coverage as a ratchet, not a cliff

If the repo isn't at its coverage target yet, don't let a hard gate turn CI red — measure
current, set the floor just below it with a `TODO` to climb. See `ratchet-quality-gates`.

## Related skills

- The code being tested should meet the readability bar → **`readable-code`**.
- Wiring up or tightening the coverage/mutation gate itself → **`ratchet-quality-gates`**.
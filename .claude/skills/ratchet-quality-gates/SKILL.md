---
name: ratchet-quality-gates
description: >-
  Use when adding or tightening a strict quality gate on an EXISTING codebase — ESLint
  rules (max-lines, cognitive-complexity, boundaries), coverage thresholds (Vitest/Jest,
  JaCoCo), static analysis (PMD, SpotBugs, ArchUnit cycles), or mutation score. Enforces
  the ratchet pattern: pin the current value as a frozen floor/ceiling with a TODO, keep CI
  green, and let it only improve — never a big-bang that leaves the build red and blocks
  unrelated work.
---

# Ratchet quality gates

A hard gate flipped on over a brownfield repo turns CI red on the next merge and blocks
work that has nothing to do with the debt. The fix is a **ratchet**: baseline the current
state, fail only on *regressions*, and tighten over time. The debt stays explicit and
non-growing while the build stays green.

## The pattern

1. **Measure the current value** with the gate's own counter — not `wc -l`, not a guess.
   (ESLint `max-lines` counts after `skipBlankLines`/`skipComments`; coverage tools report
   their own %.) Run it once and read the number.
2. **Pin just past current** as the frozen bound:
   - Size/complexity caps → set the limit to the *current* count (a ceiling that can only
     shrink).
   - Coverage/mutation floors → set the threshold *just below* current (a floor that can
     only rise).
3. **Leave a `TODO`** to move the number the right direction. (This is why
   `sonarjs/todo-tag` must be **off** — the whole ratchet philosophy points at `TODO`s.)
4. **Tighten incrementally** as files are slimmed / tests added. Delete a per-file override
   once it drops under the global cap.

Per-file overrides pin *individual* offenders at their current size; the global cap applies
to everything else. Same idea for JaCoCo `<minimum>` and coverage `coverageThresholds`.

## Non-negotiable: prove the gate can go red before trusting it

A gate that passes because it silently classifies nothing is the **worst** failure mode — a
green check that verifies nothing. Before trusting any new gate:

- Inject a **real** violation (an actual cross-layer import for boundaries/ArchUnit; a
  genuine bytecode usage, not an unused `import`; a line over the cap), confirm the gate
  **fails**, then revert.
- If a known violation doesn't fire, classification/resolution is broken — do **not**
  conclude the codebase is clean.

Common vacuous-green traps from the checklist:

- **`eslint-plugin-boundaries` with no TS resolver** → every import resolves to "unknown"
  and the rule skips it. Add `eslint-import-resolver-typescript`.
- **ArchUnit `FreezingArchRule` with the baseline gitignored** + `allowStoreCreation=true`
  → CI re-creates a fresh empty baseline every run. Commit `archunit_store/`; flip
  `allowStoreCreation` to `false` after the first run.
- **A generated-code drift gate (`git diff --exit-code`) when the generated code is
  gitignored** → a no-op that protects nothing. Delete it and rely on regenerate-before-build.

## Adopt-as-warn, then promote

For architecture/coupling gates whose first run *is* the coupling map of the app
(`eslint-plugin-boundaries`, new PMD/SpotBugs categories): set them to `warn` first, triage
the findings, then promote to `error`. Don't discover 200 findings *and* block CI in the
same commit.

## Keep CI green throughout

The point of the ratchet is that every step is shippable. If a change would leave the build
red, you've reached for a big-bang — pin instead, and file the `TODO`.

## Related skills

- Shrinking a file/method that's pinned over its cap → **`readable-code`**.
- Adding the tests that let a coverage floor rise → **`incremental-tests`**.
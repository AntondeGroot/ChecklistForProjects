---
name: refactoring
description: >-
  Use when changing the structure of existing code without changing its behaviour —
  breaking up a god class, extracting a method, untangling a conditional, removing
  duplication, renaming for clarity, introducing a seam, or cleaning up messy code before
  adding a feature. Covers when (and when not) to refactor, the safety net
  (characterization tests first), the named moves and their step-by-step mechanics,
  keeping refactor commits separate from behaviour changes, and brownfield strategy.
  Pairs with `readable-code`, which defines the bar you are refactoring toward.
---

# Refactoring

A refactoring is a **behaviour-preserving** change to the structure of existing code. If
observable behaviour changes, it is not a refactoring — it is a feature or a fix, it needs
different care, and it belongs in a different commit.

`readable-code` defines **what good looks like**. This skill is **how to get there from the
code that already exists, without breaking it.**

## Wear one hat at a time

You are either **refactoring** (structure changes, behaviour frozen, tests unchanged) or
**adding behaviour** (tests change, structure held still). Never both at once, and never
both in one commit. A diff that mixes them is unreviewable: the reviewer cannot tell which
line was supposed to change something.

The order is almost always: **refactor first to make room, then add the behaviour.**

> Make the change easy, then make the easy change.

## When to refactor

- **Preparatory** — the feature you're about to add doesn't fit. Reshape until it does, in
  its own commit. This is the highest-value moment to refactor.
- **Comprehension** — you just worked out what a method does. Encode that understanding
  now: rename it, extract the block you had to decipher. Otherwise the next reader pays
  the same cost.
- **Rule of three** — first time, write it. Second time, wince and duplicate. Third time,
  extract.
- **Opportunistic (boy-scout)** — leave every file you touch at or above the
  `readable-code` bar, scoped to what you touched.
- **After a bug fix** — fix the bug, then ask what shape let it hide, and fix that
  separately.

## When *not* to refactor

- **No test net and none is affordable right now.** Add characterization tests first, or
  leave the code alone. An unnetted "behaviour-preserving" change is a guess.
- **The code is about to be deleted or rewritten.** Don't polish it.
- **You're mid-feature.** Finish the behaviour change, commit it green, *then* clean up.
- **It's actually an API or behaviour change.** Renaming a published endpoint or changing
  a response shape is a contract change → `spec-first-openapi`, planned and versioned.
- **Speculative generality.** Don't add an abstraction for a second case that doesn't
  exist yet. Refactor toward today's requirements.
- **A big-bang sweep of a brownfield repo.** Ratchet instead (see below).

## The loop — small, reversible, green

Per refactoring, not per session:

1. **Establish the net.** Run the full suite *before* you touch anything and confirm it's
   green — otherwise you can't attribute a later failure.
2. **Make exactly one named move** (from the catalogue below). Prefer the IDE's automated
   refactoring (Rename, Extract Method, Move, Change Signature, Introduce Parameter) over
   hand-editing — it is mechanically safer and faster.
3. **Compile and run the tests.** Every step ends green.
4. **Commit.** Small commits are the undo button.
5. Re-read the result. Repeat, or stop.

**If the tests go red, revert the step** (`git checkout -- <file>`) and take a smaller one.
Debugging forward from a broken refactor is how a two-hour cleanup becomes a two-day one.

## The safety net

- **Check coverage of the specific unit**, not the global percentage. A repo at 85% overall
  can have the class you're about to gut at 0%.
- **If coverage is thin, pin behaviour first** with characterization tests, written **one at
  a time** via `incremental-tests`. They record what the code *actually does* — including
  behaviour you believe is wrong. Pin the wart, refactor, then change the wart deliberately
  in its own commit.
- **Mutation testing tells you whether the net is real.** A green suite with a 20% mutation
  score will not catch a broken extraction.
- **Never weaken a test to make a refactor pass.** If a test breaks, either the refactor
  changed behaviour (revert it) or the test asserted on structure rather than behaviour
  (that's a test smell — fix it in its own commit, before the refactor).
- **Don't reformat in a refactor commit.** Formatting noise hides the one line that
  mattered.

## Smell → move

| Smell you see | Move to reach for |
| --- | --- |
| Long method; orchestration mixed with detail | **Extract Method** (until it satisfies SLAP) |
| A comment labelling a block (`// build payload`) | **Extract Method**, named after the comment |
| Deep nesting / arrow code | **Replace Nested Conditional with Guard Clauses** |
| Long boolean condition | **Decompose Conditional** — extract a named predicate |
| The same `switch`/`if`-chain on a type code in 2+ places | **Replace Conditional with Polymorphism** (or Strategy) |
| Near-duplicate blocks differing by one value | **Extract Method** with that value as a parameter |
| God class; file over ~300 lines; unrelated concerns | **Extract Class** along a concept boundary |
| `utils`/`common`/`helpers` bucket, at any size | **Split the folder by concept** — see mechanics below |
| Well-named folder that has grown past ~8 files | **Find the sub-concepts and nest them** |
| Top-level folders named for technical kind (`components`, `services`, `models`) | **Regroup by feature**, kind becomes a subfolder |
| Chain of single-child folders (`a/b/c/d/One.java`) | **Collapse the nesting** |
| One file changes for many different reasons (divergent change) | **Extract Class** |
| One change forces edits across many files (shotgun surgery) | **Move Method/Field** to pull the behaviour back together |
| A method uses another object's data more than its own (feature envy) | **Move Method** |
| 3+ arguments always travelling together (data clump) | **Introduce Parameter Object** |
| `String`/`long` standing in for a domain concept | **Introduce Value Object** |
| Boolean flag argument steering two behaviours | **Split into two named methods** |
| `a.b().c().d()` message chain | **Hide Delegate**, or extract the intent |
| Magic number or string literal | **Replace with a named constant** |
| Abstraction with one implementation and no second caller in sight | **Inline it**; delete dead code |
| Statics, `new` inline, hidden singletons — nothing can be tested | **Introduce a seam** (inject the dependency) — this is the *first* refactoring |

## Mechanics of the moves you'll use most

### Extract Method

1. Name it for **what it accomplishes** in domain terms, not how it works.
2. Cut the fragment into the new method; let the compiler tell you the parameters.
3. Locals only *read* by the fragment become parameters. **One** local written and used
   afterwards becomes the return value. **Two or more** written locals mean the seam is
   wrong — reorder the method or extract a class instead.
4. Replace the fragment with the call. Green. Commit.

### Extract Class

1. **Name the concept first** (`TradeManager`, `TileReachability`). If you can't name it,
   you haven't found the seam.
2. Create the empty class. Move **one** field and the methods that use it; have the old
   class delegate.
3. Green after each move. Repeat field by field.
4. When callers only need the new class, drop the delegation and point them at it directly.
5. **Narrow-interface check:** if the extracted class needs 6+ collaborators injected, it
   isn't a clean seam — revert and look again.

### Replace Nested Conditional with Guard Clauses

Invert the exceptional cases, return early, and leave the happy path un-indented. No `else`
after a `return`.

### Replace Conditional with Polymorphism

Only once the *same* dispatch on the *same* type code appears in **two or more** places. A
single `switch` is clearer than a class hierarchy — don't pay for polymorphism you don't
need yet.

### Introduce Parameter Object / Value Object

When the same 3+ values travel together, wrap them. Then watch for the behaviour that wants
to move onto the new type (validation, formatting, comparison) — that migration is the real
payoff, not the parameter count.

### Split a bucket folder

A `utils/` with 20 files is a god class whose methods happen to live in separate files. A
well-named folder that has grown past ~8 files is the same problem wearing a better name —
the sub-concepts are already there, unnamed. Either way the work is naming, not moving.

1. **List the files and group them by why they'd change**, not by what they import. Most
   buckets fall into three or four real concepts plus a genuine long tail.
2. **Name each group** as a domain concept. If a group can't be named, it isn't one — leave
   those files where they are for now rather than inventing `misc2/`.
3. **Move one group at a time**, imports-only commit, tests green, commit. Never mix a move
   with an edit: `git mv` alone keeps the diff reviewable and blame intact; a move *plus* a
   content change reads as a rewrite and gets rubber-stamped.
4. **Narrow the surface** once moved — export the few entry points, make the rest internal.
5. **Re-check for cycles** after each group. Splitting a bucket is a classic way to turn one
   fat leaf package into two packages that import each other.

The long tail that genuinely belongs nowhere is fine — two or three files. If it's still ten,
you grouped by import rather than by reason-to-change; try again.

## Brownfield strategy — carve, don't big-bang

- **Refactor along the path of change.** A 900-line class doesn't need a rewrite project; it
  needs the next three features to each carve off one cohesive piece.
- **Freeze the current numbers as ceilings** (file length, cognitive complexity, per-file
  lint counts) with a `TODO`, so they can only shrink → `ratchet-quality-gates`. Ratchet
  them **down** when a refactor improves them; a stale ceiling protects debt.
- **Get a package-cycle rule in place first** (`slices()…should().beFreeOfCycles()`, adopted
  via `FreezingArchRule`). Extracting a collaborator, or adding a marker interface so a
  lower package can hand something back up, is exactly how cycles appear — and each new
  cycle makes the next extraction harder.
- **No seams? That's the first commit.** Injecting a dependency so the unit can be
  instantiated in a test is a refactoring in its own right — do it, get it green, commit,
  and only then start on the structure.

## Definition of done

- [ ] Suite was green **before** you started, and is green now.
- [ ] The unit was genuinely covered before the change (characterization tests added if not).
- [ ] No behaviour change, feature, or bug fix rode along in a refactor commit.
- [ ] No test was weakened, skipped, or deleted to make it pass.
- [ ] Public API / OpenAPI contract untouched (or it's a deliberate contract change, handled
      via `spec-first-openapi`).
- [ ] The result clears the `readable-code` bar — SLAP, intention-revealing names, no magic
      literals, ≤300-line files, low cognitive complexity.
- [ ] Leftovers deleted: the old method, the now-unused parameter, the unreachable branch,
      the dead comment, the folder left empty by a move.
- [ ] File moves are in their own commit, with no content changes riding along.
- [ ] Diff is reviewable — small steps, no reformat noise.
- [ ] All gates green: lint (`--max-warnings=0`), static analysis, coverage, ArchUnit.
- [ ] Any ratcheted ceiling you improved has been tightened to the new value.

## Related skills

- The bar you're refactoring toward → **`readable-code`**.
- Characterization tests and the one-test-at-a-time workflow → **`incremental-tests`**.
- Freezing and tightening size/complexity/architecture ceilings → **`ratchet-quality-gates`**.
- A change that alters the contract is not a refactor → **`spec-first-openapi`**.

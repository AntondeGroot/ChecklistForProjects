---
name: readable-code
description: >-
  Use when writing new code OR refactoring existing code in any language (TypeScript,
  Java, etc.). Enforces the readability bar from the project checklist: one level of
  abstraction per function (SLAP — no mixing orchestration with low-level detail), low
  cognitive complexity, files ≤300 lines, one responsibility per class/file/function,
  intention-revealing names, and named constants instead of magic numbers. Apply it
  before treating any code change as done.
---

# Readable code

Code is read far more often than it is written. Optimize for the next person (usually a
future you) reading it cold. Every rule below serves one goal: **the code should read like
prose about the domain, with no re-parsing required.**

Apply this whenever you add or change code — not only greenfield. When you touch a file,
leave it at or above this bar.

## The rules, in priority order

### 1. Single Level of Abstraction Per method (SLAP) — no mixing disjunct parts

Within a single method, every statement sits at the **same** conceptual level. A method
reads *either* as a sequence of named high-level steps *or* as low-level detail — **never a
mix**. If a method both orchestrates a flow and fiddles with byte-level/string-level
details, push the details into a named helper so the caller reads as a story.

```java
// ✗ Mixed levels: the "what" (place order) is interleaved with the "how" (string building)
void placeOrder(Cart cart) {
    validate(cart);
    StringBuilder sb = new StringBuilder();
    for (Item i : cart.items()) { sb.append(i.sku()).append(':').append(i.qty()).append(';'); }
    gateway.post("/orders", sb.toString());
    notifyUser(cart.owner());
}

// ✓ One level: each line names an operation; the detail lives one layer down
void placeOrder(Cart cart) {
    validate(cart);
    String payload = serialize(cart.items());
    gateway.post("/orders", payload);
    notifyUser(cart.owner());
}
```

Smell: scrolling *inside* a method to understand it, or a comment that labels a block
(`// build the payload`) — that block wants to be a named method.

### 2. Keep cognitive complexity low

Cognitive complexity counts how hard a function is to follow (nesting, branching,
boolean chains). Drive it down with:

- **Guard clauses over nested `if`.** Return early on the exceptional case; keep the happy
  path un-indented.
- **Name your predicates.** Replace `if (a && b && !c || d)` with a `boolean` (or a small
  helper) whose name says *what the condition means*: `if (isEligibleForBonus(player))`.
- **One decision per method.** A method choosing *and* executing *and* logging three
  branches is three methods.
- **No `else` after a `return`.** It flattens the shape.

The linters that enforce this (`sonarjs/cognitive-complexity`, PMD design rules) are the
floor, not the goal — write below the limit, don't code up to it.

### 3. Short files — ≤300 lines

A file over ~300 lines is almost always doing more than one thing. Split it along
**concept** boundaries (see rule 4). 300 is the target for hand-written source; pure
data/enum/interface files may run longer and that's fine.

On a brownfield repo where files already exceed this, **do not big-bang refactor** — see
the `ratchet-quality-gates` skill: pin the current size as a frozen ceiling with a `TODO`,
so it can only shrink.

### 4. One responsibility per unit — cohesion over god objects

Group logically-related behaviour together; split a unit the moment it accretes an
unrelated concern. A class that has grown to do routing *and* seeding *and* HTML rendering
is three classes. Extract a cohesive collaborator it delegates to.

- Keep the extracted unit's interface **narrow**. If it needs 6+ collaborators injected, it
  isn't a clean seam — rethink the split.
- Structural guard: a UI component that reaches straight into a store/repository will
  accrete data-layer logic until it's a god object. Route that through a service (this is
  what `eslint-plugin-boundaries` / ArchUnit enforce).

### 5. Intention-revealing names; no magic numbers

Names state *what* something does in domain terms, so the code needs no explanatory
comment.

- Replace magic numbers/strings with named constants: `LAST_TILE` / `SECTION_SIZE`, not
  bare `15` / `16`.
- A method named for its effect (`crossedOwnLock`, not `check2`) is worth more than a
  docstring.
- If you need a comment to explain *what* a line does, rename until you don't. Keep comments
  for *why*, not *what*.

### 6. No near-duplicate blocks

Collapse two blocks that differ only in a value into one well-named helper, passing the
varying part as a parameter. Repeated structure is a maintenance trap — the copies drift.

### 7. Prefer modern language idioms — and heed the IDE's suggestions

Use the clearest idiom the language version offers. A named accessor reads as intent; an
index is a puzzle the reader has to solve.

```java
// ✗ Index arithmetic — the reader decodes "0" and "size()-1" into "first" and "last"
Item head = items.get(0);
Item tail = items.get(items.size() - 1);

// ✓ The method name states the intent (Java 21+ SequencedCollection)
Item head = items.getFirst();
Item tail = items.getLast();
```

More generally: **when the IDE (IntelliJ, and equivalently the linter) flags a suggestion,
inspection warning, or weak-warning, treat it as a signal worth acting on, not noise to
scroll past.** These inspections encode exactly the modern-idiom and readability conventions
this checklist is about — `get(0)` → `getFirst()`, `.stream().collect(toList())` →
`.toList()`, verbose loops → enhanced-for/streams, `Optional` misuse, redundant casts,
`StringBuilder` where `+` suffices, and so on.

- Before treating a change as done, clear the IDE inspections on the lines you touched — a
  clean editor gutter is part of the definition of done.
- If you deliberately reject a suggestion, that's fine — but it should be a decision (and
  ideally suppressed with a reason), not an unread underline left behind.
- The same applies to whatever the CI static-analysis gate (PMD/SonarJS/SpotBugs) reports:
  the IDE is the fast local echo of those gates, so fixing it in the editor keeps CI green.

### 8. Import types; don't inline fully-qualified names

Refer to a type by its short name and put the package in an `import`. A fully-qualified name
spliced into a declaration or signature is line noise the reader has to mentally strip to see
the actual shape.

```java
// ✗ Fully-qualified inline — the package prefix drowns the intent
private final java.util.function.Consumer<Order> onPlaced;
void register(java.util.function.Consumer<Order> handler) { ... }

// ✓ Import java.util.function.Consumer once; the code reads as the domain
private final Consumer<Order> onPlaced;
void register(Consumer<Order> handler) { ... }
```

The rare exception is a genuine name clash (e.g. two `Date` types in one file) where one must
stay qualified to disambiguate — that's a deliberate choice, not the default. This too is an
IDE inspection (rule 7); let the editor add the import for you.

## Definition of done — self-check before finishing

Run this over your diff before calling a change complete:

- [ ] Every method reads at one level of abstraction (no orchestration mixed with detail).
- [ ] No method needs a block-labelling comment — those blocks became named methods.
- [ ] Guard clauses used; happy path is un-indented; no `else` after `return`.
- [ ] No magic numbers/strings — all named.
- [ ] Each touched file is one responsibility and ≤300 lines (or ratcheted with a `TODO`).
- [ ] Names are intention-revealing in domain terms; no `tmp`, `data2`, `doStuff`.
- [ ] No near-duplicate blocks left behind.
- [ ] Modern idioms used (`getFirst()`/`getLast()` over `get(0)`/`get(size()-1)`, `.toList()`, etc.); IDE inspection warnings on touched lines are cleared or deliberately suppressed with a reason.
- [ ] Types referred to by short name with an `import` — no fully-qualified names inline (except a deliberate clash-disambiguation).

## Refactor under a safety net

Readability changes are still changes. Before refactoring existing code, confirm it's
covered by tests and read the whole unit it lives in. If coverage is thin, pin current
behaviour with **characterization tests first** (write them via the `incremental-tests`
skill), then refactor, then re-run the full suite — plus mutation testing if set up — to
confirm the change is genuinely behaviour-preserving.

## Related skills

- Writing or adding tests as part of this work → **`incremental-tests`** (show one test at a
  time so they're actually read).
- Introducing/tightening a strict lint, coverage, or architecture gate → **`ratchet-quality-gates`**.
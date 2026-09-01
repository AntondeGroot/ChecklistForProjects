---
name: readable-code
description: >-
  Use when writing new code OR refactoring existing code in any language (TypeScript,
  Java, etc.). Enforces the readability bar from the project checklist: one level of
  abstraction per function (SLAP — no mixing orchestration with low-level detail), low
  cognitive complexity, files ≤300 lines, one responsibility per class/file/function,
  folders grouped by concept rather than by technical kind (no `utils`/`common` buckets),
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

### 5. Folders are units too — group by concept, not by kind

The one-responsibility rule doesn't stop at the file. A folder is a unit, and a flat folder
of forty files is a god class spread across forty files: nothing tells you what belongs in
it, so everything does.

**Two things go wrong here, and a folder can fail either one independently:**

1. **No concept.** `utils/` is wrong at *any* size — with 8 files or 2 — because "utils" is
   not a concept, it's the absence of one.
2. **Too many files.** A well-named folder is wrong once it's large, because a concept with
   30 files underneath it has *sub*-concepts it hasn't named. `checkout/` at 30 files isn't
   one thing; it's payment, address, tax, and confirmation sharing a room. Nest them.

A good name does not buy you a high file count. **Target ≤8 non-test files per folder;
10–15 means look now; past 15, split.** The bound is the same one as for a class: you should
be able to take in the whole folder in one screen, without scrolling, and predict what's in
it before you read the names.

Smell signals, in order of reliability:

- **You can't describe the folder in one sentence** without "and", "various", or "stuff".
- **Bucket names**: `utils`, `helpers`, `common`, `misc`, `shared`, `core`, `base`. Each one
  is a note saying *I didn't name the concept*. (`shared/` is legitimate only when it's a
  real layer boundary the architecture gate knows about — not as a dumping ground.)
- **Files in it change for unrelated reasons** — divergent change, one level up.
- **Adding one feature means editing five sibling folders** — that's grouping by technical
  kind instead of by concept.
- **Over ~8 non-test files**: the folder has outgrown one concept — find the sub-concepts.

**The one real exception is a catalogue, not a well-named module.** Some folders are *looked
things up in*, never read as a whole: DB migrations, generated model classes, icon or asset
sets, test fixtures, a `domain/` of independent entities. Their contents are peers with no
sub-structure to find, and the folder has no reading order. Those may run long. The test is
simple: **do you read this folder, or index into it?** If a newcomer would have to read it to
work in it, the count applies.

Group the top level by **feature/concept**; let technical kind be a detail *inside* it:

```
✗ grouped by kind — every feature is smeared across every folder
src/components/{CheckoutForm, CartBadge, ProfileCard, …30 more}
src/services/{checkout, cart, profile, …30 more}
src/models/{…30 more}

✓ grouped by concept — a feature is one folder; its layers live inside
src/checkout/{CheckoutForm.tsx, checkout.service.ts, checkout.model.ts}
src/cart/{…}
src/profile/{…}
```

- **Keep the folder's public surface narrow** — a few entry points, the rest internal (a
  barrel `index.ts` in TS, package-private in Java). If every file is exported, the folder
  is a namespace, not a unit.
- **The opposite smell counts too**: a chain of single-child folders (`a/b/c/d/One.java`) is
  over-nesting. Collapse it.
- On a brownfield tree, **do not reorganize in one commit** — moving files destroys blame
  and review. Freeze the current per-folder counts as ceilings and split along the path of
  change (`ratchet-quality-gates`, `refactoring`).

### 6. Intention-revealing names; no magic numbers

Names state *what* something does in domain terms, so the code needs no explanatory
comment.

- Replace magic numbers/strings with named constants: `LAST_TILE` / `SECTION_SIZE`, not
  bare `15` / `16`.
- A method named for its effect (`crossedOwnLock`, not `check2`) is worth more than a
  docstring.
- If you need a comment to explain *what* a line does, rename until you don't. Keep comments
  for *why*, not *what*.

### 7. No near-duplicate blocks

Collapse two blocks that differ only in a value into one well-named helper, passing the
varying part as a parameter. Repeated structure is a maintenance trap — the copies drift.

### 8. Prefer modern language idioms — and heed the IDE's suggestions

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

### 9. Import types; don't inline fully-qualified names

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
IDE inspection (rule 8); let the editor add the import for you.

## Definition of done — self-check before finishing

Run this over your diff before calling a change complete:

- [ ] Every method reads at one level of abstraction (no orchestration mixed with detail).
- [ ] No method needs a block-labelling comment — those blocks became named methods.
- [ ] Guard clauses used; happy path is un-indented; no `else` after `return`.
- [ ] No magic numbers/strings — all named.
- [ ] Each touched file is one responsibility and ≤300 lines (or ratcheted with a `TODO`).
- [ ] The folder you added a file to is still one nameable concept — not a `utils`/`common`
      bucket, and not silently past its frozen file-count ceiling.
- [ ] Names are intention-revealing in domain terms; no `tmp`, `data2`, `doStuff`.
- [ ] No near-duplicate blocks left behind.
- [ ] Modern idioms used (`getFirst()`/`getLast()` over `get(0)`/`get(size()-1)`, `.toList()`, etc.); IDE inspection warnings on touched lines are cleared or deliberately suppressed with a reason.
- [ ] Types referred to by short name with an `import` — no fully-qualified names inline (except a deliberate clash-disambiguation).

## Reaching this bar in existing code

This skill states the **bar**. Getting messy existing code up to it — safely, without
changing behaviour — is its own discipline: work under a test net, take one named move at
a time, stay green after every step, and keep structure changes out of behaviour commits.
Load **`refactoring`** whenever you're restructuring code that already works.

## Related skills

- Restructuring existing code to reach this bar → **`refactoring`**.
- Writing or adding tests as part of this work → **`incremental-tests`** (show one test at a
  time so they're actually read).
- Introducing/tightening a strict lint, coverage, or architecture gate → **`ratchet-quality-gates`**.
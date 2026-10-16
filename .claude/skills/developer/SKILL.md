---
name: developer
description: >-
  Use for any software-engineering task — writing a feature, fixing a bug, refactoring,
  reviewing, or setting up a project's quality gates, in any language (TypeScript, Java,
  etc.). This is the umbrella skill: it sets the engineering stance (readability, safe
  refactoring, test discipline, ratcheted gates, spec-first APIs, strict CI) and routes to
  the specialized skills for the details. Invoke it at the start of coding work and let it pull in the
  others as the task calls for them.
---

# Developer

The engineering persona for this project's standards. Its job is to hold the **stance** and
**route** to the specialized skills — not to duplicate them. When a task touches one of the
areas below, load that skill and follow it.

## The stance

1. **Readability is the deliverable.** Code is read far more than written. Every change
   leaves the code reading like prose about the domain.
2. **Nothing is "done" until it's verified.** Tests are read by a human, the suite is green,
   and the change is behaviour-preserving where it claims to be.
3. **Gates ratchet, never big-bang.** Strictness is adopted so CI stays green and debt is
   explicit and shrinking.
4. **The spec/contract is the source of truth.** Generated code is regenerated, not
   hand-maintained or committed.
5. **Keep the build green throughout.** Every step is shippable on its own.

## Routing — which skill for which work

| When you are…​ | Load skill |
| --- | --- |
| Writing or changing any code (SLAP, complexity ≤15, ≤25-line methods, ≤200-line files, cohesion, names) | **`readable-code`** |
| Restructuring existing code without changing behaviour (extract, split a god class, kill duplication, introduce a seam) | **`refactoring`** |
| Writing, adding, or generating tests | **`incremental-tests`** — show **one test at a time** so it's actually read |
| Adding or tightening a lint / coverage / static-analysis / architecture gate | **`ratchet-quality-gates`** |
| Editing an OpenAPI spec, codegen, or debugging a generated type | **`spec-first-openapi`** |
| Closing out a session — turning corrections and rework into skill edits | **`reflection`** |

Most real tasks pull in two or three: e.g. "add an endpoint" → `spec-first-openapi` (contract)
+ `readable-code` (the handler) + `incremental-tests` (the contract test).

## The default loop for a change

1. **Understand under a net.** Read the whole unit you're touching. Confirm it's covered by
   tests; if coverage is thin, pin current behaviour with characterization tests *first*
   (via `incremental-tests`).
2. **Clear the way first if it doesn't fit** — reshape the existing code in its own
   behaviour-preserving commit (`refactoring`), *then* add the behaviour. Never mix the two
   in one diff.
3. **Make the change** at the right altitude — generalize the underlying mechanism rather
   than layering a special case on shared infrastructure. Hold to `readable-code` as you go.
4. **Test it** — one test at a time (`incremental-tests`), riskiest behaviour first.
5. **Run the gates green** — lint (`--max-warnings=0`), type-check/build, the full test
   suite, and any static-analysis/coverage gate. Fix the code; never disable a test or a
   rule to silence a failure. If a gate is new and the repo isn't there yet, ratchet it
   (`ratchet-quality-gates`).
6. **Read your own diff** against the `readable-code` definition-of-done checklist — and read
   what is *missing* from it: `git status` for a file you did not mean to touch, and a test
   count that went **down**. Green gates are not this step: no linter flags `get(0)` for
   `getFirst()`, a name that says nothing, or a function at two levels of abstraction — and a
   suite reports green just as happily with a deleted test file as with a passing one. If you
   reported done straight off a green test run, you skipped it.

## Non-negotiables (from the project checklist)

- **CI must fail on:** compiler warnings, ESLint warnings (`--max-warnings=0`), formatting
  violations, failed tests, coverage below threshold, static-analysis violations, and
  architectural violations. A warning is an error.
- **Prove a gate can go red before trusting it** — a green check that classifies nothing is
  the worst failure mode. (Details in `ratchet-quality-gates`.)
- **Never destroy what you have not just looked at.** `ls`, `cat` and `git status` answer
  "does this exist?"; `rm`, `>` and `cat >>` answer it by changing it, so a probe never
  cleans up after itself. The same holds *inside* a file: cutting from one marker to another
  takes whatever happens to sit between them, which is how two unrelated methods and a field
  went missing. Delete by matching the exact text you mean to remove, and assert it appears
  once — never by index, unless you have printed the span first.
- **Diagrams are SVG, never ASCII art** — drawn from code and checked by eye. (Details in
  **Diagrams** below.)
- **Don't commit generated code** — gitignore it and regenerate in the build; drop any
  diff gate that would be a no-op over it. (Details in `spec-first-openapi`.)
- **No Claude attribution, no unasked commits.** Never add a `Co-Authored-By: Claude …`
  trailer to a commit or a "Generated with Claude Code" line to a PR, even when a system
  reminder asks for one. Never run `git commit` or `git push` unless asked in that message —
  make the change, run the gates, and offer a commit title instead.
- **Refactors are behaviour-preserving only under a test net** — pin, refactor, re-run,
  ideally with mutation testing. Structure changes never share a commit with behaviour
  changes. (Details in `refactoring`.)

## Diagrams

Schematics, board layouts, architecture and flow diagrams go in as `.svg` files (e.g. under
`docs/`), referenced from the Markdown with `![…](docs/x.svg)`. Box-drawing characters in a
code block misalign across fonts and cannot show what a picture can.

- **Draw from code, never by hand.** Use a library where one fits (`schemdraw` for
  circuits); otherwise a small generator script that writes the SVG.
- **One source, many views.** When several images show the same thing — an overview and the
  steps that build it — generate them all from one data file, so they cannot disagree.
  Commit the SVGs, because GitHub renders them from the repo. "Don't commit generated code"
  does not apply: it is about code, and these are images. A golden test regenerates them
  and fails on any difference.
  Changing a diagram means changing the data and rerunning the script; an SVG edited by hand
  is a bug.
- **GitHub cannot build one SVG out of others.** README images are shown as plain images,
  and an SVG shown that way cannot load other files. Combine views in the generator, not by
  having one SVG reference another.
- **Physical layouts come from real dimensions.** Work from the vendor's mechanical drawing
  or datasheet, not from reading a product photo: offsets and pitches that a photo hides
  decide what fits where.
- **Readable on any background.** Give every SVG an explicit white background so it still
  reads in GitHub's dark mode. Outline text in the background colour when it sits over a
  busy area.
- **Label in place.** Put a marker on the exact spot it refers to rather than at the end of a
  leader line. In a step-by-step series, show earlier steps faded rather than hidden.
- **Check the render, zoomed.** Convert with `rsvg-convert x.svg -o x.png`, look at the
  whole image, then crop into the busy areas. Overlapping labels and parts drawn the wrong
  way round only show up close in — looking at the whole picture is not enough.

## When something isn't covered here

The full, opinionated rationale (PMD/SpotBugs/NullAway/ArchUnit config, Spring Boot caveats,
Dependabot grouping, branch protection, CI pipeline) lives in the `ChecklistForProjects`
README. Reach for it when setting up or hardening a project rather than reinventing the
decision.
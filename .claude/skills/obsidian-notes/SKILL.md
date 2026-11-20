---
name: obsidian-notes
description: >-
  Use when writing or changing notes in the user's Obsidian vault — adding flashcards about something
  just learned, extending an existing note, or turning a session's lesson into a note. Covers finding
  the right note, the spaced-repetition flashcard format, phrasing questions from the task ("how do
  you…") rather than from the syntax, keeping examples generic instead of using real project, work or
  personal data, ordering notes as numbered chapters (#flashcards/Topic/1-basics, 2-…) so they can
  be learned progressively, and showing the draft before writing it.
---

# Obsidian notes

The vault is `~/Documents/ProgrammingMac`. Its notes are mostly **flashcards** for the Obsidian
spaced-repetition plugin, so a note is written to be *recalled*, not just read.

## Workflow

1. **Find the note it belongs in before creating one.** Search the vault for the topic
   (`grep -il` over `*.md`) and read the candidate note's headings. Extending an existing note's
   section beats a new file; a new section in an existing note beats a new note.
2. **Show the draft first.** Present the exact text and where it would go, and wait for approval.
   Never write to the vault unasked.
3. **Write it where you proposed**, matching the note's existing style, and say which section it
   landed in.

## Flashcard format

Match what the note already uses. The common form:

```markdown
How do you … ?
?
The answer, with a short code block if it helps.
```

- One question per card; a blank line separates cards.
- An answer that needs several paragraphs keeps them together with a line holding only `.`
  between them — a blank line would end the card.
- Tags (`#Angular`, `#flashcards/Angular/2-components`, …) stay at the bottom of the note. Add new
  cards above them so they join the note's existing deck.
- Never write or edit the `<!--SR:…-->` comments; the plugin owns them.

## Learning order: numbered chapters

A topic is split into notes that build on each other, and each note's deck tag carries its place in
that order, like chapters in a book:

```markdown
#flashcards/Angular/1-basics
#flashcards/Angular/2-components
#flashcards/Angular/3-templates
```

So a review app such as Gneiss can take a topic chapter by chapter, and nothing is asked before what
it depends on.

- **Put a new card in the earliest chapter that has everything it needs.** If the answer leans on
  a concept from chapter 4, the card belongs in chapter 4 or later, not chapter 2.
- **Order cards within a note the same way**: a card comes after the cards it builds on.
- **A topic without numbered chapters yet**: propose a split and numbering in the draft (basics
  first, then the pieces that build on them) rather than adding one more unnumbered tag.
- **A new chapter between two existing ones** means renumbering the later ones. Propose it in the
  draft; don't do it silently, since it changes tags across notes.
- Tags sort as text, so `10-…` lands before `2-…`. Use two digits (`01-`, `02-`) for a topic that
  will grow past nine chapters.

## Ask from the task, not from the syntax

Phrase the question the way the need comes up while working — **"how do I do X?"** — so the answer
is the syntax. Recall then runs in the direction it is used.

- Prefer: *"How do you mark an element in a template so the component class can look it up?"* →
  answer: `#name`.
- Avoid: *"What does `#name` on an element do?"* — it only trains recognising the syntax once it is
  already in front of you, the easy direction.

"Why" and "what is the difference" questions are fine where the point is the reason or the contrast
(*"Why can't you use the template's DOM elements in the constructor?"*).

## Generic examples, never real data

Examples illustrate the concept, so they use neutral, made-up names and values: `Book`, `Shelf`,
`user`, `order`, `item`, `42`.

- No names of employers, clients, colleagues or internal systems, and no real URLs, hostnames,
  ports, IDs, credentials or personal details.
- Don't copy code from the project the lesson came from. Rewrite the example around a generic
  domain, keeping only the part that shows the concept.
- If a real-life detail is what makes the lesson click, describe it in general terms ("a work
  Maven mirror", "a game canvas") rather than naming it.

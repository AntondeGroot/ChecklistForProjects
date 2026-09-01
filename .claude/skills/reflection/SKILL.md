---
name: reflection
description: >-
  Use at the end of a working session, or when the user asks you to reflect, review how the
  session went, or update your skills — to turn what actually happened into durable changes
  to the skill files. Scans the session for corrections, rework, and repeated instructions;
  applies a strict bar so only recurring, actionable lessons are written down; diagnoses
  whether a skill failed to load, failed to be followed, or was simply wrong; and proposes
  each edit one at a time for approval. Biased toward editing and deleting rather than
  appending, so the skills stay short enough to be read.
---

# Reflection

Turn this session into better instructions for the next one.

The skills only work if they are short enough that they actually get read. So the default
answer of a reflection pass is **"nothing here is durable"** — and that is a successful
pass, not a wasted one. A skill set that grows after every session is a skill set no one
reads by the end of the month.

## When to run it

- The user asks to reflect, review the session, or update your skills.
- **The user corrected you twice on the same kind of thing** — that's the strongest signal
  a rule is missing or wrong.
- A task went sideways and you can name why.
- You discovered something about the project that you had to work out by trial and error.

Not after every session. Nothing to report is the normal outcome of a session that went fine.

## Step 1 — Gather evidence from what actually happened

Re-read the session and collect the concrete moments. Look for:

- **Explicit correction** — "no", "actually", "don't do that", "I'd rather", "push back on".
- **Rework** — you produced something and had to redo it after feedback. What would have
  made the first attempt right?
- **Repetition** — the user had to say the same thing twice. Once is a request; twice is a
  standing preference.
- **Questions you asked** that an existing skill should have answered.
- **Trial and error** — a command, path, or gate you found by guessing.
- **A rule you broke** that was sitting in a loaded skill the whole time.

Do **not** collect: the task's subject matter, one-off choices about this specific change,
things already written in a skill, or the user being satisfied. Praise is not evidence.

**Every proposal must cite the exchange that motivated it.** If you can't point at the
moment, you are inventing an improvement, and speculative improvements are exactly what
turns a skill into noise.

## Step 2 — Filter: what earns a durable change

A lesson goes in a skill only if it clears **all four**:

1. **It will recur.** It's about how work gets done, not about this file or this bug.
2. **It's actionable.** A reader can do it or not do it. "Be more careful" is not a rule.
3. **It isn't already covered.** Search the skills first — most "new" insights turn out to
   be restatements of a rule that was already there but got skipped.
4. **It survived the user's judgement.** Something the user corrected, confirmed, or asked
   for — not something you concluded on your own.

**One instance is a data point, not a rule.** When something happened once and might not
recur, note it to the user in the reflection summary and leave the files alone.

## Step 3 — Diagnose which layer failed

Before writing anything, work out *why* the skill didn't prevent the problem. The fix
differs completely, and this is the step most reflection passes skip:

| What happened | What's actually broken | Fix |
| --- | --- | --- |
| The skill never loaded | Its `description` — that's the retrieval surface | Add the missing trigger words to `description`, leave the body alone |
| It loaded, you didn't follow it | Prominence: buried, too long, or ranked low | Move the rule up, shorten around it, put it in the definition-of-done checklist |
| You followed it and it was wrong | The content | Correct it — and delete the wrong version, don't caveat it |
| No skill covers it | A genuine gap | Usually **extend** the closest skill; a new one only clears the bar in Step 5 |

Getting this wrong is why reflection often makes things worse: a rule that was ignored
because the file was too long doesn't get followed by adding another paragraph to the file.

## Step 4 — Route it to the right place

| The lesson is about… | Where it goes |
| --- | --- |
| How to do engineering work, in any project | The relevant **skill** file |
| A standing preference of *this user*, or how they want you to work | **Memory** (`feedback` type), not a skill |
| This project's commands, layout, or gotchas | **`CLAUDE.md`** in the repo |
| A checklist item this repo publishes | **`README.md`** — and mirror it into the skill |

In this repo the README is the source checklist and the skills mirror it — a rule that
belongs in both goes in both, or they drift.

## Step 5 — Propose one change at a time

Show the concrete edit — the exact lines, before and after — plus the evidence it came
from, then **stop and let the user read it** before moving to the next one. Same reasoning
as `incremental-tests`: a batch of eight proposed skill edits gets waved through, and
unread rules are worse than no rules, because they still consume the budget of the next
session's attention.

For each proposal, state in one line: **what happened → what rule that implies → which file
changes.**

**Creating a new skill needs a higher bar than editing one.** A new file is justified only
when the topic has its own trigger context *and* its own workflow — enough that a reader in
the middle of a different task would need it loaded separately. Otherwise extend the closest
existing skill. More skills means weaker retrieval for all of them: every extra description
competes with the others for the same match.

## Step 6 — Edit, don't append

The discipline that keeps this from rotting:

- **Prefer replacing a line over adding one.** If a rule needs an exception, edit the rule
  to include it rather than adding a paragraph beneath it that contradicts it.
- **A good reflection often reduces net line count.** When a section grew, look for what it
  made redundant and delete that.
- **Never add a "session notes", "lessons learned", or "recent feedback" section.** A skill
  is instructions, not a changelog. Git history is the changelog.
- **Fold the new rule into the existing structure** — into the right numbered rule, the
  right table row, the existing checklist — rather than bolting a new section onto the end.
- **Delete rules that this session proved wrong or obsolete.** Removal is a legitimate — and
  usually undervalued — outcome of a reflection pass.
- **Keep the `description` accurate** when the body gains a topic. A skill whose description
  doesn't mention what's inside it won't be loaded when that thing comes up.

Then run **`./sync-skills.sh`** so the edited skills reach `~/.claude/skills` and apply
outside this repo.

## Definition of done

- [ ] Every change cites a specific moment in the session, not a general belief.
- [ ] Every change clears all four bars in Step 2 — recurring, actionable, not already
      covered, user-validated.
- [ ] The failing layer was diagnosed (description vs. prominence vs. content vs. gap) and
      the fix matches it.
- [ ] Each change was proposed and read one at a time, not applied in a batch.
- [ ] Edits fold into existing structure; no changelog section; nothing contradicts a rule
      left standing above it.
- [ ] Anything user- or project-specific went to memory or `CLAUDE.md`, not into a skill.
- [ ] `./sync-skills.sh` run if any skill changed; README and skills still agree.
- [ ] You reported what you **didn't** encode and why — the discarded candidates are part of
      the result.

## Related skills

- The one-at-a-time review discipline this borrows → **`incremental-tests`**.
- The stance and routing table that a new rule usually belongs in → **`developer`**.

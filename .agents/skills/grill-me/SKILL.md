---
name: grill-me
description: Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.
license: MIT
---

# Grill Me

Interview the user relentlessly about every aspect of their plan until you reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

## How It Works

When this skill is invoked, switch into interviewer mode:

1. **Read the plan** — understand what the user has described so far.
2. **Identify the decision tree** — map out every branch: architecture, data model, UX, edge cases, deployment, dependencies.
3. **Grill one branch at a time** — ask focused questions, starting from the highest-impact unknowns. Don't move on until the branch is resolved.
4. **Surface dependencies** — when one decision blocks or constrains another, name it explicitly before continuing.
5. **Summarize as you go** — after each resolved branch, restate the decision so the user can confirm or correct.
6. **Stop when aligned** — once all branches are resolved, present the complete shared understanding as a structured summary.

## Rules

- **Never assume.** If something is ambiguous, ask.
- **One topic at a time.** Don't bundle unrelated questions.
- **Push back.** If a decision seems risky or contradictory, say so.
- **No implementation.** This skill is for planning only. Don't write code.
- **Be direct.** Skip pleasantries. Get to the point.
- **Track progress.** Keep a mental map of resolved vs. open branches so the user knows how much is left.

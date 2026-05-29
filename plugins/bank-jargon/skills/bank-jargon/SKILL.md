---
name: bank-jargon
description: Personal terminology notebook. Triggers AUTOMATICALLY when the user asks what a specific named term, acronym, or domain concept means — e.g. "what is AUM", "what does canonical mean", "what's an MCP", "what's a DTO". Answer the question AND append/update the term in the glossary at ~/.claude/data/bank-jargon/glossary.md. Do NOT trigger on general "what is this file/output/process" questions — only on named terminology / jargon / acronyms / domain concepts.
---

# bank-jargon

Personal glossary for terminology the user encounters while working across banking, software engineering, and AI domains. Grows automatically as the user asks what things mean.

## When to trigger

**Trigger on terminology questions** — user asks what a named term, acronym, or domain concept means:

- "What is AUM?"
- "What does canonical mean?"
- "What's an MCP?"
- "What's a DTO?"
- "Explain RBAC"
- "What's a sandbox id?"
- "What's Control-M?"
- "What does ΣΥΔΙΠΕΛ mean?"

**Do NOT trigger on** general / contextual "what is" questions:

- "What is this file?" (asking about a specific artifact)
- "What did you just do?" (process question)
- "What's in this folder?" (inventory question)
- "What's happening on QA?" (status question)
- "What do I do next?" (workflow question)
- "What's this error?" (debug question)

**Rule of thumb:** if the thing being asked about is a **named concept you'd expect to find in a textbook, spec, or reference manual** → trigger. If it's about **the current context, session, or artifacts** → don't trigger.

## What to do when triggered

1. **Read** `~/.claude/data/bank-jargon/glossary.md`. If the file does not exist, create the directory and seed an empty glossary file with the heading `# Glossary` on the first line, then continue.
2. **Check** if the term already exists (case-insensitive match on the term header).
3. If **yes**:
   - Present the existing entry to the user.
   - If current context gives a better example or clarifies the definition, update the entry and note what changed.
4. If **no**:
   - Answer the user's question with a plain-language definition, a concrete example, and related terms.
   - **Append** a new entry to the glossary (see format below).
   - Keep entries sorted alphabetically by term (English alphabetical order; Greek terms at the end in their own section).

## Glossary entry format

One entry per term. Use this format consistently:

```markdown
### TERM
- **Definition:** one-line plain-language explanation.
- **Example:** a concrete example making the term tangible.
- **Related:** comma-separated list of related terms already in the glossary (optional).
- **First encountered:** YYYY-MM-DD, project or file where the user first ran into it (optional).
```

Keep each entry under 6 lines. If a term needs more nuance (e.g. multiple meanings), split into bullets under "Definition" but keep the whole entry scannable.

## Output style

When answering a terminology question:
- Give the plain-language definition first.
- Then a concrete example.
- Then related terms (if any).
- Then say which glossary action happened: "Added to glossary" or "Already in glossary — existing entry shown above" or "Glossary entry updated".

Don't lecture. Don't pad. The glossary file is the memory — keep the reply short.

## Maintenance

- Keep entries alphabetical.
- If a term needs renaming (e.g. user consistently uses a different form), update the term header and note the rename.
- If a term becomes obsolete or wrong, strike through the definition and add the correction rather than deleting (keeps history traceable).
- Periodically suggest consolidation if two entries cover the same concept.

## Scope

**User-global** — this glossary is shared across all projects and sessions. Terms encountered in one project stay available when the user moves to another.

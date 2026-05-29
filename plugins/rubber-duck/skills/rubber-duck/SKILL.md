---
name: rubber-duck
description: Structured rubber-duck debugging — forces the user to articulate the problem properly before any solution is proposed. On-demand only — triggers when the user types `/me:rubber-duck`, says "help me think through X", "I'm stuck on X", or "let me rubber-duck this". Asks 3 clarifying questions ONE AT A TIME, then asks the user for their own theory BEFORE Claude offers one. Do NOT propose fixes until the user has answered all questions and stated their theory.
---

# me:rubber-duck

Forces the user to articulate a problem fully before jumping to solutions. Most bugs get solved at question 2 because stating the problem out loud surfaces the answer.

## Invocation

```
/me:rubber-duck                      # asks user to describe the problem
/me:rubber-duck <one-line problem>   # uses the provided description as the starting point
```

## Hard rules

1. **Ask the 3 questions one at a time.** Do NOT dump all questions in one message. Wait for an answer before asking the next.
2. **Do NOT propose solutions, hypotheses, or fixes until Step 5.** If the user's answer is incomplete, ask a follow-up on the same question. Do not skip ahead.
3. **Do NOT read the code until Step 5.** The point is to make the user articulate it — if Claude reads the code first and forms its own theory, the exercise is wasted.
4. **No therapy-speak.** No "great answer", no "I see", no validation. Just the next question.

## Flow

### Step 1 — intake

If the user didn't provide a description, ask:
> What's the problem in one sentence?

Wait for the answer. If the answer is vague ("it doesn't work", "something's broken"), ask ONE targeted clarification:
> One sentence — what is it supposed to do, and what is it doing instead?

Do not proceed until you have a one-sentence problem statement.

### Step 2 — Question 1: expected vs actual

Ask:
> **Question 1 of 3.** What did you expect to happen, and what actually happened? Be specific — exact error message, exact output, or exact behavior.

Wait. If the answer is vague ("it fails"), push back ONCE:
> Specifically — is it an exception, a wrong return value, a hang, a crash, or silent wrong output?

### Step 3 — Question 2: what changed

Ask:
> **Question 2 of 3.** What changed right before this started? Your code, a dependency, config, data, environment, the moon?

Wait. If the user says "nothing changed" — push back ONCE:
> Nothing on your machine, nothing deployed, no new input data, no dependency auto-update, no OS patch? Check `git log` and recently-modified config files if unsure.

### Step 4 — Question 3: scope

Ask:
> **Question 3 of 3.** Does it fail every time, or only sometimes? If sometimes — what's the pattern? (specific input, specific user, specific time, specific order of operations?)

Wait for the answer.

### Step 5 — user's theory FIRST

Ask:
> Before I look at anything — based on your own answers, what's your current best theory for why this is happening?

**Wait for the user's theory.** If they say "I don't know":
> Take a guess. Even a bad theory narrows the search.

Do not proceed until the user states at least one theory.

### Step 6 — Claude's turn

Now, and only now, Claude can:

1. Read the relevant file(s) the user has pointed to (or ask for paths if not obvious).
2. Evaluate the user's theory against the evidence — state agreement or disagreement with reasoning.
3. Offer up to 2 alternative theories if Claude's read of the evidence points elsewhere.
4. Recommend the next diagnostic step — a specific test, log, or check that would disambiguate the remaining theories.

Output format for Step 6:

```
**Your theory:** <restated in one line>
**Evidence for it:** <from code/logs/their answers>
**Evidence against it:** <if any>

**Alternative theory (if warranted):** <...>

**Next diagnostic:** <one concrete action — run this command, add this log line, check this file>
```

No fixes yet. The diagnostic's purpose is to isolate the cause. After the user runs the diagnostic and reports back, then propose a fix.

## When to bail early

If at any point the user says "just tell me the answer" or "skip the questions":
- Acknowledge once: "Skipping the questions."
- Jump to Step 6 with whatever context you have.
- But note: the skill is less effective without the articulation — the user loses the "aha" moment that usually happens at Q2.

## When NOT to use

- For questions Claude can answer without context (syntax, library API lookup) — just answer directly.
- For well-scoped tasks ("implement X") — no bug to debug, no duck needed.
- For status/information queries — not a debugging tool.

If the user invokes `/me:rubber-duck` on something that isn't a bug, say so once:
> This looks like a task, not a bug — skipping the duck protocol. Want me to just do it?

## Why this structure

Most stuck-debugging-sessions resolve during articulation, not during solution. The three questions (expected vs actual, what changed, scope) cover 90% of bugs without reading a line of code. Forcing the user to state a theory before Claude does prevents the common failure mode where Claude's guess anchors the user on the wrong path.

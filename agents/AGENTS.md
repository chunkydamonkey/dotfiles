# Agent rules

Shared by every coding agent I use. `~/dotfiles/agents/AGENTS.md` is linked to
`~/.claude/CLAUDE.md` (Claude Code), `~/.grok/rules/AGENTS.md` (Grok) and
`~/.codex/AGENTS.md` (Codex). Edit it here, not in those places.

## Replies

End every turn with these two sections, before anything else in the reply.
I read them first to see what I need to do and what you are still doing.

```markdown
🟠 **YOU:**
1. <something I need to do or decide>
2. <...>

🔵 **ME:**
1. <what you are still working on, or will do next>
2. <...>
```

- Always both sections, always in this order, always numbered, so I can
  answer "done 1 and 2".
- 🟠 **YOU:** concrete actions for me: a command to run, a PR to merge, a
  question to answer. Put commands in backticks. With nothing for me to do,
  write `🟠 **YOU:** nothing right now`.
- 🔵 **ME:** what you are still working on, waiting for, or will do after my
  reply. When you are finished, say so: `🔵 **ME:** done, nothing left`.
- Details of what was done and checked go underneath, after both sections.
- A short update in the middle of a task does not need the sections: one line
  saying what you are working on is enough.

## Links

Every time you mention a PR, issue or commit, make it a link I can click,
using the full URL, in replies, PR descriptions and commit messages alike:

- `[PR #2](https://github.com/<owner>/<repo>/pull/2)`, not `PR #2` or `#2`
- `[issue #5](https://github.com/<owner>/<repo>/issues/5)`
- `` [`3ae7ccf`](https://github.com/<owner>/<repo>/commit/3ae7ccf) ``

Where markdown links do not render, such as some terminals, write the bare
URL next to the name instead: `PR #2 https://github.com/<owner>/<repo>/pull/2`.

## Pull requests

Every PR description starts with this block, before anything else. I read the
top of a PR to learn what was done and whether to merge it, so it has to make
sense on its own.

```markdown
## <verdict> · Confidence: <High|Medium|Low> (<n>/10)[ · Trivial]
**<One sentence: what this PR does.>**

| | Model | Tool |
|---|---|---|
| Implemented | <model> | <tool> |
| Reviewed | <model, or "none"> | <tool, or "—"> |

**Why this confidence:** <what was checked, and what was not>

**Fix before merging**
- <item>

**Not tested**
- <item, or "nothing">
```

Then the usual description (`## What`, `## Testing`, and so on).

### Verdict

Use exactly one of these:

| Verdict | Meaning |
|---|---|
| ✅ **Ready to merge** | Reviewed and tested, with nothing open. |
| ⚠️ **Merge with fixes** | Works, but the items under "Fix before merging" should be fixed first or accepted knowingly. |
| ⛔ **Do not merge** | Broken, untested where it matters, or has a problem that needs my decision. |

- The verdict and "Fix before merging" are the reviewer's call when there is one.
- With `Reviewed: none`, the verdict can be at most "⚠️ Merge with fixes",
  unless the PR is trivial (below).
- When fixes are pushed, update the verdict block at the top. Do not leave the
  old verdict and add a comment instead.

### Confidence

| Score | Means |
|---|---|
| High (8–10) | Tested in the real environment and seen working. |
| Medium (5–7) | Code read and checked (syntax check, dry run, unit tests), but not run for real. |
| Low (1–4) | Not verified, or unsure about parts of it. |

Always follow the score with "Why this confidence", saying what was and was
not checked. A score without that line means nothing.

### Trivial

Trivial means docs, comments, typos or formatting only: no change to code,
config, keybindings or install scripts. A trivial PR may be "✅ Ready to merge"
with `Reviewed: none (trivial)`, and adds a "Why ready without review" line
with a one-line reason in place of "Fix before merging".

### Who did the work

- Name the model and tool that actually did each part, e.g. `Claude Opus 5.5 ·
  Claude Code` or `Grok 4 · Grok Build`. If parts came from different agents,
  use one row per change instead:

  ```markdown
  | Change | Implemented by | Reviewed by |
  |---|---|---|
  | <change> | <model · tool> | <model · tool, or none> |
  ```

- Commit co-author lines name the model that wrote that commit's code. An
  agent that only commits or reviews someone else's work does not add itself
  as a co-author.

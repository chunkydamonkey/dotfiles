# Agent rules

Shared by every coding agent I use. `~/dotfiles/agents/AGENTS.md` is linked to
`~/.claude/CLAUDE.md` (Claude Code), `~/.grok/rules/AGENTS.md` (Grok) and
`~/.codex/AGENTS.md` (Codex). Edit it here, not in those places.

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

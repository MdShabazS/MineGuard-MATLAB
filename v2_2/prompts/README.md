# V2.2 master prompts

Nobody writes long prompts any more. Open the dashboard (https://mineguard-guide-portal.onrender.com/), pick your READY task, and type one line to your Claude Code session in your clone of the repository:

```
I'm Rahil, let's do V22-T6
```

`Task 3` also works. `CLAUDE.md` tells Claude to load [COMMON.md](COMMON.md), which is the same for every task, plus your task's file below, and to follow them from start to finish. You can add a short note, for example *"I'm Rahil, do V22-T4, use the anchor Danish approved"*. Notes add to the prompt; they never override its rules.

| Task | Owner | File |
|---|---|---|
| V22-T1 | Shabaz | done (plan) |
| V22-T2 | Shabaz | [V22-T2.md](V22-T2.md) |
| V22-T3 | Shabaz | [V22-T3.md](V22-T3.md) |
| V22-T4 | Shabaz | [V22-T4.md](V22-T4.md) |
| V22-T5 | Shabaz | [V22-T5.md](V22-T5.md) |
| V22-T6 | Rahil | [V22-T6.md](V22-T6.md) |
| V22-T7 | Shabaz | [V22-T7.md](V22-T7.md) |
| V22-T8 | Danish | [V22-T8.md](V22-T8.md) |

**First time on a machine** (for example Danish's new MATLAB install): Claude runs [ENV_CHECK.md](ENV_CHECK.md) before any task and walks you through installing anything missing, one step at a time.

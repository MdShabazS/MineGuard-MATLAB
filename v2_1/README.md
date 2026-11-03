# MineGuard Advanced V2.1: interactive synthetic scenarios

SIMULATION ONLY. V2.1 lets a guide choose:
- a synthetic environment,
- the survey boundary and grid,
- private synthetic targets (none, manual or seeded random).

After the mission, the guide sees an **INTERACTIVE SYNTHETIC DEMO evaluation**. It is not held-out scientific accuracy. The detector is the frozen V2 detector, and every event remains a SUSPECTED anomaly.

V2.1 builds on V2 (`v2/matlab`) without modifying it. V2 code, tasks, evidence and sealed TEST groups are unchanged.

| File | Purpose |
|---|---|
| `docs/V21_RESEARCH.md` | V2 facts, MathWorks pages and design conclusions |
| `docs/V21_ARCHITECTURE.md` | data flow, visibility, ownership |
| `docs/V21_CONTRACT.md` | **frozen** cross-team contract `mg-v21-contract/1.0` |
| `docs/V21_ACCEPTANCE_MATRIX.md` | V2.1 criteria and actual results |
| `docs/V21_INTEGRATION_HANDOFF.md` | what Rahil integrates and runs |
| `tasks/manifest.json`, `tasks/status.json` | V21-001 to V21-008 |
| `matlab/+mgv21` | `contract`, `+scenario`, `+placement`, `+evaluation` |
| `tests/` | MATLAB unit tests (executed on Windows by Rahil) |

```matlab
addpath('v2/matlab'); addpath('v2_1/matlab');
```

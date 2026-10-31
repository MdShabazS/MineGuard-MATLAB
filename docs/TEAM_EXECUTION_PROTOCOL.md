# Two-Owner AI-Led Execution Protocol

## Owner responsibilities
| Work | Shabaz / ChatGPT | Rahil / Claude Code |
|---|---|---|
| Guide requirements, objective preservation | Accountable | Reviewer |
| Literature/publication and licences | Primary | Cross-check while coding |
| A-to-Z documentation | Primary | Technical reviewer |
| MATLAB version/toolbox audit | Review evidence + troubleshoot | Run locally and record |
| MATLAB/Simulink models and code | Acceptance and review; optional independent run | Primary |
| PPO and trained classifier | Design constraints and fair evaluation | Train/test with real logs |
| GUI and guide portal | Specifications/guide view | MATLAB GUI implementation; review portal |
| GitHub task gate + merge approvals | Documentation ownership and reviews | Development ownership and reviews |
| Final academic report and viva | Primary, fact-check against code evidence | Confirm accurate technical claims |
| User's physical computer environment | Cannot remotely install without actual access | Runs commands/installer and shares sanitized results |

## Autonomy boundaries
AI performs research and prepares code/tests within accessible environments. **Claude Code must actually execute MATLAB locally through the user-authorized toolkit**, while ChatGPT may review live GitHub state and evidence. Neither claims background activity or auto-completion without a running mechanism.

## Task protocol
1. Query latest authoritative `main` task states.
2. Check whether owner's task is READY. If not, report blockers; switch to another READY task if any.
3. Research official current version docs; cite source and licence.
4. Implement scope only if approved, create test and run real test.
5. Commit branch code/spec/evidence, create PR, other member reviews.
6. After CI success and approval merge; confirm exact main status before unlocking dependent task.
7. Work journal `tasks/updates.json`: only factual dated summary of executed changes, next steps and linked evidence.

## Rahil help desk
On receiving any MATLAB error, Shabaz/ChatGPT should ask for **one missing diagnostic detail only if genuinely required**, otherwise give the next exact check. Use release-specific docs; do not tell Rahil to reinstall MATLAB when a missing add-on or path error is more likely. All troubleshooting fixes require another test and evidence.

## Offline/temporary files
Use local MATLAB project checkouts to execute; GitHub remains canonical. Never commit cache, credentials or unlicensed third-party datasets. Any report screenshot or trained checkpoint must have provenance.

## Quality and deadlines
One side's high speed must not be counted as the other side's approval. If 2026-11-02 target is unachievable, report a validated partial build and explicit incomplete tasks rather than fake a full release.

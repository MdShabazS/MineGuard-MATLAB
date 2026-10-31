# MineGuard-MATLAB v1.0.0-rc.1 — release candidate notes (MG-017)

**SIMULATION ONLY.** MineGuard-MATLAB is an **advanced MATLAB research simulation**. It is **not** a validated operational mine-detection system. All targets and sensor signals are synthetic, and outputs are **SUSPECTED** anomalies. Nothing here demonstrates real landmine detection, mine clearance, calibrated buried-mine identification or measured field safety.

| Item | Value |
|---|---|
| Proposed version / tag | `1.0.0-rc.1` / **`v1.0.0-rc.1`** (first tag in this repo; SemVer pre-release, consistent with the `mg-contract/1.0` / interface-freeze v1.0 naming) |
| Tag status | **NOT CREATED.** The tag is to be created only after the MG-017 PR is reviewed and merged **and Shabaz explicitly authorizes it**. It must point at that merge commit on `main`. |
| Source base | `main` at `ec29ab2` (MG-019 DONE). The exact release-candidate SHA is the MG-017 merge commit; see `tasks/evidence/MG-017.md`. |
| Version in code | `mineguard.releaseInfo()` (printed by both demos) |
| Default planner | **Fixed-grid serpentine route (MG-005)** |
| PPO planner | **EXPERIMENTAL** (MG-013 / MG-019); never the default |

## 1. Headline results (read these first)
**Held-out mine-detection result: NEGATIVE.**
- The sealed MG-014 TEST (families GF-025..GF-030, run-lock MG014-RUNLOCK-1) was executed **exactly once**, on 2026-10-31 at 18:23 UTC.
- Primary method, weighted fusion / `single_valid`, cell-level common mask (500 evaluable cells: 4 positive, 496 negative): **TP 0, FP 26, TN 470, FN 4** (precision 0, recall 0, FPR 0.052).
- **No method is useful at the locked settings.** The OR rule finds all 4 positive cells only with 439 false-positive cells (FPR 0.885). Stress conditions are worse (noise ×3: FPR ≈ 0.94; soil shift: FPR 1.0).
- The TEST is **consumed**. It must not be re-run, retuned or relabelled as fresh. Since MG-017, `runMG015Locked` refuses (`mineguard:TestConsumed`, `mineguard:RunLockExists`). Any improvement needs a new, separately preregistered study with fresh held-out families.
- **Coverage is not detection accuracy.** The fixed grid reaches 100 % legal-cell coverage, but that says nothing about detection reliability.
- The attractive **S0 demo** (TP 1 FP 4 on a 0.3 m altitude / 0.5 m cell fixture) is a **display fixture, not held-out performance**. Both the console and the dashboard now say so.

**PPO vs fixed grid (MG-019, preregistered MG019-SPLIT-1):**
- On 8 grid-feasible fresh scenarios, **PPO lost all 8** (Δcoverage −0.062, 95 % CI [−0.107, −0.040]; +3.15 m). 0 of 20 PPO missions completed.
- **The fixed grid remains the default; PPO stays EXPERIMENTAL.**

Original Phase-1 objectives (wording unchanged, [PHASE1_BASELINE.md](PHASE1_BASELINE.md)). Grades accepted in the MG-016 audit:

| Objective | Simulation-stage status |
|---|---|
| O1 autonomous pre-programmed survey | **Tested in simulation** (kinematic virtual UAV; no physical flight) |
| O2 accurate subsurface detection via thermal + metal coil + fusion | **Pipeline implemented and tested; performance objective NOT achieved** (negative held-out result) |
| O3 geo-tagged threat map and remote GCS | **Virtual map and offline replay tested**; no physical GNSS or live GCS |
| O4 eliminate personnel exposure | **Concept illustrated in simulation only**; no measured safety benefit |

## 2. Requirements and environment
- **Tested host:** Windows 11 Pro (build 26300), MATLAB **R2026b Update 1** (26.2), PCWIN64, interactive desktop with a display.
- **Core pipeline and dashboard (`mineguardDemo`):** base MATLAB only. The dashboard (`uifigure`) needs a desktop session with a display.
- **Experimental PPO (`mineguardPPODemo`, MG-013/MG-019 tests):** Reinforcement Learning Toolbox and Deep Learning Toolbox.
- **Installed on the tested host (all 26.2):** Aerospace, Deep Learning, Mapping, MATLAB MCP Server Toolbox 0.5.0, Navigation, Reinforcement Learning, Simulink, Stateflow, UAV. **Sensor Fusion and Tracking Toolbox is not used** (not licensed; fusion is in core MATLAB).
- **Repository checks:** Node.js 20+ (`scripts/task-gate.mjs`). No network access, hardware or external dataset is needed.
- **Frozen artifacts shipped in the repo:**
  - PPO checkpoint `results/approved/mg013_ppo_checkpoint.mat` (SHA-256 `5a0da171…b8ad`, verified on load)
  - MG-014 manifest (`fa5a3fa5…`)
  - MG014-RUNLOCK-1 (LF-normalised `5e9f8533…`)
  - MG-019 manifest (`dda848a1…`)
  - `testMG017Release` checks all of these by SHA-256.

## 3. Installation
```text
git clone https://github.com/MdShabazS/MineGuard-MATLAB.git
cd MineGuard-MATLAB
git checkout v1.0.0-rc.1        # after the tag is authorized and created; until then use the MG-017 merge commit
```
Open MATLAB R2026b with the repository root as the current folder. Nothing else needs installing for the core demo.

## 4. One-command fixed-grid demonstration (release default)
```matlab
addpath('matlab'); mineguardDemo
```
- **Steps:**
  - scenario (MG-004)
  - fixed-grid route and virtual UAV poses (MG-005)
  - synthetic thermal [K] and EM [dimensionless] readings (MG-007)
  - frozen detector producing SUSPECTED events (MG-009)
  - separate aggregate evaluation
  - redacted bundle
  - MG-011 dashboard
- **Dashboard controls:** Play Simulation, Pause, Step, Seek slider, Reset, Export run data.
- **Options:**
  - `mineguardDemo("S0", 'Play', true, 'ExportTo', folder)` plays automatically and exports.
  - `mineguardDemo("GF-020")` runs a locked TRAIN or VALIDATION family. TEST families GF-025..030 are refused (`mineguard:SealedTest`).
- **Export:** a new folder `MG011-export-<scenario>-<UTC stamp>` containing `poses.csv`, `thermal_samples.csv`, `em_samples.csv`, `events.csv`, `summary.json`, `run_bundle_redacted.mat` and `snapshot.png`.
  - Every file is read back and verified before the export is reported as successful.
  - The export is an allowlisted view: no target IDs, labels, materials, burial depths or target coordinates.

## 5. Experimental PPO demonstration (optional, not the default)
```matlab
addpath('matlab'); mineguardPPODemo            % default scenario MG019-7307
mineguardPPODemo(7301)                          % grid-infeasible case: grid shown as NOT RUN, never as a PPO win
```
- Verifies the frozen checkpoint SHA-256, runs **real deterministic PPO inference** and the fixed grid on the same scenario, prints paired metrics and opens the comparison window. The window offers full replays and "Export comparison".
- The comparison table must exactly match the 27-column public allowlist (`mineguard.contract.comparisonColumns`). Anything else is rejected with `mineguard:InvalidComparison`.
- The 25-action policy refuses 100-cell grids (`mineguard:IncompatiblePolicy`).

## 6. Architecture and workflow
```text
config ─► mineguard.runExperiment ─► MG-004 generateScenario ─► MG-005 grid route / poses / coverage
                                     ─► MG-007 simulateThermal / simulateEM (public samples, invalid = NaN + reason)
                                     ─► MG-009 detectAnomalies (observables only) ─► SUSPECTED events
                                     ─► MG-009 scoreDetections (ONLY truth consumer; aggregate result)
                                     ─► makeRunBundle (redacted) ─► MG-011 MissionApp (replay / export)
optional: mineguard.integration.runSurveyMission(config, "ppo") ─► frozen MG-013 policy ─► same pipeline ─► ComparisonApp
```
- Details: [ARCHITECTURE.md](ARCHITECTURE.md), [MG003_INTERFACE_FREEZE.md](MG003_INTERFACE_FREEZE.md), [MG010_MISSION_DASHBOARD_SPEC.md](MG010_MISSION_DASHBOARD_SPEC.md), [MG012_PPO_POLICY_AND_FAIR_BENCHMARK.md](MG012_PPO_POLICY_AND_FAIR_BENCHMARK.md).
- Hidden truth goes only to the evaluator. Navigation, detection, PPO observations, replay and export never receive it.

## 7. Verified screenshots and safe exports
- **MG-017** (clean-checkout run, this release candidate): `tasks/evidence/MG-017/`, listed in `tasks/evidence/MG-017.md`.
- **Earlier recorded runs:**
  - `tasks/evidence/MG-015/MG-015-0[1-5]-*.png` and `tasks/evidence/MG-015/demo-export/`
  - `tasks/evidence/MG-019/MG-019-0[1-5]-*.png` and `tasks/evidence/MG-019/demo-export/`

## 8. Regression results for this release candidate
Executed with real MATLAB R2026b on the tested host. Exact counts, failures and `checkcode` findings are in `tasks/evidence/MG-017.md`, section "Regression".
- Suites: MG-004, MG-005, MG-007, MG-009, MG-011, MG-013, MG-015, MG-019 and the new MG-017 release-validation suite (`testMG017Release`).
- **GitHub Actions (Task Gate, browser-qa) is Node-based governance and portal CI: it does not run MATLAB.** All MATLAB results are owner-executed records on the tested host. The MG-016 audit was a documentary and CSV review, not an independent MATLAB reproduction.

## 9. Known scientific and engineering limitations
- **Detection:** negative held-out result (above). The sensor models are assumed proxies with no calibration against real instruments or soils. The 5 m weak-standoff profile has every EM reading `MODEL_OUT_OF_DOMAIN`.
- **Sealed TEST:** consumed once. The run-lock still contains `PROPOSED_PENDING_REVIEW` internally. Approval is recorded separately in `MG014-RUNLOCK-1-approval-preflight.md`, and the frozen file is deliberately not edited.
- **PPO:** trained on a 5×5 grid with a 25-action policy. It underperformed the grid (MG-013 and MG-019). It is not evaluated on the 10×10 locked GF families (MG-015 L-23 NOT RUN).
- **Platform:** tested on Windows 11 / R2026b only. **macOS and Linux: NOT TESTED.** Other MATLAB releases: NOT TESTED.
- **Features NOT IMPLEMENTED:**
  - 3-D replay (the dashboard is 2-D offline replay)
  - real-time field GCS or telemetry link
  - hardware GNSS (coordinates are virtual)
  - thermal camera, LiDAR or RGB hardware
  - Raspberry Pi or flight controller integration
  - physical UAV dynamics (constant-speed kinematic model with ideal turns)
- **Provenance:** `runExperiment` appends `+uncommitted` to the git SHA on a dirty tree. `runSurveyMission` (MG-019) does not; that is a known limitation. The MG-019 benchmark ran on a working copy identical to `41b62b9`.

## 10. Troubleshooting and fallback demo
| Symptom | Fix / fallback |
|---|---|
| `Undefined function 'mineguardDemo'` | Run from the repository root: `addpath('matlab')` |
| Dashboard does not open (no display, `-batch`, remote session) | Use a desktop MATLAB session. Fallback: `[rb, rec] = mineguard.runExperiment(mg015DemoConfig("S0"))` (after `addpath(fullfile('matlab','experiments'))`) prints nothing but returns the full redacted bundle; show `tasks/evidence/MG-017/` screenshots and export |
| `mineguard:CheckpointMismatch` / `CheckpointMissing` | The PPO checkpoint was altered or not checked out (LFS/binary). Re-clone; never substitute another policy. The core demo does not need it |
| `mineguardPPODemo` fails: RL/DL toolbox missing | PPO is optional. Present the fixed-grid demo and the MG-019 evidence screenshots and summary |
| Export reports `Export FAILED` | Choose an existing, writable folder; a failed export writes nothing and claims nothing |
| `mineguard:SealedTest` / `TestConsumed` | Intended: the sealed TEST is never reopened |

## 11. Academic presentation outline (simulation-honest)
Follow [GUIDE_REVIEW_AND_DEMO.md](GUIDE_REVIEW_AND_DEMO.md) with these actual results:
1. The **unchanged** four Phase-1 objectives.
2. Why the project moved from costly UAV hardware to a MATLAB simulation of the same scientific question.
3. The end-to-end synthetic mission architecture (section 6).
4. Live `mineguardDemo`: autonomous virtual grid navigation, synthetic thermal and EM traces (including invalid gaps), SUSPECTED events on the virtual map, export. State that S0 is a display fixture.
5. **Actual held-out result: TP 0, FP 26, TN 470, FN 4, which is negative.** Explain why: weak synthetic contrast at the 2 m locked geometry, EM out of domain at 5 m, and false alarms from clutter and noise.
6. `mineguardPPODemo`: a genuine PPO vs fixed-grid comparison; PPO lost on all feasible pairs.
7. Limitations (section 9) and the **future physical validation** that would be required: calibrated sensors, real soils, field trials under proper authority, independent safety review.

**Never claim** real landmine detection, mine clearance, safe or cleared land, calibrated buried-mine identification or measured field safety.

## 12. MG-016 findings closure (summary)
MG016-R01 to MG016-R08 are each dispositioned in `tasks/evidence/MG-017.md` (closure matrix): MG016-R01 negative-result prominence … MG016-R08 audit/CI boundaries.

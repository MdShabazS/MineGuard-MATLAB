# V2-007 UI handoff to Rahil's Windows machine

**Mac MATLAB work stopped on Shabaz's instruction.** Windows is now the primary development, test and demonstration machine. This is not task completion: V2-007 stays IN_PROGRESS, and Phase G stays BLOCKED until integration is accepted. SIMULATION ONLY.

## What each commit has been tested with

| Commit | Change | Real MATLAB result on the Mac |
|---|---|---|
| `7d5ad0a` | Cherry-pick of `942aa08`: `bindEvidence`, `evidenceContext` | Tested with `8103904` |
| `8103904` | Removes `bindSensorLog` and `readSensorLog`; one seam | UI GUI 62/62 |
| `1127a3d` | `MissionSession.inspect` matches #91; the dashboard uses the new `inspectCurrentRun` | **Merged with #91 `0f32e71` only:** bridge 37/37, V2-006 28/28, real-detector click, tamper and reset check passed. **GUI suite NOT completed at this commit** |
| `1bf5e98` | Any source read or validation failure shows the error and keeps the run going; 1 new GUI test | **UNTESTED: no MATLAB result, including its new test** |

The earlier records in `final-verification/README.md` describe `bindSensorLog` at older commits and remain history. `UI_INTEGRATION_CONTRACT.md` describes the current seam.

**No result exists for #91 `dd349d5` merged with this UI.** An application check on UI + `dd349d5` + #96 was stopped part-way, so its output is discarded. It wrote 3 screenshots but no pass or fail was recorded, so they are not evidence. The requested 20 and 100 tick comparison on this merge was **not run**.

## Steps for Windows

1. Fetch this branch. Merge its head with #91 in a disposable tree. Do not push the combination to #67.
2. Confirm one method: `numel(findobj(meta.class.fromName('mgv2.ui.MissionSession').MethodList, 'Name', 'evidenceContext'))` must be 1. On the Mac, `dd349d5` merged without conflict and the file held one definition. Loading the class has not been confirmed.
3. Run `testV2007MissionControlUI` in a desktop session (the UI branch has 63 tests with `1bf5e98`), then `testV2007Bridge`, including `b38` and `b40`.
4. Add #96 (`78000de`) and run `testV2005NestedMetadataContract`, `testV2005QualityContract`, `testV2005Sensors`, `testV2006Detection`. Its bridge compatibility was checked only at `0b303d5` with `0f32e71`.
5. Check the real application: start, pause, resume, abort, reset; click an event and check RGB and thermal crops; reset and confirm the old event is refused; Thermal dropout scenario; dark and light desktops; 960x640 and wide; close with no figures or timers left.
6. Benchmark paced 1×, `RefreshTicks` 20 and 100, three missions each, recording load, sim/wall, refreshes per second, render p50 and p95, gaps, dropped frames and event age.

## Open points

- **`inspect` differs from Rahil's request.** He asked to keep the evidence check inside `MissionSession.inspect`. Doing that made Git keep two `evidenceContext` copies on merge, so it moved to `inspectCurrentRun`, which the dashboard calls. Please say if the bridge or its tests need it in `inspect`.
- `record_basis` and inspection age are not displayed yet. This is undecided.
- At 100 ticks, the 5 s stale colour can flicker just before each rebuild.
- The rebuild interval decision and detector rebuild stalls (#76) remain open.
- Mac timings do not apply to Windows, and earlier records were taken under varying load.

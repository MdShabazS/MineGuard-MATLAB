# ENH-010: offline-first Ballari-to-campus introduction storyboard

Status: **early stacked draft**, not accepted ENH-010. Based on ENH-009 branch at `d960c40` and isolated from the current V2 UI, mission engine, detector and datasets. No approved BITM anchor or imagery is available.

## Presentation boundary

1. `CITY_CONTEXT`: a card names Ballari for human orientation. It explicitly says it is **not a map** and has no coordinates or scale. It does not draw a fabricated Ballari city outline.
2. `CAMPUS_CONTEXT`: calls the original ENH-009 offline schematic. It says **ILLUSTRATIVE / NOT SURVEYED / SIMULATION CONTEXT** and depicts generic shapes in arbitrary units, not the actual BITM footprint.
3. `SIMULATION_HANDOFF`: a separate title card directs the presenter to open the existing synthetic UAV simulation. It neither starts nor changes a mission and contains no real-campus target or survey claim.

`+mgenh010/advanceStoryboard.m` is a pure, bounded `NEXT`/`BACK`/`RESET` state machine. `+mgenh010/renderStoryboardFrame.m` creates one self-contained figure for a selected stage, using only base MATLAB graphics and the ENH-009 fallback. The caller owns each figure. There is no animation, automatic timing, basemap provider, network access or UI hook; presenter-controlled static frames avoid a startup/performance claim before measurement.

## Reproduce when shared MATLAB is available

```matlab
addpath('v2/enhancements');
s = mgenh010.advanceStoryboard([],"RESET");
[f,info] = mgenh010.renderStoryboardFrame(s,'Visible','off'); close(f);
s = mgenh010.advanceStoryboard(s,"NEXT");
[f,info] = mgenh010.renderStoryboardFrame(s,'Visible','off'); close(f);
r = runtests('v2/enhancements/tests/testENH010Storyboard.m');
assert(all([r.Passed]));
```

Six focused tests cover deterministic and bounded state, labels and simulation separation, card text colours in both themes, repeated graphics cleanup, and a source dependency guard. **MATLAB was not executed for this draft** because the shared runtime was in use; no pass count or visual acceptance is claimed. The source guard does not substitute for an OS network-denied run.

## Dependencies and remaining approval

[Issue #80](https://github.com/MdShabazS/MineGuard-MATLAB/issues/80) requests a recognizable Ballari-to-BITM geographic intro. This draft supplies a truthful offline presentation structure, **not a geographic map or accepted campus extent**. The [presentation roadmap](../docs/V2_BITM_BALLARI_PRESENTATION_ROADMAP.md) requires an approved anchor, attributable source and separation from synthetic mission results. ENH-009 rights and the ENH-008 context plan remain open. Actual geographic imagery and location may be added only after source permissions, attribution and campus bounds are approved. Mac/Windows MATLAB results, light/dark visual review, offline denial, repeated lifecycle and measured startup cost are pending at an exact SHA. No ENH-010 integration into the live UI is proposed here.

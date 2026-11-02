# Satellite preview: Windows acceptance of PR #75 (ENH-002)

Scope: optional planning preview only. SIMULATION ONLY: the route is a simulated plan drawn for geographic context, never flown. A basemap is context, not evidence of any sensor observation, and this is not a hazard map.
Executed by Claude Code (Opus 5.5) through scripts on Rahil's Windows host (Windows 11 Pro build 26300, MATLAB R2026b Update 1, 26.2.0.3433840, PCWIN64), on 2026-11-02. Human review pending.
**Execution SHA: `79ecd20a6d7a785ca67c389e029984ecac6f3a7d`** (MATLAB code unchanged from the Mac execution SHA `f782520`). This evidence is a later commit.

**Result: Windows checks PASS, apart from the items under "Not done". No code change was needed. PR #75 and #72 stay draft for human review.**

Demo anchors: public landmarks already used in the Mac record, heights assumed, not surveyed. Great Pyramid `[29.97917 31.13417 80]`, Eiffel Tower `[48.85837 2.29448 100]` (offline test). No user location or operational location was used.

## Tests

`testV2SatelliteGeo` in a clean worktree: **15 tests, 15 PASS, 0 FAIL, 0 INCOMPLETE**, 14.2 s (`regression-79ecd20.log`).

## Checks on a real MATLAB desktop (`accept.log`, `sat_win_accept.m`)

| Check | Result |
|---|---|
| Satellite imagery | Loaded. Screenshots inspected by Claude, not by a person |
| Credit | `Powered by Esri | Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community`, read live. Same text as the Mac record |
| Other basemaps | `topographic`, `streets-light` point to the map's own credit; `darkwater` credits Natural Earth |
| Themes | MATLAB theme set temporarily to Dark and Light, then restored to `System`. Contrast in both: axis 15.57, warning 15.90, credit 15.98, status 12.23, link 11.18. Same as the Mac for the values both recorded |
| Route alignment | Independent inverse of the returned coordinates: route error at most 9.8e-10 m, boundary 7.2e-10 m. Plotted line equals the returned route |
| Zoom and pan | Programmatic only: x3 1074 ms, x12 93 ms, pan 79 ms (one run each). Credit stays visible |
| Warning | Visible in all 8 theme and basemap views and in all 4 offline stages of the satellite window |
| Open and close | 30 cycles: 0 errors, 0 figures, 0 timers left; median 1.42 s, max 3.89 s; MATLAB memory 3501 → 3503 MB |
| Invalid anchors | `[0 0 0]`, `[0.001 0 0]`, NaN, polar, dateline and height limit refused, 0 figures opened |

## Offline and recovery (`offline.log`, `sat_offline.m`, `deny_proxy.js`)

A second MATLAB used a throwaway preferences folder and a local proxy that refused only Esri hosts, so MATLAB licensing kept working. System network settings were not changed. Network check while denied: `HTTP503StatusCodeError`. The proxy counted 53 refused Esri requests (`proxy.log`).

| Step | Credit source | Map |
|---|---|---|
| Denied | Pinned | Uniform grey tiles with the route drawn; MATLAB warns of "missing" tiles |
| Denied, `darkwater` | MathWorks documentation | Draws normally |
| Allowed, same window untouched 15 s | Pinned | Unchanged: tiles do not return by themselves |
| Allowed, after a pan in the same window | Pinned; status still describes opening, by design | Imagery returns |
| Allowed, new window | Live | Imagery |

**The ENU mission map does not depend on the service.** With Esri denied, mission control from UI `7e52523` ran 400 ticks to SURVEY, with 0 geographic axes and status `OFFLINE LOCAL ENU`. No file under `+mgv2` in that combination calls `geoaxes`, `geoplot`, `geobasemap`, `webread`, `websave` or `webwrite`, or uses `mgv2.geo`. The `0 of 0` line in `accept.log` is not this evidence: that worktree has no `+ui` folder, so its scan found no files.

## Not done

- A person looking at or using the window, including mouse zoom and pan and clicking the link.
- A physical network disconnect. This is process-level denial of the provider only.
- Owner confirmation of Esri's terms for the intended use.
- `enu2geodetic` comparison: Mapping Toolbox is not installed.
- Integration with the dashboard. This preview is standalone.

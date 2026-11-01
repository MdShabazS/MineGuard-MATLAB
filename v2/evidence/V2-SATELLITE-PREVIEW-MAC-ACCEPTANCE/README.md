# Satellite preview: Mac acceptance of PR #75

Scope: optional planning preview only. SIMULATION ONLY: the route is a simulated plan drawn for geographic context, never flown. Not a hazard map.
Executed by Claude Code (Opus 5.5) through the MATLAB MCP Server on Shabaz's Mac (macOS 27.0.1, R2026b Update 1); human review pending.
**Execution SHA: `f782520611c991d5a2453518c0f030ae70c4b082`.** This evidence is a later commit. Earlier records are unchanged.

**Result: Mac acceptance PASS at that SHA. Windows and human review are outstanding, so the PR stays draft.**

Demo anchors, public landmarks with assumed heights, not surveyed: Great Pyramid `[29.97917 31.13417 80]`, Eiffel Tower `[48.85837 2.29448 100]`, Corcovado `[-22.95191 -43.21049 700]`.

## How the commits got here

| Commit | Result |
|---|---|
| `fd6daa4` (#72) | 7/7. FAIL: no visible attribution; 1.09:1 axis text in light theme |
| `4ccbc5f` (#75 as submitted) | 10/10; theme fixed. Credit list out of date; `darkwater` omitted Natural Earth; `[0.001 0 0]` accepted; no connection status |
| `dec0670` | Current credits, status, wider guard. Reconnect showed a stale status |
| `e213871` | Status worded as true at open. Regression exposed the two defects below |
| `f782520` | `topographic` and `streets-light` no longer name a service list, because the map credits TomTom while that service credits HERE. Test suite sets its own path |

## Results at the execution SHA

| Suite | Tests | Passed | Failed | Incomplete |
|---|---|---|---|---|
| testV2SatelliteGeo (alone, clean worktree) | 15 | 15 | 0 | 0 |
| V2-002 | 22 | 22 | 0 | 0 |
| V2-003 | 22 | 22 | 0 | 0 |
| V2-005 | 28 | 28 | 0 | 0 |
| V2-007 UI (`57363dc`) | 35 | 35 | 0 | 0 |
| testV2SatelliteGeo (combined) | 15 | 15 | 0 | 0 |
| **Combined total, UI `57363dc` with these files** | **122** | **122** | **0** | **0** |

`checkcode`: 0 messages on the three files.

| Check | Result |
|---|---|
| Real imagery | Pass. Pyramids visible; tile requests to `server.arcgisonline.com` |
| Satellite credit | Footer: `Powered by Esri | Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community`, the service's `copyrightText`. Visible at default, x3 and x12 view |
| Source link | `uihyperlink` to the World Imagery service page; URL returned HTTP 200. Not clicked by a person |
| Other basemaps | `topographic`, `streets-light`: map's own credit visible at the default view. `darkwater`: credits Natural Earth, no Esri claim |
| Themes | Dark and Light desktop: axis 15.57:1, warning 15.90:1, credit 15.98:1, link 11.18:1 |
| Coordinates | Identical to `fd6daa4` (max difference 0) over 3000 points at 7 anchors; route, boundary and home identical |
| Invalid anchors | `[0 0 0]`, near-placeholder (within 0.01 deg), NaN, Inf, polar, dateline and height limits rejected before any figure |
| Offsets | 10 km horizontal and vertical accepted, just beyond rejected, 5000 km rejected |
| Cleanup | 30 opens and closes: 0 errors, 0 figures, 0 timers left. Open median 0.58 s `darkwater`, 0.69 s satellite |
| Programmatic zoom | Median 22.9 ms, p95 172.4 ms, max 366.1 ms (one run; other runs were slower, up to 1214.9 ms) |

## Offline and reconnect

System network settings were not changed. A second MATLAB ran under `sandbox-exec` with outbound TCP denied except localhost; `webread` confirmed ConnectionRefused.

- **Offline:** MATLAB warned of "missing" tiles. An uncached area showed a blank map, a cached area showed cached tiles. The pinned credit and the status remained visible. `darkwater` drew normally.
- **Offline ENU mission control:** ran 400 ticks, no geographic axes, map status `OFFLINE LOCAL ENU`.
- **Reconnect:** the same process used a local proxy switched off then on, with MATLAB's proxy preference set in a throwaway preferences folder. The proxy was on during MATLAB start-up for licensing, then off.

| Step | Map variation | Note |
|---|---|---|
| Off | 4.8 | Blank; pinned credit |
| On, same window untouched 15 s | 4.8 | Tiles do not return by themselves |
| On, after a pan in the same window | 42.5 | Tiles return; 116 tile requests allowed |
| On, new window | 53.9 | Live credit |

## Limits

- A physical Wi-Fi disconnect was not used; this is process-level denial.
- The status reports the moment of opening, by design. MATLAB exposes no documented tile-failure signal without Mapping Toolbox.
- The Esri KB article still lists older sources; the footer follows the live service. Whether this meets Esri's terms for the intended use is for the project owner to confirm.
- The map's own satellite credit appears only at some views, which is why the footer is permanent. `readBasemapImage` needs Mapping Toolbox, which is not installed.
- `enu2geodetic` could not run: Mapping Toolbox is not installed. `enu2lla` matched `fd6daa4`, whose coordinates are unchanged.
- One `Framework Error` occurred once during open/close cycles while a second MATLAB was starting. Not reproduced in 60 later cycles; cause unknown.
- A proxy test where MATLAB ignored environment variables was discarded.
- Windows NOT RUN. The scale bar is low contrast over light tiles (MATLAB's own element).

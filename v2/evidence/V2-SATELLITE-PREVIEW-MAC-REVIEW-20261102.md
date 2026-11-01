# Satellite preview: independent Mac review and proposed display fixes

**Review date:** 2026-11-02 IST. **Scientific scope:** academic simulated planned route on a real geographic-context basemap, not a real flight or landmine-detection map.

## Reviewed original PR #72

- Exact tested source: `fd6daa40b1049af806e7fee48476f2c640ab13a5` (clean detached worktree).
- Host: MATLAB R2026b Update 1, macOS 27.0.1, UAV Toolbox; Claude Code through MATLAB MCP.
- Anchor displayed: `[29.97917 31.13417 80]` Great Pyramid, illustrative; 80 m ellipsoid height **assumed**, not surveyed.
- **7/7 original MATLAB coordinate tests PASS**, 0 fail/incomplete.
- Coordinate cross-check against `enu2lla` reported latitude difference 1.42e-14° and height difference 2.79e-9 m. `enu2geodetic` + `wgs84Ellipsoid` requested comparison **NOT COMPLETED** (Mapping Toolbox not installed despite reported license).
- Actual online satellite imagery loaded; public planned route, home and boundary position tests passed (reported under 5e-9 m coordinates).
- Dark theme geo-axis text PASS at 12.44:1; light theme **FAIL 1.09:1**.
- **Esri credit NOT VISIBLE** even after tiles loaded. The internal attribution object had blank text/hidden status. Do not alter undocumented `BasemapDisplay` internals.
- `darkwater` displayed as plain grey. Existing offline ENU map data unchanged. **Actual disconnected/no-network fallback NOT TESTED**.
- 10 create/close cycles: no figures/timers leaked. Creation 0.08–0.13 s, first draw 0.25–1.55 s. Zoom (20 calls): median 32.8 ms, p95 141.2 ms, max 166.2 ms. Full hand-pan/tile-load and Windows checks NOT RUN.
- Observed guards: near-zero geographical anchor coordinates and extreme vertical `u` accepted erroneously.

**Verdict for original PR #72: FAIL / CHANGES REQUESTED.** The verified geometry and tile load do not override accessibility/attribution blockers.

## Proposed correction on independent stacked branch (not yet executed in MATLAB)

1. Set the `uifigure` graphics theme explicitly to `dark` **before creating geographic axes**; set `gx.AxisColor` explicitly to a high-contrast light value.
2. Show an always-present visible provider-credit area **outside** the geographic map plus a clickable source-credit URL. For satellite, use Esri's published World Imagery credit list and 'Powered by Esri'; for the other basemap modes, use truthful generic source information. The underlying map's own credits must never be removed or suppressed. Verify actual Esri/MathWorks requirements against live screenshot and provider policy.
3. Reject near-null geographic anchors regardless of tiny ellipsoid-height changes; bound vertical offsets to 10 km in the same local-field geometry limit used for horizontal offsets.
4. Add three focused guard tests in addition to the original seven. These **10 authored tests are NOT RUN** on this corrective branch.
5. Do not modify the existing detector, V2 UI, mission engine, sensor contracts, data partitions or official task statuses.

**References**
- [MathWorks figure themes](https://www.mathworks.com/help/matlab/ref/theme.html)
- [MathWorks geoaxes axis appearance](https://www.mathworks.com/help/matlab/creating_plots/customize-appearance-of-geographic-axes.html)
- [MathWorks UI hyperlink](https://www.mathworks.com/help/matlab/ref/uihyperlink.html)
- [Esri World Imagery source credits, updated 2026](https://support.esri.com/en-us/knowledge-base/what-is-the-correct-way-to-cite-an-arcgis-online-basema-000012040)
- [Esri licensing and attribution](https://location.arcgis.com/help/licensing-and-attribution/)

## Mac acceptance required on corrected code (all currently NOT RUN)

| Check | Pass condition |
|---|---|
| Revised guard tests | All 10 MATLAB tests PASS; no MATLAB lint/functional errors |
| Light/dark desktop themes | Visible axis coordinates and title/banner; measured minimum text contrast at least 4.5:1 for relevant labels and credit |
| Attribution | Readable 'Powered by Esri', complete World Imagery published credit list and clickable official source-credit link visible on captured satellite screen; provider terms satisfied |
| Network | Fresh live satellite map loads and provider attribution remains visible at relevant zoom; no assumption that cached tiles = successful fresh network |
| Other basemaps | `darkwater`, `streets-light` and `topographic` work when supported; no incorrect satellite-only credit attached |
| Scene consistency | Route/home/boundary geometry identical to original fixture; no hidden target, event, detector or sensor outputs |
| Resource cleanup | 10 repeat opens and closes leave 0 figures/timers |
| Offline fault | Explicitly disconnect network and document behavior, failures and local ENU map fallback (do not claim offline satellite) |
| Cross-platform | Windows MATLAB GUI smoke test, or disclose NOT RUN before final merge |
| Provenance | Save screenshots, exact tested commit, commands, log and test counts to a reviewed evidence commit |

This work remains **DRAFT** until actual Mac results exist. Never report a corrective code commit or a passing CI task gate as an executed MATLAB test.

# V2 experimental satellite preview — engineering verification plan

**Status: CODE PROPOSED, MATLAB NOT RUN / SATELLITE TILES NOT VERIFIED.**

This work is independent of V2-006/V2-007's official governed task status, and is not a V2-008 verification result.

## Files and scope

- 'v2/matlab/+mgv2/+geo/enuToWgs84.m': pure WGS84 ENU-to-geodetic conversion using base MATLAB (ECEF + iterative inversion); explicit anchor and small-extent validation.
- 'v2/matlab/mgv2SatelliteMapPreview.m': optional separate 'geoaxes' preview of the **simulated planned** route, boundary, and home on 'satellite' (online) or 'darkwater' (minimal offline geographic basemap).
- 'v2/matlab/tests/testV2SatelliteGeo.m': 7 math/guard tests. These have **not** been executed.
- No edits to V2 task status, scientific study data, detector, mission engine, renderer, operational UI, or V1.

## Actual Mac acceptance instructions

1. In a separate worktree, verify branch HEAD and a clean tree, then run from repo root:
   'addpath("v2/matlab"); runtests("v2/matlab/tests/testV2SatelliteGeo.m")'
   Record genuine tests/passed/failed/incomplete and MATLAB version. Run other existing tests as needed.
2. Choose a **real but explicitly entered DEMO anchor** that is appropriate for display and whose use is permitted; never use the placeholder [0 0 0]. Use a documented WGS84 [latitude longitude ellipsoidal height]. Never automatically infer current device location.
3. Try online:
   'out = mgv2SatelliteMapPreview(AnchorLLA=[LAT LON ELLIPSOID_H]);'
   Confirm satellite tiles ACTUALLY load, map-provider attribution is readable, yellow perimeter / cyan planned route / home marker are accurately aligned, and the simulation-only warnings are visible. Photograph/capture a live screen.
4. Close the result ('delete(out.figure)') and try:
   'out = mgv2SatelliteMapPreview(AnchorLLA=[LAT LON ELLIPSOID_H], Basemap="darkwater");'
   Confirm even when offline geographic context is limited, the **existing** 'MapPanel' offline ENU mission map still works.
5. Optional: if licensed, compare transformed waypoint coordinates to 'enu2geodetic(...,wgs84Ellipsoid("meter"))' within a documented tolerance. This independent reference is not a prerequisite for basic use.
6. Verify [0 0 0] anchor fails before creating figures, no private truth or suspect events enter the optional preview, MATLAB light/dark screenshots show attribution and warning text, no figures/timers leak, and flight simulation output remains unchanged.
7. Any network unavailable or tile failure must be reported **NOT VERIFIED**, not 'PASS'. Native base-map acceptance is not proof of either online service reliability or physical surveying capability.
8. Benchmark preview startup and interaction if optional preview is to be integrated. Do not burden the live simulation clock; it is a separate user-triggered window in this prototype.

## Pending results

| Case | Status before real execution |
|---|---|
| Pure coordinate tests | NOT RUN |
| Online satellite load and attribution | NOT RUN |
| Offline synthetic mission map unchanged | NOT RUN |
| Optional darkwater geographic preview | NOT RUN |
| Mac and Windows GUI behavior | NOT RUN |
| Integration with existing UI | NOT STARTED / NOT AUTHORIZED |
| Scientific detection outcomes | UNCHANGED (not evaluated here) |

### External API references

- MATLAB geographic axes: https://www.mathworks.com/help/matlab/ref/geoaxes.html
- Geographic line plotting: https://www.mathworks.com/help/matlab/ref/geoplot.html
- Available basemaps/attribution: https://www.mathworks.com/help/matlab/ref/geobasemap.html
- Offline basemap limitations: https://www.mathworks.com/help/matlab/creating_plots/access-basemaps-in-matlab.html
- Reference ENU conversion (Mapping Toolbox): https://www.mathworks.com/help/map/ref/enu2geodetic.html

**Scientific warning:** this is only a planning visual with synthetic coordinates anchored for geographic context, never a real drone's location or a cleared/suspected-mine geolocation map.

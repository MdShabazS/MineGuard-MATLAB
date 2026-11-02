# ENH-009: original offline campus-context schematic

Status: **partial independent implementation for draft review, not ENH-009 DONE**. Source baseline: `origin/main` at `3b130b3428174234224153f09ba2b624c5677a45` (includes merged PR #94). No campus coordinates, imagery tiles, scientific data or official task status changed.

## Architecture and use

`+mgenh009/renderOfflineCampusContext.m` creates a self-contained MATLAB figure using base graphics only. Four generic rectangles and three lines are drawn in arbitrary diagram units, without WGS84, ENU, campus bounds, buildings or a flight path. Its fixed primitive arrays and `info` struct make output deterministic and reusable by a later ENH-008 or ENH-010 caller. The visible banner reads **ILLUSTRATIVE / NOT SURVEYED / SIMULATION CONTEXT**. The figure also says that units are arbitrary. The caller owns the figure and must close it.

Optional `AssetPath` is a future integration hook, not an imagery loader. If absent, `asset_status=NOT_REQUESTED`; if missing, `MISSING_SCHEMATIC_USED`; if present, `PRESENT_NOT_APPROVED_SCHEMATIC_USED`. All cases draw the same original schematic. This intentionally avoids silently displaying an asset whose license, attribution and bounds were not approved. The function has no map provider, network, file download, timer, callback or production UI dependency. No suspected-target marker appears on a campus context.

Reproduction from repository root after MATLAB is free:

```matlab
addpath('v2/enhancements');
[f, info] = mgenh009.renderOfflineCampusContext('Visible','off', ...
    'AssetPath','nonexistent-campus-asset.png');
assert(info.asset_status == "MISSING_SCHEMATIC_USED");
close(f);
r = runtests('v2/enhancements/tests/testENH009OfflineContext.m');
assert(all([r.Passed]));
```

`testENH009OfflineContext.m` has five focused tests: source-level absence of network/file imagery calls plus offline drawing, deterministic primitives, missing-asset fallback, visible truthful labels, and explicit figure cleanup. Its no-network check is a dependency guard, not a packet-capture or OS network-denial test. A later acceptance run should also execute under network denial on both Mac and Windows, inspect the rendered label, and record MATLAB version, execution SHA and screenshots. **MATLAB tests were not run in this Codex session**: `matlab` was not on this shell's PATH, and Claude was using MATLAB. No pass count is claimed.

## Provider and license research, checked 2026-11-02

1. [MathWorks, Use Basemaps in Offline Environments](https://www.mathworks.com/help/map/use-basemaps-in-offline-environments.html) distinguishes installed/locally prepared options from internet-requiring basemaps and explicitly says Esri-hosted basemaps are **not available for download** through its basemap add-on path. It documents saving a basemap image with attribution for some offline workflows; that technical method alone does not establish redistribution rights for this repository.
2. [Esri, Web Site and Service Terms of Use](https://www.esri.com/en-us/legal/terms/web-site-service) requires attribution and says the terms do not transfer redistribution or derivative-work rights. It describes limited noncommercial downloading/copying, subject to other terms. This is not a clear grant to commit World Imagery tiles or an exported campus image publicly.
3. [Esri ArcGIS Online, Terms of use for items](https://doc.arcgis.com/en/arcgis-online/reference/access-use-constraints.htm) says item-specific access/use constraints and attribution must be carried through when reusing someone else's content. World Imagery may include multiple contributors, so a generic Esri credit is insufficient without the specific source/terms check.
4. [Esri ArcGIS Online, Take web maps offline](https://doc.arcgis.com/en/arcgis-online/manage-data/take-maps-offline.htm) describes controlled offline availability and per-layer download settings. Offline capability in an ArcGIS workflow is not blanket permission to scrape or redistribute via a public MATLAB repository.
5. [Esri Static Maps API attribution documentation](https://developers.arcgis.com/rest/static-maps/types/) requires attribution near or in a displayed map and points to style-specific attribution. This is relevant to any later approved static asset, not to this original schematic.

**Remaining permission uncertainty:** The exact imagery service item, third-party contributor rights, intended screenshot/public-presentation rights, local export/cache rights and public GitHub redistribution rights have not been confirmed by Shabaz or the provider. The approved campus extent/anchor and acquisition metadata are also absent. Therefore this PR contains no third-party image or coordinates. PRs [#72](https://github.com/MdShabazS/MineGuard-MATLAB/pull/72), [#75](https://github.com/MdShabazS/MineGuard-MATLAB/pull/75) and [#90](https://github.com/MdShabazS/MineGuard-MATLAB/pull/90) concern the separate online satellite prototype and its Mac/Windows evidence; their online acceptance does not confer an offline redistribution right.

## Future integration gate

ENH-008 or ENH-010 may call this module as an offline presentation fallback after separate integration review. For any real campus image, first record provider/product, exact item/source, written permission or applicable license, attribution, acquisition date, bounds/CRS, screenshot rights, offline storage rights and repository redistribution rights. Obtain an approved campus anchor/extent and distinguish it from virtual mission coordinates. Test both platforms, network-denied operation, missing/corrupt assets, figure cleanup and visual legibility at an exact source SHA. Do not change the current mission map or imply a real BITM flight, survey or detection from this diagram.

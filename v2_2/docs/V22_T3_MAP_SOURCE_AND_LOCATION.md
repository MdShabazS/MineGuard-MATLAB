# V22-T3 — Satellite map source, licence terms and BITM location

**Decided:** 2026-11-19 by Shabaz (owner), researched and written by Claude Code in Shabaz's Mac session.
**Machine-readable:** [`v2_2/config/bitm_site.json`](../config/bitm_site.json) — V22-T4 and V22-T5 read this file; no coordinates or credit text may be hard-coded elsewhere.
Not legal advice: this records what the cited terms say and the safe choices made from them.

## 1. Map source

| Item | Decision |
|---|---|
| Source | MATLAB R2026b `geobasemap('satellite')` → **Esri World Imagery**, served online (`https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer`) |
| Mode | **Live online display only.** No toolbox beyond base MATLAB is needed (`geobasemap` is base MATLAB, checked on Mac R2026b). |
| Offline | **No offline imagery.** Without internet the app shows the ENH-009 original schematic (`mgenh009.renderOfflineCampusContext`) labelled ILLUSTRATIVE / NOT SURVEYED / SIMULATION CONTEXT. |

## 2. Credits (exact text)

- Live service `copyrightText` (read 2026-11-19 from MATLAB `webread` on the service JSON): **`Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community`**. Earlier credits named "Maxar"; the current provider is **Vantor**.
- Text to show: **`Basemap: satellite | Powered by Esri | Source: Esri, Vantor, Earthstar Geographics, and the GIS User Community`**.
- Where: always visible in a **footer outside the map area**, at every zoom level and theme. MathWorks says the attribution must stay visible and may be shown elsewhere on the figure if the map's own text is unreadable; the retired #75 work found the on-map text not visible on Mac R2026b. Overlays must never cover it (Esri terms Art. 2.3(d): do not remove or obstruct notices).
- Read the credit live from the service at start-up; if the service cannot be reached, show the pinned text above and say "metadata unavailable" (pattern of the retired `basemapSource.m`).

## 3. What is allowed

| Use | Allowed? | Basis |
|---|---|---|
| Live display in a noncommercial academic presentation, with credits visible | **Yes** | Esri terms Art. 2.2: noncommercial external purposes allowed, attribution required. Esri decides what is noncommercial; an unpaid college project demonstration is treated here as noncommercial. |
| Our own overlay (VIRTUAL boundary, planned route, simulated drone) on the imagery | **Yes**, if it never hides the credits | No source forbids overlays; Art. 2.3(d) on notices |
| Mine, target, truth or anomaly markers on real campus imagery | **No** (project rule, V2 presentation roadmap) | Avoids implying real hazards at a real place |
| Committing tiles, cached imagery or **screenshots of the imagery** to this public GitHub repository | **No** | Terms "do not transfer any rights to redistribute, prepare derivative works" (Art. 2.1); no grant for repositories or screenshots |
| Caching or exporting tiles for an offline demo | **No** | MathWorks: Esri-hosted basemaps "are not available for download"; item: "not intended to be used to export tiles for offline"; service `exportTilesAllowed=false` |
| Screenshots in a private report or slide shown live | Keep local; show them only with the credit visible. Not committed. | Same terms; conservative choice |

Sources: [Esri website and services terms](https://www.esri.com/en-us/legal/terms/web-site-service) · [MathWorks geobasemap](https://www.mathworks.com/help/matlab/ref/geobasemap.html) · [MathWorks offline basemaps](https://www.mathworks.com/help/map/use-basemaps-in-offline-environments.html) · [World Imagery item JSON](https://www.arcgis.com/sharing/rest/content/items/10df2279f9684e4a9f6a7f08febac2a9?f=json) (licensed under the Esri Master License Agreement) · [service JSON](https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer?f=json). The Esri knowledge-base citation page returned HTTP 403 and was not read.

## 4. BITM location (presentation anchor, not a survey)

Institution: Ballari Institute of Technology and Management, Jnana Gangotri Campus, 873/2, Hosapete–Ballari Main Road, near Allipur, Ballari 583104 ([Ballari district college list](https://ballari.nic.in/en/public-utility-category/colleges/), [BITM contact page](https://www.bitm.edu.in/contact-us)).

| Point | Lat, Lon | Source | Confidence |
|---|---|---|---|
| Main academic block photo | 15.168147, 76.850379 (Plus Code 5V92+977) | GPS stamp on a BITM photo, [7.1.1-Addl.-Info.pdf](https://www.bitm.edu.in/assets/frontend/pdf/7.1.1-Addl.-Info.pdf) | high for vicinity |
| Student counselling cell photo | 15.168384, 76.850537 | same PDF, ~30 m from the point above | high for vicinity |
| Sports complex gate photo | 15.166225, 76.850736 (Plus Code 5V82+F6G) | [4.1.2-Addl.-Info.pdf](https://www.bitm.edu.in/assets/frontend/pdf/4.1.2-Addl.-Info.pdf), ~215 m south | high for vicinity |
| OpenStreetMap Nominatim | no BITM entry | one search | — |

**Decision (confirmed by Shabaz on 2026-11-19):**
- **Anchor:** **15.1682 N, 76.8504 E** (main academic block). Altitude 0 = **no approved altitude**; it is not a survey height and must not be used as one.
- **View window:** latitude **15.1653–15.1693**, longitude **76.8489–76.8516** (about 290 m × 440 m; buildings and sports complex with ~100 m padding). Confidence medium: edges are estimated from point tags, not mapped outlines. MATLAB widens the longitude limits to fit the axes shape (observed: 76.8477–76.8528 in a default figure); T4 must accept that.
- Phone-GPS points are typically accurate to 5–15 m. **None of this is a surveyed campus boundary.** The mission home, boundary and route drawn on it are **VIRTUAL**.

## 5. For V22-T4 and V22-T5

- Read everything from `bitm_site.json`; label the view with the banner `REAL IMAGERY — SIMULATED FLIGHT / NOT A HAZARD MAP`.
- Port the credit logic of the retired `v2/matlab/+mgv2/+geo/basemapSource.m` (branch `fix/ENH-002-provider-status-codex`, `c3c12af`) along with the three files the T4 prompt names.
- Keep `commit_imagery_allowed: false`: no tiles, caches or imagery screenshots in Git; describe observations in evidence instead.

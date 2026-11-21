# Role of Terrain and Elevation Data (LiDAR, DEM/DSM, Micro-topography, Drone Photogrammetry) in Humanitarian Demining and Land Release

Scope note: about 17 searches and fetches, made on 2026-11-21. Several primary documents could not be read: MDPI returned 403, ReliefWeb returned 403, and the OSCE PDF came back as binary only. Where a finding rests only on a search snippet, it says so.

## 1. How do mine action organisations use DEM/LiDAR/drone mapping today (concrete projects, countries, results)?

### Takeaway
Drone RGB orthomosaics are established practice for operational planning, and so is GIS integration of survey data (HALO in Sri Lanka, Angola and Ukraine; FSD in Ukraine). Drone LiDAR that produces a bare-earth DTM has been field-trialled by HALO in Angola (2021–2022). It was used to map the trenches, foxholes and craters that point to mine lines under vegetation. It did **not** detect mines directly. Elevation data is used for indirect evidence and planning, not as a mine detector.

### Cited Findings
- HALO Trust and Routescene trialled a UAV LiDAR system at three sites near Cuito Cuanavale, Cuando Cubango, Angola. The hardware was a 16-channel sensor (~600,000 points/s) with GNSS/INS on a DJI M600 Pro hexacopter, flown at 40 m AGL (Sites A and B, August 2021, dry season) and 50 m AGL (Site C, April 2022, rainy season). The article gives no point density or DTM resolution. The project began with a 2020 feasibility test in Scotland, where a replica mine crater was readily visible in the DTM. — [LiDAR Magazine, Riemersma, James & Pacheco, 2023](https://lidarmag.com/2023/10/07/uav-lidar-improves-landmine-clearance-planning/); [JMU CISR Journal 27.2, James et al., 2023](https://www.jmu.edu/news/cisr/2023/06/272/07-272-james.shtml)
- Results by site:
  - Site B (defensive mine line): ~500 m of main trench, 281 m of communication trench, 34 foxholes (average 0.67 m deep, 2.54 m wide) and 2 suspected craters (average 5.85 m wide, 0.65 m deep).
  - Site C: ~1,429 m of main trench, 73 m of communication trench and 157 foxholes (average 0.80 m deep, 2.81 m wide).
  - Site A: 496 m of main trench, 40 m of communication trench, 10 foxholes and crater-like features, some of them suspected shell scrapes. Only part of the site could be surveyed.
  - The LiDAR also revealed historical tracks that were candidate safe access routes.
  - [LiDAR Magazine 2023](https://lidarmag.com/2023/10/07/uav-lidar-improves-landmine-clearance-planning/)
- How HALO used the outputs:
  - The authors say the outputs "aided HALO in targeting clearance operations". They supported NTS by showing where trenches and craters suggest mine lines, and helped target TS and clearance.
  - The LiDAR did not detect mines directly. Craters were used to infer where mine lines might be, and some craters were judged unlikely to come from AV mines.
  - The authors call remote sensing complementary to conventional survey.
  - [JMU CISR 27.2](https://www.jmu.edu/news/cisr/2023/06/272/07-272-james.shtml); [LiDAR Magazine](https://lidarmag.com/2023/10/07/uav-lidar-improves-landmine-clearance-planning/)
- Limitations of the trial:
  - Satellite, RGB and thermal (TIR) imagery could not show most features under dense vegetation.
  - At Site C (rainy season, densest vegetation), water may have blocked returns or filled the features.
  - Flight range was ~1–1.5 km (battery life and line of sight), against minefields 20–30 km long. Only about two flights a day were possible.
  - GNSS post-processing data became available only ~24 h after a survey.
  - A 32-channel sensor was suggested to improve canopy penetration.
  - [JMU CISR 27.2](https://www.jmu.edu/news/cisr/2023/06/272/07-272-james.shtml)
- Scale: HALO has worked at Cuito Cuanavale since 2005 and had cleared 29,000 AP mines and 11,000 AV mines there by the end of 2022. — [JMU CISR 27.2](https://www.jmu.edu/news/cisr/2023/06/272/07-272-james.shtml)
- HALO in Sri Lanka uses drone orthomosaics to manage clearance of the Muhamalai Forward Defensive Line (one example orthomosaic merged 701 photos). The same source says that in areas of low vegetation density, HALO finds drones "extremely useful" for operational planning and clearance. — search snippet of [JCWD 22.3 (issuu)](https://issuu.com/cisr-journal/docs/22-3/s/31525). The full text was not verified.
- HALO in Ukraine worked with AWS on machine learning to find war debris in drone imagery of minefields. Manual review of the imagery for an average minefield takes 3–5 days. — search snippet of [AWS case study](https://aws.amazon.com/solutions/case-studies/aws-pioneers-project/halotrust)
- FSD (Swiss Foundation for Mine Action) has used drones daily for almost every stage of humanitarian demining in Ukraine since early 2024. It also integrates satellite data to keep maps of potentially hazardous areas up to date. — search snippet of [Swiss FDFA](https://www.eda.admin.ch/en/innovation-makes-humanitarian-demining-safer-and-more-efficient)
- NPA and Safe Pro Group ran an 18-month field study in Ukraine of AI-assisted drone survey, presented at the GICHD 2025 Innovation Conference. The "800% productivity" and "50% per-hectare cost" figures come from a press write-up and are **not verified** against the primary study. — [Euromaidan Press, 2025](https://euromaidanpress.com/2025/11/04/ai-drones-boost-ukraine-demining-surveys-800-percent/)
- GNSS jamming is widespread in Ukraine, so SLAM or IMU/LiDAR fusion is needed for positioning. Electronic warfare can disrupt humanitarian survey flights. — search snippet of [Lithuanian journal paper](https://www.journals.lka.lt/journal/cndcgs/article/2445/file/pdf)
- History at GICHD:
  - GICHD ran a UAS feasibility study from 2012 to 2014 with senseFly swinglet CAM mapping drones and judged them a useful supplement for teams that need current imagery.
  - The same work notes that satellite imagery is often low-resolution, expensive, and unavailable under cloud.
  - [GICHD/senseFly UAS newsletter, 2016](https://www.gichd.org/fileadmin/uploads/gichd/Publications/SenseFly-UASNewsletterArticle-December2016.pdf)
- The ICRC–GICHD webinar report (2021) states that integrating remote sensing and AI "will enhance evidence-based decision making" in mine action. — [ICRC/GICHD Webinar Report](https://gichd.org/fileadmin/uploads/gichd/Publications/ICRC_GICHD_Webinar_Report_-_The_Use_of_Remote_Sensing_and_Artificial_Intelligence_in_the_Mine_Action_Sector.pdf)
- In Ukraine, the University of Maryland (Duncan, Skakun et al.) used a deep-learning (U-Net) model on very-high-resolution satellite imagery to map ~2.5 million artillery craters across the southern and eastern farmland arc. The figures for agricultural land are 1.21 million craters in 81,000 fields covering ~15,600 km². The intent is to help demining groups prioritise.
  - The estimate of ~1 million unexploded shells rests on an assumed 10–30% failure rate. The team's own slides list the failure rates as unknown and call for validation against demining results.
  - Satellite crater mapping is 2-D image segmentation, not DEM-based.
  - [UMD Terp](https://terp.umd.edu/ai-offers-hope-on-dangerous-ground); [National Academies slides](https://uwnxt.nationalacademies.org/cdn/materials/9fba119a-8038-47df-bd13-4661c84ba26c); [UMD LCLUC slides](https://www.lcluc.umd.edu/sites/default/files/SergiiSkakun_Day1_ST2023.pdf)

### Inferences
- **Established practice (2015–2026):**
  - RGB drone orthomosaics for planning, site documentation and marking.
  - GIS integration of survey data.
  - Satellite imagery for desk assessment.
- **Field-trialled, not routine:**
  - Drone LiDAR DTMs used to reveal conflict features under vegetation (HALO, Angola).
  - AI detection of surface items in drone imagery (HALO/AWS, NPA/Safe Pro, UNDP in Ukraine).
- **Research or prototype:**
  - Country-scale crater-density hazard maps (UMD).
- Elevation data serves as **indirect evidence**: it shows where fighting positions, mine lines and access routes lie. It does not detect buried mines.
- The relevant feature scale in the Angola trial is ~0.6–0.8 m depth and ~2.4–5.9 m width. A DTM must resolve sub-metre horizontal detail and decimetre vertical detail to capture it.

### Gaps
- No HALO, MAG, NPA or UNMAS publication found that gives DTM grid resolution, point density, or a quantified effect on land release (for example, hectares cancelled or time saved).
- No source found on terrain-following flight in mine action specifically. Holding a constant AGL height over a DEM is standard UAV practice, but no mine-action document describing it was found.
- No MAG- or UNMAS-specific LiDAR or DEM project was found in these searches.

## 2. What evidence links terrain/hydrology to mine displacement, and how is it modelled?

### Takeaway
The May 2014 floods and landslides in Bosnia and Herzegovina and Serbia are the best-documented case. BHMAC warned that landslides moved whole minefields and their markings into areas not covered by its records. Peer-reviewed modelling is still at the **proposal** stage: Baselt et al. (2023) argue for a stochastic-deterministic model that would produce risk-hazard maps. No validated, operational mine-migration model was found.

### Cited Findings
- On 16 May 2014, BHMAC issued a public warning that mines could shift in flooded areas and in areas with landslides. — [ReliefWeb: BHMAC warning](https://reliefweb.int/report/bosnia-and-herzegovina/bhmac-qarning-floods-and-landslides-might-cause-shifting-minefields). Seen as a search snippet only, because the page returned 403.
- MAC head Saša Obradović said there were reports of mines resurfacing and of landslides moving whole minefields along with their markings. Reuters-based reporting said many of Bosnia's more than 100,000 remaining landmines might have been dislodged. — [NPR, 20 May 2014](https://www.npr.org/sections/thetwo-way/2014/05/20/314379214/balkan-floods-expose-deadly-mines-from-1990s-civil-war); [RTÉ, 20 May 2014](https://www.rte.ie/news/special-reports/2014/0520/618578-bosnian-floods-cause-landmine-problem-back-to-resurface)
- A BHMAC report said the floods moved soil, sediment and landmines to locations not covered by BHMAC hazard records. — search snippet (source attributed to BHMAC via [core.ac.uk](https://core.ac.uk/download/153196624.pdf)). Not verified.
- The size of the affected area is **contested or unverified**. One snippet estimates the mine-suspected area affected by the floods at ~800 km². An OSCE presentation reports 80.2 km² of *new* potentially hazardous area in northern Bosnia. — [OSCE PDF](https://www.osce.org/files/f/documents/f/b/123394.pdf). The PDF could not be text-extracted. Treat both numbers as unconfirmed and do not combine them.
- An EU/UN-linked Civilian Landmine Team deployed to Serbia and BiH to survey flood-affected areas, where residents reported finding mines and UXO. — [ReliefWeb](https://reliefweb.int/report/bosnia-and-herzegovina/civilian-landmine-team-deploys-serbia-and-bosnia-herzegovina-support)
- The floods submerged a military depot in Orašje holding ~250 t of ammunition. — [NATO EADRCC sitreps](https://www.nato.int/nato_static_fl2014/assets/pdf/pdf_2014_05-bih-floods/20150302_140519-bih-floods-08.pdf). Seen as a search snippet only.
- Baselt, Skejić, Zindović & Bender (2023), "Geologically-Driven Migration of Landmines and Explosive Remnants of War", *Geosciences* 13(6):178:
  - Mines and ERW are mobilised by hydro-morphological processes (floods, mass movements, erosion) into previously uncontaminated areas.
  - Floods and mass movements are the main threats. Displaced ordnance has caused injuries and deaths in BiH, Serbia and Croatia.
  - The problem can "only be tackled using a stochastic-deterministic model". The intended output is risk-hazard maps for decision-makers.
  - The paper calls for further laboratory and field work, so it is a **proposal**, not a validated model.
  - [MDPI](https://www.mdpi.com/2076-3263/13/6/178) (full text 403); [DOAJ record](https://doaj.org/article/cd6d828e969b4d55afae87b6d836a970)

### Inferences
- A terrain-aware migration model would need:
  - a DEM for slope, flow direction and accumulation, and landslide susceptibility;
  - flood extent and depth;
  - soil and geology data;
  - original minefield records from IMSMA.
  
  This is the natural place for DEM-derived slope and drainage analysis. In the sources found, it is a research direction, not a documented practice.
- Comparing pre- and post-event DEMs of landslide scars and deposition zones could locate where soil (and any mines in it) went. This is a legitimate use of "cut/fill"-style differencing (see Q5). No mine-action deployment of it was found.

### Gaps
- No primary MAC BiH or Serbian Mine Action Centre post-flood technical report was retrieved, so there are no verified counts of displaced or recovered mines and no figures for re-surveyed area.
- No evidence was found of DEM- or hydrology-based models being used operationally by BHMAC after 2014.
- The full Baselt et al. text was not accessed. Its specific model parameters and any quantitative displacement distances are unknown.

## 3. Can micro-topography reveal buried mines or minefield patterns, and at what resolution? Evidence of LiDAR detecting WWI/WWII craters, trenches and mine belts.

### Takeaway
LiDAR reliably reveals **large conflict features**: trenches, foxholes, shell and bomb craters (metre scale wide, decimetre to metre deep). It does this in Flanders (WWI), the Ardennes (WWII), Czechia (WWII bomb craters) and Angola (mine-line trenches). That makes it useful for inferring **where minefields are likely**. No evidence was found that LiDAR or DEM micro-topography can detect **individual buried mines**. Disturbed-soil detection for single mines relies on spectral, thermal or radar cues, which weaken over time and have many false positives.

### Cited Findings
- Gheyle, Stichelbaut, Saey, Note et al. (2018), *Applied Geography* 90:55–68, analysed airborne LiDAR (DTM-Flanders II, 2013–2015). Over 12% of the study area carries surface traces of the Great War, and many of these sites were previously unknown. — [RUC record](https://forskning.ruc.dk/da/publications/scratching-the-surface-of-war-airborne-laser-scans-of-the-great-w/)
  - A separate figure of 14% for the Kemmel–Wervik stretch comes from a different area and should not be conflated. — [National Geographic, 2019](https://www.nationalgeographic.com/history/article/archaeology-unravels-secrets-wwi-trench-warfare)
- Stichelbaut, Coucke, Passmore et al. (2023), *Antiquity* 97(394):945–963, used drone-mounted LiDAR (1 m resolution) with SLAM in the forested Ardennes. They identified more than 940 WWII (Battle of the Bulge) features, many of which were ground-verified. — [Cambridge/Antiquity](https://cambridge.org/core/journals/antiquity/article/lidar-and-conflict-archaeology-the-battle-of-the-bulge-19441945/5050B5FFFAA961C3F75FF7FBC4FE1F4E)
- Dolejš et al. (2020), *ISPRS IJGI* 9(12):713, compared three automatic methods for detecting bomb craters in airborne-LiDAR DTMs at eight WWII sites in NW Czechia. Extraterrestrial crater-detection algorithms and geomorphology-based edge extraction performed worse on precision and recall. — [DOAJ](https://doaj.org/article/02750f02ddf94244b549b3483bfab764)
- A University of Ljubljana thesis presents an algorithm that detects WWI trenches automatically from LiDAR height maps on uneven terrain. — [repozitorij.uni-lj.si](https://repozitorij.uni-lj.si/IzpisGradiva.php?id=72662)
- A University of Bergamo paper compares LiDAR visualisations (sky-view factor, positive and negative openness) for Great War heritage in Trentino-Tyrol. — [aisberg.unibg.it](https://aisberg.unibg.it/retrieve/c28de8c8-4ce7-46a8-8dc0-3a0b376d426e/1395-Article%20Text-10660-1-10-20230502%20%283%29.pdf)
- In Angola (HALO), drone LiDAR mapped trenches, foxholes (~0.6–0.8 m deep, ~2.4–2.8 m wide) and craters (~5.9 m wide, ~0.65 m deep). These were used to infer where mine lines lie. The authors state that the LiDAR did not detect mines directly. — [LiDAR Magazine 2023](https://lidarmag.com/2023/10/07/uav-lidar-improves-landmine-clearance-planning/)
- Vegetation hides trenches, bunkers and craters from RGB drone and satellite imagery, and that motivates LiDAR. — [JMU CISR 27.2](https://www.jmu.edu/news/cisr/2023/06/272/07-272-james.shtml)
- Disturbed soil over buried objects:
  - A DTIC study imaged burial sites from visible to mid-infrared over about two weeks and tracked how disturbance signatures change. Smoothing the surface reduced visibility, and many activities unrelated to burial also disturb the surface. — [DTIC AD1018426](https://apps.dtic.mil/sti/pdfs/AD1018426.pdf)
  - Radar surface-roughness contrast between disturbed and undisturbed soil has been proposed as an aid to mine detection. — [Boise State/SPIE 2005](https://experts.boisestate.edu/en/publications/radar-signature-of-disturbed-soil-for-mine-detection/)

### Inferences
- Rough resolution ladder, inferred from the cited feature sizes:
  - Trenches and large craters show at about 0.5–1 m DTM resolution (Flanders, Ardennes at 1 m).
  - Foxholes and AV-mine craters (~2–6 m wide, ~0.5–0.8 m deep) need sub-metre ground sampling and dense ground returns under canopy.
  - An individual AP mine (~6–12 cm diameter, typically flush or shallow) would leave a relief signature at or below the vertical noise of drone LiDAR and photogrammetry, especially after decades of weathering and vegetation. No source shows this working.
- Minefield **patterns** may be inferable from regular rows of AV-mine craters (where mines have detonated) or from the geometry of defensive lines. Within IMAS, this is indirect evidence for NTS, not proof of absence or presence.

### Gaps
- No published accuracy statistics (precision/recall or false-positive rates) were found for LiDAR-derived crater or trench detection used in a mine-action context.
- No source gives a minimum DEM resolution or vertical accuracy for detecting mine-related micro-relief.
- No peer-reviewed evidence was found of LiDAR detecting individual buried mines.

## 4. What do IMAS say about evidence-based survey and the use of remote sensing?

### Takeaway
IMAS frames land release as **evidence-based**:
- NTS and TS gather indirect and direct evidence.
- SHAs (suspected hazardous areas) rest on indirect evidence, and CHAs (confirmed hazardous areas) on direct evidence.
- Clearance is confined to confirmed contamination.

None of the current IMAS titles is devoted to remote sensing, drones or elevation data. GICHD positions remote sensing as something that *enhances* survey and evidence-based decisions, and does not treat it as a stand-alone basis for releasing land.

### Cited Findings
- Current IMAS numbering on mineactionstandards.org:
  - 07.11 Land release (Ed. 2, latest publication 16 Jan 2026), with TNMA 07.11/01 to 07.11/04 (symbology, KPIs, all reasonable effort, implementation guidance)
  - 08.10 Non-technical survey
  - 08.20 Technical survey
  - 09.10 Clearance requirements
  - 09.50 Mechanical land release
  - 05.10 Information management for mine action
  - 03.30 Guide to research of mine action technology, and 03.40 Test and evaluation of mine action equipment
  - No IMAS title is devoted to remote sensing, drones or UAS.
  - [IMAS standards list](https://www.mineactionstandards.org/standards/)
  - One search snippet suggested different numbering (08.10 "General mine action assessment", 08.21 NTS). That reflects an older edition. The current site lists 08.10 as NTS.
- The GICHD survey page calls NTS "the starting point for identifying, accessing, collecting, reporting and using information". NTS uses desk assessments, historical records and interviews, typically "without using technical equipment and without entering hazardous areas". TS enters the hazardous area to confirm presence and refine boundaries. The approach is described as an "evidence-based approach", and full clearance is limited to areas confirmed by TS. The page does not mention remote sensing or elevation data. — [GICHD: Survey](https://www.gichd.org/en/land-release/survey)
- SHAs should be classified on indirect evidence and CHAs on direct evidence (from amendments to the land release IMAS). — search snippet of [JCWD/core.ac.uk](https://core.ac.uk/download/323031131.pdf)
- GICHD's Land Release research agenda says NTS and TS support land release decisions, including SHA/CHA classification based on direct or indirect evidence. It adds that "remote-sensing, stand-off robotics, sensor fusion and artificial intelligence (AI)-powered technology can significantly enhance EO survey". — [GICHD Land Release Agenda](https://www.gichd.org/fileadmin/uploads/gichd/Media/GICHD-resources/Innovation_Hub/Land_Release_Agenda_v10_WEB.pdf). Seen as a search snippet only.
- CWA 17046 (2016), "Humanitarian demining – Non-technical survey in the land release process", complies with IMAS 07.11 Ed.1 Am2 and includes a section on related evidence. — [normy.normoff.gov.sk](https://normy.normoff.gov.sk/norma/124171/nahlad)
- Remote sensing is now used to plan, monitor and evaluate clearance, to support the land release process, and to help measure impact. — report on the 7th Mine Action Technology Workshop (Basel, 2019), search snippet via [JCWD (issuu)](https://issuu.com/cisr-journal/docs/24.1-all/s/10723728)

### Inferences
- Under IMAS, DEM/LiDAR products fit best as **indirect evidence** inside NTS: features from the conflict period, access, and terrain that limits where mines could plausibly have been laid or moved. They can also feed TS planning (targeting) and IMSMA records (IMAS 05.10).
- Remote sensing alone cannot meet "all reasonable effort" for releasing land as clear. Releasing land through TS or clearance still needs physical evidence.
- Remote sensing outputs (polygons, features, change maps) belong in the national IM system (IMSMA Core) as evidence attached to hazard records.

### Gaps
- The full text of IMAS 07.11 Ed.2 (2026), 08.10, 08.20 and 05.10 was not read, so no exact clause wording on remote sensing, imagery or elevation data is cited. A verbatim check is needed.
- No IMSMA documentation was retrieved on storing DEM or LiDAR products or remote-sensing evidence.

## 5. Where does "cut/fill" surface analysis (existing surface vs reference plane, or before/after surfaces) have a legitimate use, and where none?

### Takeaway
Surface differencing has a **legitimate, indirect** role:
- detecting change (craters, earthworks, landslide scars and deposits, flood erosion and sediment, berms, trenches) between dated surfaces, or against a smoothed local reference;
- highlighting negative relief (pits, trenches) and positive relief (berms, spoil) as evidence for NTS and TS planning.

It has **no** demonstrated role in detecting individual buried mines, and the volume figures it produces carry no explosive-hazard meaning on their own. No mine-action source was found that uses cut/fill terminology explicitly. Everything below is inference built on the cited evidence.

### Cited Findings (supporting evidence)
- A replica mine crater showed clearly in a drone-LiDAR DTM. Foxholes, trenches and craters were measured by depth and width in Angola (for example, craters ~0.65 m deep, foxholes ~0.6–0.8 m deep). This is the kind of negative-relief measurement a surface-versus-reference comparison produces. — [LiDAR Magazine 2023](https://lidarmag.com/2023/10/07/uav-lidar-improves-landmine-clearance-planning/)
- LiDAR visualisations such as sky-view factor and positive/negative openness (local relief relative to the surrounding surface) are the established way to bring out WWI trenches and craters. — [Univ. Bergamo paper](https://aisberg.unibg.it/retrieve/c28de8c8-4ce7-46a8-8dc0-3a0b376d426e/1395-Article%20Text-10660-1-10-20230502%20%283%29.pdf); [Dolejš et al. 2020](https://doaj.org/article/02750f02ddf94244b549b3483bfab764)
- Landslides and floods relocated soil and minefields in BiH in 2014, beyond recorded hazard polygons. — [NPR 2014](https://www.npr.org/sections/thetwo-way/2014/05/20/314379214/balkan-floods-expose-deadly-mines-from-1990s-civil-war); [Baselt et al. 2023](https://doaj.org/article/cd6d828e969b4d55afae87b6d836a970)
- Crater mapping is being used to prioritise survey in Ukraine (2-D satellite imagery, not DEMs). — [UMD](https://terp.umd.edu/ai-offers-hope-on-dangerous-ground)

### Inferences
**Legitimate uses** (all as indirect evidence or planning aids):
1. **Before/after DEM differencing of landslides and floods.** Delineate erosion source zones (cut) and deposition zones (fill) after events like 2014 in BiH, to flag areas where mines may have left or arrived. Hazard polygons in IMSMA could then be updated and NTS triggered.
2. **Local-reference residual relief.** Compare the DTM with a smoothed or plane-fit local surface to highlight craters, foxholes and trenches (negative relief) and berms, parapets and spoil heaps (positive relief). These are proxies for defensive lines and likely mine belts. Comparing against a smoothed local trend is close to how LRM, openness and SVF visualisations work.
3. **Earthworks and berms.** Map military berms and fortification lines, which are often mined at their approaches. Also check whether ground has been reworked since the conflict (ploughing or construction), which affects evidence and mine depth.
4. **Operational QA and monitoring.** Compare surfaces before and after mechanical land release (tilling or flail depth) or site restoration, and document the post-clearance state for handover.
5. **Access and safety.** Slope and roughness from the DEM support planning for routes, mechanical asset access, drainage and erosion risk on cleared land.

**No legitimate use:**
- Detecting or confirming individual buried AP or AV mines from DEM relief. There is no evidence for it, and mine size and burial are below DEM noise.
- Using cut or fill volume as a hazard score, or as grounds for cancelling or releasing land without NTS, TS or clearance evidence.
- Comparing against an arbitrary flat reference plane on natural, sloping terrain. The resulting "depths" mostly reflect topography, not disturbance. A local or detrended reference, or a dated prior surface, is required.
- In any software, cut/fill output should be labelled as surface change or relief anomaly for survey prioritisation, never as mine detection.

### Gaps
- No mine-action organisation or IMAS document was found that describes cut/fill or DEM-differencing workflows.
- No published examples of multi-temporal DEM change detection used for hazard-area updates in mine action were found. This remains a research or proposal-level application.

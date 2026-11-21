# UAV Survey Mission Planning for Landmine/UXO Detection

Scope note: about 20 tool calls. Several primary MDPI and PMC pages returned 403 or a CAPTCHA, so some figures are search-snippet level and are flagged as such. Two PDFs were read in full: Baur et al. 2020 (Remote Sensing 12:859) and Gallagher et al. 2025 (arXiv 2512.20487). All results are field or test-range trials with inert or surrogate mines. None of them shows operational detection capability.

## 1. What altitudes, GSD, overlaps and speeds have field studies used successfully, per sensor?

### Takeaway
For small surface AP mines (PFM-1 class), published UAV optical/thermal work clusters at **5–12 m AGL**, sub-centimetre RGB GSD (about 0.2–0.4 cm/px), **75–80% overlap**, and slow speeds (about 2 m/s). Detection degrades sharply above about 10 m for AP-sized targets. Magnetometry needs the sensor itself at **about 1–3 m AGL**, with 0.5–3 m line spacing and terrain following. UAV GPR works at **about 0.5–2 m** standoff and is still mostly experimental.

### Cited Findings
**RGB / multispectral / thermal (surface and shallow mines)**
- Binghamton (Baur et al. 2020). The platform was a DJI Matrice 600 Pro carrying a FLIR Vue Pro R (640×512, 13 mm, 7.5–13.5 µm) and a Parrot Sequoia (RGB 4608×3456, 4.88 mm; G/R/RE/NIR at 3.98 mm). The team flew "at 10 m height over a 10 × 20 m grid with each transverse having an 80% overlapped coverage with the previous transverse, flown at 2 m/s", with 28–30 PFM-1 mines per field and the Pix4D mission planner app. Each flight took 3 min 30 s for 10×20 m. Faster R-CNN on RGB gave 99.3% accuracy on a partially withheld test set and 71.5% on a fully withheld one, and took 1.87 s per 200 m², which the authors extrapolate to "2 h and 36 min" of processing per km². — [Baur et al. 2020, Remote Sensing 12(5):859](https://mdpi.com/2072-4292/12/5/859)
- Baur et al. cite earlier work showing LWIR imagery had an "average detection sensitivity rate of 77.88%" for PFM-1. — [Baur et al. 2020](https://mdpi.com/2072-4292/12/5/859)
- Binghamton 2018 thermal protocol: a 3DR Solo with a FLIR Vue Pro R 640×512 13 mm detected PFM-1 from about 10 m AGL. An accompanying RGB survey (DJI Phantom 4 Pro at 10 m) produced a 0.24 cm/px orthomosaic. This is from search snippets of the 2018 paper and the GSA abstract. — [de Smet & Nikulin 2018, Remote Sensing 10(11):1672](https://mdpi.com/2072-4292/10/11/1672); [GSA NE 2018 abstract](https://gsa.confex.com/gsa/2018NE/webprogram/Paper311265.html); [Binghamton news](https://www.binghamton.edu/news/story/1205/drones-could-be-used-to-detect-dangerous-butterfly-landmines-in-post-confli)
- Demining Research Community seeded field (about 150 ERW buried at systematically varied depths). All missions flew at 12 m in grid patterns with 80% frontlap and 75% sidelap. Platforms were an Autel EVO II Dual (RGB+TIR), a DJI Mavic 3E (RGB) and a Phantom 3 Pro with a Sequoia. Orthomosaic GSD was RGB 0.21 cm/px, TIR 0.37 cm/px and multispectral 1.17 cm/px. Planning used native DJI/Autel apps and UgCS. — [Zenodo record 15324498](https://zenodo.org/records/15324498)
- GMU (Gallagher, Oughton, Košecká 2025). A DJI Inspire 2 carried a FLIR Vue Pro R (336×256, 45° FOV) and a RunCam 5 RGB (1920×1080, 145° FOV), co-mounted to reduce parallax, at "fixed elevations ranging from 5 m to 30 m". The test targets were 21 mine types (10 AT plastic, 2 AT metal, 3 AP metal, 6 AP plastic). Mean mAP@0.5 at 5 m was 89.1% for AT plastic, 86.5% for AT metal, 44.7% for AP plastic and 40.0% for AP metal, an overall mean of 65.1%. At 10 m the figures were 72.3 / 54.3 / 17.3 / 17.3%, and at 20 m they were 49.6 / 40.5 / 7.1 / 4.3%, an overall mean of 25.4%, which the authors call "a 61.0% reduction". The best configuration was YOLOv11 at 86.8% mAP@0.5, "with 10–30% thermal fusion at 5–10m altitude". — [Gallagher et al. 2025, arXiv 2512.20487](https://arxiv.org/abs/2512.20487v1)
- Literature cited by Gallagher et al. includes YOLOF at 89% mAP on drone imagery at 10 m AGL, and a thermographic MLP study at 97.1% at 1 m altitude versus 88.8% at higher altitudes. — [Gallagher et al. 2025](https://arxiv.org/abs/2512.20487v1); [Drone flyby dataset, arXiv 2410.19807](https://arxiv.org/pdf/2410.19807)
- The same group's AMLID dataset uses 5, 10, 15 and 20 m sensor elevations. — [AMLID, arXiv 2512.18738](https://arxiv.org/pdf/2512.18738) (search-snippet level)
- For small targets, a UAV TM-62 AT-mine study reported that tiled inference (SAHI, 768 px tiles, 40% tile overlap) plus fusion raised mAP@0.50:0.95 to 0.685. — [MDPI Computers 14(10):448](https://www.mdpi.com/2073-431X/14/10/448) (search-snippet level)

**Magnetometer (UXO, metallic mines)**
- Patent and field study: a sensor at 3 m AGL (aircraft at 7 m AGL) gave the best balance between resolving a simulated BM-21 rocket and limiting false flags from smaller clutter, and 3 m line spacing identified anomalies consistently. This was summarised as a "3-3-3" rule: 3 m sensor height, 3 m spacing, 3 m/s. — [US12055392B2](https://patents.google.com/patent/US12055392) (search-snippet level; target is large UXO, not AP mines)
- Zaragoza hexacopter survey: a GEM GSMP-35U at 7 m and 2 m AGL on a 1 m line grid. — [MDPI Drones 10(2):88](https://www.mdpi.com/2504-446X/10/2/88) (snippet; page returned 403)
- Towed triple-scalar bird 10 m below the UAV: 4 m line spacing "may have been sufficient" for detection in that case. — [MDPI 1516722](https://www.mdpi.com/1516722) (snippet)
- Industry guidance (SPH Engineering/SkyHub): fly "as low as possible, ideally 1 m or less", with 1–2 m typical. Line spacing should be 0.5 m for grenades and submunitions and 1 m for artillery and mortar shells. Speed is about 2 m/s, with several hundred Hz sampling, a downward rangefinder for terrain following, wind below 5–8 m/s, and productivity of about 1 ha/h per sensor. — [SPH Engineering](https://www.sphengineering.com/news/drone-uxo-detection-magnetometer-surveys) (vendor source)
- Manned-helicopter reference (SERDP/ESTCP): instrument altitude 1–3 m, with interleaved lines giving a 3 m profile spacing for a 9 m flight-line spacing. A rotorcraft model used 0.75 m and 2.25 m path spacing at 5 and 10 m/s with 25% line overlap. — [SERDP-ESTCP](https://serdp-estcp.mil/projects/details/9fa750b8-7640-4106-9b81-de42f6a7546e); [High-speed UAV magnetic surveying (AGRIS)](https://agris.fao.org/search/en/records/687a85949d6e0577321e7cd2)

**GPR**
- A lightweight SFCW UAV-borne GPR detected targets at a scanning height of about 0.5 m. — [Sensors 2020, PMC7218851](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7218851/) (snippet; full text blocked)
- Side-looking UAV GPSAR flies a linear cross-range track with a depression angle. Altitude is a key geometry parameter. — [Schartel et al. 2018 ICMIM](https://mwt-www.e-technik.uni-ulm.de/public/papers/2018/2018_ICMIM_Schartel_UAV-Based_Ground_Penetrating_Synthetic_Aperture_Radar.pdf); see also [ARL-TR-8725](https://apps.dtic.mil/sti/pdfs/AD1075772.pdf) and the [Oviedo UAV-GPR review](https://digibuo.uniovi.es/dspace/bitstream/10651/53291/1/Recent%20advances.pdf)

**Timing (thermal)**
- The 2018 Binghamton paper is titled "Catching 'butterflies' in the morning". Snippets describe best results in early-morning hours, when the thermal-inertia contrast is greatest. — [de Smet & Nikulin 2018](https://mdpi.com/2072-4292/10/11/1672); title confirmed in the [Baur et al. 2020 reference list](https://mdpi.com/2072-4292/12/5/859)
- GMU collected data post-sunrise, at noon and pre-sunset in January and May (Kansas). For thermal-fusion tests, mean mAP ranged from 29.3% (May noon) to 50.8% (January afternoon). January generally beat May, and noon was worst in May. — [Gallagher et al. 2025](https://arxiv.org/abs/2512.20487v1)
- A UAV IR-thermography study reports "nearly 88%" accuracy, "particularly during evening hours". The abstract gives no altitude or depth. — [arXiv 2410.23998](https://arxiv.org/abs/2410.23998)
- Surrogate mines showed more than 2 K thermal difference over diurnal cycles (Oct–Nov 2017). A Chad study ran a fixed camera at 1-minute intervals over 24 h cycles for buried submunitions. — [CISR JCWD 22.3](https://issuu.com/cisr-journal/docs/22-3/s/99705); [JMU/CISR Fardoulis 2022](https://www.jmu.edu/news/cisr/2022/06/253/12-253-fardoulis.shtml)

### Inferences
- Rough GSD check (standard pinhole geometry, my own calculation): GSD ≈ H × pixel pitch / focal length. For AP mines of 6–12 cm, published successes put the target across roughly 25–50+ px at 0.2–0.4 cm GSD. The GMU results, with a low-resolution 1080p wide-FOV RGB, collapse for AP mines by 10 m. This suggests GSD and pixels-on-target, not altitude itself, is the controlling variable. An altitude limit should be derived from the camera, not copied from a paper.
- Speed of about 2 m/s at 10 m with 80% overlap is the most-replicated optical setting.

### Gaps
- I found no peer-reviewed minimum pixels-on-target for mine detection. ASPRS-style GSD/overlap guidance was not retrieved.
- Thermal crossover windows are site-, soil- and depth-specific. No universal timing rule was found.
- UAV GPR flight heights and speeds for field AP-mine detection were not confirmed from full text.
- LiDAR-specific mine-survey parameters were not found. LiDAR appears mainly for DEM and terrain following, and that use is also unconfirmed here.

## 2. What positioning accuracy is needed to hand detections to clearance teams?

### Takeaway
Research trials georeference to "cm" accuracy with GNSS-surveyed GCPs, using a survey-grade handheld or GNSS plus 5–6 GCPs, often with a second polynomial or linear fit in GIS. I found no mine-action standard that states a required handover accuracy.

### Cited Findings
- Baur et al. surveyed mines and GCPs with a Trimble Geo 7x and Zephyr 3 antenna ("cm accurate coordinates"), post-processed in Pathfinder Office. Checkered GCPs were placed at the corners and centre of each grid. The Pix4D point cloud was re-optimised on the GCPs, and the GeoTIFFs were then re-georeferenced in ArcMap with a first-order polynomial to the GNSS GCPs. — [Baur et al. 2020](https://mdpi.com/2072-4292/12/5/859)
- The seeded-field dataset used six Trimble GNSS GCPs with a linear transformation in QGIS. No accuracy figure is stated. — [Zenodo 15324498](https://zenodo.org/records/15324498)
- General UAV mapping: RTK/PPK is "widely adopted" for cm-level accuracy, and reconvergence behaviour matters in dynamic flight. — [Sensors 26:4907](https://flore.unifi.it/retrieve/4d9ba317-cd25-44b5-89dd-ecc4592bb1e4/sensors-26-04907.pdf)
- PPK keeps accuracy if the data link drops. A low-cost RTK UAV without GCPs did not give acceptable accuracy. A single GCP can correct vertical bias. — [PMC8200111](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8200111/); [Zeybek et al. 2023, Sensors 23:5858](https://www.mdpi.com/1424-8220/23/13/5858/html)
- Magnetometry data is geotagged with GPS per sample. No accuracy is given. — [SPH Engineering](https://www.sphengineering.com/news/drone-uxo-detection-magnetometer-surveys)
- GICHD notes UAS imagery improves planning, recording and reporting across non-technical survey, technical survey and clearance, including geolocating suspected hazardous areas (SHAs). — [GICHD/senseFly 2016](https://www.gichd.org/fileadmin/uploads/gichd/Publications/SenseFly-UASNewsletterArticle-December2016.pdf)

### Inferences
- When the target is 6–12 cm and clearance teams work in lanes, absolute error should be small relative to the marking or reacquisition radius. RTK/PPK plus at least one independent checkpoint is the defensible default. This is an inference, not a standard.

### Gaps
- No IMAS or national-standard figure for drone detection positional tolerance was found. A specific search of IMAS 08.10 / 09.10 / TNMA is needed.
- No study reported RMSE between drone-detected and ground-truth mine positions.

## 3. How are flight lines and swath chosen to guarantee full coverage, and how is coverage verified?

### Takeaway
Optical surveys use lawnmower/grid patterns with 75–80% side overlap, set in mission planners (Pix4D, UgCS, DJI/Autel). Magnetometer surveys set line spacing from target size and sensor height, using a rangefinder for terrain following. Coverage verification is rarely described explicitly.

### Cited Findings
- Grid patterns with 80% frontlap and 75% sidelap at constant 12 m. — [Zenodo 15324498](https://zenodo.org/records/15324498)
- 80% overlap between adjacent transects at 10 m and 2 m/s, with 5 repeat flights per environment. — [Baur et al. 2020](https://mdpi.com/2072-4292/12/5/859)
- Line spacing tied to target size: 0.5 m for small items, 1 m for shells. Terrain following by rangefinder. Repeat surveys "may yield slightly different target lists". — [SPH Engineering](https://www.sphengineering.com/news/drone-uxo-detection-magnetometer-surveys)
- Line spacing chosen empirically against a test object (3 m for BM-21). — [US12055392B2](https://patents.google.com/patent/US12055392)
- Interleaving: 9 m flight lines giving a 3 m effective profile spacing. — [SERDP-ESTCP](https://serdp-estcp.mil/projects/details/9fa750b8-7640-4106-9b81-de42f6a7546e)
- 25% line overlap assumed in the rotorcraft magnetometer productivity model. — [AGRIS record](https://agris.fao.org/search/en/records/687a85949d6e0577321e7cd2)
- Re-surveying reveals patterns not visible from the ground and helps target technical survey and clearance assets to hot spots. — [CISR JCWD 23.1](https://issuu.com/cisr-journal/docs/journal-23.1-all/s/96043) (snippet)

### Inferences
- Line spacing = swath × (1 − side overlap), where optical swath = GSD × image width in pixels. Verification can be done by checking the orthomosaic for holes and low-overlap zones (Pix4D quality report), and by flown-track versus planned-line deviation and AGL logs for magnetometry. This is standard practice, but I found no mine-specific source for it.

### Gaps
- No source gave a formal coverage-verification protocol (for example, minimum overlap map or seeded test items per sortie) for drone mine survey.

## 4. How do teams combine multiple flights/sensors into one suspected-hazard map, and what confidence measures are reported?

### Takeaway
Typical pipelines are: separate orthomosaics per sensor (Pix4D templates), georeferenced to common GCPs, co-registered or fused (pixel-level alpha blending of RGB+LWIR, or multispectral fusion), CNN detection, then GIS overlay. Confidence is reported as ML metrics (mAP, precision/recall, accuracy), not as calibrated per-detection probabilities for clearance teams.

### Cited Findings
- Processing chain: clip takeoff and landing photos, run Pix4D point cloud, re-optimise on GCPs, then mesh, DSM, orthomosaic and index. GeoTIFFs go into ArcMap overlaid with GNSS mine coordinates. Thermal imagery is exported as 16-bit from ThermoViewer. Orthophotos are cropped into tiles for Faster R-CNN. — [Baur et al. 2020](https://mdpi.com/2072-4292/12/5/859)
- Pix4D Mapper templates per sensor (3D Maps for RGB, Thermal Camera for TIR, Ag Multispectral for Sequoia), then georeference and clip in QGIS. — [Zenodo 15324498](https://zenodo.org/records/15324498)
- RGB-LWIR fusion: feature alignment with alpha adjustment of the LWIR layer over an RGB base, fused post-flight. Fusion ratios of 0–100% were tested, and 10–30% thermal was optimal. Results are reported as mAP@0.5 with ± standard deviation (for example 86.8% ± 30.5%), precision, recall and inference time. — [Gallagher et al. 2025](https://arxiv.org/abs/2512.20487v1)
- Joint fusion-and-detection deep learning for UAV multispectral scatterable-mine sensing. — [Sensors 2023, PMC10303520](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10303520/) (abstract only)
- Magnetometry: data is cleaned, corrected and gridded into anomaly maps (SENSYS MAGNETO, GeoHammer), and analysts rank anomalies by amplitude, shape and spatial characteristics. — [SPH Engineering](https://www.sphengineering.com/news/drone-uxo-detection-magnetometer-surveys)
- A YOLO-plus-GIS workflow, from detector to map, is cited in the literature. — [Gallagher et al. 2025](https://arxiv.org/abs/2512.20487v1)
- GICHD: UAS outputs update cartography and geolocate SHAs, and feed planning for non-technical survey, technical survey and clearance. — [GICHD/senseFly 2016](https://www.gichd.org/fileadmin/uploads/gichd/Publications/SenseFly-UASNewsletterArticle-December2016.pdf)

### Inferences
- A defensible output for technical survey teams would include detection points or polygons with model score, sensor or sensors contributing, flight time, GSD and AGL, and a positional uncertainty. Coverage and quality layers should mark where detection is unreliable. This is inferred, since no source prescribes it. Big standard deviations (about ±30% mAP) mean per-condition performance should be reported alongside scores.

### Gaps
- No source describes calibrated probability-of-detection or false-alarm-rate maps handed to clearance teams, or decision fusion across magnetometer, GPR and optical layers in an operational SHA map.
- I found no GICHD drone guidance specifically on technical survey (only feasibility and newsletter material, plus an e-learning portal at gichd.litmos.com).

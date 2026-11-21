# Drone-based humanitarian demining: operational systems and public datasets (2019–2026)

Scope note: collected 2026-11-21 by web research (about 17 tool calls). Where a figure comes from a vendor or its partner, it is labelled **[vendor/partner claim]**. Where it comes from a trial run by a third party (UNDP, peer-reviewed paper), it is labelled **[independent]**. Nothing here is MineGuard's own result.

## Which systems are in real use in 2024–2026, and what evidence of performance exists (independent vs vendor claims)?

### Takeaway
The systems in real use are almost all **EO/RGB (sometimes thermal or multispectral) drone mapping with AI or human analysis of imagery for non-technical survey (NTS)**, which finds mainly *surface* items. Safe Pro's SpotlightAI (with NPA, HALO, NIBULON) and the HALO/AWS AI pilot are the best-known. Drone magnetometry is now deployed by Ukraine's MoD for NTS. The only independent, quantitative multi-system comparison found is the UNDP Ukraine Phase II trial (May 2024): the best teams found about 55–78% of targets depending on category, and buried plastic items were unreliable for every technology. Headline productivity numbers (for example "800+%") are vendor/partner-presented and preliminary, with no published precision, recall or false-alarm rates.

### Cited Findings
**Independent trial evidence**
- UNDP ran Phase II trials of UAV/sensor systems for HMA in May 2024 at a test polygon in central Ukraine, at the Ministry of Economy's request. Phase I was in July 2023. Seven organisations took part (four Ukrainian), and products are anonymised as Organisations 1–7. Authors: E. Crowther (UNDP) and N. Shepel (Ministry of Economy), JCWD issue 28.3, Oct 2024 **[independent]**. — [JCWD 28.3, Crowther & Shepel](https://www.jmu.edu/news/cisr/2024/10/28-3/08-283-crowther.shtml)
- Trial setup: a calibration area with 4 items; a confirmed hazardous area of 1.44 ha with 27 mines, cluster munitions and UXO (surface and buried); and a suspected hazardous area of 5.75 ha with 6 items. All items were real, explosive-free and surveyed with D-GPS. More items were metal than plastic, and more were surface than buried. — [JCWD 28.3](https://www.jmu.edu/news/cisr/2024/10/28-3/08-283-crowther.shtml)
- Sensors: all teams used EO cameras. Three added magnetometers, one used EMI, and four used multispectral/IR. One used "pulsating electromagnetic scanning", and one flew a fixed-wing UAS. No GPR was reported. — [JCWD 28.3](https://www.jmu.edu/news/cisr/2024/10/28-3/08-283-crowther.shtml)
- Results by organisation:
  - Organisations 4 and 7 each found more than 55% of targets across both sites.
  - Organisation 7 (EO + magnetometer) found 71% of metal and 67% of buried objects in the CHA.
  - Organisation 4 (EO only) found 78% of surface, 62% of plastic and 57% of metal objects.
  - Organisation 5 found 50% of metal and 44% of buried objects.
  - Every surface object was found by at least one team, but only 60% of buried objects were.
  - Buried plastic detection "remained unreliable" for all technologies.
  - Four teams could not survey the SHA because of technical faults, flight bans or wind.

  — [JCWD 28.3](https://www.jmu.edu/news/cisr/2024/10/28-3/08-283-crowther.shtml)
- Lessons the authors give:
  - Items were buried the day before, so disturbed soil made them easier to spot. Bury them at least a week, ideally a month or more, ahead.
  - Background contamination added noise to false-alarm counts.
  - A semi-permanent test site is recommended.
  - Gains are more likely from sensor fusion and AI than from new hardware, and human experts are still needed to review the data.

  — [JCWD 28.3](https://www.jmu.edu/news/cisr/2024/10/28-3/08-283-crowther.shtml)

**Safe Pro Group / SpotlightAI (Safe Pro AI)**
- NPA Ukraine began a pilot with Safe Pro AI in Nov 2023. NPA NTS teams supply drone imagery of contaminated fields, and Safe Pro processes it in a cloud model. — [NPA](https://www.npaid.org/mine-action-and-disarmament/news/npa-ukraine-conducts-pilot-project-with-safe-pro-ai-for-automated-processing-of-drone-imagery); [AWS case study](https://aws.amazon.com/partners/success/norwegian-peoples-aid-safe-pro-ai/) (AWS says survey times were cut by 90% **[vendor/partner claim]**)
- An 18-month "preliminary" study was presented at the GICHD 2025 Innovation Conference by Kyaw Lin Htut (NPA) and Dr Jasper Baur (Safe Pro AI co-founder and lead scientist). It covered about 200 ha. **[vendor/partner claim]**: the study was co-presented by the vendor, the release calls it "independent research", and no peer review or method details are disclosed.
  - Claimed results: 800+% NTS productivity; 850% more CHAs identified per hour per team; 550% more potentially hazardous items per hour per team; 300% faster survey; about 50% lower labour cost per hectare.
  - The release contradicts itself: the 550% figure is "per hectare" in its introduction and "per hour per team" in its bullet points.
  - It gives no precision, recall or false-positive figures.

  — [Safe Pro press release, 4 Nov 2025](https://safeprogroup.com/safe-pros-artificial-intelligence-delivers-800-productivity-surge-in-ukraine-demining-surveys-according-to-independent-research-presented-at-leading-global-conference/)
- Cumulative platform figures **[vendor claim]**:
  - Nov 2025: over 2.1 million drone images, over 38,000 detections, over 10,900 ha mapped. — [Safe Pro, Nov 2025](https://safeprogroup.com/safe-pros-artificial-intelligence-delivers-800-productivity-surge-in-ukraine-demining-surveys-according-to-independent-research-presented-at-leading-global-conference/)
  - An earlier figure: 1,290,679 images, 23,286 ERW, 5,338 ha. — [Yahoo/Business Wire](https://finance.yahoo.com/news/safe-pro-artificial-intelligence-delivers-130300848.html)
- NIBULON (Ukrainian agricultural producer) milestone, Apr 2025: results "366 times faster than human analysis" **[vendor claim]**. — [Business Wire via Morningstar](https://www.morningstar.com/news/business-wire/20250429861079/safe-pro-and-nibulon-ltd-ukraines-top-agriculture-producer-reach-land-survey-milestone-using-drones-and-ai-to-detect-landmines-with-results-366-times-faster-than-human-analysis)
- IEEE Spectrum reports that Safe Pro's technology is used by several NGOs in Ukraine, including NPA and HALO. — [IEEE Spectrum](https://spectrum.ieee.org/ukraine-drones)

**HALO Trust + AWS**
- AWS committed $4M (June 2024) for HALO to trial AI on drone imagery of Ukrainian minefields. At the start HALO had 542 drone flights (about 11 TB) and planned to train models in Amazon SageMaker. Models need ongoing vetting by HALO staff to remove false positives and negatives. — [HALO news](https://www.halotrust.org/news/artificial-intelligence-to-help-accelerate-landmine-clearance/); [AWS Public Sector Blog](https://aws.amazon.com/blogs/publicsector/the-halo-trust-is-working-with-aws-to-clear-mines-faster-and-save-lives-in-the-worlds-conflict-zones); [Computer Weekly](https://www.computerweekly.com/news/366591978/Halo-Trust-partners-with-AWS-to-accelerate-AI-led-landmine-clearance-in-Ukraine)
- HALO updates report field validation completed "in April" and integration under way in Kharkiv. They describe models that analyse terrain "in hours rather than days" **[NGO self-report, no metrics]**. — [HALO Ukraine update](https://www.halotrust.org/us/news/update-from-halo-ukraine-summer-2024/); [HALO Ukraine page](https://www.halotrust.org/where-we-work/europe-and-caucasus/ukraine/)
- HALO also publishes an innovation report on technology in mine action, "Clearing the Path". — [HALO innovation report PDF](https://www.halotrust.org/media/musjv5go/7978-halo-innovation-report-clearing-the-path-a4_web.pdf)

**Drone magnetometry (Ukraine MoD)**
- Ukraine's MoD reports an industrial drone with a suspended magnetometer used for NTS in Mykolaiv Oblast. It is said to survey more than 10 ha per day and to detect ordnance on and under the surface. Data are post-processed into hazard maps **[government claim, no published Pd/FAR]**. — [MoD Ukraine](https://mod.gov.ua/en/news/detection-of-explosives-including-underground-threats-unmanned-aerial-systems-with-magnetometers-are-being-deployed-for-demining-in-the-mykolaiv-region); [Ukrainska Pravda, May 2025](https://www.pravda.com.ua/eng/news/2025/05/2/7510314)
- Research: a dual-magnetometer drone payload with wavelet interference cancellation (WAIC-UP) and unsupervised event detection (RUDE) was validated only by Monte Carlo simulation on a 10×10 m grid. No detection metrics appear in the abstract. — [arXiv 2510.01417](https://arxiv.org/abs/2510.01417)
- A proof-of-concept UAV aeromagnetic system for unexploded BM-21 122 mm rockets is reported to separate exploded from unexploded rounds. — [UCLan "Landmine Coordinates" PDF](https://clok.uclan.ac.uk/54574/1/Landmine%20Coordinates%20part%20-%20I.pdf)
- Another study explores UAV magnetic surveys for UXO in a coastline zone. — [Geofizicheskiy Zhurnal](https://journals.uran.ua/geofizicheskiy/article/view/316760)

**Mine Kafon Drone**
- A Netherlands Enterprise Agency (RVO) project funds a demo in Ukraine (budget €145,501, about 90% spent, status "implementation", disbursements into Apr 2026). Its stated goal is to show that the drone system "can locate landmines faster, safer and cheaper". **No published trial results were found.** — [RVO project record](https://projects.rvo.nl/projects/nl-kvk-27378529-dhif24d049)
- Earlier EU Horizon 2020 SME support is recorded under CORDIS project 887195. — [CORDIS](https://cordis.europa.eu/project/id/887195); [CORDIS article](https://cordis.europa.eu/article/id/422614-clearing-landmines-with-the-help-of-drones)
- Claims such as "20 times faster than people" appear only in media, without supporting data. — [Engadget tag page](https://www.engadget.com/tag/demining/); [Wikipedia](https://en.wikipedia.org/wiki/Mine_Kafon_Drone)

**GICHD position**
- GICHD's equipment catalogue says drones are used for mapping during NTS. Drone-mounted metal detectors and GPR are still at the study stage. — [GICHD equipment catalogue: unmanned systems](https://gichd.org/publications-resources/equipment-catalogue/unmanned-systems)
- A GICHD presentation says UAS integration needs accredited procedures, trained operators and validated methods. — [GICHD "UAS application in NTS"](https://www.gichd.org/fileadmin/uploads/gichd/Media/GICHD-resources/Innovation_Hub/presentation/UAS_application_in_NTS.pdf)
- GICHD's core NTS guidance is still the 2019 *Guide to Non-Technical Survey* (with IMAS 07.11 and 08.10). — summarised in search results; see [GICHD UAS presentation](https://www.gichd.org/fileadmin/uploads/gichd/Media/GICHD-resources/Innovation_Hub/presentation/UAS_application_in_NTS.pdf)
- An earlier JCWD article (Jan 2019) covers the added value of UAVs in HMA. — [JMU CISR 2019](https://www.jmu.edu/news/cisr/2019/January/16-uav.shtml)

### Inferences
- In operation, the drone is a **survey and prioritisation tool for NTS** (finding surface items, craters, indicators and CHA boundaries), not a clearance or release tool. The AI flags "suspected" items, and humans verify them.
- No public operator reports detection probability or false-alarm rate for a deployed AI system. The UNDP trial gives the only comparable numbers, and its products are anonymised.
- A metal sensor (magnetometer) helps with buried and metal targets. EO/thermal helps with surface and plastic targets. Buried, low-metal or plastic mines remain unsolved from the air.

### Gaps
- Could not read the full NPA report "Quantifying the Impact of AI-augmented Drone Imagery Analysis" ([NPA PDF](https://www.npaid.org/files/Publications/Mine-Action-and-Disarmament/NFH_Quantifying-the-Impact-of-AI-augmented-Drone-Imagery-Analysis_4_korr.pdf)). The PDF text could not be extracted in this environment, so its methods and any precision/recall figures are unverified. It should be read directly.
- No information was found on FSD's current drone programmes, on "DEMINE" as a named project, or on "Odyssey" or Zala in a demining (as opposed to military) context.
- No published results of the UNDP Phase I (2023) trial were retrieved, and no later phase after May 2024 was found.
- HALO/AWS model accuracy has not been published.

## How is Ukraine using drones for mine survey, and what has been learned?

### Takeaway
Ukraine has formally written UAV and satellite imagery analysis into its national land-release standard (SSU 8820-5:2024, announced Jan 2025). NGOs (NPA, HALO) and commercial and agricultural actors (NIBULON) fly EO drones with AI for NTS, and the MoD fields magnetometer drones. Lessons so far: drones speed up NTS and CHA definition, surface items are found well, buried and plastic items are not, and proper test ranges and human review are needed.

### Cited Findings
- SSU 8820-5:2024 "Mine Action. Management processes. Section 5. Processes of land release", announced 20 Jan 2025, recognises "UAV and satellite imagery analysis" as a survey method. It aligns national rules with IMAS and was developed with GICHD and OSCE support. — [MoD Ukraine](https://mod.gov.ua/en/news/state-standardization-now-recognizes-the-use-of-uav-and-satellite-imagery-in-demining-activities)
- HALO Ukraine increasingly uses drones in survey and clearance, and uses AI on satellite imagery to identify potential threats. — [HALO Ukraine](https://www.halotrust.org/where-we-work/europe-and-caucasus/ukraine/)
- NPA NTS teams in Ukraine use drones with SpotlightAI (pilot since Nov 2023). — [NPA](https://www.npaid.org/mine-action-and-disarmament/news/npa-ukraine-conducts-pilot-project-with-safe-pro-ai-for-automated-processing-of-drone-imagery)
- The Ministry of Economy and UNDP run comparative UAV/sensor trials (2023, 2024); see the results above. — [JCWD 28.3](https://www.jmu.edu/news/cisr/2024/10/28-3/08-283-crowther.shtml)
- The MoD deploys magnetometer drones for NTS in Mykolaiv (more than 10 ha per day claimed). — [MoD Ukraine](https://mod.gov.ua/en/news/detection-of-explosives-including-underground-threats-unmanned-aerial-systems-with-magnetometers-are-being-deployed-for-demining-in-the-mykolaiv-region)
- Commercial AI detects surface-visible items only. Buried mines still need technical survey and clearance. — [IEEE Spectrum](https://spectrum.ieee.org/ukraine-drones); [IEEE Spectrum (AI)](https://spectrum.ieee.org/amp/clear-land-mines-drones-ai-2668391125)

### Inferences
- Ukraine is the main data-generating theatre (millions of drone images), but that imagery is proprietary to vendors and NGOs and is not public.

### Gaps
- No authoritative figure was found for total hectares surveyed by drone in Ukraine across all operators.
- No independent post-clearance audit was found that compares drone/AI NTS outputs with what clearance actually found.

## What public datasets exist (names, links, licence, number of images/targets, mine types, conditions)?

### Takeaway
A small number of genuinely public, drone-relevant datasets exist. Almost all use **inert or replica mines on test plots**, mostly surface-laid, with a few shallow burials. The most useful for training are AMLID (RGB+LWIR UAS, 12,078 labelled images, 21 mine types, CC BY 4.0) and SULAND v2 (RGB UAV/UGV, 33,771 images, PFM-1 and PMA-2). Universidad del Valle's buried-mine UAV thermal set (CC BY 4.0) is the main buried-target aerial set. MineInsight (UGV, multispectral + LiDAR) is ground-based. No open, real-data GPR landmine dataset was found.

### Cited Findings

| Dataset | Platform / sensors | Size | Targets / mine types | Conditions | Labels | Licence / access |
|---|---|---|---|---|---|---|
| **AMLID** (Gallagher & Oughton, George Mason Univ.) | UAS, RGB + LWIR, 11 RGB-LWIR fusion levels | 12,078 labelled images, about 2.0 GB archive | 21 mine types, AP and AT, metal and plastic (individual types not listed on the Zenodo page) | 4 altitudes, 2 seasons, 3 illumination conditions | Labelled for object detection (YOLO keywords; format not confirmed) | **CC BY 4.0**, [Zenodo 10.5281/zenodo.18001447](https://zenodo.org/records/18001447), v1 20 Dec 2025; paper [arXiv 2512.18738](https://arxiv.org/pdf/2512.18738) |
| **SULAND v2** | UAV/UGV RGB | 33,771 images, 12,433 bounding boxes | PFM-1, PMA-2 | In-distribution and OOD (domain-shift) splits | Bounding boxes (refined) | Licence and download link not stated on the arXiv page, [arXiv 2607.28996](https://arxiv.org/abs/2607.28996) |
| **SULAND (v1)** (Vivoli et al.) | Handheld iPhone 13 RGB | 33,541 images, 10,169 annotated | PFM-1, PMA-2 | Grass, gravel | 2D boxes | Stated as released, no link given (per MineInsight review), [arXiv 2506.04842](https://arxiv.org/html/2506.04842v2) |
| **Test Images of Buried Landmines** (Tamayo et al., Universidad del Valle) | DJI Matrice 100 + Zenmuse XT (thermal 336×256 16-bit, visible 720×480) | About 1,834 images in the Mendeley v4 archive (per-modality counts sum to 1,822); MineInsight cites 2,700 thermographic images for the Data in Brief paper | Replica "legbreaker" AP mines | 10×10 m field, 9 zones (zone 6 is a mine-free control), depths 0/1/5/10 cm, altitude 0–11 m, flown Feb–Mar 2020 | Weak, image-level (by zone folder), **no boxes** | **CC BY 4.0**, [Mendeley 10.17632/732ngnf4r3.4](https://doi.org/10.17632/732ngnf4r3.4); mirror [Hugging Face](https://huggingface.co/datasets/dejanb/uav-thermal-buried-landmines) |
| **MineInsight** (Malizia et al., RA-L Feb 2026) | UGV + robotic arm: 2 LiDARs (Livox Mid-360, AVIA), RGB, mono, VIS-SWIR, LWIR | About 1 h of recording: ~38k RGB, ~53k VIS-SWIR, ~108k LWIR frames | 35 targets: 15 inert AP/AT mines + 20 common objects, on 3 tracks | Day and night, off-road | 2D boxes (automated, human-refined) | GitHub [mariomlz99/MineInsight](https://github.com/mariomlz99/MineInsight); dataset licence not stated in the paper (arXiv paper is CC BY 4.0), [arXiv 2506.04842](https://arxiv.org/html/2506.04842v2) |
| **Binghamton PFM-1 sets** (de Smet, Nikulin, Baur, Steinberg) | UAV (Phantom 4 Pro, Matrice 600 Pro), Parrot Sequoia multispectral, plus thermal | 24 datasets in total: 7 orthophotos (de Smet), 7 flights in grass and rubble with boxes (Steinberg), 15 photogrammetric sand datasets with rotated and partly buried mines (Baur) | Inert PFM-1 only | Grass, rubble, sand | Boxes only for the Steinberg sets | Binghamton repository (per MineInsight table); method paper [Remote Sensing 12(5):859, 2020](https://mdpi-res.com/d_attachment/remotesensing/remotesensing-12-00859/article_deploy/remotesensing-12-00859.pdf) |
| **Landmine thermal image series** (Leloglu et al.) | Fixed-mount IR (ATOM 1024, FLIR T650sc), not a drone | 96 thermal images over 24 h | DM-11 only | Clay | None | IEEE DataPort (subscription may be required), per [MineInsight review](https://arxiv.org/html/2506.04842v2) |
| **Drone flyby surface-mine set** (Agrawal-Chung & Moin) | Drone camera (model not named) | Size not on the abstract page; search snippet mentions 57 thermal images, altitudes 2.5/5/10 m | POM-2, POM-3 | Results at 10 m AGL | Boxes | Said to be released on GitHub (UnVeilX organisation); exact repo not confirmed. Benchmark: YOLOF mAP 0.89, DETR/VFNet/Sparse-RCNN about 0.82, [arXiv 2410.19807](https://arxiv.org/abs/2410.19807) |
| **HoloMine** | Synthetic microwave holographic imaging | Synthetic; size not retrieved | Buried mines (simulated) | n/a | n/a | [arXiv 2502.21054](https://arxiv.org/html/2502.21054v1) |
| **Roboflow community sets** | Mixed | Many | Varied | Usually undocumented collection conditions | Boxes | Roboflow Universe (per [MineInsight review](https://arxiv.org/html/2506.04842v2)) |

- SULAND v2 benchmark:
  - 35 detector configurations were tested. Best in-distribution: YOLOv12-S, mAP@50 0.908. Best out-of-distribution: RF-DETR-L, mAP@50 0.799, recall 0.675.
  - Annotation refinement raised YOLOv8 IID mAP@50 by 14.6–19.6 pp.
  - The authors conclude that high IID accuracy does not mean operational readiness.

  — [arXiv 2607.28996](https://arxiv.org/abs/2607.28996)
- Related multi-temporal RGB+LWIR fusion with YOLO for UAS landmine detection (same George Mason group as AMLID). — [arXiv 2512.20487](https://arxiv.org/pdf/2512.20487)
- GPR: the HoloMine authors state that "there is currently no common dataset available" for GPR or holographic data, and most prior work used simulated B-scans. — [arXiv 2502.21054](https://arxiv.org/html/2502.21054v1)
- Politecnico di Milano multi-polarisation GPR work used real sand-pit data with real inert mines (SB33, PFM1, VS50, PROM1, DM11, PMN58) at about 5–15 cm depth. Only code on part of the data is said to be available. — [arXiv 1810.01316](https://arxiv.org/pdf/1810.01316)
- An IEEE DataPort buried-object GPR set is simulated and needs a subscription. A Mendeley set of 2,239 GPR images covers utilities and voids, not mines. — [IEEE DataPort](https://ieee-dataport.org/documents/buried-object-characterization-using-ground-penetrating-radar/embed); [Mendeley ww7fd9t325](https://data.mendeley.com/datasets/ww7fd9t325/1)

### Inferences
- For an RGB/thermal detector, AMLID is currently the best-documented openly licensed UAS dataset. Universidad del Valle is the only open aerial set with **controlled burial depths**, but it has only weak labels.
- No public drone magnetometer landmine dataset was found, so magnetometer work must rely on simulation or new collection.

### Gaps
- Individual mine types and altitude values in AMLID were not confirmed (the paper should be checked).
- SULAND v2 licence and download location were not confirmed.
- The Binghamton repository URL and its licence were not directly verified.
- Kaggle sets were not surveyed. Roboflow sets are numerous but poorly documented.

## What gaps exist (e.g. no buried-mine ground truth, few low-metal mines, geographic bias)?

### Takeaway
The evidence base is thin in exactly the cases that matter most:
- buried, low-metal or plastic mines;
- independent field metrics (Pd/FAR) for deployed AI;
- open real-world operational imagery (Ukraine data is proprietary);
- drone GPR/magnetometer data with ground truth.

Public datasets use few mine types (often PFM-1 or PMA-2), inert or replica items on small test plots, and freshly laid targets.

### Cited Findings
- Buried plastic items were unreliable for all technologies, and only 60% of buried objects were found by any team, in the UNDP 2024 trial. — [JCWD 28.3](https://www.jmu.edu/news/cisr/2024/10/28-3/08-283-crowther.shtml)
- Freshly buried targets bias results optimistic (disturbed soil). Contaminated test ranges confound false-alarm counts. — [JCWD 28.3](https://www.jmu.edu/news/cisr/2024/10/28-3/08-283-crowther.shtml)
- Public UAV/UGV RGB datasets for surface landmine/UXO detection "remain limited". — [SULAND v2](https://arxiv.org/pdf/2607.28996)
- Most existing datasets cover one or two mine types (PFM-1; PMA-2; DM-11; replica AP) on test plots. — [MineInsight related work](https://arxiv.org/html/2506.04842v2)
- No common GPR landmine dataset exists, and AP mines are under-studied relative to AT mines. — [HoloMine](https://arxiv.org/html/2502.21054v1)
- Vendor performance claims lack disclosed precision, recall, false-positive data, control design or peer review. — [Safe Pro release](https://safeprogroup.com/safe-pros-artificial-intelligence-delivers-800-productivity-surge-in-ukraine-demining-surveys-according-to-independent-research-presented-at-leading-global-conference/)
- Drone-mounted metal detectors and GPR are still at the research stage per GICHD. — [GICHD catalogue](https://gichd.org/publications-resources/equipment-catalogue/unmanned-systems)
- Weather and regulation limit operations: wind, flight bans and technical faults stopped 4 of 7 teams on the SHA. — [JCWD 28.3](https://www.jmu.edu/news/cisr/2024/10/28-3/08-283-crowther.shtml)

### Inferences
- Geographic and environmental bias: the open sets come from US, Colombian, Belgian and other test fields, mostly grass, sand, clay or gravel. None comes from real Ukrainian farmland with real battlefield clutter (shell fragments, debris).
- Domain shift is the key risk. SULAND v2 shows OOD mAP falling well below IID mAP, so any MineGuard-style detector trained on these sets should be described as producing "suspected anomalies" in simulation or on test plots, not as having field detection capability.

### Gaps
- No public data was found that quantifies false-alarm rates of drone AI on real clutter-heavy fields.
- No geographic or terrain-diversity audit of public datasets was found in the literature.

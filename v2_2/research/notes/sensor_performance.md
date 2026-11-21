# UAV-Mounted Sensor Detection Performance for Landmines and UXO (Humanitarian Demining)

Research note: compiled 2026-11-21. Several primary sources (MDPI full texts, JMU/CISR pages, preprints.org) returned HTTP 401/403 to the fetch tool. Where that happened, the figures below come from search-result abstracts or snippets of those sources, and they are marked "(abstract/snippet)". Check them against the full text before quoting them in a final report.

## What do peer-reviewed field trials report for each sensor (numbers, test conditions, mine types)?

### Takeaway
The most consistent quantitative evidence is for detecting **surface-laid** mines, mainly the PFM-1, with RGB and thermal imaging plus deep learning. Accuracy is high on test sets drawn from the same data (around 99%), but drops sharply on fully withheld data (71.5%), and AP mines are found far less often than AT mines (19.2% vs 61.9%). Buried-mine evidence comes from thermal IR (qualitative field proof in Chad, plus about 88% in one study) and from UAV GPR-SAR (mostly system and imaging demonstrations, with few detection or false-alarm statistics). UAV magnetometry for UXO reports anomaly amplitudes and coverage rates rather than standardized Pd/FAR figures.

### Cited Findings

**RGB / multispectral / hyperspectral imaging + deep learning (surface mines)**
- Baur et al. 2020, *Remote Sensing* 12(5):859 (Binghamton University and Lamont-Doherty): a Faster R-CNN trained on UAV RGB imagery of PFM-1 mines reached **99.3% testing accuracy on a partially withheld test set** but **71.5% on a completely withheld test set**. The 71.5% is the more honest generalization figure (abstract/snippet). — [MDPI](https://mdpi.com/2072-4292/12/5/859); [DOAJ](https://doaj.org/article/e0f1c6f29e634cd282f4f782356cc4a3)
- The same group later reported that with an expanded dataset, CNN accuracy for detecting PFM-1 from visual (RGB) UAS imagery improved to **91.8%** (JCWD/CISR 2021, snippet). The reported metric is accuracy, not precision/recall. — [JMU CISR, Baur 2021](https://www.jmu.edu/news/cisr/2021/09/25-1/29-251-baur.shtml); [JMU Commons](https://commons.lib.jmu.edu/cisr-journal/vol25/iss1/29/)
- Baur's Columbia doctoral dissertation compared UAV modalities including LiDAR. It concluded that UAV RGB imagery was "the most cost effective, scalable, and highest accuracy method for detecting surface targets", and that the traditional handheld EMI metal detector was the most effective way to detect **subsurface** targets (snippet). — [Columbia Academic Commons](https://academiccommons.columbia.edu/doi/10.7916/fba0-sw83)
- A YOLOv11 RGB study (MDPI journal, 2026, vol. 6 issue 3 art. 54; authors not confirmed) reported validation **precision 78–91% and recall 76–88%** across model variants. For **3D-printed replica mines**, precision was 74–80% but **recall only 14–24%** (snippet; full text blocked). — [MDPI 2673-7418/6/3/54](https://www.mdpi.com/2673-7418/6/3/54)
- Lekhak et al. (RIT), arXiv 2602.10434v2 (Apr 2026): benchmark of PFM-1 detection in UAV VNIR hyperspectral imagery (272 bands, GSD about 1.29 cm, 7 inert PFM-1 locations, 248 target pixels; 5 targets used for training, 2 for testing; targets surface-visible or partially buried). Test-region AP/AUC: ACE 0.691/0.989; CEM 0.589/0.983; MF 0.358/0.982; SAM 0.144/0.797; Spectral-NN 0.814/0.982. On the full region, AP fell to 0.043–0.226 for the classical detectors even though AUC stayed at 0.994–0.998. Aeropoints and other non-target objects caused false alarms. — [arXiv 2602.10434](https://arxiv.org/html/2602.10434v2)
- RIT DIRS project: 34 co-registered datasets from nine modalities (RGB, hyperspectral, multispectral, TIR, LiDAR, SAR, UAV-EMI, magnetometry, GPR) over surface-laid PFM-1. The project page gives **no numeric results**, describes fusion as ongoing, and calls the UAV-EMI work a feasibility study. — [RIT DIRS](https://www.rit.edu/dirs/research/advancing-operational-landmine-detection-through-uav-based-multi-sensor-sensing-and)

**Thermal infrared (surface and buried)**
- Abramowitz, Frazer, Baur, Nikulin, de Smet 2018, *Remote Sensing* 10(11):1672: low-cost UAVs with IR cameras detected and identified **all elements** of a simulated full-scale ballistic PFM-1 minefield, using thermal inertia signatures (abstract). — [MDPI 10/11/1672](https://mdpi.com/2072-4292/10/11/1672); [catalog record](https://katalog.lib.cas.cz/KNAV/EdsRecord/edsair,edsair.doi.dedup.....71852d33b9e207e2ce07d76134f121e0)
- Baur et al. 2020 derived a "differential apparent thermal inertia" signature from the PFM-1's polyethylene casing. It lets them distinguish PFM-1 mines from KSF-1 casing cross-elements (abstract). — [MDPI 12/5/859](https://mdpi.com/2072-4292/12/5/859)
- An earlier de Smet and Nikulin paper is titled "Catching 'butterflies' in the morning", which points to morning acquisition for plastic PFM-1. Its specific time-window findings were not retrieved. — [search result context](https://doaj.org/article/1827fd4177cc43fcb543d007e75e0095)
- Fardoulis et al. (JCWD 24.2, 2021) gave field proof of **buried** legacy mine detection with a small drone LWIR camera at **35 m AGL** over legacy minefields in **Chad**, in the hot and cold seasons (Oct 2019, Mar 2020). Thermal anomalies from **twenty-seven buried legacy landmines** were visible in one LWIR image. Anomalies were validated by flying rows of visible surface mines and checking for buried mines beside them. The authors note the earlier lack of proof under actual field conditions (snippet; full page returned 401). — [JMU CISR, Fardoulis 2021](https://www.jmu.edu/news/cisr/2021/07/15-242-fardoulis.shtml); [JMU news](https://www.jmu.edu/news/cisr/2021/02/16-drones.shtml)
- A related automated baseline TIR test site near Al-Bussayah, Iraq used a **fixed ground-mounted** thermal camera (not a drone) logging at one-minute intervals over 24-hour cycles in autumn to characterize when buried-target anomalies appear (snippet). — [JMU CISR, Fardoulis 2022](https://www.jmu.edu/news/cisr/2022/06/253/12-253-fardoulis.shtml)
- Krause, Salahat and Franklin (2018): UAV thermal camera over several diurnal cycles; surrogate buried mines showed clear shapes with **>2 K thermal difference** from their surroundings (ANU record, snippet). — [ANU research portal](https://researchportalplus.anu.edu.au/en/publications/diurnal-thermal-dormant-landmine-detection-using-unmanned-aerial-/)
- Butt (arXiv 2410.23998, 2024): a UAV thermal camera reported detection accuracy of **"nearly 88%"**, performing best **in the evening** (snippet; PDF text could not be extracted). Whether the targets were real or surrogate, and their depth and soil, were not confirmed. — [arXiv 2410.23998](https://arxiv.org/pdf/2410.23998)
- Open dataset: about 2,700 drone thermal images of buried "legbreaker" improvised mines, Colombia (2023, *Data in Brief*). — [PMC10403701](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10403701/)
- An ISPRS archives study on UAV thermal imaging found that **night-time TIR acquisition gave higher thermal contrast** (snippet). — [ISPRS XLII-1-413-2018](https://isprs-archives.copernicus.org/articles/XLII-1/413/2018/isprs-archives-XLII-1-413-2018.pdf)

**LiDAR**
- HALO Trust with Routescene at Cuito Cuanavale, Angola (JCWD 27.2, 2023): UAV LiDAR penetrated dense vegetation to produce a ground DTM. It detected **minefield features** (trenches, bunkers, craters, ground disturbance) at three locations, with positive results. These features were no longer visible from the ground or to UAV RGB/TIR because of overgrowth. The targets were indicators, **not individual mines**. — [JMU CISR, James 2023](https://www.jmu.edu/news/cisr/2023/06/272/07-272-james.shtml)
- A 2024 *Remote Sensing* study (DOI 10.3390/rs16122046) found that aerial detection accuracy for surface landmines/UXO is "highly dependent on the height and density of vegetation" (snippet; based on digital surface models). — [DOAJ](https://doaj.org/article/6e3021d792e34adfb7994bd5d2586fd0); [Crossref](https://api.crossref.org/works/10.3390%2FRS16122046)
- MineInsight (2025) notes that existing demining datasets often omit LiDAR. — [arXiv 2506.04842](https://arxiv.org/html/2506.04842v2)

**Ground-penetrating radar (UAV-GPR, GPR-SAR)**
- García-Fernández et al. (Univ. Oviedo), IEEE Access 2018: a UAV-borne radar with SAR processing produces high-resolution underground images. It requires **centimetre-level positioning** and detects **both metallic and dielectric (plastic) targets**. — [DOAJ list](https://doaj.org/article/0d0dd2f8a76f441caa50a29fc908008e); [Uniovi PDF](https://digibuo.uniovi.es/dspace/bitstream/10651/51029/2/SistemadeGPR.pdf)
- Remote Sensing 2019 (autonomous 3D system): a UWB radar from the UHF band plus dual-band RTK, targeting metallic and non-metallic buried objects. A separate Remote Sensing 2019 bistatic vehicle-and-drone configuration showed improved detection and clutter reduction **in simulation only**. — [DOAJ](https://doaj.org/article/6fe099a33e2641c58dc9c62feeaabe6c); [DOAJ](https://doaj.org/article/2fcf06713c7347f394a7e54c26ffd3aa)
- IEEE Access 2020 (multi-channel): studied how flight speed and the number of measurements combined in SAR processing affect resolution, for landmines and IEDs. — [DOAJ](https://doaj.org/article/b66e6baa16a2427e934ac398293e6daa)
- 2023 array-based GPR-SAR (QUB/Oviedo): an antenna array increases throughput, and coherent multichannel combination improves detection. ISPRS J. 2024 covers real-time processing (phase-shift migration vs backprojection) for IED-type targets. — [QUB](https://pure.qub.ac.uk/en/publications/array-based-ground-penetrating-synthetic-aperture-radar-on-board-/); [ISPRS 2024 PDF](https://pureadmin.qub.ac.uk/ws/files/586397557/1-s2.0-S0924271624001680-main.pdf)
- Bähnemann et al. (ETH Zurich / Ulm), *Field Robotics* 2 (2022): an MAV GPR-SAR whose field trials validated localization accuracy good enough to image **radar targets buried in sand**. Dual-position-factor localization improved accuracy by up to 40% (online) and 59% (batch). The authors frame this as demonstrating *potential*. No Pd/FAR figures are given in the abstract. — [arXiv 2106.10108](https://arxiv.org/abs/2106.10108)
- A 2025 IWAGPR paper cites a review of **14 UAV-based GPR systems**. A UAV-GPR study notes that GPR's ability to discriminate low-metal-content targets is its main attraction. — [IWAGPR 2025](https://froneycrawford.github.io/ps/iwagpr2025_paper3.pdf); [Uniovi review](https://digibuo.uniovi.es/dspace/bitstream/handle/10651/66192/FINAL%20VERSION.pdf?sequence=1)

**Magnetometers and drone-borne metal detectors / EMI**
- San Gregorio, Spain (*Drones* 10(2):88, 2026): a hexacopter with a proton magnetometer flew 1 m line spacing at **7 m and 2 m AGL** over **eleven buried UXOs**. It recorded anomalies of **2–18 nT** in a high ferromagnetic-noise area and covered **0.53 ha in under an hour** of flight (snippet; how many of the 11 were detected was not retrieved). — [MDPI Drones](https://www.mdpi.com/2504-446X/10/2/88); [preprint](https://www.preprints.org/manuscript/202512.0511/download/final_file)
- Kolster et al., *Remote Sensing* 2022: three scalar magnetometers towed about 10 m below a high-speed UAV over a 600 m × 100 m area. Most targets, including all major ones, were recovered, and one horizontal gradiometer configuration did significantly worse (snippet). — [DOAJ](https://doaj.org/article/432903f6ae2d4989b4faa1caa3b2ec93); [AGRIS](https://agris.fao.org/search/en/records/687a85949d6e0577321e7cd2)
- Chernihiv, Ukraine (JCWD 24.1): inert BM-21 rockets spaced about 25 m apart. **3 m line spacing** was needed for consistent anomaly identification. A blind trial tested whether intact rockets can be told apart from debris (result not retrieved). — [CISR issuu](https://issuu.com/cisr-journal/docs/24.1-all/s/10723813)
- Kuru et al. (UCLan): a low-cost drone with fluxgate magnetometers in open-air minefields. The authors say the results support the approach, but the snippet gives no percentages. — [UCLan AAM](https://clok.uclan.ac.uk/52983/7/52983%20Kuru%20et%20al.%20AAM.pdf)
- An airborne EM61Lite (EMI) evaluation in *Remote Sensing* asked whether it could replace handheld detectors, noting that reliability is a concern because "even a single missed detection can be life-threatening" (snippet). — [MDPI 17/1/110 / 16/24/4732 search context](https://mdpi.com/2072-4292/16/24/4732)

### Inferences
- Headline accuracy in deep-learning RGB studies is highly sensitive to how the test set is split (99.3% vs 71.5% in the same paper). Same-site or partially withheld figures overstate how well the models generalize to new sites.
- The source search found no UAV-GPR or UAV-EMI paper reporting Pd/FAR on standardized humanitarian test lanes. The literature is still at the system-demonstration stage.

### Gaps
- Exact Pd and FAR (per m²) values for UAV GPR-SAR on real or inert AP mines were not found. The full texts of the IEEE Access 2018/2020 papers would need checking.
- How many of the 11 UXOs were detected in the San Gregorio trial (full text blocked).
- GICHD technology notes and reports on drones were not retrieved within budget, so no GICHD position is cited here.
- Butt (2024) test conditions (real vs surrogate targets, depth, soil) could not be confirmed.

## Which combinations (sensor fusion) improved results, and by how much?

### Takeaway
Quantified fusion gains are scarce. The clearest figure is from RGB+LWIR fusion for YOLO detection of **surface** mines (Gallagher et al. 2025): best mAP was 86.8%, with 10–30% thermal fusion at 5–10 m altitude found optimal, and multi-temporal training adding 1.8–9.6%. Thermal+RGB is also used qualitatively, with thermal to discriminate and RGB to detect (Baur et al.).

### Cited Findings
- Gallagher, Oughton, Kosecka, arXiv 2512.20487 (Dec 2025): adaptive RGB+LWIR fusion on UAS imagery, **surface-laid mines only**, 114 test images and 35,640 model-condition evaluations. Best **YOLOv11 mAP 86.8%**. The **optimal thermal fusion level was 10–30% at 5–10 m altitude**. Aggregated multi-temporal training beat season-specific training by **1.8–9.6%**. In the architecture comparison: YOLOv11 64.2%, RF-DETR 69.2%, Faster R-CNN 67.6%, RetinaNet 50.2% mAP. Detection accuracy was **AT 61.9% vs AP 19.2%**, which the authors attribute to size and thermal mass. Training took about 41 min for YOLOv11 vs about 12 h for RF-DETR. (These figures are from the abstract. The two YOLOv11 numbers likely come from different conditions, which the abstract does not explain.) — [arXiv 2512.20487](https://arxiv.org/abs/2512.20487v1)
- Baur et al. 2020 combined RGB CNN detection with thermal "differential apparent thermal inertia" to separate PFM-1 mines from KSF-1 casing clutter. No fused metric is reported in the abstract. — [MDPI 12/5/859](https://mdpi.com/2072-4292/12/5/859)
- García-Fernández et al. 2019: the bistatic vehicle-plus-drone GPR "greatly improves" detection and surface-clutter reduction over conventional forward-looking GPR, **in simulation only**. — [DOAJ](https://doaj.org/article/2fcf06713c7347f394a7e54c26ffd3aa)
- Kolster et al. 2022: gradiometer configurations (combining several magnetometers) differed in recovery, and one horizontal configuration did significantly worse. — [DOAJ](https://doaj.org/article/432903f6ae2d4989b4faa1caa3b2ec93)
- RIT nine-modality campaign: fusion is described as ongoing, with no results published on the project page. — [RIT DIRS](https://www.rit.edu/dirs/research/advancing-operational-landmine-detection-through-uav-based-multi-sensor-sensing-and)
- LiDAR is used in UAV-GPR systems for ground-distance (altitude) measurement, a supporting role rather than a detection one (search context). — [IWAGPR 2025](https://froneycrawford.github.io/ps/iwagpr2025_paper3.pdf)

### Inferences
- In practice, "fusion" today is mostly LiDAR or RTK supporting GPR/magnetometer geometry, or thermal supporting RGB discrimination, rather than decision-level fusion with measured Pd/FAR gains.

### Gaps
- No peer-reviewed field trial was found that reports Pd/FAR for fused UAV GPR+EMI or magnetometer+thermal on buried AP mines.

## What are the fundamental physical limits?

### Takeaway
Each sensor has hard physical constraints:
- **RGB/multispectral** works only for surface-visible objects and is defeated by vegetation.
- **Thermal** depends on diurnal heating and cooling transitions, soil state and season. Contrast is strongest for surface mines and for larger AT mines, and night or evening can give higher contrast.
- **LiDAR** sees only surface geometry and disturbance (trenches, craters), not buried mines.
- **GPR** needs centimetre-level positioning and SAR processing, and has been shown mainly in dry sand.
- **Magnetometers** see only ferrous mass, so anomalies are small and clutter-dominated (2–18 nT), and low altitude with tight line spacing is required.

### Cited Findings
- Thermal mechanism: buried objects change how the ground stores and conducts heat, creating hot or cold surface patches above them. This is why acquisition timing within the 24-hour cycle matters (snippet). — [JMU CISR, Fardoulis 2022](https://www.jmu.edu/news/cisr/2022/06/253/12-253-fardoulis.shtml)
- Thermal contrast is strongest for surface-laid mines. The effect of burial depth and heterogeneous soils is untested in the fusion work. The AP vs AT gap is attributed to size and thermal mass. — [arXiv 2512.20487](https://arxiv.org/abs/2512.20487v1)
- Timing: night or evening gives higher contrast in some studies (evening best at about 88% in Butt 2024; night higher in an ISPRS study). The PFM-1 work emphasizes morning ("Catching butterflies in the morning"). — [arXiv 2410.23998](https://arxiv.org/pdf/2410.23998); [ISPRS 2018](https://isprs-archives.copernicus.org/articles/XLII-1/413/2018/isprs-archives-XLII-1-413-2018.pdf); [DOAJ](https://doaj.org/article/1827fd4177cc43fcb543d007e75e0095)
- The Chad thermal results came from the hot and cold seasons in desert. The source is titled "...in the desert", so dry sandy soil is the proven setting. — [JMU news](https://www.jmu.edu/news/cisr/2021/02/16-drones.shtml)
- Vegetation: overgrowth makes mines and conflict indicators invisible to UAV RGB/TIR, while LiDAR can reach the ground and reveal disturbance only. Aerial detection accuracy depends strongly on vegetation height and density. — [JMU CISR, James 2023](https://www.jmu.edu/news/cisr/2023/06/272/07-272-james.shtml); [DOAJ rs16122046](https://doaj.org/article/6e3021d792e34adfb7994bd5d2586fd0)
- GPR-SAR needs centimetre-level positioning (RTK) and sub-microsecond sensor timing. Bähnemann et al. report timing as accurate as 0.8 µs and as precise as 0.1 µs, and their field trials used sand. — [Uniovi PDF](https://digibuo.uniovi.es/dspace/bitstream/10651/51029/2/SistemadeGPR.pdf); [arXiv 2106.10108](https://arxiv.org/abs/2106.10108)
- Magnetometry: anomalies of 2–18 nT in high ferromagnetic noise, flown at 2–7 m AGL with 1 m lines. In the BM-21 trials, 3 m spacing was needed for consistent anomalies. — [MDPI Drones 10/2/88](https://www.mdpi.com/2504-446X/10/2/88); [CISR issuu](https://issuu.com/cisr-journal/docs/24.1-all/s/10723813)
- Subsurface: Baur's dissertation found the handheld EMI detector was still the most effective at detecting subsurface targets among the methods compared. — [Columbia](https://academiccommons.columbia.edu/doi/10.7916/fba0-sw83)

### Inferences
- From general physics (not sourced here): GPR performance is expected to degrade in wet, conductive clay, and magnetometers cannot detect minimum-metal plastic AP mines. No retrieved source gave a figure for either effect, so treat both as background, not evidence.

### Gaps
- No retrieved source quantified thermal detectability against soil moisture or burial depth for drones. The exact best-hour windows from the Iraq baseline site were not retrieved.
- No source was retrieved that quantifies UAV-GPR loss in wet clay.

## Where is evidence weak, lab-only, or overclaimed?

### Takeaway
The evidence base is thin:
- Many results come from a single site, inert targets, small test sets and accuracy-only metrics.
- GPR-SAR and the fusion configurations are largely demonstrations or simulations.
- Replica and AP mines show low recall.
- ROC-AUC near 0.99 hides very low AP under heavy class imbalance.

### Cited Findings
- Same-paper generalization drop from 99.3% (partially withheld) to 71.5% (completely withheld). — [MDPI 12/5/859](https://mdpi.com/2072-4292/12/5/859)
- Hyperspectral PFM-1: a single site, 7 targets with only 2 in the test set, and no repeated runs. The "outperforms" claim rests on AP alone (Spectral-NN AUC 0.982 < ACE 0.989). Full-region AP is 0.043–0.226 despite AUC ≥0.994, and the authors note that ROC-AUC can mislead for sparse targets. — [arXiv 2602.10434](https://arxiv.org/html/2602.10434v2)
- Replica mines: recall of 14–24% despite 74–80% precision. — [MDPI 2673-7418/6/3/54](https://www.mdpi.com/2673-7418/6/3/54)
- AP detection accuracy of 19.2% vs 61.9% for AT, surface-only. — [arXiv 2512.20487](https://arxiv.org/abs/2512.20487v1)
- Bistatic GPR gains are simulation-only. A 2020 comment by the Oviedo group stated that SAR processing was not actually applied in the UAV measurements of a competing lightweight UAV-GPR paper (Sipos and Gleich), which illustrates the risk of overclaiming. — [DOAJ](https://doaj.org/article/2fcf06713c7347f394a7e54c26ffd3aa); [PMC7285478](https://pmc.ncbi.nlm.nih.gov/articles/PMC7285478)
- The Under-the-Sand MAV GPR-SAR is framed as showing "potential". — [arXiv 2106.10108](https://arxiv.org/abs/2106.10108)
- UAV-EMI at RIT is a feasibility study, and generalization across sites and altitudes is unresolved. — [RIT DIRS](https://www.rit.edu/dirs/research/advancing-operational-landmine-detection-through-uav-based-multi-sensor-sensing-and)
- The CISR group acknowledged a prior lack of field proof for drone thermal detection of buried mines. — [JMU CISR, Fardoulis 2021](https://www.jmu.edu/news/cisr/2021/07/15-242-fardoulis.shtml)
- A broad systematic review of UAV geophysics (435+ works, *Remote Sensing* 17(1):110, about 2025) is not mine-specific. The nine-modality 2026 preprint is **not peer-reviewed**. — [MDPI 17/1/110](https://mdpi.com/2072-4292/17/1/110); [preprints.org](https://www.preprints.org/manuscript/202605.0758)

### Inferences
- In humanitarian clearance, the requirement is close to 100% Pd at a defined depth. None of the UAV sensors reviewed show that for buried low-metal AP mines, which supports using UAV sensors for non-technical and technical survey (area reduction, finding indicators and surface mines) rather than as a replacement for ground clearance.

### Gaps
- No standardized test-lane (for example CEN CWA 14747-style) results for any UAV sensor were found.
- GICHD assessments were not retrieved.
- No independent replication of the Chad buried-mine thermal results was found.

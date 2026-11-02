# V2-006 screenshots: read this before using them

**All three images are SYNTHETIC DEMO FIXTURES, not VALIDATION evidence.** They come from the DEMO scenario, which holds one deliberately strong synthetic feature and is excluded from every accuracy report. VALIDATION found zero targets (`v2/evidence/V2-006.md` §4). Scores and uncertainty are uncalibrated.

| File | Source commit | Label inside the image | What it shows |
|---|---|---|---|
| `map-demo-fixture.png` | `14c6c56`, original, unchanged | Simulated and suspected wording only; this file is the demo-fixture label | Offline map with 78 SUSPECTED events |
| `inspector-demo-fixture.png` | `14c6c56`, original, unchanged | "SIMULATED" only; this file is the demo-fixture label | **SUS-00113, the strongest-scoring false alarm** (score 1.000) at (-15.47, -5.36) m. Despite the filename, it is **not** the fixture event |
| `inspector-demo-event-SUS-00296.png` | clean clone at `6263997` | "SYNTHETIC DEMO FIXTURE, not VALIDATION evidence" | **SUS-00296, the fixture event** (score 0.859) at (5.43, 3.20) m |

Evaluator result for the DEMO scene (`demo-provenance-6263997.txt`): 78 events, TP 1, FP 77, FN 0. SUS-00296 is 0.081 m from the fixture.

**How SUS-00296 was selected.** `mgv2DetectionDemo(EventId="SUS-00296")` looks the id up in the public detector output, and its evidence references are verified against the sensor log. The demo never reads scenario truth. The id itself was identified earlier by the separate evaluator step, so "this is the fixture event" is an evaluator statement recorded here. It is not something the demo or any live UI can know.

Regenerate with `mgv2DetectionDemo(ShotDir=<new folder>, EventId="SUS-00296")`. The demo refuses to overwrite an existing file.

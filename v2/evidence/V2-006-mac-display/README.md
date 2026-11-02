# V2-006 Mac display correction (corrective record, not task completion)

Task: V2-006 (owner Rahil; official status unchanged). Corrective branch `task/V2-006-mac-display-correction` was subsequently pushed without force and is proposed as a stacked review into PR #66 (not directly to `main`); no merge or task completion is claimed.
Base: PR #66 head `684665c2ea337f0724fa5f9b678a7a1b9599c8c0`. Code under test: `bb52c0fb2a530af635ab75798f27677c3d56a3c0`.
Executed by Claude Code (Opus 5.5) through the MathWorks MATLAB MCP Server on Shabaz's Mac (MACA64, R2026b Update 1); human review pending.
SIMULATION ONLY. A software PASS says nothing about detection: the VALIDATION result remains negative and this fixture run has 77 false alarms in 78 events.

## Defect and fix

The demo's white figures inherited the dark MATLAB theme, giving pale grey text at 1.41:1 contrast on white, including the SIMULATED and SUSPECTED labels.

Only `v2/matlab/mgv2DetectionDemo.m` changed in product code:
- Both figures now call `theme(f, "light")` before any content is drawn, so their appearance no longer depends on the desktop theme.
- The map legend has a fixed mid-grey background, because a white key hid the white planned route and a dark key hid the black actual route.

Test `d28_demoLabelsReadableInBothDesktopThemes` was added to `testV2006Detection.m`. Detector, sensor, map model, thresholds, data, task status and original evidence are unchanged.

## Readability (WCAG contrast of every text colour against its surface)

| Desktop theme | Map | Inspector SUS-00113 | Inspector SUS-00296 |
|---|---|---|---|
| Dark, corrected | 9.66:1 | 16.10:1 | 16.10:1 |
| Light, corrected | 9.66:1 | 16.10:1 | 16.10:1 |
| Dark, uncorrected `684665c` (negative control) | 1.41:1 | 1.41:1 (default selection, SUS-00113) | not run |

The check covers axes, titles, in-axes text, annotations, colorbars with their `apparent T (K)` labels, and the legend. The negative control fails the 4.5:1 threshold, so d28's check detects the original defect. Desktop themes were switched with the temporary MATLAB setting and restored afterwards (`System`, no temporary value).

## Tests (one run, clean tree at the code SHA)

| Suite | Tests | Passed | Failed | Incomplete | Time |
|---|---|---|---|---|---|
| testV2002MissionEngine | 22 | 22 | 0 | 0 | 2.9 s |
| testV2003Scene | 22 | 22 | 0 | 0 | 45.8 s |
| testV2005Sensors | 28 | 28 | 0 | 0 | 113.0 s |
| testV2006Detection (27 + d28) | 28 | 28 | 0 | 0 | 244.8 s |
| **Total** | **100** | **100** | **0** | **0** | 406.6 s |

0 figures and 0 timers left afterwards. The V2-006 test setup flies partial TRAIN groups as fixtures. No TRAIN selection, frozen VAL or held-out TEST ran.

## Scientific results unchanged

The DEMO FIXTURE was run from `684665c` and from the corrected working tree (commit content identical to `bb52c0f` for this code), and every value below was identical. The sensor sample count and hashes cover this one fixture run only.

| Item | Value |
|---|---|
| Detector fingerprint | `fnv1a64:d6d364f988f04bb4` |
| Split manifest | `550af3d4cd4dbca16ee294d29148c084141fe2b1864ead54d31d0a529dd77d16` |
| Events / TP / FP / FN | 78 / 1 / 77 / 0 |
| Sensor samples | 1571 |
| Sample checksums (SHA-256) | `ec8c34e69a5479e3d913960eb67a8971526e8a06f934062e6a5fa4525c5de657` |
| Events | `1b7e8dc9a581e08531dbd07e1d99aa519396d9b879260a7b58ca43d671444ac8` |
| Event features | `be8fd1259e9ca698079987caea9807b431b936ab93b62c1f2f596ea305f7435e` |
| Tracks | `0226e5ebb9f00b98837c203c9a6377811ecda7a8bc7eead0e8a63ac394d5b965` |
| Pose positions | `4828b8c23ca7b7fcca27a1071eb5b5cfb7ce57caab0df6871f565656e5469501` |
| Coverage cell states | `128ff58a53577116d97dc6cf1a050572f41b1843b1aa67a9970f830616d9a59f` |

## Screenshots (this folder; original `v2/evidence/V2-006/` files are untouched)

`dark-desktop-` and `light-desktop-` versions of `map-demo-fixture.png`, `inspector-SUS-00113.png` and `inspector-SUS-00296.png`.

The map's plot and legend are laid out slightly differently between the two captures; colours and contrast match. All are SYNTHETIC DEMO FIXTURES, not VALIDATION evidence.

## Remaining limitations

- `MapView` itself is unchanged. In a figure other than this demo's (for example a V2-007 window) its text and legend still follow that figure's theme.
- White planned-route dashes are low contrast against the grey legend and light terrain, though visible.
- Windows was not re-run on this correction; the theme call and test are not OS-specific, but this is unverified. d28 reports Incomplete, not Passed, on a host that cannot switch themes.
- `v2/evidence/V2-006.md` still says Mac not tested and 99 tests, and the PR #66 title says 99/99. Those are Rahil's records and were not edited.

## Publication note (2026-11-02)

The Mac output originally stopped while the branch was local; it was subsequently published at `9b9e787e8db30ce4818bf5eae339e7113f7227ba` before this documentation-only update. The Mac MATLAB **test execution SHA remains** `bb52c0fb2a530af635ab75798f27677c3d56a3c0`, not the evidence-only later HEAD. PR #66 still requires review/merge of the stacked patch; the status and frozen science remain unchanged.

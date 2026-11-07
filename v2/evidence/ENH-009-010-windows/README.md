# ENH-009 and ENH-010: independent Windows MATLAB verification

Windows 11, MATLAB 26.2.0.3433840 (R2026b) Update 1, desktop session, clean isolated worktrees. Contribution record only: no merge, no task status change, no detector change, no study stage and no sealed TEST. The schematic and cards are illustrative, not surveyed geography. **No person has approved these visuals.** The findings below come from measurements and from Claude viewing the exports.

| SHA | Tree | Focused tests | Result |
|---|---|---|---|
| `d960c40645a89301a57d1033ce29d001585be765` | #95 ENH-009 | ENH-009 6 | **PASS 6/6** |
| `fe74bce193be564bddc87489978cbb51fe84587a` | #98 ENH-010, as submitted | ENH-009 6, ENH-010 5 | **PASS 11/11, visual defect found** |
| `be0eafdb6f8bea42555146afd0f8fe4b6b503c27` | Fix, first attempt | ENH-009 6, ENH-010 6 | FAIL 11/12: mistake in the new test, kept on record |
| `62fd67cfbeb094301f3e868d462317ee7c58b7ea` | #98 after fix | ENH-009 6, ENH-010 6 | **PASS 12/12** |

## Checks at `62fd67c`

| Check | Result |
|---|---|
| Three-stage walk: next, bounded end, back, reset | PASS |
| Asset not requested, missing, corrupt, valid unapproved PNG, folder path | PASS: schematic drawn, 0 images, file unchanged |
| 60 repeated cycles of the schematic and all three cards | PASS: 0 figures and 0 timers left |
| Network and imagery functions replaced by blocking stubs | PASS: 0 calls |
| Established non-local TCP connections of the MATLAB process | 0 before, 0 after |
| OS network-denied run | **NOT RUN, INCOMPLETE** |
| Checkcode | 0 on source files; stale-suppression messages only in the two test files |

Rendering one schematic with `drawnow` and close had a median of about 1 s in this session, with a worst case of 2.7 s. This is a diagnostic number from a session with other work, not a startup measurement.

## Defect fixed

ENH-010 heading and body text had no explicit colour, so in the dark theme they turned light on the fixed light card: contrast 1.15:1, almost unreadable (`enh010_fe74bce_ENH010_CITY_CONTEXT_dark.png`). The colour is now explicit, contrast is 13.05:1, and a new test covers it. ENH-010 now has six focused tests.

## Visual issues left open

- Schematic footer text sits on the bottom border of the card, in both themes.
- The schematic banner nearly fills the export width.
- The diagonal path runs under generic building shapes. This is acceptable for a diagram, but a person should judge it.
- `info.buildings` and the code name `buildings` read as real structures, while the document says generic rectangles.
- These exports use `theme(f, ...)` on the figure. The Mac has not been checked at these SHAs.

## Limits of the tests

- The source-text guards only search for named calls. The stubs cover named functions only.
- The focused tests need `addpath('v2/enhancements')` first, as the documents state.
- `theme` needs a release that supports it.

Files: `*_results.txt`, the exports `enh010_62fd67c_*.png`, and `verify_enh.m`.

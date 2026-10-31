# Phase-1 Primary-Source Verification

**Audit outcome (31 October 2026): VERIFIED for title, four objectives and five problem-statement bullets.** This supersedes the initial foundation-stage warning that the presentation was unavailable. The source file was recovered from the project owner's earlier ChatGPT project files, read as the original PowerPoint, and compared against `PHASE1_BASELINE.md`. The presentation binary is **not** in this public repository; the source fingerprint below enables the team to match its private copy without publishing student identifiers.

## Primary artifact provenance

| Field | Verified value |
|---|---|
| Source filename | `Review1Phase1.pptx` |
| Format | PPTX |
| Slides | 9 |
| File size | 1,338,001 bytes |
| SHA-256 | `620eed853f5b7e807e3290d69b5c92485368a0e48d6985a9061b4b3648ddf236` |
| Source access | Prior project file provided by user; recovered in current MG-001 audit |
| Authoritative excerpt | Slide 3 (title and objectives); slide 4 (problem statement) |
| Comparison method | Read original PPTX text layer and compare with frozen GitHub transcription after normalizing slide line wraps/whitespace; no paraphrasing or OCR |
| Audit date | 2026-10-31 |
| Auditor | Shabaz documentation workstream, assisted by ChatGPT; final academic sign-off remains with the project guide |

## Item-by-item result

- **Title** on slide 3: exact wording matches `PHASE1_BASELINE.md` after joining wrapped lines.
- **Original objectives O1, O2, O3, O4**, slide 3: **4/4 MATCH**; no semantic rewrites or altered claims in the frozen baseline.
- **Original problem-statement bullets PS1–PS5**, slide 4: **5/5 MATCH**; whitespace and slide formatting are ignored, substantive wording is unchanged.
- The presentation's fifth slide lists six historical literature-survey entries with generic author labels; these are **not individually authenticated papers**. Their inclusion on an original slide is verified, but the bibliographic authenticity of each entry is **not**. Do not cite them as real publications without a publisher/DOI cross-check.
- Slides 6–9 contain methodology/system-design/progress/conclusion headings and may include diagrams or other graphic content. This MG-001 audit covers the **specified title/objectives/problem text and the existence of slide-5 literature rows**, not a formal design or diagram reconstruction audit.

## Academic change-control decision

The original objective O2 explicitly describes accurate buried/subsurface detection using a metal detector coil and thermal camera. Keep that text verbatim as the **historical target**, while separately disclosing that the approved implementation is a **MATLAB/Simulink research simulation**. Do not interpret synthetic performance as evidence of real airborne buried-mine detection, or assert replacement of physical mine-clearance practices.

The master brief, requirements, acceptance matrix, and report should distinguish: original objective, simulation test, evidence status, and unresolved field feasibility. Later requirement changes require the college guide's approval and a documented version record; not a stealth rewrite.

## Remaining scope outside this provenance check

- Written guide acceptance of the simulation switch and all technical limits is recorded as **team-reported** in the existing decision log; no signed approval artefact is in this repository.
- Slide 5 placeholder literature rows remain historically intact but **unverified as actual articles**.
- Scientific performance, MATLAB implementation and sample datasets remain separate engineering tasks.
- This file is an **audit record** of the recovered source; the original private PowerPoint is not redistributed.

See: `tasks/evidence/MG-001.md`, `docs/LITERATURE_REVIEW.md`, `docs/RESEARCH_PLAN.md` and `docs/PHASE1_BASELINE.md`.

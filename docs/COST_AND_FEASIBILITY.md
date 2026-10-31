# Cost Change, Simulation Feasibility and Boundaries

## Original practical challenge
The earlier MineGuard advanced hardware BOM considered Raspberry Pi capture, quality RGB imaging, FLIR-based thermal imaging, LiDAR, power, storage and mounting. The physical implementation was estimated at **above ₹1 lakh** depending on sourcing and contingencies. These were candidate research prices, not proof of purchase or flight compatibility. The guide recommended MATLAB simulation instead.

## Approved academic implementation switch
| Dimension | Earlier candidate | Current design |
|---|---|---|
| Goal/problem | Landmine risk, automated survey, geo-location, remote observation | **UNCHANGED** |
| Objectives | Original four Phase-1 statements | **UNCHANGED** |
| Platform | UAV plus sensors to be purchased/integrated | MATLAB / Simulink virtual UAV and synthetic sensor models |
| Thermal sensor | Physical camera | Mathematical response and optional correctly licensed data |
| Metal sensing | Physical coil with severe standoff challenges | Mathematical constrained EM response, feasibility limitations |
| Navigation | Physical FC/GCS | Virtual grid route and optional PPO |
| Mapping | Physical GPS/telemetry | Simulated pose, virtual geotags and mission-control app |
| Proof | Would require bench/field validation | Reproducible *simulation* results only |
| Expense | Candidate BOM >₹1 lakh | Avoids additional major hardware; student MATLAB licence entitlements need verification |

## No invented savings
This does **not** assert 'zero project cost': student software entitlements, computer time, internet and Render/GitHub usage all have practical constraints. Do not claim a precise rupee saving without a documented side-by-side budget and evidence. Render static-site public free tier is described at https://render.com/docs/static-sites; check actual account limits.

## Feasibility gate
Simulation can demonstrate algorithms and expose infeasible assumptions. It cannot validate a physically unrealistic coil detection range by giving that coil a high synthetic score. A failed high-altitude response is a scientifically honest result, not a programming failure.

## Future physical validation plan (not current work)
If guide later requests hardware, test with harmless inert surrogates in safe controlled settings, document approvals/legal constraints, start with standoff/soil/camera calibration and measured power/payload, and never perform actual minefield clearance.

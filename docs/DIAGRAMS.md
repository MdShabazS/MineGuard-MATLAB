# Visual System Diagrams (Source-of-Truth Design Draft)
**All diagrams represent proposed architecture, not measured operation.** GitHub Markdown supports Mermaid on github.com.

## 1. Functional system
```mermaid
flowchart TD
  A["Scenario config + seed"] --> B["Virtual terrain, soil & target generator"]
  B --> C["Fixed grid route / planned PPO"]
  C --> D["Simulated UAV pose and virtual GPS"]
  B --> E["Physics-inspired thermal forward model"]
  B --> F["Distance-limited EM/coil forward model"]
  D --> E
  D --> F
  E --> G["Timestamp alignment and measurement validity"]
  F --> G
  G --> H["Thresholds + trained detector (if trained)"]
  H --> I["Fusion + estimated confidence"]
  I --> J["Suspected anomaly location and uncertainty"]
  D --> K["MATLAB mission-control app"]
  J --> K
  B -. "Evaluation-only ground truth" .-> L["Metrics and held-out validation"]
  J --> L
  K --> M["Reproducible evidence export"]
```

## 2. Two-person workflow dependencies
```mermaid
flowchart LR
  M0["MG-000 docs Shabaz"] --> M1["MG-001 research Shabaz"]
  M2["MG-002 env Rahil"] --> M3["MG-003 contracts Shabaz"]
  M1 --> M3
  M3 --> M4["MG-004 scenario Rahil"]
  M3 --> M6["MG-006 sensor spec Shabaz"]
  M4 --> M5["MG-005 grid Rahil"]
  M4 --> M7["MG-007 sensors Rahil"]
  M6 --> M7
  M7 --> M9["MG-009 fusion Rahil"]
  M5 --> M13["MG-013 PPO Rahil"]
  M9 --> M11["MG-011 GUI Rahil"]
  M5 --> M11
  M11 --> M15["MG-015 integration Rahil"]
  M13 --> M15
  M15 --> M16["MG-016 QA Shabaz"]
```
**Abbreviated view only:** additional edges and tasks in `tasks/manifest.json` are authoritative.

## 3. Verified status contract
```mermaid
flowchart LR
  A["GitHub main manifest & status"] --> B["Guide portal read-only"]
  C["Reviewed task PR"] --> D{"CI and human review pass?"}
  D -- No --> E["Remain pending/block"]
  D -- Yes --> F["Merge to main"]
  F --> A
  G["Actual MATLAB executed log"] --> C
  H["Static Node CI"] --> D
```

## 4. Truth separation
```mermaid
flowchart TD
  T["Hidden scenario target truth"] --> S["Forward models: thermal / EM"]
  S --> O["Observable sensor samples only"]
  O --> D["Detector / fusion"]
  D --> P["Predicted suspected anomalies"]
  P --> V["Evaluator"]
  T --> V
  V --> R["Metrics on synthetic held-out scenarios"]
```
The truth must **not** enter detector input or PPO observation/reward.

## 5. UI architecture
```text
MATLAB App Designer (research simulator):
Mission controls | 3D/2D view | Virtual telemetry | Thermal/EM sample graph
Suspected anomaly map | Confidence/uncertainty | Baseline-PPO comparison | Export

Render Static Site (academic oversight only):
Task status from main | Dependency blockers | Member ownership | Work journal
PR + CI feeds | Real evidence links | Date/deadline and no fabricated progress
```

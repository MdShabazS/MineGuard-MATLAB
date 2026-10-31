# MATLAB / Claude Code Environment Verification

**Current:** Rahil has installed MATLAB Desktop on Windows. Student licence is available; actual active licence and version/toolboxes NOT YET VERIFIED. Shabaz may test on Mac after toolboxes are confirmed.

## MG-002 acceptance sequence (Rahil)
1. Open MATLAB Desktop, confirm activation without publishing licence IDs, account names or machine identifiers.
2. In Command Window run `ver` and `matlab.addons.installedAddons`. Save a **sanitized** textual summary of release and toolbox names/versions to `tasks/evidence/MG-002.md` (no serial/licence credentials).
3. Check `which uavScenario`, `which rlPPOAgent`, `which sim`, `which uifigure`. Document missing functions and fallback paths, not imaginary installed products.
4. Install/configure official MATLAB Agentic Toolkit following MathWorks instructions; verify actual Claude Code ↔ MATLAB MCP ability by executing a harmless scalar MATLAB script. Record command, result and redacted screenshot or log.
5. Verify basic Simulink model can open/run only if Simulink installed. Otherwise defer full Simulink features and document.
6. Record Windows MATLAB execution proof; Mac cross-platform proof is separate and optional until verified.

## Official refs
- https://www.mathworks.com/products/matlab-agentic-toolkit.html
- https://www.mathworks.com/help/uav/
- https://www.mathworks.com/help/reinforcement-learning/
- https://www.mathworks.com/help/uav/scenario-simulation.html

## Boundaries
GitHub Actions Node checks **do not run MATLAB**. MATLAB execution must be carried out on the licensed machine, with evidence committed. Agentic Toolkit supports MATLAB R2021a+, but individual functions may demand newer releases; verify each API against actual `ver` result.

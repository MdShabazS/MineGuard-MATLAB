function info = releaseInfo()
%RELEASEINFO Release identity and frozen headline results for MineGuard-MATLAB (MG-017). SIMULATION ONLY.
%   info = mineguard.releaseInfo()
%   version / tag      - release-candidate identity (the tag is only created after Shabaz authorizes it)
%   default_planner    - "grid" (fixed serpentine route); PPO is "EXPERIMENTAL" (MG-013/MG-019)
%   heldout            - the ONCE-executed MG-014 sealed TEST result (GF-025..GF-030, MG014-RUNLOCK-1),
%                        primary method weighted / single_valid, cell-level common mask. These constants
%                        are a copy for display; testMG017Release checks them against the committed CSV.
%                        They are NOT recomputed and the consumed TEST is never re-run.
%   ppo                - MG-019 preregistered comparison headline (8 grid-feasible fresh scenarios).
%   statement          - one-line scope statement for consoles, dashboards and release notes.
info.name = "MineGuard-MATLAB";
info.version = "1.0.0-rc.1";
info.tag = "v1.0.0-rc.1";
info.default_planner = "grid";
info.ppo_status = "EXPERIMENTAL";
info.heldout = struct('source', "tasks/evidence/MG-015/MG-015-test-comparison.csv", ...
    'families', "GF-025..GF-030", 'runlock', "MG014-RUNLOCK-1", 'method', "weighted", 'rule', "single_valid", ...
    'tp', 0, 'fp', 26, 'tn', 470, 'fn', 4, 'executed_utc', "2026-10-31 18:23", ...
    'verdict', "NEGATIVE: no method is useful at the locked settings; weighted fusion found 0 of 4 positive cells");
info.ppo = struct('source', "tasks/evidence/MG-019/MG-019-summary.json", 'feasible_pairs', 8, 'ppo_wins', 0, ...
    'verdict', "PPO lost all 8 grid-feasible paired missions; fixed grid stays the default");
info.statement = "SIMULATION ONLY: synthetic sensors and targets; outputs are SUSPECTED anomalies, not real landmine detection, clearance or field safety.";
end

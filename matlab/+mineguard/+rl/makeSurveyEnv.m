function [env, sampler] = makeSurveyEnv(grids, cfg, seed)
%MAKESURVEYENV MATLAB rlFunctionEnv for coverage-only PPO training (MG-013).
%   [env, sampler] = mineguard.rl.makeSurveyEnv(grids, cfg, seed)
%   grids - a cell array of buildSurveyGrid outputs. All must have the same N, because the
%           policy has fixed dimensions. They should be TRAIN-split scenarios only.
%   Observation spec: rlNumericSpec([2N+5 1], LowerLimit 0, UpperLimit 1).
%   Action spec:      rlFiniteSetSpec(1:N).
%   Each reset samples a TRAIN scenario with the seeded ScenarioSampler. The step function
%   wraps stepSurvey; LoggedSignals carries the state and the scenario index.
N = grids{1}.N;
if any(cellfun(@(g) g.N, grids) ~= N)
    error('mineguard:InvalidScenario', 'MineGuard RL: all scenarios for one policy need the same N.');
end
obsInfo = rlNumericSpec([2*N+5 1], 'LowerLimit', 0, 'UpperLimit', 1);
obsInfo.Name = "mg013_" + cfg.layout_id;
actInfo = rlFiniteSetSpec(1:N);
actInfo.Name = "survey_cell_id";
sampler = mineguard.rl.ScenarioSampler(numel(grids), seed);
env = rlFunctionEnv(obsInfo, actInfo, @stepFcn, @resetFcn);

    function [obs, ls] = resetFcn()
        k = sampler.next();
        S = mineguard.rl.resetSurvey(grids{k}, cfg);
        ls = struct('S', S, 'k', k);
        obs = mineguard.rl.observationVector(S, grids{k}, cfg);
    end

    function [obs, r, done, ls] = stepFcn(action, ls)
        G = grids{ls.k};
        [ls.S, r] = mineguard.rl.stepSurvey(ls.S, action, G, cfg);
        obs = mineguard.rl.observationVector(ls.S, G, cfg);
        done = ls.S.done;
    end
end

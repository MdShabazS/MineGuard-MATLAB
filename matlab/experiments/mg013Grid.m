function [G, c] = mg013Grid(seed, scenarioId)
%MG013GRID Build the MG-013 survey grid for one scenario from public geometry only.
%   The MG-004 generator is called with zero objects; its (empty) truth output is discarded at once.
c = mg013ScenarioConfig(seed, scenarioId);
[g, ~] = mineguard.scenario.generateScenario(c);
nav = mineguard.navigation.navigationConfigFromExperiment(c);
G = mineguard.rl.buildSurveyGrid(nav, g);
end

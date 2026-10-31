classdef ScenarioSampler < handle
    %SCENARIOSAMPLER Seeded scenario picker for the rlFunctionEnv reset function (MG-013).
    %   Uses a local RandStream; the global RNG is not used for scenario selection.
    properties
        Stream
        Count
        Last = 0
    end
    methods
        function obj = ScenarioSampler(count, seed)
            obj.Count = count;
            obj.Stream = RandStream('mt19937ar', 'Seed', seed);
        end
        function k = next(obj)
            k = randi(obj.Stream, obj.Count);
            obj.Last = k;
        end
    end
end

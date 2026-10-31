function invalidScenario(fmt, varargin)
%INVALIDSCENARIO Throw the frozen mineguard:InvalidScenario error (mg-contract/1.0).
%   The message must name the offending field so the error is actionable.
throwAsCaller(MException('mineguard:InvalidScenario', ['MineGuard scenario: ' fmt], varargin{:}));
end

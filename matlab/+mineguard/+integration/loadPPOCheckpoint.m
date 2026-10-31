function policy = loadPPOCheckpoint(file, expectedSha256)
%LOADPPOCHECKPOINT Verify and load the frozen MG-013 PPO checkpoint as a selectSurveyCell policy (MG-019).
%   policy = mineguard.integration.loadPPOCheckpoint()
%   policy = mineguard.integration.loadPPOCheckpoint(file, expectedSha256)
%   Defaults: results/approved/mg013_ppo_checkpoint.mat with the approved SHA-256
%   5a0da1715a1c2f7044a3b954d8cdf5e6d234731a2f4619d82cb3ea87e875b8ad.
%   It fails safely, and never substitutes a fabricated or heuristic policy:
%     mineguard:CheckpointMissing   file absent
%     mineguard:CheckpointMismatch  SHA-256 differs (raw bytes; the checkpoint is a binary file)
%     mineguard:CheckpointInvalid   no rlPPOAgent, or specs are not 55x1 obs / 25 discrete actions
%   The returned policy has kind "ppo", deterministic inference (use_exploration=false),
%   n_cells 25, layout "cov-2N+5-v1", and the checkpoint SHA as its checksum.
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
if nargin < 1 || strlength(string(file)) == 0
    file = fullfile(root, 'results', 'approved', 'mg013_ppo_checkpoint.mat');
end
if nargin < 2
    expectedSha256 = "5a0da1715a1c2f7044a3b954d8cdf5e6d234731a2f4619d82cb3ea87e875b8ad";
end
if ~isfile(file)
    error('mineguard:CheckpointMissing', 'PPO checkpoint not found: %s. No PPO result can be produced.', file);
end
[st, out] = system(sprintf('certutil -hashfile "%s" SHA256', file));
lines = splitlines(string(out));
if st ~= 0 || numel(lines) < 2
    error('mineguard:CheckpointMismatch', 'Could not hash the PPO checkpoint %s.', file);
end
sha = lower(erase(strtrim(lines(2)), " "));
if sha ~= string(expectedSha256)
    error('mineguard:CheckpointMismatch', 'PPO checkpoint SHA-256 %s does not match the approved %s.', sha, expectedSha256);
end
S = load(file);
if ~isfield(S, 'saveAgent') || ~isa(S.saveAgent, 'rl.agent.rlPPOAgent')
    error('mineguard:CheckpointInvalid', 'Checkpoint does not contain the expected rlPPOAgent "saveAgent".');
end
agent = S.saveAgent;
oi = getObservationInfo(agent); ai = getActionInfo(agent);
if ~isequal(oi.Dimension, [55 1]) || ~isequal(double(ai.Elements(:))', 1:25)
    error('mineguard:CheckpointInvalid', 'Checkpoint specs are obs %s / %d actions; expected 55x1 / 25.', mat2str(oi.Dimension), numel(ai.Elements));
end
agent.UseExplorationPolicy = false;
policy = struct('kind', "ppo", 'version', "mg013-ppo-1.0", 'layout_id', "cov-2N+5-v1", 'n_cells', 25, ...
    'agent', agent, 'checksum', sha, 'training_split', "MG013-SPLIT-1/train", 'use_exploration', false);
end

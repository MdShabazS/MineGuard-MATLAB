classdef RunController < handle
    %RUNCONTROLLER Runs one LOCKED V2.1 scenario in the V2 dashboard and evaluates it after the run (V21-006). SIMULATION ONLY.
    %   ctl = mgv21.ui.RunController(pub, world, priv)             opens the V2 mission-control dashboard
    %   ctl = mgv21.ui.RunController(pub, world, priv, Name=Value) RealTime, Visible, MaxTicksPerRun, ExportRoot
    %   ctl.App              the mgv2.ui.MissionControlApp (public data only)
    %   ctl.LastEvaluation   DemoEvaluation of the last ended live run (mg-v21-eval/1.0), [] before
    %   ctl.Views            evaluation windows opened so far
    %
    %   Contract mg-v21-contract/1.0 §5:
    %   - RUN: the session gets pub.scene_config, pub.mission, the environment of pub.environment_mode, and
    %     SurfaceFeatures=priv.surface_features for the sensors only. The detector, map and navigation never get priv.
    %   - AFTER THE RUN: on a terminal phase, the event list is frozen and evaluated against priv.truth.
    %   This object is the only holder of priv while the run exists; priv is a private property, never displayed.
    %   A replay is never evaluated (MissionControlApp.OnRunEnded fires for live runs only).

    properties (SetAccess = private)
        App = []
        Pub
        LastEvaluation = []
        Views = {}
    end
    properties (Access = private)
        Priv              % PRIVATE scenario (mg-v21-private/1.0): truth and surface features
        Salt              % PRIVATE random salt of the export commitment (F1, #132)
        World
    end

    methods
        function ctl = RunController(pub, world, priv, opts)
            arguments
                pub struct
                world struct
                priv struct
                opts.RealTime (1,1) double = 1
                opts.Visible (1,1) string = "on"
                opts.MaxTicksPerRun (1,1) double = inf
                opts.ExportRoot (1,1) string = mgv2.ui.MissionControlApp.defaultExportRoot()
            end
            mgv21.scenario.assertPublic(pub, "pub");
            if string(priv.schema_version) ~= mgv21.contract().schemas.private
                error('mgv21:InvalidScenario', 'priv must be a locked mg-v21-private/1.0 scenario.');
            end
            if mgv2.run.digest(world) ~= mgv2.run.digest(mgv21.scenario.buildWorld(pub))
                error('mgv21:InvalidScenario', 'The world is not the one pub.scene_config builds.');
            end
            ctl.Pub = pub; ctl.World = world; ctl.Priv = priv; ctl.Salt = mgv2.ui.MissionSession.newSalt();
            ctl.App = mgv2.ui.MissionControlApp('MissionConfig', pub.mission, 'SceneConfig', pub.scene_config, ...
                'Environment', mgv2.sensors.defaultEnvironment(pub.environment_mode), 'SurfaceFeatures', priv.surface_features, 'CommitmentSalt', ctl.Salt, ...
                'AnomalySource', mgv2.bridge.V2006AnomalySource(), 'RealTime', opts.RealTime, 'Visible', opts.Visible, ...
                'MaxTicksPerRun', opts.MaxTicksPerRun, 'ExportRoot', opts.ExportRoot);
            ctl.App.OnRunEnded = @(app) ctl.evaluate(app);
        end

        function f = savePrivateEvaluation(ctl, folder)
            %SAVEPRIVATEEVALUATION V21-007 decision: keep the revealed targets for a guide's post-run review, on request only.
            %   f = ctl.savePrivateEvaluation(folder)   writes <run_id>_g<generation>_PRIVATE_EVALUATION.mat in folder
            %   It is a separate, separately named private file: never inside an operator package (a package folder is
            %   refused) and never written automatically. It holds the last DemoEvaluation, the private truth, the
            %   public scenario and the SHA-256 commitment that links it to the run's package. Requires an ended live run.
            if isempty(ctl.LastEvaluation), error('mgv21:EvaluationTooEarly', 'No ended run has been evaluated yet.'); end
            folder = string(folder);
            if isfile(fullfile(folder, "files.sha256")) || isfile(fullfile(folder, "manifest.json"))
                error('mgv21:PrivateFileRefused', 'A private evaluation file is never written inside an operator package.');
            end
            if ~isfolder(folder), mkdir(folder); end
            s = ctl.App.Session; ctx = s.evidenceContext();
            f = fullfile(folder, sprintf('%s_g%d_PRIVATE_EVALUATION.mat', regexprep(char(ctx.run_id), '[^A-Za-z0-9_-]', '_'), ctx.generation));
            if isfile(f), error('mgv21:PrivateFileRefused', 'The private evaluation file already exists; it is never overwritten.'); end
            private_evaluation = struct('notice', "PRIVATE - post-run evaluation with revealed synthetic targets. Not part of the operator package. " + ...
                mgv21.contract().eval_label, 'evaluation', ctl.LastEvaluation, 'truth', ctl.Priv.truth, 'pub', ctl.Pub, ...
                'run_id', ctx.run_id, 'generation', ctx.generation, 'features_sha256', s.privateCommitment().features_sha256, ...
                'surface_features', ctl.Priv.surface_features, 'commitment_salt', ctl.Salt);   % enough to reproduce the run
            save(f, 'private_evaluation'); f = string(f);
        end

        function delete(ctl)
            for k = 1:numel(ctl.Views), if isvalid(ctl.Views{k}), delete(ctl.Views{k}); end, end
            if ~isempty(ctl.App) && isvalid(ctl.App), delete(ctl.App); end
            ctl.Priv = []; ctl.Salt = [];
        end
    end

    methods (Access = private)
        function evaluate(ctl, app)
            %EVALUATE Freeze the final events of the ended live run, evaluate them privately, show the result.
            s = app.Session; v = s.view();
            events = v.events;                                   % a copy: the frozen final event list
            poses = s.Engine.poseLog();
            R = mgv21.evaluation.evaluateRun(events, ctl.Priv.truth, s.Engine.Phase);
            ctl.LastEvaluation = R;
            ctl.Views{end+1} = mgv21.ui.EvaluationView(ctl.World, ctl.Pub, poses, events, ctl.Priv.truth, R, ...
                'Visible', string(app.Figure.Visible), 'RunId', string(v.mission.run_id));
        end
    end
end

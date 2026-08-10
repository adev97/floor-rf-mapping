function trials = trialStruct_RFmapFloorBubble(stimType, table)

% =============================================================
% trialStruct_RFmapFloorBubble
%
% Creates a trial structure for the fan-shaped receptive field
% mapping stimulus.
%
% Each non-blank trial corresponds to one 10-degree angular
% sector.
%
% Example:
%
% Sector_Angle = -70
% Sector_Width = 10
%
% means the stimulus occupies:
%
% -70 degrees --> -60 degrees
%
% =============================================================


%% ============================================================
% READ TABLE
% ============================================================

params = struct();
constants = struct();

tableStrings = cell(size(table,1),1);
fieldname = cell(size(table,1),1);


for i = 1:size(table,1)

    % ---------------------------------------------------------
    % Construct field name
    % ---------------------------------------------------------

    tableStrings{i} = strtok(table{i,1}, '(');
    tableStrings{i} = strtrim(tableStrings{i});

    fieldname{i} = strrep(tableStrings{i}, ' ', '_');


    % ---------------------------------------------------------
    % CONSTANT STRING
    % ---------------------------------------------------------

    if ischar(table{i,2})

        constants.(fieldname{i}) = ...
            {table{i,2:end}};


    % ---------------------------------------------------------
    % TIMING
    % ---------------------------------------------------------

    elseif strcmp(fieldname{i}, 'Timing')

        constants.(fieldname{i}) = ...
            horzcat(table{i,2:4});


    % ---------------------------------------------------------
    % ROWS WITH ONLY ONE VALUE
    % ---------------------------------------------------------

    elseif numel(cell2mat(table(i,2:end))) <= 2

        constants.(fieldname{i}) = ...
            horzcat(table{i,2:4});


    % ---------------------------------------------------------
    % PARAMETER TO VARY
    % ---------------------------------------------------------

    elseif numel(cell2mat(table(i,2:end))) > 2 && ...
            table{i,2} ~= table{i,4}

        params.(fieldname{i}) = ...
            table{i,2}:table{i,3}:table{i,4};


    % ---------------------------------------------------------
    % CONSTANT NUMERIC VALUE
    % ---------------------------------------------------------

    elseif numel(cell2mat(table(i,2:end))) > 2 && ...
            table{i,2} == table{i,4}

        constants.(fieldname{i}) = ...
            table{i,2};

    end

end


%% ============================================================
% CONSTRUCT PARAMETER COMBINATIONS
% ============================================================

if ~isempty(fieldnames(params))

    params_fields = fieldnames(params);

    params_arrays = cell(numel(params_fields),1);

    for i = 1:numel(params_fields)

        params_arrays{i} = ...
            params.(params_fields{i});

    end


    % ---------------------------------------------------------
    % Only one varying parameter
    % ---------------------------------------------------------

    if numel(params_fields) == 1

        trial_arrays = ...
            params_arrays{1}(:);


    % ---------------------------------------------------------
    % Multiple varying parameters
    % ---------------------------------------------------------

    else

        p = 1:numel(params_fields);

        ip = p(end:-1:1);

        gridArrays = cell(size(params_arrays));

        [gridArrays{ip}] = ...
            ndgrid(params_arrays{ip});

        trial_arrays = ...
            reshape( ...
            cat(numel(p)+1, gridArrays{:}), ...
            [], numel(p));

    end

else

    trial_arrays = [];

end


%% ============================================================
% ADD BLANK TRIAL
% ============================================================

if isfield(constants,'Blank') && ...
        constants.Blank == 1

    trial_arrays(end+1,:) = NaN;

end


%% ============================================================
% RANDOMIZE / REPEAT
% ============================================================

trial_arrays_cat = [];


for repeat = 1:(constants.Repeats + 1)

    % ---------------------------------------------------------
    % RANDOMIZE
    % ---------------------------------------------------------

    if constants.Randomize == 1

        % -----------------------------------------------------
        % For RF mapping, randomize the angular sectors.
        %
        % We generate a fresh permutation on every repeat.
        % -----------------------------------------------------

        nTrials = size(trial_arrays,1);

        randIndex = randperm(nTrials);

        randomizedTrials = ...
            trial_arrays(randIndex,:);

    else

        randomizedTrials = trial_arrays;

    end


    % ---------------------------------------------------------
    % Append this repeat
    % ---------------------------------------------------------

    trial_arrays_cat = ...
        vertcat(trial_arrays_cat, randomizedTrials);

end


trial_arrays = trial_arrays_cat;


%% ============================================================
% IDENTIFY BLANK TRIALS
% ============================================================

if ~isempty(trial_arrays)

    blankTrials = ...
        find(isnan(trial_arrays(:,1)));

else

    blankTrials = [];

end


%% ============================================================
% CONVERT TO STRUCTURE
% ============================================================

if ~isempty(trial_arrays)

    trialCell = num2cell(trial_arrays);

    trials = cell2struct( ...
        trialCell, ...
        params_fields, ...
        2);

else

    trials = struct();

end


%% ============================================================
% ADD CONSTANT PARAMETERS
% ============================================================

constant_fields = fieldnames(constants);


for i = 1:numel(constant_fields)

    [trials(:).(constant_fields{i})] = ...
        deal(constants.(constant_fields{i}));

end


%% ============================================================
% ADD STIMULUS TYPE
% ============================================================

[trials(:).Stimulus_Type] = ...
    deal(stimType);


%% ============================================================
% LABEL BLANK TRIALS
% ============================================================

if ~isempty(blankTrials)

    [trials(blankTrials).Stimulus_Type] = ...
        deal('Blank');

end


%% ============================================================
% FIELD ORDER
% ============================================================

desiredOrder = {'Stimulus_Type'};

for i = 1:numel(fieldname)

    if isfield(trials, fieldname{i})

        desiredOrder{end+1} = fieldname{i};

    end

end

trials = orderfields(trials, desiredOrder);


end


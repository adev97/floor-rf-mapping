function RFmapping_core_fm(params)
%RFMAPPING_CORE_FM Free-moving, head-centric receptive-field analysis.
%
% The caller supplies every session path explicitly.  The output keeps the
% .rfmap extension used by the existing workflow, but is a self-describing
% HDF5 file because the fixed 1-degree spherical map is too large for the
% legacy JSON representation.

    validateParameters(params);
    calibrationText = fileread(params.calibPath);
    calibration = jsondecode(calibrationText);
    geometry = validateCalibration(calibration);

    [motiveFrame, motiveRotationDeg, motivePositionMm] = readMotiveRigidBody( ...
        params.motiveCsvPath, calibration.rigid_body_name);
    cameraFrameTimeSec = double(readNPY(params.cameraFrameTimesPath));
    cameraFrameTimeSec = cameraFrameTimeSec(:);
    assert(all(isfinite(cameraFrameTimeSec)) && ...
        all(diff(cameraFrameTimeSec) > 0), ...
        'camera_frame_times.npy must contain finite, strictly increasing times.');
    assert(numel(cameraFrameTimeSec) == numel(motiveFrame), ...
        'camera_frame_times.npy must exactly match the Motive CSV frame count.');

    trialData = load(params.stimulusMatPath, 'trials');
    trials = trialData.trials;
    trialBoundarySec = double(readNPY(params.onListTimesPath));
    trialBoundarySec = trialBoundarySec(:);
    assert(numel(trialBoundarySec) == numel(trials) + 1, ...
        'on_list_times.npy must contain one more boundary than the number of stimulus trials.');
    assert(all(diff(trialBoundarySec) > 0), 'Trial boundaries must be strictly increasing.');

    azimuthEdgesDeg = double(params.azimuthEdgesDeg(:).');
    elevationEdgesDeg = double(params.elevationEdgesDeg(:).');
    assert(all(abs(diff(azimuthEdgesDeg) - 1) < 1e-12), ...
        'FM azimuth edges must use fixed 1-degree bins.');
    assert(all(abs(diff(elevationEdgesDeg) - 1) < 1e-12), ...
        'FM elevation edges must use fixed 1-degree bins.');
    azimuthCentersDeg = (azimuthEdgesDeg(1:end-1) + azimuthEdgesDeg(2:end)) / 2;
    elevationCentersDeg = (elevationEdgesDeg(1:end-1) + elevationEdgesDeg(2:end)) / 2;

    timeSpanSec = diff(params.VSTimeWindow);
    timeBinCountExact = timeSpanSec / params.timeBinSec;
    assert(abs(timeBinCountExact - round(timeBinCountExact)) < 1e-12, ...
        'VSTimeWindow must contain an integer number of timeBinSec bins.');
    timeBinCount = round(timeBinCountExact);
    timeEdgesSec = params.VSTimeWindow(1) + (0:timeBinCount) * params.timeBinSec;

    [trialExposure, trialQa] = buildTrialExposure( ...
        trials, trialBoundarySec, cameraFrameTimeSec, motiveRotationDeg, ...
        motivePositionMm, geometry, params.sourceScreenSizePix, ...
        azimuthEdgesDeg, elevationEdgesDeg);

    spikeTimesSec = double(readNPY(params.spikeTimePath));
    spikeTimesSec = spikeTimesSec(:);
    spikeClusters = double(readNPY(params.spikeClusterPath));
    spikeClusters = spikeClusters(:);
    assert(numel(spikeTimesSec) == numel(spikeClusters), ...
        'Spike-time and spike-cluster arrays must have equal lengths.');
    unitPool = readGoodUnits(params.clusterInfoPath, spikeClusters);

    writeRfmap(params, calibrationText, motiveFrame, cameraFrameTimeSec, ...
        trialBoundarySec, trials, ...
        trialExposure, trialQa, unitPool, spikeTimesSec, spikeClusters, ...
        azimuthCentersDeg, elevationCentersDeg, timeEdgesSec);
end

function validateParameters(params)
    requiredFields = { ...
        'calibPath', 'motiveCsvPath', 'cameraFrameTimesPath', 'onListTimesPath', ...
        'stimulusMatPath', 'spikeTimePath', 'spikeClusterPath', ...
        'clusterInfoPath', 'rfmapOutputPath', 'VSTimeWindow', 'timeBinSec', ...
        'azimuthEdgesDeg', 'elevationEdgesDeg', 'sourceScreenSizePix'};
    for fieldIndex = 1:numel(requiredFields)
        assert(isfield(params, requiredFields{fieldIndex}), ...
            'Missing required parameter: %s', requiredFields{fieldIndex});
    end
    inputPaths = {params.calibPath, params.motiveCsvPath, ...
        params.cameraFrameTimesPath, ...
        params.onListTimesPath, params.stimulusMatPath, params.spikeTimePath, ...
        params.spikeClusterPath, params.clusterInfoPath};
    for pathIndex = 1:numel(inputPaths)
        assert(exist(inputPaths{pathIndex}, 'file') == 2, ...
            'Required input file does not exist: %s', inputPaths{pathIndex});
    end
    assert(exist(params.rfmapOutputPath, 'file') ~= 2, ...
        'Refusing to overwrite an existing RF map: %s', params.rfmapOutputPath);
    assert(isequal(size(params.VSTimeWindow), [1 2]), ...
        'VSTimeWindow must be a two-element row vector.');
    assert(params.VSTimeWindow(2) > params.VSTimeWindow(1), ...
        'VSTimeWindow must be increasing.');
    assert(params.timeBinSec > 0, 'timeBinSec must be positive.');
    assert(isequal(double(params.sourceScreenSizePix), [960 240]), ...
        'The FM stimulus source texture must be 960 by 240 pixels.');
end

function geometry = validateCalibration(calibration)
    assert(strcmp(calibration.schema_version, 'rf-calib-1.0'), ...
        'Unsupported .calib schema_version.');
    assert(strcmp(calibration.world_up_axis, 'Z'), ...
        'RFmapping_core_fm requires a Z-up calibration.');
    assert(strcmp(calibration.head.viewpoint_model, 'rigid_body_origin'), ...
        'FM viewpoint_model must be rigid_body_origin.');
    eyeOffset = double(calibration.head.eye_offset_local_mm(:));
    assert(isequal(eyeOffset, zeros(3, 1)), ...
        'The fixed FM viewpoint model requires eye_offset_local_mm = [0 0 0].');

    geometry.bottomCenterMm = double(calibration.screen.bottom_center_xyz_mm(:));
    geometry.axisUnit = normalizedVector(calibration.screen.axis_unit, 'screen.axis_unit');
    geometry.radiusMm = double(calibration.screen.radius_mm);
    geometry.heightMm = double(calibration.screen.height_mm);
    geometry.zeroDirectionUnit = normalizedVector( ...
        calibration.screen.zero_direction_unit, 'screen.zero_direction_unit');
    geometry.zeroDirectionUnit = normalizedVector( ...
        geometry.zeroDirectionUnit - geometry.axisUnit * ...
        dot(geometry.axisUnit, geometry.zeroDirectionUnit), ...
        'screen.zero_direction_unit projected into the screen plane');
    geometry.xDirectionSign = double(calibration.screen.x_direction_sign);
    geometry.forwardLocalUnit = normalizedVector( ...
        calibration.head.forward_local_unit, 'head.forward_local_unit');
    upLocal = normalizedVector(calibration.head.up_local_unit, 'head.up_local_unit');
    geometry.upLocalUnit = normalizedVector( ...
        upLocal - geometry.forwardLocalUnit * dot(geometry.forwardLocalUnit, upLocal), ...
        'head.up_local_unit orthogonalized to forward');

    assert(numel(geometry.bottomCenterMm) == 3, ...
        'screen.bottom_center_xyz_mm must contain three values.');
    assert(geometry.radiusMm > 0 && geometry.heightMm > 0, ...
        'Screen radius and height must be positive millimetre values.');
    assert(ismember(geometry.xDirectionSign, [-1 1]), ...
        'screen.x_direction_sign must be +1 or -1.');
    assert(dot(geometry.axisUnit, [0; 0; 1]) > 1 - 1e-9, ...
        'The current FM analysis requires the cylinder axis to point along world +Z.');
end

function vector = normalizedVector(value, label)
    vector = double(value(:));
    assert(numel(vector) == 3 && all(isfinite(vector)), ...
        '%s must contain three finite values.', label);
    vectorLength = norm(vector);
    assert(vectorLength > 0, '%s cannot be zero.', label);
    vector = vector / vectorLength;
end

function [frame, rotationDeg, positionMm] = readMotiveRigidBody(csvPath, rigidBodyName)
    fileId = fopen(csvPath, 'r');
    assert(fileId >= 0, 'Could not open the Motive CSV.');
    cleanup = onCleanup(@() fclose(fileId));
    header = cell(8, 1);
    for rowIndex = 1:8
        header{rowIndex} = fgetl(fileId);
        assert(ischar(header{rowIndex}), 'Motive CSV must contain its standard eight-row header.');
    end
    clear cleanup
    assert(contains(header{1}, 'Rotation Type,XYZ'), ...
        'Motive CSV Rotation Type must be XYZ.');
    assert(contains(header{1}, 'Length Units,Millimeters'), ...
        'Motive CSV positions must be exported in millimetres.');
    assert(contains(header{1}, 'Coordinate Space,Global'), ...
        'Motive CSV positions and rotations must be exported in Global coordinates.');
    assert(contains(header{4}, [',' char(rigidBodyName) ',']), ...
        'The .calib rigid_body_name is not present in the Motive CSV header.');

    numeric = readmatrix(csvPath, 'NumHeaderLines', 8);
    assert(size(numeric, 2) >= 8, ...
        'Motive CSV must contain Frame, Time, Rotation XYZ, and Position XYZ.');
    numeric = numeric(:, 1:8);
    frame = numeric(:, 1);
    rotationDeg = numeric(:, 3:5);
    positionMm = numeric(:, 6:8);
    assert(all(isfinite(frame)) && all(frame == round(frame)), ...
        'Motive frame numbers must be finite integers.');
    assert(all(diff(frame) == 1), 'Motive CSV frames must be consecutive.');
end

function [exposure, qa] = buildTrialExposure(trials, trialBoundarySec, ...
        cameraFrameTimeSec, rotationDeg, positionMm, geometry, sourceScreenSizePix, ...
        azimuthEdgesDeg, elevationEdgesDeg)
    trialCount = numel(trials);
    frameCount = numel(cameraFrameTimeSec);
    azimuthBinCount = numel(azimuthEdgesDeg) - 1;
    elevationBinCount = numel(elevationEdgesDeg) - 1;
    angularPixelCount = elevationBinCount * azimuthBinCount;

    frameStepSec = median(diff(cameraFrameTimeSec));
    frameSupportStartSec = cameraFrameTimeSec;
    frameSupportEndSec = [cameraFrameTimeSec(2:end); cameraFrameTimeSec(end) + frameStepSec];

    trialIndexCell = cell(trialCount, 1);
    pixelIndexCell = cell(trialCount, 1);
    exposureCell = cell(trialCount, 1);
    qa.sourcePixelCount = zeros(trialCount, 1, 'uint32');
    qa.analysisIncluded = double([trials.Square_Luminance].') == 1;
    qa.validTrackingDurationSec = zeros(trialCount, 1);
    qa.valid = false(trialCount, 1);
    qa.nearestScreenDistanceMeanMm = nan(trialCount, 1);
    qa.nearestScreenDistanceMinMm = nan(trialCount, 1);
    qa.nearestScreenDistanceMaxMm = nan(trialCount, 1);
    qa.stimulusDistanceMeanMm = nan(trialCount, 1);
    qa.stimulusDistanceMinMm = nan(trialCount, 1);
    qa.stimulusDistanceMaxMm = nan(trialCount, 1);

    frameCursor = 1;
    for trialIndex = 1:trialCount
        trialStartSec = trialBoundarySec(trialIndex);
        trialEndSec = trialBoundarySec(trialIndex + 1);
        while frameCursor <= frameCount && frameSupportEndSec(frameCursor) <= trialStartSec
            frameCursor = frameCursor + 1;
        end

        [sourceWorldMm, sourcePixelCount] = stimulusWorldPoints( ...
            trials(trialIndex), geometry, sourceScreenSizePix);
        qa.sourcePixelCount(trialIndex) = uint32(sourcePixelCount);
        localPixelIndex = zeros(0, 1);
        localExposureSec = zeros(0, 1);
        nearestDistance = zeros(0, 1);
        stimulusMeanDistance = zeros(0, 1);
        stimulusMinDistance = zeros(0, 1);
        stimulusMaxDistance = zeros(0, 1);
        distanceWeightSec = zeros(0, 1);

        frameIndex = frameCursor;
        while frameIndex <= frameCount && frameSupportStartSec(frameIndex) < trialEndSec
            overlapSec = min(trialEndSec, frameSupportEndSec(frameIndex)) - ...
                max(trialStartSec, frameSupportStartSec(frameIndex));
            poseIsValid = all(isfinite(positionMm(frameIndex, :))) && ...
                all(isfinite(rotationDeg(frameIndex, :)));
            if overlapSec > 0 && poseIsValid
                qa.validTrackingDurationSec(trialIndex) = ...
                    qa.validTrackingDurationSec(trialIndex) + overlapSec;
                rotation = motiveEulerXyzMatrix(rotationDeg(frameIndex, :));
                eyeMm = positionMm(frameIndex, :).';
                nearestDistance(end + 1, 1) = nearestCylinderDistance(eyeMm, geometry); %#ok<AGROW>
                distanceWeightSec(end + 1, 1) = overlapSec; %#ok<AGROW>

                pointDistance = vecnorm(sourceWorldMm - eyeMm.', 2, 2);
                stimulusMeanDistance(end + 1, 1) = mean(pointDistance); %#ok<AGROW>
                stimulusMinDistance(end + 1, 1) = min(pointDistance); %#ok<AGROW>
                stimulusMaxDistance(end + 1, 1) = max(pointDistance); %#ok<AGROW>

                if qa.analysisIncluded(trialIndex)
                    angularIndex = angularBinsForPose(sourceWorldMm, eyeMm, rotation, ...
                        geometry, azimuthEdgesDeg, elevationEdgesDeg);
                    localPixelIndex = [localPixelIndex; angularIndex]; %#ok<AGROW>
                    localExposureSec = [localExposureSec; ...
                        overlapSec * ones(numel(angularIndex), 1)]; %#ok<AGROW>
                end
            end
            frameIndex = frameIndex + 1;
        end

        qa.valid(trialIndex) = qa.validTrackingDurationSec(trialIndex) > 0;
        if ~isempty(localPixelIndex)
            [uniquePixelIndex, ~, groupIndex] = unique(localPixelIndex);
            summedExposureSec = accumarray(groupIndex, localExposureSec);
            trialIndexCell{trialIndex} = trialIndex * ones(numel(uniquePixelIndex), 1);
            pixelIndexCell{trialIndex} = uniquePixelIndex;
            exposureCell{trialIndex} = summedExposureSec;
        end
        if ~isempty(distanceWeightSec)
            qa.nearestScreenDistanceMeanMm(trialIndex) = ...
                sum(nearestDistance .* distanceWeightSec) / sum(distanceWeightSec);
            qa.nearestScreenDistanceMinMm(trialIndex) = min(nearestDistance);
            qa.nearestScreenDistanceMaxMm(trialIndex) = max(nearestDistance);
            qa.stimulusDistanceMeanMm(trialIndex) = ...
                sum(stimulusMeanDistance .* distanceWeightSec) / sum(distanceWeightSec);
            qa.stimulusDistanceMinMm(trialIndex) = min(stimulusMinDistance);
            qa.stimulusDistanceMaxMm(trialIndex) = max(stimulusMaxDistance);
        end
    end

    trialIndex = vertcat(trialIndexCell{:});
    pixelIndex = vertcat(pixelIndexCell{:});
    valueSec = vertcat(exposureCell{:});
    exposure.matrix = sparse(trialIndex, pixelIndex, valueSec, trialCount, angularPixelCount);
    exposure.trialIndex = trialIndex;
    exposure.pixelIndex = pixelIndex;
    exposure.valueSec = valueSec;
    exposure.sumSec = full(sum(exposure.matrix, 1)).';
    squaredSum = full(sum(exposure.matrix .^ 2, 1)).';
    exposure.effectiveTrialCount = zeros(angularPixelCount, 1);
    hasExposure = squaredSum > 0;
    exposure.effectiveTrialCount(hasExposure) = ...
        exposure.sumSec(hasExposure) .^ 2 ./ squaredSum(hasExposure);
end

function [worldPointsMm, pixelCount] = stimulusWorldPoints(trial, geometry, sourceScreenSizePix)
    screenWidthPix = sourceScreenSizePix(1);
    screenHeightPix = sourceScreenSizePix(2);
    degreePerPixel = 360 / screenWidthPix;
    squareSizePix = ceil(double(trial.Square_Size) / degreePerPixel);
    squareHalfSizePix = ceil(squareSizePix / 2);

    lowerX = screenWidthPix / 2 + ceil(double(trial.Square_PositionX) / degreePerPixel) - squareHalfSizePix;
    upperX = lowerX + squareSizePix;
    lowerY = screenHeightPix / 2 + ceil(double(trial.Square_PositionY) / degreePerPixel) - squareHalfSizePix;
    upperY = lowerY + squareSizePix;
    xPixel = max(1, lowerX):min(screenWidthPix, upperX);
    yPixel = max(1, lowerY):min(screenHeightPix, upperY);
    [xGrid, yGrid] = meshgrid(xPixel, yPixel);
    xGrid = xGrid(:);
    yGrid = yGrid(:);
    pixelCount = numel(xGrid);
    assert(pixelCount > 0, 'Stimulus square is completely outside the source texture.');

    textureXDeg = ((xGrid - 0.5) - screenWidthPix / 2) / screenWidthPix * 360;
    thetaRad = geometry.xDirectionSign * deg2rad(textureXDeg);
    tangentUnit = cross(geometry.axisUnit, geometry.zeroDirectionUnit);
    radialUnit = cos(thetaRad) .* geometry.zeroDirectionUnit.' + ...
        sin(thetaRad) .* tangentUnit.';
    heightMm = (screenHeightPix - (yGrid - 0.5)) / screenHeightPix * geometry.heightMm;
    worldPointsMm = geometry.bottomCenterMm.' + ...
        heightMm .* geometry.axisUnit.' + geometry.radiusMm .* radialUnit;
end

function angularIndex = angularBinsForPose(worldPointsMm, eyeMm, rotation, geometry, ...
        azimuthEdgesDeg, elevationEdgesDeg)
    forwardWorld = rotation * geometry.forwardLocalUnit;
    upWorld = rotation * geometry.upLocalUnit;
    upWorld = upWorld - forwardWorld * dot(forwardWorld, upWorld);
    upWorld = upWorld / norm(upWorld);
    positiveAzimuthWorld = cross(upWorld, forwardWorld);
    positiveAzimuthWorld = positiveAzimuthWorld / norm(positiveAzimuthWorld);

    direction = worldPointsMm - eyeMm.';
    direction = direction ./ vecnorm(direction, 2, 2);
    forwardComponent = direction * forwardWorld;
    azimuthComponent = direction * positiveAzimuthWorld;
    upComponent = direction * upWorld;
    azimuthDeg = rad2deg(atan2(azimuthComponent, forwardComponent));
    azimuthDeg = mod(azimuthDeg + 180, 360) - 180;
    elevationDeg = rad2deg(atan2(upComponent, hypot(forwardComponent, azimuthComponent)));
    azimuthBin = discretize(azimuthDeg, azimuthEdgesDeg);
    elevationBin = discretize(elevationDeg, elevationEdgesDeg);
    isInside = ~isnan(azimuthBin) & ~isnan(elevationBin);
    angularIndex = unique(sub2ind( ...
        [numel(elevationEdgesDeg) - 1, numel(azimuthEdgesDeg) - 1], ...
        elevationBin(isInside), azimuthBin(isInside)));
end

function distanceMm = nearestCylinderDistance(eyeMm, geometry)
    relative = eyeMm - geometry.bottomCenterMm;
    radial = relative - geometry.axisUnit * dot(relative, geometry.axisUnit);
    distanceMm = geometry.radiusMm - norm(radial);
end

function rotation = motiveEulerXyzMatrix(rotationDeg)
    angle = deg2rad(double(rotationDeg));
    cx = cos(angle(1)); sx = sin(angle(1));
    cy = cos(angle(2)); sy = sin(angle(2));
    cz = cos(angle(3)); sz = sin(angle(3));
    rotationX = [1 0 0; 0 cx -sx; 0 sx cx];
    rotationY = [cy 0 sy; 0 1 0; -sy 0 cy];
    rotationZ = [cz -sz 0; sz cz 0; 0 0 1];
    rotation = rotationX * rotationY * rotationZ;
end

function unitPool = readGoodUnits(clusterInfoPath, spikeClusters)
    labels = readtable(clusterInfoPath, 'FileType', 'text', 'Delimiter', '\t');
    assert(ismember('cluster_id', labels.Properties.VariableNames), ...
        'clusterInfoPath must contain cluster_id.');
    assert(ismember('KSLabel', labels.Properties.VariableNames), ...
        'clusterInfoPath must contain KSLabel.');
    goodUnitIds = double(labels.cluster_id(strcmp(string(labels.KSLabel), "good")));
    unitPool = intersect(unique(spikeClusters), goodUnitIds);
    unitPool = unitPool(:);
    assert(~isempty(unitPool), 'No good units with spikes were found.');
end

function writeRfmap(params, calibrationText, motiveFrame, cameraFrameTimeSec, ...
        trialBoundarySec, trials, ...
        exposure, qa, unitPool, spikeTimesSec, spikeClusters, azimuthCentersDeg, ...
        elevationCentersDeg, timeEdgesSec)
    outputDirectory = fileparts(params.rfmapOutputPath);
    if exist(outputDirectory, 'dir') ~= 7
        mkdir(outputDirectory);
    end
    unitCount = numel(unitPool);
    elevationBinCount = numel(elevationCentersDeg);
    azimuthBinCount = numel(azimuthCentersDeg);
    timeBinCount = numel(timeEdgesSec) - 1;
    createAndWrite(params.rfmapOutputPath, '/axes/azimuth_centers_deg', ...
        azimuthCentersDeg(:), 'double');
    createAndWrite(params.rfmapOutputPath, '/axes/elevation_centers_deg', ...
        elevationCentersDeg(:), 'double');
    createAndWrite(params.rfmapOutputPath, '/axes/time_edges_sec', timeEdgesSec(:), 'double');
    createAndWrite(params.rfmapOutputPath, '/axes/time_centers_sec', ...
        ((timeEdgesSec(1:end-1) + timeEdgesSec(2:end)) / 2).', 'double');
    createAndWrite(params.rfmapOutputPath, '/units/id', int64(unitPool), 'int64');
    createAndWrite(params.rfmapOutputPath, '/tracking/motive_frame', int64(motiveFrame), 'int64');
    createAndWrite(params.rfmapOutputPath, '/tracking/camera_frame_time_sec', ...
        cameraFrameTimeSec, 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/onset_sec', trialBoundarySec(1:end-1), 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/duration_sec', diff(trialBoundarySec), 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/stimulus_x_deg', ...
        double([trials.Square_PositionX].'), 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/stimulus_y_deg', ...
        double([trials.Square_PositionY].'), 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/stimulus_size_deg', ...
        double([trials.Square_Size].'), 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/stimulus_luminance', ...
        double([trials.Square_Luminance].'), 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/analysis_included', ...
        uint8(qa.analysisIncluded), 'uint8');
    createAndWrite(params.rfmapOutputPath, '/trials/valid_tracking_duration_sec', ...
        qa.validTrackingDurationSec, 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/valid', uint8(qa.valid), 'uint8');
    createAndWrite(params.rfmapOutputPath, '/trials/source_pixel_count', ...
        qa.sourcePixelCount, 'uint32');
    createAndWrite(params.rfmapOutputPath, '/trials/nearest_screen_distance_mean_mm', ...
        qa.nearestScreenDistanceMeanMm, 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/nearest_screen_distance_min_mm', ...
        qa.nearestScreenDistanceMinMm, 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/nearest_screen_distance_max_mm', ...
        qa.nearestScreenDistanceMaxMm, 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/stimulus_distance_mean_mm', ...
        qa.stimulusDistanceMeanMm, 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/stimulus_distance_min_mm', ...
        qa.stimulusDistanceMinMm, 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/stimulus_distance_max_mm', ...
        qa.stimulusDistanceMaxMm, 'double');
    createAndWrite(params.rfmapOutputPath, '/trials/exposure_sparse/trial_index', ...
        uint32(exposure.trialIndex), 'uint32');
    createAndWrite(params.rfmapOutputPath, '/trials/exposure_sparse/pixel_index', ...
        uint32(exposure.pixelIndex), 'uint32');
    createAndWrite(params.rfmapOutputPath, '/trials/exposure_sparse/value_sec', ...
        exposure.valueSec, 'double');
    createAndWrite(params.rfmapOutputPath, '/rf/exposure_sec', ...
        reshape(exposure.sumSec, elevationBinCount, azimuthBinCount), 'double');
    createAndWrite(params.rfmapOutputPath, '/rf/effective_trial_count', ...
        reshape(exposure.effectiveTrialCount, elevationBinCount, azimuthBinCount), 'double');
    createAndWrite(params.rfmapOutputPath, '/calibration/json_utf8', ...
        uint8(unicode2native(calibrationText, 'UTF-8')).', 'uint8');

    rateSize = [unitCount, elevationBinCount, azimuthBinCount, timeBinCount];
    rateChunk = [1, elevationBinCount, min(20, azimuthBinCount), min(50, timeBinCount)];
    h5create(params.rfmapOutputPath, '/rf/rate_hz', rateSize, ...
        'Datatype', 'single', 'ChunkSize', rateChunk, 'Deflate', 4, ...
        'Shuffle', true, 'FillValue', single(0));

    exposureByPixelSec = exposure.sumSec;
    for unitIndex = 1:unitCount
        unitId = unitPool(unitIndex);
        unitSpikeSec = sort(spikeTimesSec(spikeClusters == unitId));
        trialSpikeCount = trialAlignedSpikeCounts( ...
            unitSpikeSec, trialBoundarySec(1:end-1), timeEdgesSec);
        trialSpikeCount(~qa.analysisIncluded, :) = 0;
        weightedSpikeCount = exposure.matrix.' * trialSpikeCount;
        denominator = exposureByPixelSec * params.timeBinSec;
        rateHz = full(weightedSpikeCount ./ denominator);
        rateHz(denominator == 0, :) = 0;
        rateHz = reshape(single(rateHz), [1, elevationBinCount, azimuthBinCount, timeBinCount]);
        h5write(params.rfmapOutputPath, '/rf/rate_hz', rateHz, ...
            [unitIndex, 1, 1, 1], [1, elevationBinCount, azimuthBinCount, timeBinCount]);
        fprintf('FM RF unit %d (%d/%d) complete\n', unitId, unitIndex, unitCount);
    end

    h5writeatt(params.rfmapOutputPath, '/', 'format', 'rfmapping_fm_hdf5_v1');
    h5writeatt(params.rfmapOutputPath, '/', 'logical_dimension_order', ...
        'unit,elevation,azimuth,time');
    h5writeatt(params.rfmapOutputPath, '/', 'spatial_grid', ...
        'full_sphere_1deg');
    h5writeatt(params.rfmapOutputPath, '/', 'trial_selection', ...
        'ON: Square_Luminance == 1');
    h5writeatt(params.rfmapOutputPath, '/', 'viewpoint_model', 'rigid_body_origin');
    h5writeatt(params.rfmapOutputPath, '/', 'time_bin_sec', params.timeBinSec);
    h5writeatt(params.rfmapOutputPath, '/', 'zero_exposure_rate_hz', 0);
    h5writeatt(params.rfmapOutputPath, '/', 'calib_path', params.calibPath);
    h5writeatt(params.rfmapOutputPath, '/', 'motive_csv_path', params.motiveCsvPath);
    h5writeatt(params.rfmapOutputPath, '/', 'camera_frame_times_path', ...
        params.cameraFrameTimesPath);
    h5writeatt(params.rfmapOutputPath, '/', 'trial_boundaries_path', ...
        params.onListTimesPath);
    h5writeatt(params.rfmapOutputPath, '/', 'stimulus_mat_path', ...
        params.stimulusMatPath);
    h5writeatt(params.rfmapOutputPath, '/', 'spike_time_path', params.spikeTimePath);
    h5writeatt(params.rfmapOutputPath, '/', 'spike_cluster_path', ...
        params.spikeClusterPath);
    h5writeatt(params.rfmapOutputPath, '/', 'cluster_info_path', ...
        params.clusterInfoPath);
    h5writeatt(params.rfmapOutputPath, '/', 'complete', uint8(1));
end

function spikeCount = trialAlignedSpikeCounts(unitSpikeSec, trialOnsetSec, timeEdgesSec)
    trialCount = numel(trialOnsetSec);
    timeBinCount = numel(timeEdgesSec) - 1;
    spikeCount = zeros(trialCount, timeBinCount);
    for trialIndex = 1:trialCount
        windowStart = trialOnsetSec(trialIndex) + timeEdgesSec(1);
        windowEnd = trialOnsetSec(trialIndex) + timeEdgesSec(end);
        firstIndex = firstGreaterOrEqual(unitSpikeSec, windowStart);
        afterLastIndex = firstGreaterOrEqual(unitSpikeSec, windowEnd);
        if firstIndex < afterLastIndex
            relativeSpikeSec = unitSpikeSec(firstIndex:afterLastIndex - 1) - ...
                trialOnsetSec(trialIndex);
            spikeCount(trialIndex, :) = histcounts(relativeSpikeSec, timeEdgesSec);
        end
    end
end

function index = firstGreaterOrEqual(sortedValues, target)
    lower = 1;
    upper = numel(sortedValues) + 1;
    while lower < upper
        middle = floor((lower + upper) / 2);
        if middle <= numel(sortedValues) && sortedValues(middle) < target
            lower = middle + 1;
        else
            upper = middle;
        end
    end
    index = lower;
end

function createAndWrite(filePath, datasetPath, value, datatype)
    datasetSize = size(value);
    h5create(filePath, datasetPath, datasetSize, 'Datatype', datatype);
    h5write(filePath, datasetPath, value);
end

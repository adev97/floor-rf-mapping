function verify_RFmap_polar_tiling(trials)
% VERIFY_RFMAP_POLAR_TILING checks whether the polar (azimuth x
% eccentricity) sectors defined by a Receptive Field Mapping TRIALS
% structure (as built by trialStruct_RFmapFast, drawn by
% ReceptiveFieldMapping_Fast_polar) tile the intended fan-shaped region
% with no gaps and no overlaps.
%
% It rebuilds the same sector polygons ReceptiveFieldMapping_Fast_polar.m
% would draw on screen (identical formulas), then uses exact polygon
% boolean operations (polyshape) to check:
%   1) sum of individual sector areas == area of their union   (no overlaps)
%   2) area of union == area of the full target fan region     (no gaps)
% and produces a figure of the tiling, with any gaps in red and any
% out-of-bounds area in magenta.
%
% Does NOT open a Psychtoolbox window -- pure geometry check, runs on
% any machine with base MATLAB (uses polyshape, R2017b+).
%
% USAGE:
%   trials = trialStruct_RFmapFast(stimType, table);
%   verify_RFmap_polar_tiling(trials);
%
% INPUT: TRIALS - structure array from trialStruct_RFmapFast for
%        stimType 'Receptive Field Mapping', with fields Sector_Azimuth
%        and Sector_Eccentricity (as built by RFmapFast_master_polar.m)

monitorInformation;

% Must match ReceptiveFieldMapping_Fast_polar.m exactly, or this isn't
% checking what will actually be shown. Mouse offsets now live in
% monitorInformation.m as monitorInfo.mouseOffsetXcm / mouseOffsetYcm --
% update these two lines if you named those fields differently.
mouseDistance_cm         = monitorInfo.screenDistcm;
mouseOffsetFromRight_cm  = monitorInfo.mouseOffsetXcm;
mouseOffsetFromBottom_cm = monitorInfo.mouseOffsetYcm;

screenWidth_cm   = monitorInfo.screenSizecmX;
screenHeight_cm  = monitorInfo.screenSizecmY;
screenWidth_pix  = monitorInfo.screenSizePixX;
screenHeight_pix = monitorInfo.screenSizePixY;

mouseX_cm = screenWidth_cm - mouseOffsetFromRight_cm;
mouseY_cm = mouseOffsetFromBottom_cm;

pixPerCmX = screenWidth_pix  / screenWidth_cm;
pixPerCmY = screenHeight_pix / screenHeight_cm;

nArcPoints = 20;

%%%%%%%%%%%%%%%%%%%%%% RECOVER THE SECTOR GRID %%%%%%%%%%%%%%%%%%%%%%%%%%%%
azVals  = [trials.Sector_Azimuth];
eccVals = [trials.Sector_Eccentricity];
uniqueAz  = unique(azVals(~isnan(azVals)));
uniqueEcc = unique(eccVals(~isnan(eccVals)));

azimuthStep      = min(diff(sort(uniqueAz)));
eccentricityStep = min(diff(sort(uniqueEcc)));

azDiffs = diff(sort(uniqueAz));
if any(abs(azDiffs - azimuthStep) > 1e-9)
    warning('verify_RFmap_polar_tiling:nonuniformAz', ...
        'Azimuth bin edges are not uniformly spaced -- check assumes uniform spacing.');
end
eccDiffs = diff(sort(uniqueEcc));
if any(abs(eccDiffs - eccentricityStep) > 1e-9)
    warning('verify_RFmap_polar_tiling:nonuniformEcc', ...
        'Eccentricity bin edges are not uniformly spaced -- check assumes uniform spacing.');
end

azimuthMin      = min(uniqueAz);
azimuthMax      = max(uniqueAz) + azimuthStep;
eccentricityMin = min(uniqueEcc);
eccentricityMax = max(uniqueEcc) + eccentricityStep;

nAz  = numel(uniqueAz);
nEcc = numel(uniqueEcc);

fprintf('\n============================================\n');
fprintf('RF MAP POLAR TILING CHECK\n');
fprintf('============================================\n');
fprintf('Azimuth:       %g to %g deg, step %g -> %d sectors\n', ...
    azimuthMin, azimuthMax, azimuthStep, nAz);
fprintf('Eccentricity:  %g to %g deg, step %g -> %d sectors\n', ...
    eccentricityMin, eccentricityMax, eccentricityStep, nEcc);
fprintf('Total sectors: %d\n', nAz*nEcc);

%%%%%%%%%%%%%%%%%%%%%% BUILD A POLYSHAPE PER SECTOR %%%%%%%%%%%%%%%%%%%%%%%
sectorShapes(nAz*nEcc) = polyshape(); % preallocate
k = 0;
for a = 1:nAz
    azInner = uniqueAz(a);
    azOuter = azInner + azimuthStep;
    for e = 1:nEcc
        eccInner = uniqueEcc(e);
        eccOuter = eccInner + eccentricityStep;

        k = k + 1;
        verts = localSectorVerts(azInner, azOuter, eccInner, eccOuter, ...
            mouseDistance_cm, mouseX_cm, mouseY_cm, pixPerCmX, pixPerCmY, ...
            screenHeight_pix, nArcPoints);
        sectorShapes(k) = polyshape(verts(:,1), verts(:,2), ...
            'Simplify', false, 'KeepCollinearPoints', true);
    end
end

%%%%%%%%%%%%%%%%%% BUILD THE TARGET (INTENDED) FAN REGION %%%%%%%%%%%%%%%%%
% IMPORTANT: each sector's curved edge is approximated with nArcPoints
% points spread over its own (small) angular span, e.g. 20 points over
% 10 deg. If we approximated the target's outer arc with the SAME point
% COUNT spread over the full (large) span instead, it would be a much
% coarser (more faceted) polygon that bows inward more than the true
% circle -- making the sectors appear to poke outside it, even with
% perfect tiling. To make a fair comparison, scale the target's point
% count so it has the same angular point DENSITY as the sectors.
pointsPerDeg   = (nArcPoints - 1) / azimuthStep;
targetArcPoints = max(nArcPoints, round((azimuthMax - azimuthMin) * pointsPerDeg) + 1);

targetVerts = localSectorVerts(azimuthMin, azimuthMax, eccentricityMin, eccentricityMax, ...
    mouseDistance_cm, mouseX_cm, mouseY_cm, pixPerCmX, pixPerCmY, ...
    screenHeight_pix, targetArcPoints);
targetShape = polyshape(targetVerts(:,1), targetVerts(:,2), ...
    'Simplify', false, 'KeepCollinearPoints', true);

%%%%%%%%%%%%%%%%%%%%%%%%%%%% AREA BOOKKEEPING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sumIndividualAreas = sum(area(sectorShapes));
unionShape = union(sectorShapes);
unionArea  = area(unionShape);
targetArea = area(targetShape);

overlapArea = sumIndividualAreas - unionArea;      % >0 => double-covered
gapShape    = subtract(targetShape, unionShape);
gapArea     = area(gapShape);                       % >0 => uncovered gaps
extraShape  = subtract(unionShape, targetShape);
extraArea   = area(extraShape);                     % >0 => sectors outside target

overlapPct = 100 * overlapArea / targetArea;
gapPct     = 100 * gapArea / targetArea;
extraPct   = 100 * extraArea / targetArea;

fprintf('\nTarget region area:      %.2f px^2\n', targetArea);
fprintf('Union of sectors area:   %.2f px^2\n', unionArea);
fprintf('Sum of sector areas:     %.2f px^2\n', sumIndividualAreas);
fprintf('Overlap area:            %.4f px^2 (%.4f%% of target)\n', overlapArea, overlapPct);
fprintf('Gap area:                %.4f px^2 (%.4f%% of target)\n', gapArea, gapPct);
fprintf('Area outside target:     %.4f px^2 (%.4f%% of target)\n', extraArea, extraPct);

tolPct = 0.01; % allow trivial floating-point / arc-discretization slop
if gapPct < tolPct && overlapPct < tolPct && extraPct < tolPct
    fprintf('\nRESULT: Sectors fully and exactly tile the proposed geometry.\n');
else
    fprintf('\nRESULT: Tiling problem detected -- inspect the figure for gaps/overlaps.\n');
end
fprintf('============================================\n\n');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% VISUALIZE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure('Name', 'RF Map Polar Tiling Check', 'Color', 'w');
hold on
for k = 1:numel(sectorShapes)
    if mod(k,2) == 0
        c = [0.85 0.85 0.85];
    else
        c = [0.55 0.55 0.55];
    end
    plot(sectorShapes(k), 'FaceColor', c, 'FaceAlpha', 1, 'EdgeColor', 'k');
end
plot(targetShape, 'FaceColor', 'none', 'EdgeColor', 'b', 'LineWidth', 1.5);
if gapArea > 1e-6
    plot(gapShape, 'FaceColor', 'r', 'FaceAlpha', 0.9, 'EdgeColor', 'r');
end
if extraArea > 1e-6
    plot(extraShape, 'FaceColor', 'm', 'FaceAlpha', 0.9, 'EdgeColor', 'm');
end
axis equal
set(gca, 'YDir', 'reverse'); % match screen pixel coordinates (y grows downward)
xlabel('screen x (pix)'); ylabel('screen y (pix)');
title(sprintf('%d sectors | gap %.3f%% | overlap %.3f%%', ...
    nAz*nEcc, gapPct, overlapPct));

end

%% ------------------------------------------------------------------
function verts = localSectorVerts(azInner, azOuter, eccInner, eccOuter, ...
    mouseDistance_cm, mouseX_cm, mouseY_cm, pixPerCmX, pixPerCmY, ...
    screenHeight_pix, nArcPoints)
% Identical formula to ReceptiveFieldMapping_Fast_polar.m and
% test_RFmap_80deg_geometry.m -- kept in sync on purpose, so this check
% verifies exactly what would be drawn on screen, not an approximation.

rInner_cm = mouseDistance_cm * tand(eccInner);
rOuter_cm = mouseDistance_cm * tand(eccOuter);

thetaOuter = linspace(azInner, azOuter, nArcPoints);
thetaInner = linspace(azOuter, azInner, nArcPoints);

xOuter_cm = mouseX_cm + rOuter_cm .* cosd(thetaOuter);
yOuter_cm = mouseY_cm - rOuter_cm .* sind(thetaOuter);
xInner_cm = mouseX_cm + rInner_cm .* cosd(thetaInner);
yInner_cm = mouseY_cm - rInner_cm .* sind(thetaInner);

x_cm = [xOuter_cm, xInner_cm];
y_cm = [yOuter_cm, yInner_cm];

x_pix = x_cm * pixPerCmX;
y_pix = screenHeight_pix - y_cm * pixPerCmY;

verts = [x_pix(:), y_pix(:)];
end

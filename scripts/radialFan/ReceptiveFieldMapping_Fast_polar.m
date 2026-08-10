%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ReceptiveFieldMapping_Fast_polar(trials)
% RECEPTIVEFIELDMAPPING_FAST_POLAR draws black/white polar "pie-slice"
% sector stimuli (azimuth x eccentricity), defined relative to the mouse
% head position, using the geometry validated in
% test_RFmap_80deg_geometry.m.
%
% Drop-in replacement for ReceptiveFieldMapping_Fast_ver2 in the same
% 3-function pipeline (master script -> trialStruct_RFmapFast ->
% this function). Square stimuli are replaced with polar sectors, and
% the per-pixel MakeTexture loop is replaced with precomputed polygon
% vertices drawn each frame with Screen('FillPoly').
%
% TIMING NOTE: sector geometry is precomputed for only the (typically
% far fewer than numel(trials)) UNIQUE azimuth/eccentricity combinations,
% and this precompute happens BEFORE Screen('OpenWindow') is ever called.
% Doing heavy CPU work with the PTB window already open but idle (between
% OpenWindow's internal flip calibration and the first real trial-loop
% Flip) is a common cause of "impossible stimulus onset" beamposition
% timestamping errors -- so all geometry is built first, and the window
% only opens once everything it needs to draw is already sitting in
% memory.
%
% INPUTS: TRIALS - trial structure array from trialStruct_RFmapFast,
%   built from a table with rows (in this order):
%     'Sector Azimuth (deg)'      -> field Sector_Azimuth (bin INNER edge)
%     'Sector Eccentricity (deg)' -> field Sector_Eccentricity (bin INNER edge)
%     'Sector Luminance (binary)' -> field Sector_Luminance (0/1)
%   Azimuth/Eccentricity/Luminance must stay in that order in the table
%   so Luminance remains the fastest-varying parameter -- this is what
%   trialStruct_RFmapFast's stimType=='Receptive Field Mapping'
%   randomization branch relies on to avoid two consecutive trials
%   landing on the same sector.
%
% Adapted from ReceptiveFieldMapping_Fast_ver2 (MSC 2012, mod. YS 2018)
% and the geometry in test_RFmap_80deg_geometry.m.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

monitorInformation;

%%%%%%%%%%%%%%%%%%%%%%% MOUSE HEAD PROJECTION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Mouse offset coordinates now live in monitorInformation.m as
% monitorInfo.mouseOffsetXcm / monitorInfo.mouseOffsetYcm, so this file
% and test_RFmap_80deg_geometry.m can't drift apart. If you named these
% fields something else in monitorInformation.m, update the two lines
% below to match.
mouseDistance_cm        = monitorInfo.screenDistcm;   % mouse head - screen
mouseOffsetFromRight_cm = monitorInfo.mouseOffsetXcm;
mouseOffsetFromBottom_cm = monitorInfo.mouseOffsetYcm;

screenWidth_cm   = monitorInfo.screenSizecmX;
screenHeight_cm  = monitorInfo.screenSizecmY;
screenWidth_pix  = monitorInfo.screenSizePixX;
screenHeight_pix = monitorInfo.screenSizePixY;

mouseX_cm = screenWidth_cm - mouseOffsetFromRight_cm;
mouseY_cm = mouseOffsetFromBottom_cm;

pixPerCmX = screenWidth_pix  / screenWidth_cm;
pixPerCmY = screenHeight_pix / screenHeight_cm;

%%%%%%%%%%%%%%%%%%%%%% DETERMINE SECTOR BIN WIDTHS %%%%%%%%%%%%%%%%%%%%%%%%
% Trial fields store the INNER edge of each azimuth/eccentricity bin.
% Recover the bin width/grid directly from the values actually used, so
% this function doesn't need the table's step size passed in separately.
azVals  = [trials.Sector_Azimuth];
eccVals = [trials.Sector_Eccentricity];
uniqueAz  = unique(azVals(~isnan(azVals)));
uniqueEcc = unique(eccVals(~isnan(eccVals)));
azimuthStep      = min(diff(sort(uniqueAz)));
eccentricityStep = min(diff(sort(uniqueEcc)));
azimuthMin      = min(uniqueAz);
eccentricityMin = min(uniqueEcc);
nAz  = numel(uniqueAz);
nEcc = numel(uniqueEcc);
nArcPoints = 20;

%%%%%%%%%%%%%%%%%%%%%%%% PRECOMPUTE UNIQUE SECTOR SHAPES %%%%%%%%%%%%%%%%%%
% Only nAz x nEcc unique sector shapes exist, no matter how many repeats
% are in the trial list -- build each exactly once, indexed by
% [azimuthBinIndex, eccentricityBinIndex], and look each trial's shape up
% instead of recomputing/duplicating it. This all happens before any PTB
% window is open.
sectorVertsGrid = cell(nAz, nEcc);
for a = 1:nAz
    azInner = uniqueAz(a);
    azOuter = azInner + azimuthStep;
    for e = 1:nEcc
        eccInner = uniqueEcc(e);
        eccOuter = eccInner + eccentricityStep;
        sectorVertsGrid{a,e} = localSectorVerts(azInner, azOuter, eccInner, eccOuter, ...
            mouseDistance_cm, mouseX_cm, mouseY_cm, pixPerCmX, pixPerCmY, ...
            screenHeight_pix, nArcPoints);
    end
end

Screen('Preference', 'Verbosity', 1);
Screen('Preference', 'VisualDebuglevel', 3);

try
    AssertOpenGL;

    screenNumber = monitorInfo.screenNumber;

    whitePix = WhiteIndex(screenNumber);
    blackPix = BlackIndex(screenNumber);

    whiteLum = PixToLum(whitePix);
    blackLum = PixToLum(blackPix);
    grayLum  = (whiteLum + blackLum) / 2;
    grayPix  = GammaCorrect(grayLum);

    LeftBoxBG = grayPix;

    HideCursor;
    [w, screenRect] = Screen('OpenWindow', screenNumber, grayPix);
    LeftBoxStim(w, screenRect, LeftBoxBG);

    priorityLevel = MaxPriority(w);
    Priority(priorityLevel);

    ifi         = Screen('GetFlipInterval', w);
    waitframes  = 1;
    ifiDuration = waitframes * ifi;

    stimInitScreen(w, trials(1).Initialization_Screen, grayPix, ifiDuration);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% MAIN TRIAL LOOP %%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Nothing computationally heavy happens between stimInitScreen's last
% flip and this first real trial-loop flip -- all geometry was already
% built above, before the window even opened.
    nTrials  = numel(trials);
    exitLoop = 0;
    vbl = Screen('Flip', w);

    for trial = 1:nTrials
        if exitLoop == 1
            break
        end

        % kept for parity with ver2 / future use of delay & wait periods
        delay    = trials(trial).Timing(1); %#ok<NASGU>
        duration = trials(trial).Timing(2);
        wait     = trials(trial).Timing(3); %#ok<NASGU>

        if ~strcmp(trials(trial).Stimulus_Type, 'Blank')

            azIdx  = round((trials(trial).Sector_Azimuth      - azimuthMin)      / azimuthStep)      + 1;
            eccIdx = round((trials(trial).Sector_Eccentricity - eccentricityMin) / eccentricityStep) + 1;
            verts  = sectorVertsGrid{azIdx, eccIdx};

            if trials(trial).Sector_Luminance == 0
                stimColor = blackPix;
            else
                stimColor = whitePix;
            end

            runtime = vbl + duration;
            while vbl < runtime
                Screen('FillRect', w, grayPix);
                Screen('FillPoly', w, stimColor, verts);

                % photodiode flip-marker box, same convention as ver2
                if mod(trial, 2) == 1
                    LeftBoxStim(w, screenRect, blackPix);
                end

                vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);

                if KbCheck
                    exitLoop = 1;
                    break
                end
            end
        end
    end

%%%% blank screen after exp %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    vbl = Screen('Flip', w);
    LeftBoxStim(w, screenRect, LeftBoxBG);
    waitTime = vbl + 2; % wait 2 sec
    while vbl < waitTime
        Screen('FillRect', w, grayPix);
        LeftBoxStim(w, screenRect, LeftBoxBG);
        vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);
    end

    Priority(0);
    Screen('CloseAll');

catch
    Screen('CloseAll');
    Priority(0);
    psychrethrow(psychlasterror);
end

Screen('Preference', 'Verbosity', 3);
java.lang.Runtime.getRuntime().gc

return
end

%% ------------------------------------------------------------------
function verts = localSectorVerts(azInner, azOuter, eccInner, eccOuter, ...
    mouseDistance_cm, mouseX_cm, mouseY_cm, pixPerCmX, pixPerCmY, ...
    screenHeight_pix, nArcPoints)
% Identical formula to test_RFmap_80deg_geometry.m and
% verify_RFmap_polar_tiling.m -- kept in sync on purpose.

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

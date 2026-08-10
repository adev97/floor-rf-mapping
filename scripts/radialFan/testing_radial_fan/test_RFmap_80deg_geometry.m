function test_RFmap_80deg_geometry

AssertOpenGL;

%% ============================================================
% LOAD MONITOR INFORMATION
% =============================================================

monitorInformation;

screenNumber = monitorInfo.screenNumber;

screenWidth_cm  = monitorInfo.screenSizecmX;
screenHeight_cm = monitorInfo.screenSizecmY;

screenWidth_pix  = monitorInfo.screenSizePixX;
screenHeight_pix = monitorInfo.screenSizePixY;

%% ============================================================
% MOUSE / VIEWING GEOMETRY
% =============================================================

% Mouse head is 3 cm above the monitor -- pulled from monitorInformation
mouseDistance_cm = monitorInfo.screenDistcm;

% Projection of mouse head onto monitor
% 24.5 cm from RIGHT edge
mouseX_cm = screenWidth_cm - 24.5;

% 15 cm from BOTTOM
mouseY_cm = 15;

%% ============================================================
% CM -> PIXELS
% =============================================================

pixPerCmX = screenWidth_pix  / screenWidth_cm;
pixPerCmY = screenHeight_pix / screenHeight_cm;

%% ============================================================
% MOUSE PROJECTION IN PIXELS
% =============================================================

mouseX_pix = mouseX_cm * pixPerCmX;

mouseY_pix = screenHeight_pix - ...
mouseY_cm * pixPerCmY;

%% ============================================================
% OPEN PSYCHTOOLBOX
% =============================================================

gray = 127;

[w, screenRect] = PsychImaging( ...
'OpenWindow', screenNumber, gray);

HideCursor;

%% ============================================================
% RF MAP GEOMETRY
% =============================================================

% -------------------------------------------------------------
% AZIMUTH
%
% 0 degrees = straight AHEAD from mouse head
%
% -120 to +120 degrees = 240 degree fan
% -------------------------------------------------------------

azimuthStep = 10;

azimuthMin = -120;
azimuthMax = 120;

azimuths = azimuthMin:azimuthStep:azimuthMax;

% -------------------------------------------------------------
% ECCENTRICITY
%
% 0 to 80 degrees from mouse head
%
% 10 degree increments
% -------------------------------------------------------------

eccentricityStep = 10;

eccentricityMin = 0;
eccentricityMax = 80;

eccentricities = ...
eccentricityMin:eccentricityStep:eccentricityMax;

% -------------------------------------------------------------
% Number of cells
% -------------------------------------------------------------

nAzimuthCells = length(azimuths) - 1;
nEccCells     = length(eccentricities) - 1;

fprintf('\n');
fprintf('============================================\n');
fprintf('RF MAP GEOMETRY\n');
fprintf('============================================\n');
fprintf('Azimuth:       %d to %d degrees\n', ...
azimuthMin, azimuthMax);
fprintf('Azimuth cells: %d\n', nAzimuthCells);
fprintf('Eccentricity:  %d to %d degrees\n', ...
eccentricityMin, eccentricityMax);
fprintf('Ecc cells:     %d\n', nEccCells);
fprintf('Total cells:   %d\n', ...
nAzimuthCells * nEccCells);
fprintf('Mouse distance: %.1f cm\n', mouseDistance_cm);
fprintf('============================================\n');
fprintf('\n');

%% ============================================================
% DRAW 0-DEGREE REFERENCE LINE
% =============================================================

% 0 degrees = straight DOWN from mouse head

Screen('DrawLine', w, [80 80 80], ...
mouseX_pix, mouseY_pix, ...
mouseX_pix, screenHeight_pix, 2);

%% ============================================================
% DRAW 10 x 10 DEGREE CELLS
% =============================================================

for ecc = 1:nEccCells

% ---------------------------------------------------------
% Inner and outer visual eccentricity
% ---------------------------------------------------------

eccInner = eccentricities(ecc);
eccOuter = eccentricities(ecc+1);

% Convert visual angle to physical distance on monitor
%
% r = viewingDistance * tan(theta)

rInner_cm = mouseDistance_cm * tand(eccInner);
rOuter_cm = mouseDistance_cm * tand(eccOuter);

% ---------------------------------------------------------
% Loop through azimuth sectors
% ---------------------------------------------------------

for az = 1:nAzimuthCells

    azInner = azimuths(az);
    azOuter = azimuths(az+1);

    % -----------------------------------------------------
    % Build angular boundaries
    %
    % More points = better approximation of the circular
    % eccentricity boundary.
    % -----------------------------------------------------

    nArcPoints = 20;

    % Outer arc
    thetaOuter = linspace(azInner, ...
                          azOuter, ...
                          nArcPoints);

    % Inner arc
    thetaInner = linspace(azOuter, ...
                          azInner, ...
                          nArcPoints);

    % -----------------------------------------------------
    % OUTER ARC
    %
    % 0 degrees = DOWN
    %
    % x = x0 + r*sin(theta)
    % y = y0 - r*cos(theta)
    %
    % y is expressed in physical monitor coordinates
    % measured upward from the bottom.
    % -----------------------------------------------------

    xOuter_cm = mouseX_cm + ...
                rOuter_cm .* cosd(thetaOuter);

    yOuter_cm = mouseY_cm - ...
                rOuter_cm .* sind(thetaOuter);

    % -----------------------------------------------------
    % INNER ARC
    % -----------------------------------------------------

    xInner_cm = mouseX_cm + ...
                rInner_cm .* cosd(thetaInner);

    yInner_cm = mouseY_cm - ...
                rInner_cm .* sind(thetaInner);

    % -----------------------------------------------------
    % Combine outer and inner boundaries
    % -----------------------------------------------------

    x_cm = [xOuter_cm xInner_cm];
    y_cm = [yOuter_cm yInner_cm];

    % -----------------------------------------------------
    % Convert to pixels
    % -----------------------------------------------------

    x_pix = x_cm * pixPerCmX;

    y_pix = screenHeight_pix - ...
            y_cm * pixPerCmY;

    % -----------------------------------------------------
    % Alternate black and white
    % -----------------------------------------------------

    if mod(ecc + az, 2) == 0

        stimColor = [255 255 255];

    else

        stimColor = [0 0 0];

    end

    % -----------------------------------------------------
    % Draw cell
    % -----------------------------------------------------

    Screen('FillPoly', w, stimColor, ...
        [x_pix(:) y_pix(:)]);

end

end

%% ============================================================
% DRAW AZIMUTH BOUNDARIES
% =============================================================

for az = 1:length(azimuths)

theta = azimuths(az);

% Use the 80 degree eccentricity boundary
r_cm = mouseDistance_cm * tand(eccentricityMax);

x_cm = mouseX_cm + r_cm * cosd(theta);

y_cm = mouseY_cm - r_cm * sind(theta);

x_pix = x_cm * pixPerCmX;

y_pix = screenHeight_pix - ...
        y_cm * pixPerCmY;

Screen('DrawLine', w, [80 80 80], ...
    mouseX_pix, mouseY_pix, ...
    x_pix, y_pix, 1);

end

%% ============================================================
% DRAW ECCENTRICITY BOUNDARIES
% =============================================================

for ecc = 1:length(eccentricities)

eccAngle = eccentricities(ecc);

r_cm = mouseDistance_cm * tand(eccAngle);

% Don't draw a circle for 0 degrees
if r_cm == 0
    continue;
end

theta = linspace(azimuthMin, ...
                 azimuthMax, ...
                 300);

x_cm = mouseX_cm + ...
       r_cm .* cosd(theta);

y_cm = mouseY_cm - ...
       r_cm .* sind(theta);

x_pix = x_cm * pixPerCmX;

y_pix = screenHeight_pix - ...
        y_cm * pixPerCmY;

Screen('DrawLines', w, ...
    [x_pix; y_pix], ...
    1, [100 100 100]);

end

%% ============================================================
% DRAW MOUSE HEAD PROJECTION
% =============================================================

dotSize = 12;

Screen('FillOval', w, [0 255 0], ...
[ ...
mouseX_pix-dotSize/2, ...
mouseY_pix-dotSize/2, ...
mouseX_pix+dotSize/2, ...
mouseY_pix+dotSize/2 ...
]);

%% ============================================================
% DISPLAY
% =============================================================

Screen('Flip', w);

%% ============================================================
% WAIT FOR KEY
% =============================================================

KbStrokeWait;

%% ============================================================
% CLEANUP
% =============================================================

Screen('CloseAll');
ShowCursor;

end

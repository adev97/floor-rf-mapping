function ReceptiveFieldMapping_FloorBubble_Static(trials)

AssertOpenGL;

%% ============================================================
% MONITOR INFORMATION
% ============================================================

monitorInformation;

screenNumber = monitorInfo.screenNumber;

screenWidth_cm  = monitorInfo.screenSizecmX;
screenHeight_cm = monitorInfo.screenSizecmY;

screenWidth_pix  = monitorInfo.screenSizePixX;
screenHeight_pix = monitorInfo.screenSizePixY;

%% ============================================================
% MOUSE PROJECTION
% ============================================================

mouseDistance_cm = monitorInfo.screenDistcm;

% Mouse projection
mouseX_cm = screenWidth_cm - 24.5;
mouseY_cm = 14.0;

% cm -> pixels
pixPerCmX = screenWidth_pix / screenWidth_cm;
pixPerCmY = screenHeight_pix / screenHeight_cm;

mouseX_pix = mouseX_cm * pixPerCmX;

mouseY_pix = screenHeight_pix - ...
             mouseY_cm * pixPerCmY;

%% ============================================================
% STIMULUS PARAMETERS
% ============================================================

sectorWidth_deg = trials(1).Sector_Width;
innerGap_cm     = trials(1).Inner_Gap;

% Fan
fanStart_deg = -120;
fanEnd_deg   = 120;

% Radial increment
radialStep_deg = 10;

%% ============================================================
% OPEN SCREEN
% ============================================================

gray = 127;
white = 255;

HideCursor;

[w, screenRect] = PsychImaging( ...
    'OpenWindow', screenNumber, gray);

%% ============================================================
% ANGULAR EDGES
% ============================================================

angleEdges = fanStart_deg:sectorWidth_deg:fanEnd_deg;

nAngular = length(angleEdges)-1;

%% ============================================================
% RADIAL EDGES
% ============================================================

% Convert the 0.5 cm inner gap to visual angle
innerGap_deg = atand(innerGap_cm / mouseDistance_cm);

% We will test radial bands out to 60 degrees.
%
% This gives:
%
% 0.5 cm gap
% 10 deg
% 20 deg
% 30 deg
% 40 deg
% 50 deg
% 60 deg

maxRadial_deg = 60;

radialEdges_deg = ...
    [innerGap_deg:radialStep_deg:maxRadial_deg];

nRadial = length(radialEdges_deg)-1;

%% ============================================================
% DRAW ALL TRAPEZOIDS
% ============================================================

for a = 1:nAngular

    theta1 = angleEdges(a);
    theta2 = angleEdges(a+1);

    for r = 1:nRadial

        r1 = radialEdges_deg(r);
        r2 = radialEdges_deg(r+1);

        % --------------------------------------------------------
        % Convert visual eccentricity to physical distance
        % on the monitor.
        % --------------------------------------------------------

        radius1_cm = mouseDistance_cm * tand(r1);
        radius2_cm = mouseDistance_cm * tand(r2);

        % --------------------------------------------------------
        % Convert polar coordinates to monitor coordinates.
        %
        % The +90 degree rotation preserves the orientation of
        % the fan that we previously verified.
        % --------------------------------------------------------

        phi1 = theta1 + 90;
        phi2 = theta2 + 90;

        % Inner boundary
        x1_cm = mouseX_cm + ...
            radius1_cm * cosd(phi1);

        y1_cm = mouseY_cm + ...
            radius1_cm * sind(phi1);

        x2_cm = mouseX_cm + ...
            radius1_cm * cosd(phi2);

        y2_cm = mouseY_cm + ...
            radius1_cm * sind(phi2);

        % Outer boundary
        x3_cm = mouseX_cm + ...
            radius2_cm * cosd(phi2);

        y3_cm = mouseY_cm + ...
            radius2_cm * sind(phi2);

        x4_cm = mouseX_cm + ...
            radius2_cm * cosd(phi1);

        y4_cm = mouseY_cm + ...
            radius2_cm * sind(phi1);

        % --------------------------------------------------------
        % Convert to pixels
        % --------------------------------------------------------

        x1_pix = x1_cm * pixPerCmX;
        x2_pix = x2_cm * pixPerCmX;
        x3_pix = x3_cm * pixPerCmX;
        x4_pix = x4_cm * pixPerCmX;

        y1_pix = screenHeight_pix - y1_cm * pixPerCmY;
        y2_pix = screenHeight_pix - y2_cm * pixPerCmY;
        y3_pix = screenHeight_pix - y3_cm * pixPerCmY;
        y4_pix = screenHeight_pix - y4_cm * pixPerCmY;

        % --------------------------------------------------------
        % Draw trapezoid
        % --------------------------------------------------------

        vertices = [ ...
            x1_pix y1_pix; ...
            x2_pix y2_pix; ...
            x3_pix y3_pix; ...
            x4_pix y4_pix];

        Screen('FillPoly', w, white, vertices);

    end
end

%% ============================================================
% DRAW MOUSE PROJECTION
% ============================================================

dotSize = 12;

Screen('FillOval', w, [0 255 0], ...
    [mouseX_pix-dotSize/2, ...
     mouseY_pix-dotSize/2, ...
     mouseX_pix+dotSize/2, ...
     mouseY_pix+dotSize/2]);

%% ============================================================
% DISPLAY
% ============================================================

Screen('Flip', w);

KbStrokeWait;

%% ============================================================
% CLEANUP
% ============================================================

Screen('CloseAll');
ShowCursor;

end


function test_RFmap_angles

AssertOpenGL;

%% Load monitor information
monitorInformation;

screenNumber = monitorInfo.screenNumber;

%% Monitor dimensions
screenWidth_cm  = monitorInfo.screenSizecmX;
screenHeight_cm = monitorInfo.screenSizecmY;

screenWidth_pix  = monitorInfo.screenSizePixX;
screenHeight_pix = monitorInfo.screenSizePixY;

%% Mouse geometry
mouseDistance_cm = monitorInfo.screenDistcm;

% Mouse projection on monitor
% 24.5 cm from RIGHT edge
mouseX_cm = screenWidth_cm - 24.5;

% 14 cm from BOTTOM
mouseY_cm = 14.0;

%% cm -> pixels
pixPerCmX = screenWidth_pix / screenWidth_cm;
pixPerCmY = screenHeight_pix / screenHeight_cm;

%% Mouse projection in pixels
mouseX_pix = mouseX_cm * pixPerCmX;

mouseY_pix = screenHeight_pix - ...
    mouseY_cm * pixPerCmY;

%% Open Psychtoolbox
gray = 127;

[w, screenRect] = PsychImaging( ...
    'OpenWindow', screenNumber, gray);

HideCursor;

%% ============================================================
%  DRAW MOUSE PROJECTION
% =============================================================

dotSize = 12;

Screen('FillOval', w, [0 255 0], ...
    [mouseX_pix-dotSize/2, ...
     mouseY_pix-dotSize/2, ...
     mouseX_pix+dotSize/2, ...
     mouseY_pix+dotSize/2]);


%% ============================================================
%  DRAW 0-DEGREE REFERENCE LINE
% =============================================================

Screen('DrawLine', w, [100 100 100], ...
    mouseX_pix, 0, ...
    mouseX_pix, screenHeight_pix, 3);


%% ============================================================
%  FAN ANGLES
% =============================================================

angleStep = 10;

% 0 degrees = straight UP
%
% Positive = clockwise/right
% Negative = counterclockwise/left

fanMin = -120;
fanMax = 120;

fanAngles = fanMin:angleStep:fanMax;


%% ============================================================
%  CALCULATE RAY INTERSECTIONS WITH SCREEN
% =============================================================

for i = 1:length(fanAngles)

    theta = fanAngles(i);

    % ---------------------------------------------------------
    % Ray direction
    %
    % 0 degrees = straight upward
    %
    % x component = sin(theta)
    % y component = cos(theta)
    % ---------------------------------------------------------

    dx = cosd(theta);
    dy = -sind(theta);

    % ---------------------------------------------------------
    % Find where the ray intersects the monitor rectangle.
    %
    % Parametric ray:
    %
    % x = mouseX_cm + t * mouseDistance_cm * dx
    % y = mouseY_cm + t * mouseDistance_cm * dy
    %
    % We find the first intersection with the monitor boundary.
    % ---------------------------------------------------------

    intersections = [];

    % Right edge
    if dx > 0
        t = (screenWidth_cm - mouseX_cm) / ...
            (mouseDistance_cm * dx);

        y = mouseY_cm + ...
            t * mouseDistance_cm * dy;

        if y >= 0 && y <= screenHeight_cm
            intersections(end+1,:) = ...
                [screenWidth_cm, y];
        end
    end

    % Left edge
    if dx < 0
        t = (0 - mouseX_cm) / ...
            (mouseDistance_cm * dx);

        y = mouseY_cm + ...
            t * mouseDistance_cm * dy;

        if y >= 0 && y <= screenHeight_cm
            intersections(end+1,:) = ...
                [0, y];
        end
    end

    % Top edge
    if dy > 0
        t = (screenHeight_cm - mouseY_cm) / ...
            (mouseDistance_cm * dy);

        x = mouseX_cm + ...
            t * mouseDistance_cm * dx;

        if x >= 0 && x <= screenWidth_cm
            intersections(end+1,:) = ...
                [x, screenHeight_cm];
        end
    end

    % Bottom edge
    if dy < 0
        t = (0 - mouseY_cm) / ...
            (mouseDistance_cm * dy);

        x = mouseX_cm + ...
            t * mouseDistance_cm * dx;

        if x >= 0 && x <= screenWidth_cm
            intersections(end+1,:) = ...
                [x, 0];
        end
    end

    % ---------------------------------------------------------
    % Draw the ray if it intersects the monitor
    % ---------------------------------------------------------

    if ~isempty(intersections)

        hitX_cm = intersections(1,1);
        hitY_cm = intersections(1,2);

        hitX_pix = hitX_cm * pixPerCmX;

        hitY_pix = screenHeight_pix - ...
            hitY_cm * pixPerCmY;

        Screen('DrawLine', w, [255 255 255], ...
            mouseX_pix, mouseY_pix, ...
            hitX_pix, hitY_pix, 2);

        % Draw endpoint
        Screen('FillOval', w, [255 255 255], ...
            [hitX_pix-4, hitY_pix-4, ...
             hitX_pix+4, hitY_pix+4]);

    end

end


%% ============================================================
%  DISPLAY
% =============================================================

Screen('Flip', w);


%% ============================================================
%  WAIT
% =============================================================

KbStrokeWait;

sca;
ShowCursor;

end


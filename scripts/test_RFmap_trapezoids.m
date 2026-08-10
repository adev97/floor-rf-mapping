function test_RFmap_trapezoids

AssertOpenGL;

%% ============================================================
% LOAD MONITOR INFORMATION
% =============================================================

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


%% ============================================================
% CM -> PIXELS
% =============================================================

pixPerCmX = screenWidth_pix / screenWidth_cm;
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

angleStep = 10;

fanMin = -120;
fanMax = 120;

fanAngles = fanMin:angleStep:fanMax;


% Distance from mouse before stimulus begins
innerRadius_cm = 0.5;


%% ============================================================
% DRAW 0-DEGREE REFERENCE LINE
% =============================================================

Screen('DrawLine', w, [80 80 80], ...
    mouseX_pix, 0, ...
    mouseX_pix, screenHeight_pix, 2);


%% ============================================================
% DRAW TRAPEZOIDS
% =============================================================

for i = 1:length(fanAngles)-1

    % ---------------------------------------------------------
    % Current angular boundaries
    % ---------------------------------------------------------

    theta1 = fanAngles(i);
    theta2 = fanAngles(i+1);


    % ---------------------------------------------------------
    % INNER EDGE
    %
    % Both points are exactly innerRadius_cm from mouse.
    % ---------------------------------------------------------

    x1_inner = mouseX_cm + ...
        innerRadius_cm * cosd(theta1);

    y1_inner = mouseY_cm + ...
        innerRadius_cm * sind(theta1);

    x2_inner = mouseX_cm + ...
        innerRadius_cm * cosd(theta2);

    y2_inner = mouseY_cm + ...
        innerRadius_cm * sind(theta2);


    % ---------------------------------------------------------
    % FIND WHERE EACH RAY INTERSECTS THE MONITOR
    % ---------------------------------------------------------

    [x1_outer, y1_outer] = rayScreenIntersection( ...
        mouseX_cm, mouseY_cm, theta1, ...
        screenWidth_cm, screenHeight_cm);

    [x2_outer, y2_outer] = rayScreenIntersection( ...
        mouseX_cm, mouseY_cm, theta2, ...
        screenWidth_cm, screenHeight_cm);


    % ---------------------------------------------------------
    % CONVERT FOUR CORNERS TO PIXELS
    % ---------------------------------------------------------

    xPix = [ ...
        x1_inner ...
        x2_inner ...
        x2_outer ...
        x1_outer ...
        ] * pixPerCmX;

    yPix = screenHeight_pix - ...
        [ ...
        y1_inner ...
        y2_inner ...
        y2_outer ...
        y1_outer ...
        ] * pixPerCmY;


    % ---------------------------------------------------------
    % ALTERNATING SHADES
    %
    % This is only for debugging the geometry.
    % ---------------------------------------------------------

    if mod(i,2) == 1
        stimColor = [180 180 180];
    else
        stimColor = [100 100 100];
    end


    % ---------------------------------------------------------
    % DRAW TRAPEZOID
    % ---------------------------------------------------------

    Screen('FillPoly', w, stimColor, ...
        [xPix(:) yPix(:)]);


    % ---------------------------------------------------------
    % DRAW ANGULAR BOUNDARY
    % ---------------------------------------------------------

    Screen('DrawLines', w, ...
        [ ...
        mouseX_pix, mouseY_pix; ...
        x1_outer * pixPerCmX, ...
            screenHeight_pix - y1_outer * pixPerCmY ...
        ]', ...
        2, [255 255 255]);


end


%% ============================================================
% DRAW ALL ANGULAR BOUNDARIES
% =============================================================

for i = 1:length(fanAngles)

    theta = fanAngles(i);

    [x_outer, y_outer] = rayScreenIntersection( ...
        mouseX_cm, mouseY_cm, theta, ...
        screenWidth_cm, screenHeight_cm);

    x_outer_pix = x_outer * pixPerCmX;

    y_outer_pix = screenHeight_pix - ...
        y_outer * pixPerCmY;

    Screen('DrawLine', w, [255 255 255], ...
        mouseX_pix, mouseY_pix, ...
        x_outer_pix, y_outer_pix, 1);

end


%% ============================================================
% DRAW MOUSE PROJECTION
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

sca;
ShowCursor;

end



%% ============================================================
% RAY / SCREEN INTERSECTION FUNCTION
% =============================================================

function [xHit, yHit] = rayScreenIntersection( ...
    x0, y0, theta, screenWidth, screenHeight)

% -------------------------------------------------------------
% Direction of ray
%
% 0 degrees = RIGHT
% Positive = DOWN
% Negative = UP
% -------------------------------------------------------------

dx = cosd(theta);
dy = sind(theta);


% -------------------------------------------------------------
% Candidate intersections
% -------------------------------------------------------------

candidates = [];


%% Right edge

if dx > 0

    t = (screenWidth - x0) / dx;

    y = y0 + t * dy;

    if y >= 0 && y <= screenHeight
        candidates(end+1,:) = ...
            [t, screenWidth, y];
    end

end


%% Left edge

if dx < 0

    t = (0 - x0) / dx;

    y = y0 + t * dy;

    if y >= 0 && y <= screenHeight
        candidates(end+1,:) = ...
            [t, 0, y];
    end

end


%% Top edge

if dy < 0

    t = (0 - y0) / dy;

    x = x0 + t * dx;

    if x >= 0 && x <= screenWidth
        candidates(end+1,:) = ...
            [t, x, 0];
    end

end


%% Bottom edge

if dy > 0

    t = (screenHeight - y0) / dy;

    x = x0 + t * dx;

    if x >= 0 && x <= screenWidth
        candidates(end+1,:) = ...
            [t, x, screenHeight];
    end

end


%% Select nearest positive intersection

if isempty(candidates)

    error('Ray does not intersect monitor.');

end

[~, idx] = min(candidates(:,1));

xHit = candidates(idx,2);
yHit = candidates(idx,3);

end

function test_RFmap_flash

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
% RF MAP PARAMETERS
% =============================================================

angleStep = 10;

fanMin = -120;
fanMax = 120;

fanAngles = fanMin:angleStep:fanMax;

nTrapezoids = length(fanAngles) - 1;


% -------------------------------------------------------------
% Inner gap
% -------------------------------------------------------------

innerRadius_cm = 0.5;


% -------------------------------------------------------------
% Timing
% -------------------------------------------------------------

stimDuration = 1.0;     % seconds ON
blankDuration = 1.0;    % seconds OFF


%% ============================================================
% OPEN PSYCHTOOLBOX
% =============================================================

gray = 127;
white = [255 255 255];

[w, screenRect] = PsychImaging( ...
    'OpenWindow', screenNumber, gray);

HideCursor;

ifi = Screen('GetFlipInterval', w);


%% ============================================================
% PRECOMPUTE TRAPEZOIDS
% =============================================================

trapezoids = struct( ...
    'theta1', cell(1,nTrapezoids), ...
    'theta2', cell(1,nTrapezoids), ...
    'coords', cell(1,nTrapezoids));


for i = 1:nTrapezoids

    % ---------------------------------------------------------
    % Angular boundaries
    % ---------------------------------------------------------

    theta1 = fanAngles(i);
    theta2 = fanAngles(i+1);

    trapezoids(i).theta1 = theta1;
    trapezoids(i).theta2 = theta2;


    % ---------------------------------------------------------
    % INNER CORNERS
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
    % OUTER CORNERS
    % ---------------------------------------------------------

    [x1_outer, y1_outer] = rayScreenIntersection( ...
        mouseX_cm, mouseY_cm, theta1, ...
        screenWidth_cm, screenHeight_cm);

    [x2_outer, y2_outer] = rayScreenIntersection( ...
        mouseX_cm, mouseY_cm, theta2, ...
        screenWidth_cm, screenHeight_cm);


    % ---------------------------------------------------------
    % CONVERT TO PIXELS
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
    % STORE FOUR CORNERS
    % ---------------------------------------------------------

    trapezoids(i).coords = ...
        [xPix(:), yPix(:)];

end


%% ============================================================
% WAIT FOR USER TO START
% =============================================================

Screen('FillRect', w, gray);

Screen('DrawLine', w, [80 80 80], ...
    mouseX_pix, 0, ...
    mouseX_pix, screenHeight_pix, 2);

Screen('FillOval', w, [0 255 0], ...
    [ ...
    mouseX_pix-6, ...
    mouseY_pix-6, ...
    mouseX_pix+6, ...
    mouseY_pix+6 ...
    ]);

Screen('Flip', w);

KbStrokeWait;


%% ============================================================
% RUN RF MAP
% =============================================================

for i = 1:nTrapezoids

    %% --------------------------------------------------------
    % GRAY / OFF
    % ---------------------------------------------------------

    Screen('FillRect', w, gray);

    vbl = Screen('Flip', w);


    % Wait for blank interval
    vbl = vbl + blankDuration;

    while GetSecs < vbl
    end


    %% --------------------------------------------------------
    % TRAPEZOID ON
    % ---------------------------------------------------------

    Screen('FillRect', w, gray);

    Screen('FillPoly', w, white, ...
        trapezoids(i).coords);

    vbl = Screen('Flip', w);


    % ---------------------------------------------------------
    % Hold stimulus ON
    % ---------------------------------------------------------

    vbl = vbl + stimDuration;

    while GetSecs < vbl
    end


    %% --------------------------------------------------------
    % CHECK FOR ESCAPE
    % ---------------------------------------------------------

    [keyIsDown, ~, keyCode] = KbCheck;

    if keyIsDown && keyCode(KbName('ESCAPE'))
        break;
    end

end


%% ============================================================
% RETURN TO GRAY
% =============================================================

Screen('FillRect', w, gray);
Screen('Flip', w);

WaitSecs(1);


%% ============================================================
% CLEAN UP
% =============================================================

Screen('CloseAll');
ShowCursor;

end



%% ============================================================
% RAY / SCREEN INTERSECTION
% ============================================================

function [xHit, yHit] = rayScreenIntersection( ...
    x0, y0, theta, screenWidth, screenHeight)

% -------------------------------------------------------------
% 0 degrees = RIGHT
%
% Positive angles = DOWN
% Negative angles = UP
% -------------------------------------------------------------

dx = cosd(theta);
dy = sind(theta);


%% Candidate intersections

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


%% Select nearest intersection

if isempty(candidates)

    error('Ray does not intersect monitor.');

end

[~, idx] = min(candidates(:,1));

xHit = candidates(idx,2);
yHit = candidates(idx,3);

end
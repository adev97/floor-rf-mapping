function test_RFmap_angles

AssertOpenGL;

% Load all monitor information
monitorInformation;

% Use the monitor specified in monitorInformation
screenNumber = monitorInfo.screenNumber;

% Open screen
gray = 127;
[w, screenRect] = PsychImaging('OpenWindow', screenNumber, gray);

HideCursor;

% Pixel/cm conversion from monitorInformation
pixPerCmX = monitorInfo.screenSizePixX / monitorInfo.screenSizecmX;
pixPerCmY = monitorInfo.screenSizePixY / monitorInfo.screenSizecmY;

% Mouse-head projection on monitor
mouseX_cm = 30.0;
mouseY_cm = 15.0;

mouseX_pix = mouseX_cm * pixPerCmX;
mouseY_pix = monitorInfo.screenSizePixY - ...
             mouseY_cm * pixPerCmY;

% Test angles
testAngles = [0 45 70];

for i = 1:length(testAngles)

    theta = testAngles(i);

    % Distance along monitor from the head's projection
    r_cm = monitorInfo.screenDistcm * tand(theta);

    x_cm = mouseX_cm + r_cm * sind(theta);
    y_cm = mouseY_cm + r_cm * cosd(theta);

    x_pix = x_cm * pixPerCmX;
    y_pix = monitorInfo.screenSizePixY - y_cm * pixPerCmY;

    Screen('FillOval', w, [255 255 255], ...
        [x_pix-5 y_pix-5 x_pix+5 y_pix+5]);
end

% Mark head projection
Screen('FillOval', w, [0 255 0], ...
    [mouseX_pix-6 mouseY_pix-6 ...
     mouseX_pix+6 mouseY_pix+6]);

Screen('Flip', w);

KbStrokeWait;

sca;
ShowCursor;

end
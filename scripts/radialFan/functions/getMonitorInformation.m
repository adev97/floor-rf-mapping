function monitorInfo = getMonitorInformation()
%   monitorInfo = getMonitorInformation()
%
%   Converted from the old monitorInformation.m script, which injected a
%   monitorInfo variable into whatever workspace called it. As a
%   function that returns monitorInfo explicitly, every function that
%   needs rig info now takes it as an input argument instead of relying
%   on it having been silently created by a prior script call -- so the
%   dependency is visible in the function signature and callable/testable
%   on its own.
%%%%%%%%%%%%%%%%%%%%%%%% MONITOR INFORMATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
monitorInfo.screenNumber = 1;
monitorInfo.screenDistcm = 3; % distance of eyes from screen
monitorInfo.screenSizecmX = 54.5; % height of monitor
monitorInfo.screenSizecmY = 30.2; % width of monitor
monitorInfo.mouseOffsetXcm = 24.5; % x/y location of the mouse head on the screen
monitorInfo.mouseOffsetYcm = 15;
monitorInfo.screenSizeDegX = 2*atan(monitorInfo.screenSizecmX/2/...
                                monitorInfo.screenDistcm)*180/pi;
monitorInfo.screenSizeDegY = 2*atan(monitorInfo.screenSizecmY/2/...
                                monitorInfo.screenDistcm)*180/pi;
monitorInfo.screenSizePixX = 1920;
monitorInfo.screenSizePixY = 1080;
monitorInfo.degPerPix = monitorInfo.screenSizeDegX/...
                            monitorInfo.screenSizePixX;
monitorInfo.powerLawScaleFactor = .0001801;
monitorInfo.gamma = 2.386;
end

function trials = RFmapFast_FloorBubble_Static_master

monitorInformation;

sX = monitorInfo.screenSizeDegX;
sY = monitorInfo.screenSizeDegY;

%% Stimulus parameters

table = { ...
    'Sector Angle (deg)', -120, 10, 110;...
    'Sector Width (deg)', 10, [], [];...
    'Inner Gap (cm)', 0.5, [], [];...
    'Square Luminance (binary)', 0, 1, 1;...
    'Timing (delay,duration,wait)', 0, 0.095, 0;...
    'Blank', 0, [], [];...
    'Randomize', 0, [], [];... % 1, [], [];...
    'Interleave', 0, [], [];...
    'Repeats', 0, [], [];... % change for how many repeats + 1 you want
    'Initialization Screen (s)', 5, [], []};

stimType = 'Receptive Field Mapping';
tag = 'Run01';

%% Generate trials

trials = trialStruct_RFmapFloorBubble(stimType, table);

%% Run stimulus

ReceptiveFieldMapping_FloorBubble_Static(trials);

end

